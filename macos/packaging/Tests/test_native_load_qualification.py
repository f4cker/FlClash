import base64
import copy
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch

SPEC = importlib.util.spec_from_file_location(
    'qualification', Path(__file__).parents[1] / 'qualify_native_loads.py',
)
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)


class QualificationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.app = self.root / 'Flash.app'
        self.app.mkdir()
        self.scratch = self.root / 'scratch'
        self.scratch.mkdir(mode=0o700)
        self.evidence_root = self.root / 'evidence'
        self.evidence_root.mkdir(mode=0o700)
        self.evidence_path = self.evidence_root / 'observation.json'
        self.challenge = 'fresh_challenge_123456789'
        self.package_info = (
            '<pkg-info format-version="2" identifier="com.layoute.flash.managed.install" '
            'install-location="/" auth="root"><relocate/><scripts>'
            '<preinstall file="./preinstall"/><postinstall file="./postinstall"/>'
            '</scripts></pkg-info>'
        ).encode()
        self.protocol = {'schema': 1, 'challenge': self.challenge, 'ok': True, 'code': 'ok',
                         'probes': {name: True for name in Q.PROBES}}
        for name, value in (('SCRATCH_ROOT', self.scratch), ('EVIDENCE_ROOT', self.evidence_root)):
            replacement = patch.object(Q, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)
        forbidden = patch.object(Q.subprocess, 'Popen', side_effect=AssertionError('No actual process execution'))
        forbidden.start()
        self.addCleanup(forbidden.stop)

    def execution(self):
        scratch = self.scratch / 'session-fixture'
        stdout = (Q.PREFIX + json.dumps(self.protocol) + '\n').encode()
        return {'pid': 12345, 'owned': True, 'returncode': 0, 'timeout': False,
                'output_overflow': False, 'terminated_by_harness': False,
                'observed_executable': str(self.app / 'Contents/MacOS/Flash'),
                'architecture': 'arm64', 'duration_seconds': 0.5, 'challenge': self.challenge,
                'argv': ['/usr/bin/sandbox-exec', '-f', str(scratch / 'diagnostic.sb'),
                         '/usr/bin/arch', '-arm64', str(self.app / 'Contents/MacOS/Flash'),
                         '--flash-verify-native-loads', '--challenge=' + self.challenge],
                'sandbox_sha256': Q.digest(Q.sandbox_profile(self.app, scratch).encode()),
                'stdout_base64': base64.b64encode(stdout).decode(), 'stdout_sha256': Q.digest(stdout),
                'stderr_base64': '', 'stderr_sha256': Q.digest(b'')}

    def state(self):
        return {'host': {'architecture': 'arm64'}, 'inventory': {'resource': {'sha256': 'fixture'}},
                'static_report_sha256': 'static', 'build_metadata_sha256': 'metadata',
                'source_sha256': {'qualify_native_loads.py': 'harness'}, 'pins': {'sha1': 'fixed'}}

    def evidence(self):
        return {'schema': 1, 'qualified': True, 'actualGUIloads': True, 'packaging_accepted': False,
                'before': self.state(), 'after': self.state(), 'execution': self.execution(),
                'protocol': self.protocol}

    def test_exact_protocol_requires_fresh_challenge_all_four_and_real_booleans(self):
        encoded = lambda value: (Q.PREFIX + json.dumps(value) + '\n').encode()
        self.assertEqual(Q.parse_protocol(encoded(self.protocol), self.challenge), self.protocol)
        defects = []
        for key, value in (('schema', True), ('schema', 2), ('challenge', 'other_token_123456'),
                           ('ok', 1), ('ok', False), ('code', 'partial')):
            result = copy.deepcopy(self.protocol)
            result[key] = value
            defects.append(result)
        for name in Q.PROBES:
            for value in (False, 1, None):
                result = copy.deepcopy(self.protocol)
                result['probes'][name] = value
                defects.append(result)
        result = copy.deepcopy(self.protocol)
        result['probes']['unknown'] = True
        defects.append(result)
        result = copy.deepcopy(self.protocol)
        del result['probes']['sqlite_memory']
        defects.append(result)
        for result in defects:
            with self.subTest(result=result), self.assertRaises(ValueError):
                Q.parse_protocol(encoded(result), self.challenge)
        for output in (b'', encoded(self.protocol) * 2, b'FLASH_NATIVE_LOADS not-json\n'):
            with self.subTest(output=output), self.assertRaises(ValueError):
                Q.parse_protocol(output, self.challenge)
        with self.assertRaises(ValueError):
            Q.parse_protocol(encoded(self.protocol), '../invalid')

    def test_exit_pid_arch_bounds_command_and_sandbox_cannot_be_freely_asserted(self):
        record = self.execution()
        Q.validate_execution(record, self.app, 'arm64')
        for key, value in (
            ('pid', 0), ('pid', True), ('owned', False), ('returncode', True), ('returncode', 70),
            ('returncode', -9), ('timeout', True), ('output_overflow', True),
            ('terminated_by_harness', True), ('architecture', 'x86_64'),
            ('observed_executable', '/Applications/Flash.app/Contents/MacOS/Flash'),
            ('duration_seconds', 99), ('stdout_sha256', 'changed'), ('stderr_base64', '%%%'),
            ('sandbox_sha256', 'changed'), ('argv', ['/bin/sh', '-c', 'bad']),
        ):
            changed = copy.deepcopy(record)
            changed[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                Q.validate_execution(changed, self.app, 'arm64')

    def test_stale_or_different_artifact_report_metadata_os_sources_fail(self):
        Q.validate_evidence(self.evidence(), self.state(), self.app)
        for key, value in (('qualified', False), ('actualGUIloads', False), ('packaging_accepted', True)):
            evidence = copy.deepcopy(self.evidence())
            evidence[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_evidence(evidence, self.state(), self.app)
        for key in self.state():
            changed = copy.deepcopy(self.state())
            changed[key] = 'modified'
            with self.subTest(key=key), self.assertRaises(ValueError):
                Q.validate_evidence(self.evidence(), changed, self.app)
        evidence = copy.deepcopy(self.evidence())
        evidence['after']['inventory'] = {}
        with self.assertRaises(ValueError):
            Q.validate_evidence(evidence, self.state(), self.app)

    def test_sandbox_real_data_keychain_evidence_and_helper_are_denied(self):
        profile = Q.sandbox_profile(self.app, self.scratch)
        self.assertEqual(profile.splitlines()[:3], ['(version 1)', '(debug deny)', '(deny default)'])
        self.assertEqual(profile.count('(debug deny)'), 1)
        self.assertNotIn('(with report)', profile)
        for directive in ('(deny default)', '(import "dyld-support.sb")',
                          '(deny network*)', '(deny process-fork)', '(deny sysctl-write)',
                          '(deny file-write* (require-not (subpath ' + json.dumps(str(self.scratch)) + ')))',
                          '(deny mach-lookup (global-name "com.layoute.flash.helper"))'):
            self.assertIn(directive, profile)
        for path in Q.denied_paths():
            self.assertIn('(deny file-read* (subpath ' + json.dumps(str(path)) + '))', profile)
        self.assertIn('Library/Application Support/com.layoute.flash', profile)
        self.assertIn('Library/Application Support/com.follow.clash', profile)
        self.assertIn('Library/Application Support/Flash Signing', profile)
        self.assertIn('/Library/Application Support/Flash', profile)
        writes = [line for line in profile.splitlines() if 'allow file-write' in line]
        self.assertEqual(writes, ['(allow file-write* (subpath ' + json.dumps(str(self.scratch)) + '))'])
        self.assertNotIn('(allow network', profile)
        self.assertNotIn('(allow process-fork', profile)
        self.assertNotIn('(allow mach-lookup)', profile)
        self.assertEqual(
            [line.strip() for line in profile.splitlines() if 'iokit' in line],
            ['(allow iokit-open-user-client (iokit-user-client-class "IOGPUDeviceUserClient")',
             '(iokit-user-client-class "AGXDeviceUserClient")',
             '(iokit-user-client-class "IOSurfaceRootUserClient"))'],
        )
        self.assertEqual(profile.count('(allow iokit'), 1)
        for unapproved in ('iokit-open-service', 'IOAccelerator', 'IOSurfaceSendRight'):
            self.assertNotIn(unapproved, profile)
        allowed_names = [
            'com.apple.windowserver.active', 'com.apple.CARenderServer',
            'com.apple.MTLCompilerService', 'com.apple.coreservices.launchservicesd',
            'com.apple.CoreServices.coreservicesd',
        ]
        exact_lookup = '(allow mach-lookup ' + ' '.join(
            '(global-name ' + json.dumps(name) + ')' for name in allowed_names
        ) + ')'
        self.assertIn(exact_lookup, ' '.join(profile.split()))
        self.assertEqual(profile.count('(allow mach-lookup'), 1)
        self.assertCountEqual(
            [json.loads(part.split(')', 1)[0]) for part in profile.split('(global-name ')[1:]],
            allowed_names + ['com.layoute.flash.helper'],
        )
        for unapproved in ('pasteboard', 'tcc', 'opendirectory', 'logd',
                           'distributednotifications', 'DiskArbitration', 'lsd.openurl'):
            self.assertFalse(any(unapproved.lower() in name.lower() for name in allowed_names))
        self.assertTrue(any('OS-managed' in caveat for caveat in Q.CAVEATS))

    def test_host_evidence_binds_installed_dyld_bootstrap_policy(self):
        version = plistlib.dumps({'ProductVersion': 'fixture-version', 'ProductBuildVersion': 'fixture-build'})
        info = types.SimpleNamespace(sysname='Darwin', machine='arm64', release='fixture-release', version='fixture')
        with patch.object(Q.os, 'uname', return_value=info):
            with patch.object(Q.Path, 'read_bytes', side_effect=[version, b'OS-dyld-policy']):
                host = Q.host()
        self.assertEqual(host['dyld_bootstrap_profile_sha256'], Q.digest(b'OS-dyld-policy'))
        self.assertEqual(host['product_build'], 'fixture-build')
        self.assertEqual(host['architecture'], 'arm64')
        for nested in (b'(import "other.sb")', b'(include "other.sb")'):
            with patch.object(Q.os, 'uname', return_value=info):
                with patch.object(Q.Path, 'read_bytes', side_effect=[version, nested]):
                    with self.subTest(nested=nested), self.assertRaises(ValueError):
                        Q.host()
        evidence = self.evidence()
        evidence['before']['host'] = host
        evidence['after']['host'] = host
        current = copy.deepcopy(evidence['before'])
        Q.validate_evidence(evidence, current, self.app)
        current['host']['dyld_bootstrap_profile_sha256'] = Q.digest(b'changed-OS-dyld-policy')
        with self.assertRaises(ValueError):
            Q.validate_evidence(evidence, current, self.app)

    def fake_process(self, stdout):
        process = MagicMock()
        process.pid = 12345
        for name, data in (('stdout', stdout), ('stderr', b'')):
            reader, writer = os.pipe()
            os.write(writer, data)
            os.close(writer)
            setattr(process, name, os.fdopen(reader, 'rb'))
        process.poll.return_value = 0
        process.wait.return_value = 0
        return process

    def test_mock_supervision_uses_only_diagnostic_args_and_clean_fake_home(self):
        stdout = (Q.PREFIX + json.dumps(self.protocol) + '\n').encode()
        process = self.fake_process(stdout)
        work = self.scratch / 'session-fixture'
        work.mkdir(mode=0o700)
        with patch.object(Q.subprocess, 'Popen', return_value=process) as spawn:
            with patch.object(Q, 'executable_for_pid', return_value=str(self.app / 'Contents/MacOS/Flash')):
                record = Q.supervise(self.app, work, self.challenge, 'arm64')
        Q.validate_execution(record, self.app, 'arm64')
        arguments, kwargs = spawn.call_args.args[0], spawn.call_args.kwargs
        self.assertEqual(arguments[-2:], ['--flash-verify-native-loads', '--challenge=' + self.challenge])
        self.assertEqual(arguments[:2], ['/usr/bin/sandbox-exec', '-f'])
        self.assertEqual(kwargs['env']['HOME'], str(work / 'home'))
        self.assertEqual(kwargs['env']['CFFIXED_USER_HOME'], str(work / 'home'))
        for forbidden in ('DYLD_INSERT_LIBRARIES', 'CODESIGN_ALLOCATE', 'PYTHONPATH', 'SSH_AUTH_SOCK'):
            self.assertNotIn(forbidden, kwargs['env'])
        self.assertTrue(kwargs['start_new_session'])
        self.assertEqual(kwargs['stdin'], subprocess.DEVNULL)
        self.assertNotIn('shell', kwargs)
        process.kill.assert_not_called()

    def test_mock_timeout_and_overflow_kill_only_owned_pid_and_reap(self):
        for defect in ('timeout', 'overflow'):
            process = self.fake_process(b'fixture')
            process.poll.return_value = None
            process.kill.side_effect = lambda: setattr(process.poll, 'return_value', -9)
            process.wait.return_value = -9
            work = self.scratch / ('session-' + defect)
            work.mkdir()
            with patch.object(Q.subprocess, 'Popen', return_value=process):
                with patch.object(Q, 'executable_for_pid', return_value='fixture'):
                    if defect == 'timeout':
                        with patch.object(Q.time, 'monotonic', side_effect=[0, 30, 31]):
                            record = Q.supervise(self.app, work, self.challenge, 'arm64')
                    else:
                        with patch.object(Q.os, 'read', return_value=b'x' * (Q.OUTPUT_LIMIT + 1)):
                            record = Q.supervise(self.app, work, self.challenge, 'arm64')
            self.assertTrue(record['timeout'] if defect == 'timeout' else record['output_overflow'])
            self.assertTrue(record['terminated_by_harness'])
            process.kill.assert_called_once_with()
            process.wait.assert_called_with(timeout=3)
            with self.assertRaises(ValueError):
                Q.validate_execution(record, self.app, 'arm64')

    def test_verify_mode_cannot_launch_probe_and_checks_current_snapshot(self):
        with patch.object(Q, 'driver', return_value=MagicMock()) as signer:
            with patch.object(Q, 'protected_json', return_value=(self.evidence(), 'hash')):
                with patch.object(Q, 'make_scratch', return_value=tempfile.TemporaryDirectory(dir=self.root)):
                    with patch.object(Q, 'frozen_state', return_value=self.state()) as frozen:
                        with patch.object(Q, 'supervise', side_effect=AssertionError('Must not run')):
                            Q.verify(self.app, self.root / 'metadata.json', self.evidence_path)
        frozen.assert_called_once()
        signer.assert_called_once()

    def test_probe_evidence_exclusive_and_changed_after_state_is_failed(self):
        signer = MagicMock()
        with patch.object(Q, 'driver', return_value=signer), patch.object(Q, 'secrets') as secrets:
            secrets.token_urlsafe.return_value = self.challenge
            with patch.object(Q, 'make_scratch', side_effect=lambda: tempfile.TemporaryDirectory(dir=self.root)):
                with patch.object(Q, 'frozen_state', side_effect=[self.state(), {'changed': True}]):
                    with patch.object(Q, 'supervise', return_value=self.execution()):
                        with self.assertRaises(ValueError):
                            Q.run_approved(self.app, self.root / 'metadata.json', self.evidence_path)
                evidence = json.loads(self.evidence_path.read_bytes())
                self.assertIs(evidence['qualified'], False)
                self.assertIs(evidence['actualGUIloads'], False)
                self.assertIs(evidence['packaging_accepted'], False)
                self.assertEqual(self.evidence_path.stat().st_mode & 0o777, 0o600)
                with patch.object(Q, 'frozen_state', return_value=self.state()):
                    with patch.object(Q, 'supervise') as supervise, self.assertRaises(FileExistsError):
                        Q.run_approved(self.app, self.root / 'metadata.json', self.evidence_path)
                    supervise.assert_not_called()

    def test_copy_and_expanded_package_must_preserve_signed_inventory(self):
        signer = MagicMock()
        signer.inventory.return_value = {'code': {'sha256': 'exact'}}
        expected = {'inventory': {'code': {'sha256': 'exact'},
                                 'Contents/Library/HelperTools/FlashMaintenance': {'sha256': Q.digest(b'maintenance')}}}
        signer.inventory.return_value = expected['inventory']
        Q.check_copy(self.app, expected, signer)
        signer.inventory.return_value = {'code': {'sha256': 'modified'}}
        with self.assertRaises(ValueError):
            Q.check_copy(self.app, expected, signer)
        signer.inventory.return_value = expected['inventory']
        expanded = self.root / 'expanded'
        required = expanded / 'Payload/Library/Application Support/Flash/.incoming/Flash.app'
        required.mkdir(parents=True)
        scripts = expanded / 'Scripts'
        scripts.mkdir()
        for name in ('preinstall', 'postinstall', 'FlashMaintenance'):
            (scripts / name).write_bytes(b'fixture')
        signer.read_regular.side_effect = lambda path: (
            self.package_info if path.name == 'PackageInfo' else b'maintenance')
        Q.check_expanded(expanded, 'install', expected, signer)
        with self.assertRaises(ValueError):
            Q.check_expanded(expanded, 'repair', expected, signer)
        expected['inventory']['Contents/Library/HelperTools/FlashMaintenance']['sha256'] = 'changed'
        with self.assertRaises(ValueError):
            Q.check_expanded(expanded, 'install', expected, signer)

    def test_package_info_enforces_fixed_root_exact_hooks_and_no_relocation(self):
        base = self.package_info.decode()
        mutations = (
            ('install-location="/"', 'install-location="/tmp"'),
            ('install-location="/"', ''),
            ('pkg-info', 'other-info'),
            ('<scripts>', '<scripts timeout="99">'),
            ('<preinstall file="./preinstall"/>', ''),
            ('<postinstall file="./postinstall"/>', ''),
            ('file="./preinstall"', 'file="./postinstall"'),
            ('file="./postinstall"', 'file="/tmp/postinstall"'),
            ('file="./preinstall"', 'file="./preinstall" component="other"'),
            ('<postinstall file="./postinstall"/>', '<preinstall file="./preinstall"/>'),
            ('</scripts>', '<other file="./preinstall"/></scripts>'),
            ('</scripts>', '</scripts><scripts/>'),
            ('<scripts><preinstall file="./preinstall"/><postinstall file="./postinstall"/></scripts>', ''),
            ('<relocate/>', '<relocate><bundle id="com.layoute.flash" path="/tmp/Flash.app"/></relocate>'),
            ('<relocate/>', '<relocate search="true"/>'),
            ('<relocate/>', '<relocate/><relocate/>'),
        )
        signer = MagicMock()
        for original, changed in mutations:
            metadata = base.replace(original, changed).encode()
            self.assertNotEqual(metadata, self.package_info)
            signer.read_regular.side_effect = lambda path: (
                metadata if path.name == 'PackageInfo' else self.fail('Invalid metadata accepted'))
            with self.subTest(original=original, changed=changed), self.assertRaises(ValueError):
                Q.check_expanded(self.root / 'expanded', 'install', {}, signer)

    def test_frozen_state_binds_full_static_report_build_metadata_and_sources(self):
        signer = MagicMock()
        signer.CERTIFICATE_SHA1, signer.CERTIFICATE_SHA256 = 'CERT1', 'CERT256'
        signer.staging_path.return_value = self.app
        signer.tree_digest.return_value = 'tree'
        entries = {'Contents/MacOS/Flash': {'sha256': 'all-signed-bytes'}}
        signer.inventory.return_value = entries
        signer.trusted_verifier.return_value.load_commands.return_value = {'arm64': ([], [])}
        base_target = {'role': 'gui', 'binary': 'Contents/MacOS/Flash', 'path': '.',
                       'identifier': 'com.layoute.flash', 'entitlements': {'library-exception': True}}
        signer.signing_targets.side_effect = lambda *args: [copy.deepcopy(base_target)]
        signer.verify_target.return_value = {'arm64': {'flags': 'runtime', 'certificate': 'fixed'}}
        target = dict(base_target, architectures=['arm64'], verified_slices=signer.verify_target.return_value)
        info = {'CFBundleShortVersionString': '0.9.7', 'CFBundleVersion': '2026111301',
                'FlashDartDefines': base64.b64encode(b'MACOS_MANAGED_HELPER=true').decode()}
        signer.read_regular.side_effect = lambda path: (
            plistlib.dumps(info) if path == self.app / 'Contents/Info.plist' else path.name.encode())
        report = {'schema': 1, 'static_verification': True, 'actualGUIloads': False,
                  'packaging_accepted': False, 'app': str(self.app),
                  'pins': {'certificate_sha1': 'CERT1', 'certificate_sha256': 'CERT256'},
                  'after': {'tree_sha256': 'tree', 'entries': entries}, 'targets': [target],
                  'inputs': {'driver_sha256': Q.digest(b'sign_fixed_payload.py'),
                             'verifier_sha256': Q.digest(b'stage_managed_payload.py'),
                             'gui_entitlements_sha256': Q.digest(b'FixedGUI.entitlements')},
                  'defines': {'intended_static_candidate': {'MACOS_MANAGED_HELPER': True,
                              'FC_PINNED_CERTIFICATE_SHA1': 'CERT1', 'FC_MANAGED_CANDIDATE_ENABLED': 1}}}
        metadata = {'version': '0.9.7', 'build_number': '2026111301',
                    'certificate_sha1': 'CERT1', 'apple_team': '', 'runtime_acceptance': False,
                    'actualGUIloads': False, 'packaging_accepted': False,
                    'defines': {'APP_ENV': 'stable', 'MACOS_MANAGED_HELPER': True,
                                'FC_MANAGED_CANDIDATE_ENABLED': 1}}
        def freeze(report_value, metadata_value):
            with tempfile.TemporaryDirectory(dir=self.root) as scratch:
                with patch.object(Q, 'protected_json', side_effect=[(report_value, 'static-hash'),
                                                                    (metadata_value, 'metadata-hash')]):
                    with patch.object(Q, 'host', return_value={'architecture': 'arm64'}):
                        return Q.frozen_state(self.app, self.root / 'metadata.json', signer, Path(scratch))
        result = freeze(report, metadata)
        self.assertEqual(result['inventory'], entries)
        self.assertEqual(result['static_report_sha256'], 'static-hash')
        self.assertEqual(result['build_metadata_sha256'], 'metadata-hash')
        self.assertEqual(result['targets'], [target])
        for key, value in (('actualGUIloads', True), ('packaging_accepted', True),
                           ('runtime_acceptance', True), ('build_number', 'other'),
                           ('certificate_sha1', 'other')):
            changed = copy.deepcopy(metadata)
            changed[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                freeze(report, changed)
        for candidate in (0, True, '1', None):
            changed = copy.deepcopy(metadata)
            changed['defines']['FC_MANAGED_CANDIDATE_ENABLED'] = candidate
            with self.subTest(candidate=candidate), self.assertRaises(ValueError):
                freeze(report, changed)
        for key in ('after', 'inputs', 'targets'):
            changed = copy.deepcopy(report)
            changed[key] = None
            with self.subTest(key=key), self.assertRaises(ValueError):
                freeze(changed, metadata)
        info['FlashDartDefines'] += ',' + base64.b64encode(b'MACOS_MANAGED_HELPER=false').decode()
        with self.assertRaises(ValueError):
            freeze(report, metadata)

    def test_package_builder_requires_explicit_evidence_before_output_and_expands_static(self):
        script = (Path(__file__).parents[1] / 'build_managed_packages.sh').read_text()
        self.assertIn('"$#" == 4', script)
        self.assertNotIn('FC_ARTIFACT_LOADS_VERIFIED', script)
        self.assertNotIn('FC_PACKAGE_CERTIFICATE_SHA1', script)
        self.assertLess(script.index('\nverify_evidence\n'), script.index('/bin/mkdir -m 0700'))
        self.assertLess(script.index('/usr/bin/ditto'), script.index('verify_evidence --verify-copy'))
        self.assertIn('/usr/sbin/pkgutil --expand-full', script)
        self.assertLess(script.index('--expand-full'), script.index('verify_evidence --verify-expanded-package'))
        for forbidden in ('/usr/sbin/installer', '/bin/launchctl', 'sudo ', 'open -a'):
            self.assertNotIn(forbidden, script)


if __name__ == '__main__':
    unittest.main()
