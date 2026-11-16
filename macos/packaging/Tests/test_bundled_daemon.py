import importlib.util
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

    def test_signed_verification_requires_plist_in_code_resources_files2(self):
        files2 = {'Library/LaunchDaemons/com.layoute.flash.daemon.plist': {'hash2': b'x'},
                  'Library/HelperTools/FlashHelper': {'cdhash': b'x'}, 'MacOS/FlClashCore': {'cdhash': b'x'}}
        self.write('Contents/_CodeSignature/CodeResources', plistlib.dumps({'files2': files2}))
        calls = []

        def codesign(*arguments):
            calls.append(arguments)
            return subprocess.CompletedProcess(arguments, 0, b'', b'CDHash=' + b'ab' * 20 + b'\n')
        with patch.object(STAGE, 'codesign', side_effect=codesign):
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
        self.assertEqual(STAGE.SIGNING_ORDER, ('core', 'helper', 'framework', 'gui'))
        source = (PACKAGING / 'sign_fixed_payload.py').read_text()
        body = source[source.index('def signing_targets'):source.index('def requirement')]
        self.assertLess(body.index('for role, relative, identifier in FIXED'), body.index("role='framework'"))
        self.assertLess(body.index("role='framework'"), body.index("role='gui'"))
        self.assertNotIn('FlashMaintenance', source)
        self.assertEqual(signer.requirement('x'), STAGE.requirement('x'))

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
