import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

PACKAGING = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('local_release', PACKAGING / 'local_release.py')
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)


class LocalReleaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.patch = patch.object(RELEASE, 'ROOT', self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.identity = {'head': 'a' * 40, 'tag': 'v0.9.8', 'version': '0.9.8', 'build': '2026111405'}
        self.config = {'sdk': '/configured/sdk', 'signer': '/configured/protected-adapter',
                       'signer_sha256': 'b' * 64, 'service': '/configured/Flash.app',
                       'service_receipt': '/configured/service.json', 'service_receipt_sha256': 'c' * 64}
        self.directory = self.root / 'run'
        self.release = RELEASE.Release(self.identity, self.config, self.directory)
        self.pubspec = self.root / 'pubspec.yaml'
        self.pubspec.write_text('version: 0.9.8+2026111405\nhooks:\n  user_defines:\n'
                               '    setup:\n      build_assets: true\n    rust_api:\n      build_assets: true\n')

    def git(self, *args):
        return {'branch': 'main', 'status': '', 'submodule': ' ' + 'f' * 40 + ' plugins/example',
                'rev-parse': self.identity['head']}[args[0]]

    def public_assets(self):
        public = self.directory / 'public'
        public.mkdir()
        dmg = public / 'Flash-0.9.8-macos-arm64.dmg'
        dmg.write_bytes(b'fake-dmg-never-mounted')
        (public / 'SHA256SUMS').write_text(RELEASE.sha(dmg) + '  ' + dmg.name + '\n')
        RELEASE.save(self.directory / 'manifest.json', {'schema': 1, 'source': self.identity,
                     'assets': {p.name: RELEASE.sha(p) for p in public.iterdir()}})
        self.release.state['manifest_sha256'] = RELEASE.sha(self.directory / 'manifest.json')
        return dmg

    def changelog(self, text='Prewarm mount data'):
        version = {'version': '0.9.8', 'tag': 'v0.9.8', 'date': '2026-11-14', 'prerelease': False,
                   'groups': [{'type': 'fix', 'entries': [{'id': '73e701d', 'scope': 'mount', 'text': text}]}]}
        (self.root / 'changelog.json').write_text(json.dumps({'schemaVersion': 2, 'versions': [version]}))
        return version

    def test_static_verification_uses_current_packaging_without_changing_signer(self):
        spec = importlib.util.spec_from_file_location('portable_verification', PACKAGING / 'verify_split_service.py')
        verifier = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(verifier)
        fixed = types.SimpleNamespace(PACKAGING=Path('/old/staging'), WORKTREE=Path('/protected/signing'))
        constraint = object()
        signer = types.SimpleNamespace(dependencies=lambda: (fixed, constraint))
        actual, observed = verifier.static_dependencies(signer)
        self.assertEqual(actual.PACKAGING, PACKAGING)
        self.assertEqual(actual.WORKTREE, Path('/protected/signing'))
        self.assertIs(observed, constraint)

    def test_bundle_marketing_and_build_versions_must_match(self):
        app = self.directory / 'gui/Flash.app'
        (app / 'Contents/MacOS').mkdir(parents=True)
        core = app / RELEASE.CORE
        core.write_bytes(b'fake-retained-core')
        plist = app / 'Contents/Info.plist'
        plist.write_bytes(plistlib.dumps({'CFBundleShortVersionString': '0.9.8', 'CFBundleVersion': '2026111405'}))
        with patch.object(RELEASE, 'CORE_SHA256', RELEASE.sha(core)):
            RELEASE.check_version(app, self.identity)
            for key, value in [('version', '0.9.7'), ('build', '2026111404')]:
                with self.assertRaisesRegex(ValueError, 'version differs'):
                    RELEASE.check_version(app, dict(self.identity, **{key: value}))
            (app / 'Contents/Library').mkdir()
            with self.assertRaisesRegex(ValueError, 'embed helper'):
                RELEASE.check_version(app, self.identity)

    def test_local_config_requires_ignored_private_file_and_pinned_adapter(self):
        config = dict(self.config, schema=1)
        sdk = self.root / 'sdk'
        (sdk / 'bin/cache').mkdir(parents=True)
        (sdk / 'bin/cache/flutter.version.json').write_text('{"flutterVersion":"3.47.4"}')
        signer = self.root / 'adapter'
        signer.write_text('#!/bin/sh\nexit 99\n')
        signer.chmod(0o700)
        service = self.root / 'service/Flash.app'
        service.mkdir(parents=True)
        receipt = self.root / 'service.json'
        receipt.write_text('{}')
        config.update(sdk=str(sdk), signer=str(signer), signer_sha256=RELEASE.sha(signer),
                      service=str(service), service_receipt=str(receipt))
        path = self.root / '.airbuild/config.json'
        path.parent.mkdir()
        path.write_text(json.dumps(config))
        path.chmod(0o600)
        with patch.object(RELEASE, 'git', side_effect=lambda *a: str(path) if a[0] == 'check-ignore' else ''):
            self.assertEqual(RELEASE.configuration(path), config)
            signer.write_text('changed adapter')
            with self.assertRaisesRegex(ValueError, 'adapter pin'):
                RELEASE.configuration(path)
            path.chmod(0o644)
            with self.assertRaisesRegex(ValueError, '0600'):
                RELEASE.configuration(path)

    def test_clean_main_tag_and_pubspec_alignment(self):
        with patch.object(RELEASE, 'git', side_effect=self.git):
            self.assertEqual(RELEASE.source_identity('v0.9.8'), self.identity)
            for tag in ('v0.9.7', '../v0.9.8', 'v0.9.8-pre.1'):
                with self.subTest(tag=tag), self.assertRaises(ValueError):
                    RELEASE.source_identity(tag)
            self.pubspec.write_text(self.pubspec.read_text().replace('build_assets: true', 'build_assets: false'))
            with self.assertRaisesRegex(ValueError, 'hooks'):
                RELEASE.source_identity('v0.9.8')

    def test_dirty_wrong_branch_tag_or_submodule_fails_closed(self):
        for key, value in [('branch', 'feature'), ('status', ' M pubspec.yaml'),
                           ('submodule', '-missing'), ('rev-parse-tag', 'b' * 40)]:
            def git(*args):
                if key == 'rev-parse-tag' and args == ('rev-parse', 'v0.9.8^{commit}'):
                    return value
                return value if args[0] == key else self.git(*args)
            with self.subTest(key=key), patch.object(RELEASE, 'git', side_effect=git), self.assertRaises(ValueError):
                RELEASE.source_identity('v0.9.8')

    def test_manifest_allowlist_tampering_and_symlinks(self):
        dmg = self.public_assets()
        self.assertEqual({p.name for p in self.release.assets()}, {dmg.name, 'SHA256SUMS'})
        for name in ('signing-receipt.json', 'Flash-helper-install.pkg', 'Flash-helper-repair.pkg'):
            private = dmg.parent / name
            private.write_text('not a public asset')
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'Unexpected public'):
                self.release.assets()
            private.unlink()
        dmg.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'asset changed'):
            self.release.assets()
        dmg.unlink()
        dmg.symlink_to(self.pubspec)
        with self.assertRaisesRegex(ValueError, 'regular file'):
            self.release.assets()

    def test_resume_rejects_source_and_config_changes(self):
        for identity, config in [(dict(self.identity, head='f' * 40), self.config),
                                 (self.identity, dict(self.config, service_receipt_sha256='d' * 64))]:
            with self.assertRaisesRegex(ValueError, 'Resume source/config changed'):
                RELEASE.Release(identity, config, self.directory)
        resumed = RELEASE.Release(self.identity, self.config, self.directory)
        self.assertEqual(resumed.state, self.release.state)

    def test_notes_preserve_app_markers_json_and_honest_scope(self):
        version = self.changelog('A --> B')
        body = RELEASE.notes(self.identity)
        payload = body.split(RELEASE.JSON_BEGIN + '\n')[1].split('\n-->')[0]
        self.assertEqual(json.loads(payload)['versions'], [version])
        self.assertIn(RELEASE.BEGIN, body)
        self.assertIn(RELEASE.END, body)
        self.assertNotIn('-->', payload)
        for text in ('arm64', '2026111402', 'embedded first-install', 'not notarized', 'Self-signed', 'runtime acceptance'):
            self.assertIn(text, body)
        self.assertIn('no separate helper download', body)
        self.assertNotIn('helper separately', body)
        with self.assertRaises(ValueError):
            RELEASE.notes(dict(self.identity, tag='v0.9.9'))

    def test_lock_is_released_on_error(self):
        with self.assertRaisesRegex(RuntimeError, 'interrupted'):
            with RELEASE.release_lock(self.root / 'lock-dir'):
                raise RuntimeError('interrupted')
        with RELEASE.release_lock(self.root / 'lock-dir'):
            pass

    def test_real_build_then_staging_precedes_sign_request(self):
        service = {'Core': 'immutable'}
        staged = Mock()
        embedded = Mock()
        events = []
        def stage_gui(fresh, app, core, pin):
            events.append('stage-gui')
            self.assertEqual(pin, RELEASE.CORE_SHA256)
            self.assertIn('new-xcode-macos', str(fresh))
            app.mkdir(parents=True)
        staged.stage_gui.side_effect = stage_gui
        embedded.stage.side_effect = lambda *args: events.append('embed-installers')
        def inventory(*args):
            events.append('unsigned-inventory')
            return {'fresh': 'code', 'embedded': 'installers'}
        fixed = types.SimpleNamespace(inventory=inventory, trusted_verifier=lambda: None)
        def command(argv, **kwargs):
            self.assertEqual(Path(argv[1]).name, 'build_local_gui.sh')
            output = Path(argv[3])
            output.mkdir()
            (output / 'build.log').write_text('fresh compiler output')
            return ''
        with patch.object(RELEASE, 'command', side_effect=command) as run, \
                patch.object(RELEASE, 'module', side_effect=lambda name: embedded
                             if name == 'embedded_helper_installer' else staged), \
                patch.object(RELEASE, 'static_dependencies', return_value=(fixed, None)), \
                patch.object(RELEASE, 'check_service', return_value=service), \
                patch.object(RELEASE, 'check_version', side_effect=lambda *args: events.append('check-version')), \
                patch.object(self.release, 'unchanged'):
            self.release.build()
            self.release.build()
        self.assertEqual(events, ['stage-gui', 'embed-installers', 'check-version', 'unsigned-inventory'])
        embedded.stage.assert_called_once_with(
            self.release.app, Path(self.config['service']), self.directory / 'helper-packages',
            Path(self.config['service_receipt']), self.config['service_receipt_sha256'],
            RELEASE.CORE_SHA256, RELEASE.HELPER_BUILD)
        self.assertEqual(run.call_count, 1)
        request = RELEASE.pinned(self.release.request, self.release.state['request_sha256'])
        self.assertEqual(request['source'], self.identity)
        self.assertEqual(request['unsigned_entries'], {'fresh': 'code', 'embedded': 'installers'})
        self.assertEqual(request['certificate_sha1'], RELEASE.IDENTITY)
        self.assertEqual(request['mode'], 'gui-only')
        self.assertFalse(self.release.response.exists())

    def test_embedded_package_failure_prevents_unsigned_sign_request(self):
        staged, embedded = Mock(), Mock()
        embedded.stage.side_effect = ValueError('invalid released package')
        with patch.object(RELEASE, 'command') as run, \
                patch.object(RELEASE, 'module', side_effect=lambda name: embedded
                             if name == 'embedded_helper_installer' else staged), \
                patch.object(RELEASE, 'check_service', return_value={}), \
                patch.object(RELEASE, 'static_dependencies') as signing:
            with self.assertRaisesRegex(ValueError, 'invalid released package'):
                self.release.build()
        self.assertEqual(run.call_count, 1)
        signing.assert_not_called()
        self.assertFalse(self.release.request.exists())
        self.assertNotIn('request_sha256', self.release.state)
        self.assertFalse(self.release.response.exists())

    def test_verify_rejects_invalid_embedded_manifest_before_signature_gate(self):
        RELEASE.save(self.release.request, {'unsigned_entries': {}})
        self.release.state['request_sha256'] = RELEASE.sha(self.release.request)
        receipt = self.directory / 'gui-receipt.json'
        RELEASE.save(receipt, {'before': {'entries': {}}})
        RELEASE.save(self.release.response, {'schema': 1, 'request_sha256': self.release.state['request_sha256'],
                     'gui_receipt': str(receipt), 'gui_receipt_sha256': RELEASE.sha(receipt)})
        self.release.state['response_sha256'] = RELEASE.sha(self.release.response)
        embedded = Mock()
        embedded.verify.side_effect = ValueError('invalid embedded manifest')
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'check_version'), \
                patch.object(RELEASE, 'module', return_value=embedded) as load:
            with self.assertRaisesRegex(ValueError, 'invalid embedded manifest'):
                self.release.verify()
        load.assert_called_once_with('embedded_helper_installer')
        embedded.verify.assert_called_once_with(self.release.app)

    def test_verify_binds_fresh_code_and_request_before_static_signatures(self):
        self.release.state['service_inventory'] = {}
        RELEASE.save(self.release.request, {'unsigned_entries': {'fresh': 'code'}})
        self.release.state['request_sha256'] = RELEASE.sha(self.release.request)
        receipt = self.directory / 'gui-receipt.json'
        RELEASE.save(receipt, {'before': {'entries': {'old': 'code'}}})
        RELEASE.save(self.release.response, {'schema': 1, 'request_sha256': self.release.state['request_sha256'],
                     'gui_receipt': str(receipt), 'gui_receipt_sha256': RELEASE.sha(receipt)})
        self.release.state['response_sha256'] = RELEASE.sha(self.release.response)
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'module') as load:
            with self.assertRaisesRegex(ValueError, 'fresh unsigned code'):
                self.release.verify()
            load.assert_not_called()

    def test_signer_failure_never_marks_signed_or_packages(self):
        RELEASE.save(self.release.request, {'unsigned_entries': {}})
        self.release.state['request_sha256'] = RELEASE.sha(self.release.request)
        fixed = types.SimpleNamespace(inventory=lambda *args: {}, trusted_verifier=lambda: None)
        original_sha = RELEASE.sha
        with patch.object(self.release, 'unchanged'), \
                patch.object(RELEASE, 'static_dependencies', return_value=(fixed, None)), \
                patch.object(RELEASE, 'sha', side_effect=lambda p: self.config['signer_sha256']
                             if str(p) == self.config['signer'] else original_sha(p)), \
                patch.object(RELEASE, 'command', side_effect=subprocess.CalledProcessError(1, 'protected-adapter')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.release.sign()
        self.assertNotIn('response_sha256', self.release.state)
        self.assertFalse((self.directory / 'public').exists())

    def test_package_failure_detaches_only_own_mount_and_retains_evidence(self):
        response = {'gui_receipt': 'gui.json', 'gui_receipt_sha256': 'a' * 64}
        calls = []
        def command(argv, **kwargs):
            calls.append([str(arg) for arg in argv])
            if 'build_split_packages.sh' in str(argv[1]):
                output = self.directory / 'packages'
                output.mkdir()
                (output / 'Flash.dmg').write_bytes(b'fake')
            return ''
        stage = types.SimpleNamespace(verify_copy=Mock(side_effect=ValueError('bundle changed')))
        with patch.object(self.release, 'verify', return_value=response), \
                patch.object(RELEASE, 'command', side_effect=command), patch.object(RELEASE, 'module', return_value=stage):
            with self.assertRaisesRegex(ValueError, 'bundle changed'):
                self.release.package()
        self.assertEqual([call[1] for call in calls[1:]], ['verify', 'attach', 'detach'])
        self.assertIn('-readonly', calls[2])
        self.assertEqual(calls[2][-2], calls[3][-1])
        self.assertTrue((self.directory / 'packages/Flash.dmg').exists())
        self.assertNotIn('manifest_sha256', self.release.state)
        self.assertEqual(list(self.directory.glob('verify-dmg-*')), [])

    def test_package_success_renames_and_hashes_only_two_public_assets(self):
        response = {'gui_receipt': 'gui.json', 'gui_receipt_sha256': 'a' * 64}
        def command(argv, **kwargs):
            if 'build_split_packages.sh' in str(argv[1]):
                self.assertEqual(argv[2], 'gui-only')
                output = self.directory / 'packages'
                output.mkdir()
                (output / 'Flash.dmg').write_bytes(b'fake-styled-dmg')
            return ''
        stage = types.SimpleNamespace(verify_copy=Mock())
        with patch.object(self.release, 'verify', return_value=response), \
                patch.object(RELEASE, 'command', side_effect=command), patch.object(RELEASE, 'module', return_value=stage):
            self.release.package()
            self.release.package()
        self.assertEqual(stage.verify_copy.call_count, 1)
        self.assertEqual({p.name for p in self.release.assets()}, {'Flash-0.9.8-macos-arm64.dmg', 'SHA256SUMS'})
        self.assertEqual(list(self.directory.glob('verify-dmg-*')), [])

    def test_detach_failure_preserves_mountpoint_without_recursive_cleanup(self):
        response = {'gui_receipt': 'gui.json', 'gui_receipt_sha256': 'a' * 64}
        def command(argv, **kwargs):
            if 'build_split_packages.sh' in str(argv[1]):
                (self.directory / 'packages').mkdir()
                (self.directory / 'packages/Flash.dmg').write_bytes(b'fake')
            if argv[1] == 'detach':
                raise subprocess.CalledProcessError(1, argv)
            return ''
        stage = types.SimpleNamespace(verify_copy=Mock())
        with patch.object(self.release, 'verify', return_value=response), \
                patch.object(RELEASE, 'command', side_effect=command), patch.object(RELEASE, 'module', return_value=stage):
            with self.assertRaises(subprocess.CalledProcessError):
                self.release.package()
        self.assertEqual(len(list(self.directory.glob('verify-dmg-*'))), 1)
        self.assertFalse((self.directory / 'public').exists())

    def test_draft_and_explicit_publish_only_allowlisted_assets(self):
        self.changelog()
        self.public_assets()
        calls = []
        body = ''
        def command(argv, **kwargs):
            nonlocal body
            argv = [str(arg) for arg in argv]
            calls.append(argv)
            self.assertEqual(argv[0], 'gh')
            if argv[1] == 'api' and '/commits/' in argv[-1]:
                return json.dumps({'sha': self.identity['head']})
            if 'releases/generate-notes' in ' '.join(argv):
                return json.dumps({'body': 'Automatically generated changes'})
            if argv[1:3] == ['release', 'create']:
                body = (self.directory / 'release-notes.md').read_text()
                return ''
            if argv[1:3] == ['release', 'view']:
                return json.dumps({'isDraft': True, 'tagName': 'v0.9.8', 'targetCommitish': self.identity['head'],
                                   'assets': [{'name': p.name} for p in self.release.assets()], 'body': body})
            if argv[1:3] == ['release', 'download']:
                name = argv[argv.index('--pattern') + 1]
                destination = Path(argv[argv.index('--dir') + 1]) / name
                destination.write_bytes((self.directory / 'public' / name).read_bytes())
                return ''
            if argv[1:3] == ['release', 'edit']:
                return ''
            self.fail('Unexpected command: ' + str(argv))
        with patch.object(self.release, 'verify'), patch.object(RELEASE, 'command', side_effect=command):
            self.release.draft()
            self.assertFalse(any('edit' in argv for argv in calls))
            self.release.publish()
        create = next(argv for argv in calls if argv[1:3] == ['release', 'create'])
        self.assertEqual({Path(p).name for p in create[-2:]}, {'Flash-0.9.8-macos-arm64.dmg', 'SHA256SUMS'})
        self.assertIn('--draft', create)
        self.assertIn('--verify-tag', create)
        self.assertEqual(calls[-1][-2:], ['--draft=false', '--latest'])
        self.assertIn('Automatically generated changes', body)
        self.assertTrue(self.release.state['published'])

    def test_run_orchestrates_all_phases_and_publishes_only_when_explicit(self):
        fake = Mock(directory=self.directory)
        with patch.object(RELEASE, 'source_identity', return_value=self.identity), \
                patch.object(RELEASE, 'configuration', return_value=self.config), \
                patch.object(RELEASE, 'notes', return_value='notes'), patch.object(RELEASE, 'Release', return_value=fake), \
                patch.object(RELEASE.sys, 'platform', 'darwin'), \
                patch.object(RELEASE.os, 'uname', return_value=types.SimpleNamespace(machine='arm64')), \
                patch.object(RELEASE.os, 'getuid', return_value=501), \
                patch.object(RELEASE.os, 'umask'), patch('builtins.print'):
            self.assertEqual(RELEASE.main(['run', '--tag', 'v0.9.8', '--run', 'one-command']), 0)
            self.assertEqual([call[0] for call in fake.method_calls], ['build', 'sign', 'package', 'draft'])
            fake.reset_mock()
            self.assertEqual(RELEASE.main(['run', '--tag', 'v0.9.8', '--run', 'one-command', '--publish']), 0)
            self.assertEqual([call[0] for call in fake.method_calls], ['build', 'sign', 'package', 'draft', 'publish'])

    def test_run_stops_on_build_failure_before_signing_or_network(self):
        fake = Mock(directory=self.directory)
        fake.build.side_effect = ValueError('offline dependency missing')
        with patch.object(RELEASE, 'source_identity', return_value=self.identity), \
                patch.object(RELEASE, 'configuration', return_value=self.config), \
                patch.object(RELEASE, 'notes', return_value='notes'), patch.object(RELEASE, 'Release', return_value=fake), \
                patch.object(RELEASE.sys, 'platform', 'darwin'), \
                patch.object(RELEASE.os, 'uname', return_value=types.SimpleNamespace(machine='arm64')), \
                patch.object(RELEASE.os, 'getuid', return_value=501), \
                patch.object(RELEASE.os, 'umask'), patch('builtins.print'):
            self.assertEqual(RELEASE.main(['run', '--tag', 'v0.9.8', '--run', 'failed', '--publish']), 1)
        self.assertEqual([call[0] for call in fake.method_calls], ['build'])

    def test_remote_source_mismatch_never_creates_release(self):
        self.public_assets()
        with patch.object(self.release, 'verify'), patch.object(RELEASE, 'command', return_value='{"sha":"wrong"}') as run:
            with self.assertRaisesRegex(ValueError, 'Remote main/tag'):
                self.release.draft()
        self.assertEqual(run.call_count, 1)

    def test_remote_asset_injection_never_publishes(self):
        self.public_assets()
        notes = self.directory / 'release-notes.md'
        notes.write_text('reviewed')
        self.release.state.update(draft_created=True, notes_sha256=RELEASE.sha(notes))
        draft = {'isDraft': True, 'tagName': 'v0.9.8', 'targetCommitish': self.identity['head'],
                 'body': 'reviewed', 'assets': [{'name': 'private-receipt.json'}]}
        with patch.object(self.release, 'remote'), patch.object(RELEASE, 'command', return_value=json.dumps(draft)) as run:
            with self.assertRaisesRegex(ValueError, 'allowlist'):
                self.release.publish()
        self.assertEqual(run.call_count, 1)


class HelperBuildModeTests(unittest.TestCase):
    def test_builder_records_real_source_state_before_compilation(self):
        source = (PACKAGING / 'build_local_gui.sh').read_text()
        records = (
            '/usr/bin/git rev-parse HEAD > "$out/source-head.txt"',
            '/usr/bin/git --no-optional-locks status --porcelain > "$out/source-status.txt"',
        )
        for record in records:
            with self.subTest(record=record):
                self.assertEqual(source.count(record), 1)
                self.assertLess(source.index('cd "$root"'), source.index(record))
                self.assertLess(source.index('mkdir -p "$out/kept-caches"'), source.index(record))
                self.assertLess(source.index(record), source.index('for cache in flutter_build setup_build_cache'))
                self.assertLess(source.index(record), source.index('/usr/bin/sandbox-exec -p "$guard"'))

    def run_stage(self, mode=None, configuration='Release', candidate='0', managed=True):
        import base64
        with tempfile.TemporaryDirectory() as temporary:
            env = dict(os.environ, DART_DEFINES=base64.b64encode(
                ('MACOS_MANAGED_HELPER=' + str(managed).lower()).encode()).decode(),
                CONFIGURATION=configuration, TARGET_BUILD_DIR=temporary,
                CONTENTS_FOLDER_PATH='Flash.app/Contents', ARCHS='arm64',
                FC_MANAGED_CANDIDATE_ENABLED=candidate)
            env.pop('FC_MACOS_PACKAGE_MODE', None)
            if mode is not None:
                env['FC_MACOS_PACKAGE_MODE'] = mode
            return subprocess.run(['/bin/bash', str(PACKAGING / 'stage_managed_helper.sh')],
                                  env=env, capture_output=True, text=True)

    def test_explicit_gui_only_exits_without_compiler(self):
        self.assertEqual(self.run_stage('gui-only').returncode, 0)

    def test_invalid_mode_and_non_release_fail(self):
        self.assertNotEqual(self.run_stage('invalid').returncode, 0)
        self.assertNotEqual(self.run_stage('gui-only', configuration='Debug').returncode, 0)

    def test_stale_embedded_helper_is_not_silently_deleted(self):
        import base64
        with tempfile.TemporaryDirectory() as temporary:
            helper = Path(temporary) / 'Flash.app/Contents/Library/HelperTools'
            helper.mkdir(parents=True)
            env = dict(os.environ, FC_MACOS_PACKAGE_MODE='gui-only', CONFIGURATION='Release',
                       DART_DEFINES=base64.b64encode(b'MACOS_MANAGED_HELPER=true').decode(),
                       TARGET_BUILD_DIR=temporary, CONTENTS_FOLDER_PATH='Flash.app/Contents')
            result = subprocess.run(['/bin/bash', str(PACKAGING / 'stage_managed_helper.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('fresh build', result.stderr)
            self.assertTrue(helper.is_dir())

    def test_default_helper_update_validation_and_unmanaged_behavior_preserved(self):
        result = self.run_stage(candidate='invalid')
        self.assertIn('FC_MANAGED_CANDIDATE_ENABLED', result.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Managed helper requires Release', self.run_stage(configuration='Debug').stderr)
        self.assertEqual(self.run_stage(managed=False).returncode, 0)


if __name__ == '__main__':
    unittest.main()
