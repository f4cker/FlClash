import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PACKAGING = Path(__file__).resolve().parents[1]
MACOS = PACKAGING.parent


def load(name):
    spec = importlib.util.spec_from_file_location('bundled_' + name, PACKAGING / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


STAGE = load('stage_bundle_payload')
MACHO = bytes.fromhex('cffaedfe') + b'synthetic-never-execute'
REVISION = '13e00727c64d2cc4d0bb20e293732d02c3ed0382'


def mock_codesign(calls):
    def codesign(*arguments):
        calls.append(arguments)
        return subprocess.CompletedProcess(arguments, 0, b'', b'CDHash=' + b'ab' * 20 + b'\n')
    return codesign


class BundledDaemonTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.app = self.root / 'Flash.app'
        self.write(STAGE.CORE, MACHO, 0o755)
        self.write(STAGE.HELPER, MACHO + plistlib.dumps({'CFBundleIdentifier': STAGE.HELPER_ID}), 0o755)
        self.write(STAGE.DAEMON_PLIST, (MACOS / 'PrivilegedHelper/com.layoute.flash.daemon.plist').read_bytes())
        self.write('Contents/Info.plist', plistlib.dumps({'CFBundleIdentifier': 'com.layoute.flash'}))

    def write(self, relative, data, mode=0o644):
        path = self.app / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(mode)
        return path

    def plist(self, **changes):
        data = dict(STAGE.DAEMON_SCHEMA, **changes)
        for key, value in list(data.items()):
            if value is None:
                del data[key]
        self.write(STAGE.DAEMON_PLIST, plistlib.dumps(data))

    def test_repository_plist_is_the_exact_schema_and_lints(self):
        source = MACOS / 'PrivilegedHelper/com.layoute.flash.daemon.plist'
        self.assertEqual(plistlib.loads(source.read_bytes()), STAGE.DAEMON_SCHEMA)
        subprocess.run(['/usr/bin/plutil', '-lint', str(source)], check=True, capture_output=True)
        self.assertFalse((MACOS / 'PrivilegedHelper/com.layoute.flash.helper.plist').exists())

    def test_plist_schema_label_and_bundle_program(self):
        facts = STAGE.check_layout(self.app)
        self.assertEqual(set(facts), {'core_sha256', 'helper_sha256', 'daemon_plist_sha256'})
        schema = STAGE.DAEMON_SCHEMA
        self.assertEqual(schema['Label'], 'com.layoute.flash.daemon')
        self.assertNotEqual(schema['Label'], STAGE.LEGACY_LABEL)
        self.assertEqual(schema['BundleProgram'], 'Contents/Library/HelperTools/FlashHelper')
        self.assertEqual(schema['MachServices'], {'com.layoute.flash.daemon': True})
        self.assertEqual(schema['AssociatedBundleIdentifiers'], ['com.layoute.flash'])
        for key in ('KeepAlive', 'RunAtLoad', 'Program', 'ProgramArguments', 'UserName'):
            self.assertNotIn(key, schema)

    def test_program_keys_and_schema_drift_are_rejected(self):
        for changes, message in [({'Program': '/Library/x'}, 'BundleProgram only'),
                                 ({'ProgramArguments': ['x']}, 'BundleProgram only'),
                                 ({'Label': STAGE.LEGACY_LABEL}, 'exact bundled schema'),
                                 ({'RunAtLoad': True}, 'exact bundled schema'),
                                 ({'AssociatedBundleIdentifiers': None}, 'exact bundled schema'),
                                 ({'BundleProgram': '/Library/PrivilegedHelperTools/x'}, 'exact bundled schema')]:
            with self.subTest(changes=changes):
                self.plist(**changes)
                with self.assertRaisesRegex(ValueError, message):
                    STAGE.check_layout(self.app)

    def test_bundle_program_must_exist_as_mach_o(self):
        (self.app / STAGE.HELPER).unlink()
        with self.assertRaises(FileNotFoundError):
            STAGE.check_layout(self.app)
        self.write(STAGE.HELPER, b'#!/bin/sh\n', 0o755)
        with self.assertRaisesRegex(ValueError, 'Mach-O'):
            STAGE.check_layout(self.app)
        self.write(STAGE.HELPER, MACHO + plistlib.dumps({'CFBundleIdentifier': 'other'}), 0o755)
        with self.assertRaisesRegex(ValueError, '__info_plist'):
            STAGE.check_layout(self.app)
        (self.app / STAGE.HELPER).unlink()
        (self.app / STAGE.HELPER).symlink_to(self.app / STAGE.CORE)
        with self.assertRaises(ValueError):
            STAGE.check_layout(self.app)

    def test_no_pkg_installer_or_legacy_artifacts(self):
        for relative in ('Contents/Resources/HelperInstaller/Flash-helper-install.pkg',
                         'Contents/Library/HelperTools/FlashMaintenance',
                         'Contents/Library/LaunchDaemons/com.layoute.flash.helper.plist'):
            with self.subTest(relative=relative):
                path = self.write(relative, MACHO, 0o755)
                with self.assertRaisesRegex(ValueError, 'Legacy helper artifact'):
                    STAGE.check_layout(self.app)
                path.unlink()
        self.write('Contents/Info.plist', plistlib.dumps({'CFBundleIdentifier': 'com.layoute.flash',
                                                          'FlashMinimumServiceBuild': '2026111503'}))
        with self.assertRaisesRegex(ValueError, 'FlashMinimumServiceBuild'):
            STAGE.check_layout(self.app)

    def test_extra_launch_daemons_or_tools_are_rejected(self):
        self.write('Contents/Library/LaunchDaemons/extra.plist', plistlib.dumps({}))
        with self.assertRaisesRegex(ValueError, 'LaunchDaemons'):
            STAGE.check_layout(self.app)

    def seal(self, **inputs):
        calls = []
        with patch.object(STAGE, 'codesign', side_effect=mock_codesign(calls)):
            contract = STAGE.seal_compatibility(self.app, inputs.get('version', 'v1.19.34'),
                                                inputs.get('revision', REVISION))
        return contract, calls

    def test_signed_verification_requires_plist_in_code_resources_files2(self):
        self.seal()
        files2 = {'Library/LaunchDaemons/com.layoute.flash.daemon.plist': {'hash2': b'x'},
                  'Library/HelperTools/FlashHelper': {'cdhash': b'x'}, 'MacOS/FlClashCore': {'cdhash': b'x'}}
        self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({'files2': files2}))
        calls = []
        with patch.object(STAGE, 'codesign', side_effect=mock_codesign(calls)):
            facts = STAGE.verify_signed(self.app)
            self.assertEqual(facts['helper_cdhash'], 'ab' * 20)
            verified = [args for args in calls if args[0] == '--verify']
            requirements = [arg for args in verified for arg in args if arg.startswith('-R=')]
            for identifier in ('com.layoute.flash.core', 'com.layoute.flash.helper', 'com.layoute.flash'):
                self.assertIn('-R=' + STAGE.requirement(identifier), requirements)
            self.assertTrue(all('certificate leaf = H"' + STAGE.CERTIFICATE_SHA1 + '"' in r for r in requirements))
            del files2['Library/LaunchDaemons/com.layoute.flash.daemon.plist']
            self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({'files2': files2}))
            with self.assertRaisesRegex(ValueError, 'not sealed in CodeResources files2'):
                STAGE.verify_signed(self.app)

    def test_signing_order_is_inside_out_with_the_unchanged_identity(self):
        signer = load('sign_fixed_payload')
        self.assertEqual(signer.CERTIFICATE_SHA1, STAGE.CERTIFICATE_SHA1)
        self.assertEqual([role for role, _, _ in signer.FIXED], ['core', 'helper'])
        self.assertEqual(dict((role, path) for role, path, _ in signer.FIXED),
                         {'core': STAGE.CORE, 'helper': STAGE.HELPER})
        self.assertEqual(dict((role, ident) for role, _, ident in signer.FIXED)['helper'], STAGE.HELPER_ID)
        self.assertEqual(STAGE.SIGNING_ORDER, ('core', 'contract', 'helper', 'framework', 'gui'))
        source = (PACKAGING / 'sign_fixed_payload.py').read_text()
        body = source[source.index('def signing_targets'):source.index('def requirement')]
        self.assertLess(body.index('for role, relative, identifier in FIXED'), body.index("role='framework'"))
        self.assertLess(body.index("role='framework'"), body.index("role='gui'"))
        self.assertNotIn('FlashMaintenance', source)
        self.assertEqual(signer.requirement('x'), STAGE.requirement('x'))

    def test_contract_is_sealed_after_core_signing_with_the_signed_core_hash(self):
        info = self.app / 'Contents/Info.plist'
        info.chmod(0o644)
        contract, calls = self.seal()
        # Core signature is verified against its pinned requirement before the contract is written.
        self.assertEqual(calls, [('--verify', '--strict', '--all-architectures',
                                  '-R=' + STAGE.requirement('com.layoute.flash.core'), str(self.app / STAGE.CORE))])
        self.assertEqual(contract, {'CallerPolicy': 3, 'ServiceAPI': 1, 'CoreAPI': 1,
                                    'CoreSHA256': hashlib.sha256(MACHO).hexdigest(),
                                    'CoreVersion': 'v1.19.34', 'CoreRevision': REVISION})
        stored = plistlib.loads(info.read_bytes())
        self.assertEqual(stored['FlashHelperCompatibility'], contract)
        self.assertEqual(stored['CFBundleIdentifier'], 'com.layoute.flash')
        self.assertEqual(info.stat().st_mode & 0o777, 0o644)
        self.assertFalse((self.app / 'Contents/.Info.plist.contract').exists())
        self.assertNotIn(True, [type(v) is bool for v in contract.values()])
        subprocess.run(['/usr/bin/plutil', '-lint', str(info)], check=True, capture_output=True)
        with self.assertRaisesRegex(ValueError, 'already present'):
            self.seal()

    def test_contract_sealing_keeps_binary_plist_format(self):
        self.write('Contents/Info.plist', plistlib.dumps({'CFBundleIdentifier': 'com.layoute.flash'},
                                                          fmt=plistlib.FMT_BINARY))
        self.seal()
        self.assertTrue((self.app / 'Contents/Info.plist').read_bytes().startswith(b'bplist00'))

    def test_contract_refuses_unsigned_core_outer_seal_and_bad_inputs(self):
        with patch.object(STAGE, 'codesign', side_effect=subprocess.CalledProcessError(1, 'codesign')):
            with self.assertRaises(subprocess.CalledProcessError):
                STAGE.seal_compatibility(self.app, 'v1.19.34', REVISION)
        self.assertIsNone(STAGE.read_contract(self.app))
        for version, revision in (('', REVISION), ('v1', ''), ('v' * 129, REVISION), (1, REVISION)):
            with self.subTest(version=version, revision=revision), self.assertRaisesRegex(ValueError, '1-128'):
                self.seal(version=version, revision=revision)
        self.assertIsNone(STAGE.read_contract(self.app))
        self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({}))
        with self.assertRaisesRegex(ValueError, 'before the app seal'):
            self.seal()
        self.assertIsNone(STAGE.read_contract(self.app))

    def test_contract_validation_mirrors_helper_compatibility(self):
        contract, _ = self.seal()
        self.assertEqual(STAGE.validate_contract(dict(contract)), contract)
        bad = [dict(contract, CallerPolicy=2), dict(contract, CallerPolicy=True), dict(contract, ServiceAPI=1.0),
               dict(contract, CoreAPI='1'), dict(contract, CoreSHA256=contract['CoreSHA256'].upper()),
               dict(contract, CoreSHA256='ab'), dict(contract, AcceptedCoreSHA256=[contract['CoreSHA256']]),
               dict(contract, CoreVersion=''), dict(contract, CoreRevision='r' * 129), [contract], None]
        for key in contract:
            missing = dict(contract)
            del missing[key]
            bad.append(missing)
        for value in bad:
            with self.subTest(value=value), self.assertRaises(ValueError):
                STAGE.validate_contract(value)
        # A malformed contract in Info.plist also fails the layout check.
        info = plistlib.loads((self.app / 'Contents/Info.plist').read_bytes())
        info['FlashHelperCompatibility']['CallerPolicy'] = 2
        self.write('Contents/Info.plist', plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError, 'CallerPolicy'):
            STAGE.check_layout(self.app)

    def test_signed_verification_requires_contract_bound_to_signed_core(self):
        files2 = {'Library/LaunchDaemons/com.layoute.flash.daemon.plist': {'hash2': b'x'},
                  'Library/HelperTools/FlashHelper': {'cdhash': b'x'}, 'MacOS/FlClashCore': {'cdhash': b'x'}}
        self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({'files2': files2}))
        with patch.object(STAGE, 'codesign', side_effect=mock_codesign([])):
            with self.assertRaisesRegex(ValueError, 'lacks the FlashHelperCompatibility'):
                STAGE.verify_signed(self.app)
        (self.app / 'Contents/_CodeSignature/CodeResources').unlink()
        (self.app / 'Contents/_CodeSignature').rmdir()
        contract, _ = self.seal()
        self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({'files2': files2}))
        with patch.object(STAGE, 'codesign', side_effect=mock_codesign([])):
            self.assertEqual(STAGE.verify_signed(self.app)['compatibility'], contract)
            # Core bytes changed after sealing (e.g. re-signed) -> contract no longer binds Core.
            self.write(STAGE.CORE, MACHO + b'resigned', 0o755)
            with self.assertRaisesRegex(ValueError, 'CoreSHA256 differs'):
                STAGE.verify_signed(self.app)

    def test_seal_command_line(self):
        with patch.object(STAGE, 'codesign', side_effect=mock_codesign([])), \
                contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(STAGE.main(['seal-compatibility', str(self.app), '--core-version', 'v1.19.34',
                                         '--core-revision', REVISION]), 0)
            self.assertEqual(STAGE.main(['seal-compatibility', str(self.app), '--core-version', 'v1.19.34',
                                         '--core-revision', REVISION]), 1)
        self.assertIn('CoreVersion=v1.19.34', out.getvalue())
        self.assertEqual(STAGE.read_contract(self.app)['CoreVersion'], 'v1.19.34')
        for argv in (['seal-compatibility', str(self.app)],
                     ['seal-compatibility', str(self.app), '--core-version', 'v1'],
                     ['check', str(self.app), '--core-version', 'v1']):
            with self.subTest(argv=argv), self.assertRaises(SystemExit), \
                    contextlib.redirect_stderr(io.StringIO()):
                STAGE.main(argv)

    def test_fresh_build_must_not_carry_a_contract(self):
        self.seal()
        with self.assertRaisesRegex(ValueError, 'only be sealed after Core signing'):
            STAGE.stage(self.app, self.root / 'run/gui/Flash.app')

    def test_stage_copies_exactly_and_refuses_overwrite(self):
        destination = self.root / 'run/gui/Flash.app'
        facts = STAGE.stage(self.app, destination)
        self.assertEqual(facts, STAGE.check_layout(self.app))
        STAGE.verify_copy(self.app, destination)
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            STAGE.stage(self.app, destination)
        (destination / STAGE.CORE).write_bytes(MACHO + b'changed')
        with self.assertRaisesRegex(ValueError, 'differs'):
            STAGE.verify_copy(self.app, destination)

    def test_xcode_phase_uses_bundled_daemon_staging(self):
        project = (MACOS / 'Runner.xcodeproj/project.pbxproj').read_text()
        self.assertIn('packaging/stage_bundled_daemon.sh', project)
        self.assertNotIn('stage_managed_helper.sh', project)
        self.assertIn('Shared/LegacyResidue.m', project)
        self.assertNotIn('HelperInstaller', project)
        for removed in ('build_split_packages.sh', 'build_managed_packages.sh', 'installer',
                        'embedded_helper_installer.py', 'stage_managed_helper.sh'):
            self.assertFalse((PACKAGING / removed).exists(), removed)


if __name__ == '__main__':
    unittest.main()
