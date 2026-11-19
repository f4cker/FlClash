import base64
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location('manifest_tool', ROOT / 'tool/macos/make_update_manifest.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class UpdateChannelManifestTests(unittest.TestCase):
    def payload(self, channel='stable', version='1.0.0', build=2026111902):
        facts = {'version': '1.0.0', 'build': build, 'helperBuild': build, 'minimumSystemVersion': '12.0',
                 'channel': channel, 'releaseVersion': version}
        tag = 'v' + version
        facts['releaseMetadata'] = TOOL.channel_metadata(facts, channel, version, tag, 'a' * 40, 'release/1.0')
        name = 'Flash-1.0.0-macos-arm64.zip'
        return TOOL.make_payload(facts, {'arch': 'arm64', 'name': name, 'size': 4, 'sha256': 'a' * 64,
                                       'url': f'{TOOL.DEFAULT_BASE_URL}/{tag}/{name}'}, 'fixture', '2026-11-19')

    def test_stable_remains_schema_one_and_beta_requires_schema_two(self):
        for channel, schema in [('stable', 1), ('beta', 2)]:
            payload = self.payload(channel)
            self.assertEqual(payload['schema'], schema)
            TOOL.validate_channel_payload(payload)
            policy = TOOL.publication_policy(payload)
            self.assertEqual(policy['prerelease'], channel == 'beta')
            self.assertEqual(policy['make_latest'], 'false' if channel == 'beta' else 'true')
            self.assertEqual(policy['repository'], 'f4cker/flash-releases')
            payload['schema'] = 3 - schema
            with self.assertRaises(ValueError):
                TOOL.validate_channel_payload(payload)

    def test_bundle_must_seal_explicit_identity_before_signing(self):
        for facts in [{}, {'channel': 'stable', 'releaseVersion': '1.0.0'},
                      {'channel': 'beta', 'releaseVersion': '1.0.1'}]:
            with self.assertRaisesRegex(ValueError, 'Bundle must seal'):
                TOOL.channel_metadata(facts, 'beta', '1.0.0', 'v1.0.0', 'a' * 40, 'dev')

    def test_source_and_repository_are_bound_not_inferred_from_names(self):
        payload = self.payload('beta', '1.0.0')
        self.assertEqual(payload['channel'], 'beta')
        self.assertEqual(payload['release']['sourceRepository'], 'f4cker/FlClash')
        for key, value in [('repository', 'other/repo'), ('sourceCommit', 'A' * 40), ('tag', '../v1'),
                           ('sourceBranch', 'branch with space'), ('version', '1.0.0-beta.01')]:
            altered = copy.deepcopy(payload)
            altered['release'][key] = value
            with self.assertRaises(ValueError, msg=key):
                TOOL.validate_channel_payload(altered)
        payload['assets'][0]['url'] += '?ignored=1'
        with self.assertRaises(ValueError):
            TOOL.validate_channel_payload(payload)

    def test_future_missing_channel_is_not_legacy(self):
        payload = self.payload()
        payload.pop('channel')
        with self.assertRaises(ValueError):
            TOOL.validate_channel_payload(payload)
        payload['build'] = 2026111901
        TOOL.validate_channel_payload(payload)
        with self.assertRaises(ValueError):
            TOOL.publication_policy(payload)

    def test_global_app_and_helper_builds_and_semantic_history_must_grow(self):
        history = [{'channel': 'beta', 'tag': 'v1.0.0-beta.1', 'version': '1.0.0-beta.1',
                    'build': 2026111901, 'helperBuild': 2026111901}]
        TOOL.validate_release_ledger(self.payload(), history)
        for changes in [{'build': 2026111902}, {'helperBuild': 2026111902}, {'version': '1.1.0-beta.1'},
                        {'tag': 'v1.0.0'}]:
            with self.assertRaises(ValueError):
                TOOL.validate_release_ledger(self.payload(), [{**history[0], **changes}])
        with self.assertRaises(ValueError):
            TOOL.validate_release_ledger(self.payload(), [])

    def test_beta_publication_must_preserve_stable_snapshot(self):
        before = {'id': 100, 'tag': 'v1.0.0', 'manifest_sha256': 'a' * 64}
        TOOL.assert_stable_latest_unchanged(before, dict(before))
        for key, value in [('id', 101), ('tag', 'v1.1.0-beta.1'), ('manifest_sha256', 'b' * 64)]:
            with self.assertRaisesRegex(ValueError, 'changed stable latest'):
                TOOL.assert_stable_latest_unchanged(before, {**before, key: value})

    def test_publication_delivery_matrix_and_latest_snapshots(self):
        before = {'id': 100, 'tag': 'v0.9.15', 'manifest_sha256': 'a' * 64}
        for channel in ['stable', 'beta']:
            payload = self.payload(channel)
            release = {'repository': 'f4cker/flash-releases', 'tag_name': 'v1.0.0',
                       'prerelease': channel == 'beta', 'draft': False}
            TOOL.validate_publication(payload, release, before, before)
            for key, value in [('repository', 'f4cker/FlClash'), ('tag_name', 'v0.9.15'),
                               ('prerelease', channel != 'beta'), ('draft', True)]:
                with self.assertRaises(ValueError):
                    TOOL.validate_publication(payload, {**release, key: value}, before, before)
            if channel == 'beta':
                with self.assertRaises(ValueError):
                    TOOL.validate_publication(payload, release)

    def test_legacy_dmg_publisher_cannot_publish_new_channel_builds(self):
        spec = importlib.util.spec_from_file_location('legacy_release', ROOT / 'macos/packaging/local_release.py')
        legacy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(legacy)
        legacy.require_legacy_build('2026111901')
        with self.assertRaisesRegex(ValueError, 'channel-era'):
            legacy.require_legacy_build('2026111902')
        release = object.__new__(legacy.Release)
        release.identity = {'build': '2026111902'}
        with patch.object(legacy, 'command') as command:
            with self.assertRaises(ValueError):
                release.publish()
            command.assert_not_called()

    def test_envelope_matrix_with_fake_crypto_only(self):
        for channel in ['stable', 'beta']:
            payload = self.payload(channel)
            envelope = {'schema': payload['schema'], 'payload': base64.b64encode(json.dumps(payload).encode()).decode(),
                        'signature': base64.b64encode(bytes(64)).decode()}
            with patch.object(TOOL, 'verify', return_value=True):
                self.assertEqual(TOOL.open_envelope(envelope, bytes(32)), payload)
                with self.assertRaises(SystemExit):
                    TOOL.open_envelope({**envelope, 'schema': 3 - payload['schema']}, bytes(32))
                with self.assertRaises(SystemExit):
                    TOOL.open_envelope({**envelope, 'channel': channel}, bytes(32))
            with patch.object(TOOL, 'verify', return_value=False):
                with self.assertRaises(SystemExit):
                    TOOL.open_envelope(envelope, bytes(32))


if __name__ == '__main__':
    unittest.main()
