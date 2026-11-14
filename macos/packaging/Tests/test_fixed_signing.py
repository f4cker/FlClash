import base64
import copy
import errno
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch

SPEC = importlib.util.spec_from_file_location(
    'fixed_signing', Path(__file__).parents[1] / 'sign_fixed_payload.py',
)
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)


class SigningPolicyTests(unittest.TestCase):
    def setUp(self):
        old_umask = os.umask(0o077)
        self.addCleanup(os.umask, old_umask)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.app = self.root / '.airbuild/candidate/Flash.app'
        self.app.mkdir(parents=True, mode=0o755)
        self.calls = []
        self.certificate = b'synthetic-public-certificate-not-a-real-identity'
        self.pin1 = hashlib.sha1(self.certificate).hexdigest().upper()
        self.pin256 = hashlib.sha256(self.certificate).hexdigest().upper()
        for name, value in (
            ('WORKTREE', self.root), ('CERTIFICATE_SHA1', self.pin1),
            ('CERTIFICATE_SHA256', self.pin256),
        ):
            replacement = patch.object(DRIVER, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)
        acl = patch.object(DRIVER, 'require_no_acl')
        self.acl = acl.start()
        self.addCleanup(acl.stop)
        self.verifier = DRIVER.trusted_verifier()
        self.make_payload()
        for directory, _, _ in os.walk(self.root):
            Path(directory).chmod(0o755)
        self.root.chmod(0o700)
        execution = patch.object(DRIVER, 'run_tool', side_effect=self.tool)
        execution.start()
        self.addCleanup(execution.stop)
        forbidden = patch.object(DRIVER.subprocess, 'run', side_effect=AssertionError('No real tools'))
        forbidden.start()
        self.addCleanup(forbidden.stop)

    def write(self, relative, data, mode=0o644):
        path = self.app / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(mode)
        return path

    def binary(self, relative):
        return self.write(relative, bytes.fromhex('cffaedfe') + b'synthetic-never-execute', 0o755)

    def make_payload(self):
        self.binary('Contents/MacOS/Flash')
        self.write('Contents/Info.plist', plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleExecutable': 'Flash',
        }))
        for _, relative, _ in DRIVER.FIXED:
            self.binary(relative)
        for name, identifier in DRIVER.FRAMEWORKS.items():
            framework = self.app / f'Contents/Frameworks/{name}.framework'
            self.binary(f'Contents/Frameworks/{name}.framework/Versions/A/{name}')
            self.write(f'Contents/Frameworks/{name}.framework/Versions/A/Resources/Info.plist',
                       plistlib.dumps({'CFBundleIdentifier': identifier, 'CFBundleExecutable': name}))
            (framework / 'Versions/Current').symlink_to('A')
            (framework / name).symlink_to(f'Versions/Current/{name}')
            (framework / 'Resources').symlink_to('Versions/Current/Resources')
        self.write('Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/'
                   'NativeAssetsManifest.json', json.dumps({
                       'format-version': [1, 0, 0], 'native-assets': {
                           platform: {key: ['absolute', f'@executable_path/../Frameworks/{name}.framework/{name}']
                                      for key, name in self.verifier.ASSETS.items()}
                           for platform in self.verifier.PLATFORMS.values()
                       },
                   }).encode())

    def targets(self):
        return DRIVER.signing_targets(self.app, DRIVER.inventory(self.app, self.verifier))

    def tool(self, arguments):
        self.calls.append(arguments)
        stdout, stderr = b'', b''
        if arguments[0] == '/usr/bin/lipo':
            stdout = b'arm64 x86_64'
        elif arguments[0] == '/usr/bin/otool':
            stdout = '\n'.join(f'{arguments[-1]} (architecture {architecture}):'
                               for architecture in ('arm64', 'x86_64')).encode()
        elif arguments[0] == '/usr/bin/codesign':
            if '--verbose=4' in arguments:
                target = next(target for target in self.targets()
                              if str(self.app / target['path']) == arguments[-1])
                stderr = (f'Identifier={target["identifier"]}\n'
                          'CodeDirectory v=20500 size=1 flags=0x10000(runtime) hashes=1+1\n'
                          'TeamIdentifier=not set\n').encode()
            elif any(argument.startswith('--extract-certificates=') for argument in arguments):
                prefix = next(argument.split('=', 1)[1] for argument in arguments
                              if argument.startswith('--extract-certificates='))
                Path(prefix + '0').write_bytes(self.certificate)
            elif '--entitlements' in arguments and '--display' in arguments:
                stdout = plistlib.dumps(DRIVER.GUI_ENTITLEMENTS if arguments[-1] == str(self.app) else {})
        else:
            self.fail(f'Unexpected tool: {arguments}')
        return subprocess.CompletedProcess(arguments, 0, stdout, stderr)

    def execute(self):
        with patch('builtins.print'):
            return DRIVER.execute(str(self.app), DRIVER.KEYCHAIN, self.pin1)

    def test_complete_mock_signing_binds_every_file_and_keeps_runtime_gates_false(self):
        report = json.loads(self.execute().read_text())
        self.assertTrue(report['static_verification'])
        for key in ('actualGUIloads', 'packaging_accepted', 'runtime_gate_changed'):
            self.assertIs(report[key], False)
        self.assertEqual(report['after']['tree_sha256'], DRIVER.tree_digest(report['after']['entries']))
        self.assertEqual(len(report['targets']), 9)
        for target in report['targets']:
            self.assertEqual(target['architectures'], ['arm64', 'x86_64'])
            self.assertEqual(set(target['verified_slices']), {'arm64', 'x86_64'})
            self.assertIn('sha256', report['after']['entries'][target['binary']])
        signing = [args for args in self.calls if '--sign' in args]
        self.assertEqual(len(signing), 9)
        self.assertEqual(signing[-1][-1], str(self.app))
        for args in signing:
            self.assertNotIn('--deep', args)
            self.assertIn('--timestamp=none', args)
            self.assertEqual(args[args.index('--keychain') + 1], DRIVER.KEYCHAIN)
            self.assertEqual(args[args.index('--sign') + 1], self.pin1)
            self.assertEqual(args[args.index('--options') + 1], 'runtime')
            self.assertIn('=designated => ', args[args.index('--requirements') + 1])
        self.assertTrue(any('--deep' in args and '--verify' in args for args in self.calls))
        verify = [args for args in self.calls if '-R' in args]
        self.assertEqual(len(verify), 9)
        for arguments in verify:
            target = next(target for target in report['targets'] if str(self.app / target['path']) == arguments[-1])
            self.assertEqual(arguments[arguments.index('-R') + 1], '=' + DRIVER.requirement(target['identifier']))
        extractions = [args for args in self.calls if any(arg.startswith('--extract-certificates=') for arg in args)]
        self.assertEqual(len(extractions), 18)
        for arguments in extractions:
            self.assertNotIn('--extract-certificates', arguments)
            self.assertTrue(arguments[-2].startswith('--extract-certificates='))
        self.assertEqual(report['defines']['artifact_values'], 'not established by static signing')
        self.assertEqual(report['defines']['intended_static_candidate']['FC_MANAGED_CANDIDATE_ENABLED'], 1)
        self.assertNotIn('FC_MANAGED_GUI_LOADS_VERIFIED', report['defines'])

    def test_only_gui_gets_minimal_library_exception(self):
        for target in self.targets():
            expected = DRIVER.GUI_ENTITLEMENTS if target['role'] == 'gui' else {}
            self.assertEqual(target['entitlements'], expected)
            for forbidden in ('com.apple.security.get-task-allow',
                              'com.apple.security.cs.allow-dyld-environment-variables'):
                self.assertNotIn(forbidden, target['entitlements'])
        source = Path(__file__).parents[1] / 'FixedGUI.entitlements'
        self.assertEqual(plistlib.loads(source.read_bytes()), DRIVER.GUI_ENTITLEMENTS)

    def test_staging_rejects_external_relative_noncanonical_and_original_artifact(self):
        for value in ('Flash.app', str(self.root / 'Flash.app'), str(self.app) + '/',
                      str(self.app.parent / '../candidate/Flash.app'),
                      str(DRIVER.PACKAGING.parents[1] / 'build/macos/Build/Products/Release/Flash.app')):
            with self.subTest(value=value), self.assertRaises((ValueError, OSError)):
                DRIVER.staging_path(value)
        self.assertEqual(DRIVER.staging_path(str(self.app)), self.app)

    def test_symlinked_staging_parent_rejected(self):
        alias = self.root / '.airbuild/alias'
        alias.symlink_to(self.app.parent)
        with self.assertRaises(ValueError):
            DRIVER.staging_path(str(alias / 'Flash.app'))

    def test_wrong_keychain_certificate_and_root_fail_before_tools(self):
        for keychain, certificate in ((DRIVER.KEYCHAIN + '.other', self.pin1),
                                      (DRIVER.KEYCHAIN, '0' * 40)):
            with self.assertRaises(ValueError):
                DRIVER.execute(str(self.app), keychain, certificate)
        with patch.object(DRIVER.os, 'getuid', return_value=0), self.assertRaises(ValueError):
            self.execute()
        self.assertEqual(self.calls, [])

    def test_unreviewed_driver_location_fails(self):
        with patch.object(DRIVER, '__file__', str(self.root / 'driver.py')):
            with self.assertRaises(ValueError):
                self.execute()
        self.assertEqual(self.calls, [])

    def test_verifier_hash_change_fails_before_exec(self):
        with patch.object(DRIVER, 'read_regular', return_value=b'raise AssertionError("must not execute")'):
            with self.assertRaisesRegex(ValueError, 'verifier changed'):
                DRIVER.trusted_verifier()

    def test_unknown_macho_or_framework_is_not_signed(self):
        self.binary('Contents/Resources/hidden')
        with self.assertRaisesRegex(ValueError, 'Mach-O'):
            self.execute()
        self.assertEqual(self.calls, [])

    def test_extra_framework_and_missing_fixed_code_rejected(self):
        extra = self.app / 'Contents/Frameworks/Injected.framework'
        extra.mkdir()
        with self.assertRaisesRegex(ValueError, 'framework'):
            self.targets()
        extra.rmdir()
        (self.app / DRIVER.FIXED[0][1]).unlink()
        with self.assertRaisesRegex(ValueError, 'Mach-O'):
            self.targets()

    def test_bundle_identity_cannot_be_supplied_by_untrusted_payload(self):
        self.write('Contents/Info.plist', plistlib.dumps({
            'CFBundleIdentifier': 'com.evil.app', 'CFBundleExecutable': 'Flash',
        }))
        with self.assertRaisesRegex(ValueError, 'identity'):
            self.targets()

    def test_unsafe_modes_are_rejected_independently_of_filesystem_chmod(self):
        path = self.write('Contents/Resources/mode-fixture', b'fixture')
        real_lstat = Path.lstat
        for mode in (0o666, 0o664, 0o4644, 0o2644, 0o1644, 0o755):
            def observed(candidate):
                metadata = real_lstat(candidate)
                if candidate == path:
                    return os.stat_result((stat.S_IFREG | mode, *metadata[1:]))
                return metadata
            with self.subTest(mode=oct(mode)), patch.object(Path, 'lstat', observed):
                with self.assertRaises(ValueError):
                    DRIVER.inventory(self.app, self.verifier)

    def test_hardlink_special_executable_and_writeable_modes_rejected(self):
        path = self.write('Contents/Resources/data', b'fixture')
        os.link(path, self.app / 'Contents/Resources/alias')
        with self.assertRaises(ValueError):
            DRIVER.inventory(self.app, self.verifier)
        (self.app / 'Contents/Resources/alias').unlink()
        for mode in (0o666, 0o664, 0o4644, 0o2644, 0o1644, 0o755):
            path.chmod(mode)
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                DRIVER.inventory(self.app, self.verifier)
        path.chmod(0o644)
        path.unlink()
        os.mkfifo(path)
        with self.assertRaises(ValueError):
            DRIVER.inventory(self.app, self.verifier)

    def test_acl_and_unsafe_staging_modes_rejected(self):
        self.app.parent.chmod(0o777)
        with self.assertRaises(ValueError):
            DRIVER.staging_path(str(self.app))
        self.app.parent.chmod(0o755)
        self.acl.side_effect = ValueError('ACL rejected')
        with self.assertRaises(ValueError):
            DRIVER.inventory(self.app, self.verifier)

    def test_cross_framework_and_external_symlinks_rejected(self):
        link = self.app / 'Contents/Frameworks/App.framework/Versions/Current'
        link.unlink()
        for target in ('../../../rust_api.framework/Versions/A', '/tmp', '../../../../../'):
            link.symlink_to(target)
            with self.subTest(target=target), self.assertRaises((ValueError, OSError)):
                DRIVER.inventory(self.app, self.verifier)
            link.unlink()

    def test_load_boundary_or_missing_architecture_fails_before_signing(self):
        def bad_load(arguments):
            result = self.tool(arguments)
            if arguments[0] == '/usr/bin/otool':
                result.stdout += b'\ncmd LC_LOAD_DYLIB\nname /tmp/injected.dylib (offset 12)\n'
            return result
        with patch.object(DRIVER, 'run_tool', side_effect=bad_load), self.assertRaises(ValueError):
            self.execute()
        self.assertFalse(any('--sign' in args for args in self.calls))
        def missing_slice(arguments):
            result = self.tool(arguments)
            if arguments[0] == '/usr/bin/lipo' and arguments[-1].endswith('/FlashHelper'):
                result.stdout = b'arm64'
            return result
        with patch.object(DRIVER, 'run_tool', side_effect=missing_slice), self.assertRaises(ValueError):
            self.execute()
        self.assertFalse(any('--sign' in args for args in self.calls))

    def test_new_report_required_and_failure_never_becomes_success(self):
        self.execute()
        self.calls.clear()
        with self.assertRaises(FileExistsError):
            self.execute()
        self.assertFalse(any('--sign' in args for args in self.calls))
        report_path = self.app.parent / 'Flash.signing-static.json'
        report_path.unlink()
        def failure(arguments):
            if '--sign' in arguments:
                raise subprocess.CalledProcessError(1, arguments)
            return self.tool(arguments)
        with patch.object(DRIVER, 'run_tool', side_effect=failure), self.assertRaises(subprocess.CalledProcessError):
            self.execute()
        report = json.loads(report_path.read_text())
        self.assertIs(report['static_verification'], False)
        self.assertIs(report['actualGUIloads'], False)
        self.assertEqual(report['failure'], 'CalledProcessError')

    def test_subprocess_failures_preserve_bounded_exact_output_without_retry_or_raw_command(self):
        stdout = b'public-output\xff' + b'x' * 5000
        stderr = b'public-failure\xfe' + b'y' * 6000
        report_path = self.app.parent / 'Flash.signing-static.json'
        for error_type in (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            attempts = []
            def failure(arguments):
                if '--sign' in arguments:
                    attempts.append(arguments)
                    command = arguments[:-1] + ['--synthetic-secret=DO_NOT_RECORD_THIS'] + arguments[-1:]
                    if error_type is subprocess.CalledProcessError:
                        raise error_type(23, command, output=stdout, stderr=stderr)
                    raise error_type(command, 120, output=stdout, stderr=stderr)
                return self.tool(arguments)
            with self.subTest(error_type=error_type.__name__):
                with patch.object(DRIVER, 'run_tool', side_effect=failure):
                    with self.assertRaises(error_type):
                        self.execute()
                self.assertEqual(len(attempts), 1)
                raw = report_path.read_text()
                self.assertNotIn('DO_NOT_RECORD_THIS', raw)
                self.assertNotIn(DRIVER.KEYCHAIN, raw)
                report = json.loads(raw)
                self.assertIs(report['static_verification'], False)
                self.assertIs(report['actualGUIloads'], False)
                self.assertIs(report['packaging_accepted'], False)
                self.assertEqual(report['failure'], error_type.__name__)
                detail = report['failure_details']
                self.assertEqual(detail['tool'], '/usr/bin/codesign')
                self.assertEqual(detail['action'], 'sign')
                self.assertEqual(detail['target']['role'], 'core')
                self.assertEqual(detail['returncode'], 23 if error_type is subprocess.CalledProcessError else None)
                if error_type is subprocess.TimeoutExpired:
                    self.assertEqual(detail['timeout_seconds'], 120)
                for name, data in (('stdout', stdout), ('stderr', stderr)):
                    captured = detail[name]
                    self.assertEqual(base64.b64decode(captured['base64']), data[:4096])
                    self.assertEqual(captured['text'], data[:4096].decode('utf-8', errors='replace'))
                    self.assertEqual(captured['captured_bytes'], len(data))
                    self.assertEqual(captured['retained_bytes'], 4096)
                    self.assertIs(captured['truncated'], True)
                with patch.object(DRIVER, 'run_tool', side_effect=failure):
                    with self.assertRaises(FileExistsError):
                        self.execute()
                self.assertEqual(len(attempts), 1)
                report_path.unlink()

    def test_failure_diagnostics_identify_readonly_verify_and_omit_unknown_tools(self):
        target = self.targets()[0]
        command = ['/usr/bin/codesign', '--verify', '-R', '=' + DRIVER.requirement(target['identifier']),
                   str(self.app / target['path'])]
        error = subprocess.CalledProcessError(1, command, output=b'', stderr=b'public verification failure')
        detail = DRIVER.tool_failure_details(error, self.app, [target])
        self.assertEqual(detail['action'], 'verify')
        self.assertEqual(detail['target']['identifier'], target['identifier'])
        self.assertIs(detail['stderr']['truncated'], False)
        self.assertEqual(base64.b64decode(detail['stderr']['base64']), error.stderr)
        error.cmd = ['/unapproved/tool', '--password', 'DO_NOT_RECORD_THIS']
        detail = DRIVER.tool_failure_details(error, self.app, [target])
        self.assertEqual(set(detail), {'details_omitted'})

    def test_every_architecture_checks_flags_entitlements_and_certificate(self):
        target = self.targets()[-1]
        target['architectures'] = ['arm64', 'x86_64']
        scratch = self.root / 'inspection'
        scratch.mkdir()
        real_tool = self.tool
        for defect in ('flags', 'entitlements', 'certificate', 'team', 'timestamp', 'identifier'):
            def corrupt(arguments):
                output = real_tool(arguments)
                if '--arch' not in arguments or arguments[arguments.index('--arch') + 1] != 'x86_64':
                    return output
                if '--verbose=4' in arguments:
                    if defect == 'flags':
                        output.stderr = output.stderr.replace(b'0x10000(runtime)', b'0x10002(adhoc,runtime)')
                    elif defect == 'team':
                        output.stderr = output.stderr.replace(b'not set', b'UNEXPECTED')
                    elif defect == 'timestamp':
                        output.stderr += b'Timestamp=unexpected\n'
                    elif defect == 'identifier':
                        output.stderr = output.stderr.replace(b'Identifier=com.layoute.flash', b'Identifier=evil')
                if defect == 'entitlements' and '--entitlements' in arguments:
                    output.stdout = plistlib.dumps({'com.apple.security.get-task-allow': True})
                if defect == 'certificate' and any(arg.startswith('--extract-certificates=') for arg in arguments):
                    prefix = next(arg.split('=', 1)[1] for arg in arguments if arg.startswith('--extract-certificates='))
                    Path(prefix + '0').write_bytes(b'wrong')
                return output
            with self.subTest(defect=defect), patch.object(DRIVER, 'run_tool', side_effect=corrupt):
                with self.assertRaises(ValueError):
                    DRIVER.verify_target(self.app, target, scratch)

    def test_non_signature_resource_changes_fail(self):
        before = DRIVER.inventory(self.app, self.verifier)
        after = copy.deepcopy(before)
        after['Contents/Info.plist']['sha256'] = 'changed'
        with self.assertRaises(ValueError):
            DRIVER.check_signing_delta(before, after, self.targets())


class ToolContractTests(unittest.TestCase):
    def test_environment_and_stdin_are_not_inherited(self):
        result = subprocess.CompletedProcess([], 0, b'fixture', b'')
        with patch.dict(os.environ, {'DYLD_INSERT_LIBRARIES': '/evil', 'CODESIGN_ALLOCATE': '/evil',
                                     'PYTHONPATH': '/evil', 'HOME': '/evil'}):
            with patch.object(DRIVER.subprocess, 'run', return_value=result) as run:
                DRIVER.run_tool(['/usr/bin/lipo', '-archs', '/fixture'])
        keywords = run.call_args.kwargs
        self.assertEqual(keywords['env'], DRIVER.ENVIRONMENT)
        self.assertEqual(keywords['stdin'], subprocess.DEVNULL)
        self.assertEqual(keywords['cwd'], '/')
        self.assertTrue(keywords['check'])
        self.assertNotIn('shell', keywords)
        for tool in ('codesign', '/tmp/codesign', '/usr/bin/security', '/bin/sh'):
            with self.subTest(tool=tool), self.assertRaises(ValueError):
                DRIVER.run_tool([tool])

    def test_fixed_public_contract_pins(self):
        self.assertEqual(DRIVER.CERTIFICATE_SHA1, 'BBA7F8529FD271B9848EC03A2CE3F4780F585556')
        self.assertEqual(DRIVER.CERTIFICATE_SHA256,
                         'E8346770F4BF2ABC94F755A136677CDA84B821A668B0983E7FBEF21F8A646E95')
        self.assertEqual(DRIVER.KEYCHAIN,
                         '/Users/layoute/Library/Application Support/Flash Signing/FlashSigning.keychain-db')
        self.assertEqual(DRIVER.VERIFIER_SHA256, DRIVER.sha256(
            (Path(__file__).parents[1] / 'stage_managed_payload.py').read_bytes()))

    def acl_node(self, **changes):
        fields = dict(st_dev=1, st_ino=2, st_mode=stat.S_IFREG | 0o600, st_uid=501,
                      st_gid=20, st_nlink=1, st_flags=0, st_ctime_ns=123456789)
        fields.update(changes)
        return types.SimpleNamespace(**fields)

    def acl_library(self, pointer=0, size=32):
        return types.SimpleNamespace(
            acl_init=MagicMock(return_value=1), acl_get_link_np=MagicMock(return_value=pointer),
            acl_size=MagicMock(return_value=size), acl_valid=MagicMock(return_value=0), acl_free=MagicMock(),
        )

    def test_acl_null_enoent_accepts_only_stable_existing_known_nodes(self):
        for kind in (stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK):
            node = self.acl_node(st_mode=kind | 0o600)
            library = self.acl_library()
            with self.subTest(kind=kind), patch.object(DRIVER.sys, 'platform', 'darwin'):
                with patch.object(DRIVER.ctypes, 'CDLL', return_value=library):
                    with patch.object(DRIVER.ctypes, 'get_errno', return_value=errno.ENOENT):
                        with patch.object(Path, 'lstat', side_effect=[node, copy.copy(node)]) as inspect:
                            DRIVER.require_no_acl(Path('/synthetic'))
            self.assertEqual(inspect.call_count, 2)
            library.acl_free.assert_called_once_with(1)

    def test_acl_null_other_errors_or_uninspectable_changed_metadata_reject(self):
        node = self.acl_node()
        failures = [(error, [node, node]) for error in
                    (0, errno.EACCES, errno.EPERM, errno.EIO, errno.EINVAL, errno.ENOTSUP)]
        failures.extend((errno.ENOENT, [node, self.acl_node(**{field: value})]) for field, value in (
            ('st_dev', 2), ('st_ino', 3), ('st_mode', stat.S_IFDIR | 0o600), ('st_uid', 0),
            ('st_gid', 0), ('st_nlink', 2), ('st_flags', 1), ('st_ctime_ns', 123456790)))
        failures.extend((errno.ENOENT, states) for states in (
            [FileNotFoundError()], [node, FileNotFoundError()], [self.acl_node(st_nlink=0)],
            [self.acl_node(st_mode=stat.S_IFIFO | 0o600)]))
        for error, states in failures:
            library = self.acl_library()
            with self.subTest(error=error, states=states), patch.object(DRIVER.sys, 'platform', 'darwin'):
                with patch.object(DRIVER.ctypes, 'CDLL', return_value=library):
                    with patch.object(DRIVER.ctypes, 'get_errno', return_value=error):
                        with patch.object(Path, 'lstat', side_effect=states):
                            with self.assertRaises((ValueError, OSError)):
                                DRIVER.require_no_acl(Path('/synthetic'))
        for initial, size, pointer, valid in ((0, 32, 0, 0), (1, -1, 0, 0), (1, 32, 2, -1)):
            library = self.acl_library(pointer, size)
            library.acl_init.return_value = initial
            library.acl_valid.return_value = valid
            with self.subTest(initial=initial, size=size, pointer=pointer):
                with patch.object(DRIVER.sys, 'platform', 'darwin'):
                    with patch.object(DRIVER.ctypes, 'CDLL', return_value=library):
                        with patch.object(DRIVER.ctypes, 'get_errno', return_value=errno.ENOENT):
                            with patch.object(Path, 'lstat', return_value=node):
                                with self.assertRaises(ValueError):
                                    DRIVER.require_no_acl(Path('/synthetic'))

    def test_acl_check_rejects_nonempty_or_unreadable_acl_and_frees_objects(self):
        for size, pointer, allowed in ((32, 2, True), (64, 2, False), (-1, 2, False), (32, 0, False)):
            library = types.SimpleNamespace(
                acl_init=MagicMock(return_value=1), acl_get_link_np=MagicMock(return_value=pointer),
                acl_size=MagicMock(side_effect=[32, size]), acl_valid=MagicMock(return_value=0),
                acl_free=MagicMock(),
            )
            with self.subTest(size=size, pointer=pointer), patch.object(DRIVER.sys, 'platform', 'darwin'):
                with patch.object(DRIVER.ctypes, 'CDLL', return_value=library):
                    with patch.object(Path, 'lstat', return_value=self.acl_node()):
                        if allowed:
                            DRIVER.require_no_acl(Path('/synthetic'))
                        else:
                            with self.assertRaises(ValueError):
                                DRIVER.require_no_acl(Path('/synthetic'))
            library.acl_free.assert_any_call(1)
            if pointer:
                library.acl_free.assert_any_call(pointer)


if __name__ == '__main__':
    unittest.main()
