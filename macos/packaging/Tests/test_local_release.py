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
                       'signer_sha256': 'b' * 64}
        self.directory = self.root / 'run'
        self.release = RELEASE.Release(self.identity, self.config, self.directory)
        (self.root / 'build_config.yaml').write_text('tags: with_gvisor\ncore_version: v1.19.34\n')
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

    def stage_module(self):
        loader = importlib.util.spec_from_file_location('bundle_stage', PACKAGING / 'stage_bundle_payload.py')
        stage = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(stage)
        return stage

    def bundled_app(self, app):
        stage = self.stage_module()
        macho = bytes.fromhex('cffaedfe') + b'synthetic-never-execute'
        for relative, data in ((stage.CORE, macho),
                               (stage.HELPER, macho + plistlib.dumps({'CFBundleIdentifier': stage.HELPER_ID}))):
            path = app / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            path.chmod(0o755)
        plist = app / stage.DAEMON_PLIST
        plist.parent.mkdir(parents=True)
        plist.write_bytes(plistlib.dumps(stage.DAEMON_SCHEMA))
        (app / stage.RETIRED_DAEMON_PLIST).write_bytes(plistlib.dumps(stage.RETIRED_DAEMON_SCHEMA))
        info = {'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleShortVersionString': '0.9.8',
                'CFBundleVersion': '2026111405'}
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        return stage, info

    def test_bundle_marketing_and_build_versions_must_match(self):
        app = self.directory / 'gui/Flash.app'
        stage, info = self.bundled_app(app)
        module_patch = patch.object(RELEASE, 'module', return_value=stage)
        module_patch.start()
        self.addCleanup(module_patch.stop)
        facts = RELEASE.check_version(app, self.identity)
        self.assertEqual(set(facts), {'core_sha256', 'helper_sha256', 'daemon_plist_sha256',
                                      'retired_daemon_plist_sha256'})
        for key, value in [('version', '0.9.7'), ('build', '2026111404')]:
            with self.assertRaisesRegex(ValueError, 'version differs'):
                RELEASE.check_version(app, dict(self.identity, **{key: value}))
        (app / RELEASE.CORE).unlink()
        with self.assertRaises(FileNotFoundError):
            RELEASE.check_version(app, self.identity)

    def test_local_config_requires_ignored_private_file_and_pinned_adapter(self):
        config = dict(self.config, schema=2)
        sdk = self.root / 'sdk'
        (sdk / 'bin/cache').mkdir(parents=True)
        (sdk / 'bin/cache/flutter.version.json').write_text('{"flutterVersion":"3.47.4"}')
        signer = self.root / 'adapter'
        signer.write_text('#!/bin/sh\nexit 99\n')
        signer.chmod(0o700)
        config.update(sdk=str(sdk), signer=str(signer), signer_sha256=RELEASE.sha(signer))
        path = self.root / '.airbuild/config.json'
        path.parent.mkdir()
        path.write_text(json.dumps(config))
        path.chmod(0o600)
        with patch.object(RELEASE, 'git', side_effect=lambda *a: str(path) if a[0] == 'check-ignore' else ''):
            self.assertEqual(RELEASE.configuration(path), config)
            path.write_text(json.dumps(dict(config, schema=1, service='/legacy/Flash.app')))
            with self.assertRaisesRegex(ValueError, 'Unexpected local config fields'):
                RELEASE.configuration(path)
            path.write_text(json.dumps(config))
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
                                 (self.identity, dict(self.config, signer_sha256='d' * 64))]:
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
        for text in ('arm64', 'inside Flash.app', 'SMAppService', 'Login Items', 'not notarized',
                     'Self-signed', 'runtime acceptance', 'no separate helper download'):
            self.assertIn(text, body)
        for text in ('2026111503', 'install package', 'repair'):
            self.assertNotIn(text, body)
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
        staged = Mock(SIGNING_ORDER=('core', 'contract', 'helper', 'framework', 'gui'))
        staged.compatibility_inputs.side_effect = lambda version, revision: {
            'CallerPolicy': 3, 'ServiceAPI': 1, 'CoreAPI': 1, 'CoreVersion': version, 'CoreRevision': revision}
        events = []
        facts = {'core_sha256': '1' * 64, 'helper_sha256': '2' * 64, 'daemon_plist_sha256': '3' * 64}
        def stage(fresh, app):
            events.append('stage')
            self.assertIn('new-xcode-macos', str(fresh))
            return facts
        staged.stage.side_effect = stage
        def inventory(app):
            events.append('unsigned-inventory')
            return {'fresh': 'code'}
        staged.inventory.side_effect = inventory
        def check_version(*args):
            events.append('check-version')
            return facts
        def command(argv, **kwargs):
            self.assertEqual(Path(argv[1]).name, 'build_local_gui.sh')
            output = Path(argv[3])
            output.mkdir()
            (output / 'build.log').write_text('fresh compiler output')
            return ''
        with patch.object(RELEASE, 'command', side_effect=command) as run, \
                patch.object(RELEASE, 'module', return_value=staged), \
                patch.object(RELEASE, 'check_version', side_effect=check_version), \
                patch.object(self.release, 'unchanged'):
            self.release.build()
            self.release.build()
        self.assertEqual(events, ['stage', 'check-version', 'unsigned-inventory'])
        self.assertEqual(run.call_count, 1)
        request = RELEASE.pinned(self.release.request, self.release.state['request_sha256'])
        self.assertEqual(request['source'], self.identity)
        self.assertEqual(request['unsigned_entries'], {'fresh': 'code'})
        self.assertEqual(request['unsigned_facts'], facts)
        self.assertEqual(request['certificate_sha1'], RELEASE.IDENTITY)
        self.assertEqual(request['mode'], 'bundled-daemon')
        self.assertEqual(request['signing_order'], ['core', 'contract', 'helper', 'framework', 'gui'])
        self.assertEqual(request['compatibility_inputs'], {
            'CallerPolicy': 3, 'ServiceAPI': 1, 'CoreAPI': 1, 'CoreVersion': 'v1.19.34',
            'CoreRevision': self.identity['head']})

    def test_core_version_comes_from_the_single_build_config_entry(self):
        (self.root / 'build_config.yaml').write_text('tags: x\ncore_version: v1.2.3\ncore_dir: core\n')
        self.assertEqual(RELEASE.core_version(), 'v1.2.3')
        (self.root / 'build_config.yaml').write_text('core_version: v1\ncore_version: v2\n')
        with self.assertRaisesRegex(ValueError, 'exactly one core_version'):
            RELEASE.core_version()
        with patch.object(RELEASE, 'ROOT', PACKAGING.parents[1]):
            self.assertRegex(RELEASE.core_version(), r'^v\d+\.\d+\.\d+$')
        self.assertFalse(self.release.response.exists())

    def test_layout_failure_prevents_unsigned_sign_request(self):
        staged = Mock()
        staged.stage.side_effect = ValueError('Legacy helper artifact present')
        with patch.object(RELEASE, 'command') as run, patch.object(RELEASE, 'module', return_value=staged):
            with self.assertRaisesRegex(ValueError, 'Legacy helper artifact'):
                self.release.build()
        self.assertEqual(run.call_count, 1)
        staged.inventory.assert_not_called()
        self.assertFalse(self.release.request.exists())
        self.assertNotIn('request_sha256', self.release.state)

    def signed_run(self, receipt_extra=None, unsigned=None):
        facts = {'core_sha256': '1' * 64, 'helper_sha256': '2' * 64, 'daemon_plist_sha256': '3' * 64,
                 'retired_daemon_plist_sha256': '4' * 64}
        inputs = {'CallerPolicy': 3, 'ServiceAPI': 1, 'CoreAPI': 1, 'CoreVersion': 'v1.19.34',
                  'CoreRevision': self.identity['head']}
        RELEASE.save(self.release.request, {'unsigned_entries': {'fresh': 'code'}, 'unsigned_facts': facts,
                                            'compatibility_inputs': inputs,
                                            'signing_order': ['core', 'contract', 'helper', 'framework', 'gui']})
        self.release.state['request_sha256'] = RELEASE.sha(self.release.request)
        receipt = self.directory / 'bundle-receipt.json'
        signed = dict(facts, helper_cdhash='h' * 40, core_cdhash='c' * 40,
                      compatibility=dict(inputs, CoreSHA256=facts['core_sha256']))
        body = {'schema': 2, 'mode': 'bundled-daemon', 'before': {'entries': unsigned or {'fresh': 'code'}},
                'signing_order': ['core', 'contract', 'helper', 'framework', 'gui'], **signed}
        body.update(receipt_extra or {})
        RELEASE.save(receipt, body)
        RELEASE.save(self.release.response, {'schema': 2, 'request_sha256': self.release.state['request_sha256'],
                     'receipt': str(receipt), 'receipt_sha256': RELEASE.sha(receipt)})
        self.release.state['response_sha256'] = RELEASE.sha(self.release.response)
        return signed

    def test_verify_binds_receipt_to_signed_helper_core_and_plist(self):
        signed = self.signed_run()
        stage = Mock()
        stage.verify_signed.return_value = signed
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'check_version'), \
                patch.object(RELEASE, 'module', return_value=stage):
            self.release.verify()
            for key in ('helper_cdhash', 'core_cdhash', 'core_sha256'):
                stage.verify_signed.return_value = dict(signed, **{key: 'other'})
                with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'Receipt does not bind'):
                    self.release.verify()
            stage.verify_signed.return_value = dict(signed, daemon_plist_sha256='9' * 64)
            with self.assertRaisesRegex(ValueError, 'Daemon plist changed'):
                self.release.verify()
            stage.verify_signed.return_value = dict(signed, retired_daemon_plist_sha256='9' * 64)
            with self.assertRaisesRegex(ValueError, 'Retired daemon plist changed'):
                self.release.verify()

    def test_verify_binds_sealed_contract_to_request_inputs_and_signed_core(self):
        signed = self.signed_run()
        stage = Mock()
        contract = signed['compatibility']
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'check_version'), \
                patch.object(RELEASE, 'module', return_value=stage):
            for changed in (dict(contract, CoreVersion='v0'), dict(contract, CoreRevision='other'),
                            dict(contract, CoreSHA256='9' * 64), dict(contract, CallerPolicy=2)):
                stage.verify_signed.return_value = dict(signed, compatibility=changed)
                with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, 'request inputs'):
                    self.release.verify()

    def test_verify_requires_receipt_to_bind_the_contract(self):
        signed = self.signed_run({'compatibility': None})
        stage = Mock()
        stage.verify_signed.return_value = signed
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'check_version'), \
                patch.object(RELEASE, 'module', return_value=stage):
            with self.assertRaisesRegex(ValueError, 'compatibility contract'):
                self.release.verify()

    def test_verify_rejects_outside_in_signing_order(self):
        self.signed_run({'signing_order': ['gui', 'framework', 'helper', 'core']})
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'module') as load:
            with self.assertRaisesRegex(ValueError, 'inside-out'):
                self.release.verify()
            load.assert_not_called()

    def test_verify_binds_fresh_code_and_request_before_static_signatures(self):
        self.signed_run(unsigned={'old': 'code'})
        with patch.object(self.release, 'unchanged'), patch.object(RELEASE, 'module') as load:
            with self.assertRaisesRegex(ValueError, 'fresh unsigned code'):
                self.release.verify()
            load.assert_not_called()

    def test_signer_failure_never_marks_signed_or_packages(self):
        RELEASE.save(self.release.request, {'unsigned_entries': {}})
        self.release.state['request_sha256'] = RELEASE.sha(self.release.request)
        stage = types.SimpleNamespace(inventory=lambda *args: {})
        original_sha = RELEASE.sha
        with patch.object(self.release, 'unchanged'), \
                patch.object(RELEASE, 'module', return_value=stage), \
                patch.object(RELEASE, 'sha', side_effect=lambda p: self.config['signer_sha256']
                             if str(p) == self.config['signer'] else original_sha(p)), \
                patch.object(RELEASE, 'command', side_effect=subprocess.CalledProcessError(1, 'protected-adapter')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.release.sign()
        self.assertNotIn('response_sha256', self.release.state)
        self.assertFalse((self.directory / 'public').exists())

    def test_package_failure_detaches_only_own_mount_and_retains_evidence(self):
        response = {'receipt': 'bundle.json', 'receipt_sha256': 'a' * 64}
        calls = []
        def command(argv, **kwargs):
            calls.append([str(arg) for arg in argv])
            if any('make_styled_dmg.sh' in str(arg) for arg in argv):
                output = self.directory / 'packages'
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
        response = {'receipt': 'bundle.json', 'receipt_sha256': 'a' * 64}
        def command(argv, **kwargs):
            if any('make_styled_dmg.sh' in str(arg) for arg in argv):
                output = self.directory / 'packages'
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
        response = {'receipt': 'bundle.json', 'receipt_sha256': 'a' * 64}
        def command(argv, **kwargs):
            if any('make_styled_dmg.sh' in str(arg) for arg in argv):
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

    def run_stage(self, configuration='Release', candidate='0', managed=True, prepare=None):
        import base64
        with tempfile.TemporaryDirectory() as temporary:
            if prepare:
                prepare(Path(temporary) / 'Flash.app/Contents')
            env = dict(os.environ, DART_DEFINES=base64.b64encode(
                ('MACOS_MANAGED_HELPER=' + str(managed).lower()).encode()).decode(),
                CONFIGURATION=configuration, TARGET_BUILD_DIR=temporary,
                CONTENTS_FOLDER_PATH='Flash.app/Contents', ARCHS='arm64',
                FC_MANAGED_CANDIDATE_ENABLED=candidate, SRCROOT=str(PACKAGING.parent))
            result = subprocess.run(['/bin/bash', str(PACKAGING / 'stage_bundled_daemon.sh')],
                                    env=env, capture_output=True, text=True)
            contents = Path(temporary) / 'Flash.app/Contents'
            result.files = sorted(str(p.relative_to(contents)) for p in contents.rglob('*') if p.is_file())
            return result

    def test_release_stage_copies_both_daemon_plists(self):
        result = self.run_stage()
        if result.returncode != 0 and 'xcrun' in result.stderr + result.stdout:
            self.skipTest('no compiler')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Library/LaunchDaemons/com.layoute.flash.helperd.plist', result.files)
        self.assertIn('Library/LaunchDaemons/com.layoute.flash.daemon.plist', result.files)

    def test_unmanaged_build_embeds_nothing(self):
        result = self.run_stage(managed=False)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.files, [])

    def test_invalid_candidate_and_non_release_fail(self):
        result = self.run_stage(candidate='invalid')
        self.assertIn('FC_MANAGED_CANDIDATE_ENABLED', result.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Bundled daemon requires Release', self.run_stage(configuration='Debug').stderr)

    def test_stale_legacy_artifacts_are_not_silently_deleted(self):
        for stale in ('Library/HelperTools/FlashMaintenance',
                      'Library/LaunchDaemons/com.layoute.flash.helper.plist', 'Resources/HelperInstaller'):
            def prepare(contents, stale=stale):
                (contents / stale).parent.mkdir(parents=True, exist_ok=True)
                (contents / stale).write_text('legacy')
            with self.subTest(stale=stale):
                result = self.run_stage(prepare=prepare)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Stale legacy helper artifact', result.stderr)
                self.assertIn(stale, result.files)

    def test_source_compiles_helper_with_info_plist_and_copies_daemon_plist(self):
        script = (PACKAGING / 'stage_bundled_daemon.sh').read_text()
        self.assertIn('-sectcreate __TEXT __info_plist "$SRCROOT/PrivilegedHelper/Info.plist"', script)
        self.assertIn('-o "$library/HelperTools/FlashHelper"', script)
        self.assertIn('for plist in com.layoute.flash.helperd.plist com.layoute.flash.daemon.plist; do', script)
        self.assertIn('/bin/cp "$SRCROOT/PrivilegedHelper/$plist" "$library/LaunchDaemons/"', script)
        for forbidden in ('Maintenance.m', 'com.layoute.flash.helper.plist" "$library', 'codesign',
                          'launchctl', 'registerAndReturnError', 'pkgbuild', 'sudo '):
            self.assertNotIn(forbidden, script)

if __name__ == '__main__':
    unittest.main()
