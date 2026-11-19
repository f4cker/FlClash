import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
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

    def reservation(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name).resolve()
        source = {'head': 'a' * 40, 'archive_sha256': 'b' * 64}
        signing = {'schema': 'flash-mitm4-bundle-signing-v1',
                   'release_identity': {'source_head': 'a' * 40, 'channel': 'stable',
                                        'releaseVersion': '1.0.0', 'version': '1.0.0', 'build': '2026111902'},
                   'verify_signed': {'helper_version': '2026111902',
                                     'compatibility': {'CoreRevision': 'a' * 40}}}
        evidence = {}
        for name, receipt in [('sourceReceipt', source), ('signingReceipt', signing)]:
            path = root / (name + '.json')
            path.write_text(json.dumps(receipt))
            evidence[name] = str(path)
            evidence[name + 'Sha256'] = TOOL.sha256_file(path)
        return {'channel': 'stable', 'tag': 'v1.0.0', 'version': '1.0.0',
                'build': 2026111902, 'helperBuild': 2026111902,
                'disposition': 'unpublished-reservation', 'reservation': evidence}

    def rewrite_receipt(self, entry, name, receipt):
        path = Path(entry['reservation'][name])
        path.write_text(json.dumps(receipt))
        entry['reservation'][name + 'Sha256'] = TOOL.sha256_file(path)

    def test_legacy_and_explicit_published_rows_keep_semantic_floor(self):
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        stable = {'channel': 'stable', 'tag': 'v1.0.0', 'version': '1.0.0',
                  'build': 2026111902, 'helperBuild': 2026111902}
        for entry in [stable, {**stable, 'disposition': 'published'}]:
            with self.assertRaisesRegex(ValueError, 'semantic version'):
                TOOL.validate_release_ledger(candidate, [entry])

    def test_pinned_unpublished_stable_reserves_build_without_setting_semantic_floor(self):
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        delivered = {'channel': 'stable', 'tag': 'v0.9.15-mitm.12', 'version': '0.9.15',
                     'build': 2026111901, 'helperBuild': 2026111901}
        reservation = self.reservation()
        TOOL.validate_release_ledger(candidate, [delivered, reservation])
        TOOL.validate_release_ledger(candidate, [reservation])
        with self.assertRaisesRegex(ValueError, 'semantic version'):
            TOOL.validate_release_ledger(candidate, [{**delivered, 'version': '1.0.0'}, reservation])

    def test_unpublished_reservations_still_block_app_helper_and_tag_reuse(self):
        entry = self.reservation()
        for field in ('build', 'helperBuild'):
            for build in (2026111901, 2026111902):
                candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
                candidate[field] = build
                with self.assertRaisesRegex(ValueError, 'builds must grow', msg=field):
                    TOOL.validate_release_ledger(candidate, [entry])
        with self.assertRaisesRegex(ValueError, 'tags are immutable'):
            TOOL.validate_release_ledger(self.payload('stable', '1.0.0', 2026111903), [entry])

    def test_unknown_disposition_fails_closed_and_only_explicit_reservations_relax_floor(self):
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        for disposition in ('unpublished', 'draft', '', None, False, 0, [], {}):
            entry = self.reservation()
            entry['disposition'] = disposition
            with self.assertRaisesRegex(ValueError, 'disposition'):
                TOOL.validate_release_ledger(candidate, [entry])
        for explicit in (False, True):
            entry = self.reservation()
            if explicit:
                entry['disposition'] = 'published'
            else:
                del entry['disposition']
            with self.assertRaisesRegex(ValueError, 'semantic version'):
                TOOL.validate_release_ledger(candidate, [entry])

    def test_reservations_require_complete_pinned_readable_receipts(self):
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        for evidence in (None, {}, {'sourceReceipt': 'not-absolute'}, 'receipt'):
            entry = self.reservation()
            entry['reservation'] = evidence
            with self.assertRaises(ValueError):
                TOOL.validate_release_ledger(candidate, [entry])
        for name in ('sourceReceipt', 'signingReceipt'):
            for failure in ('missing-file', 'relative-path', 'missing-key', 'wrong-hash', 'invalid-hash',
                            'invalid-json', 'invalid-object'):
                entry = self.reservation()
                evidence = entry['reservation']
                path = Path(evidence[name])
                if failure == 'missing-file':
                    path.unlink()
                elif failure == 'relative-path':
                    evidence[name] = path.name
                elif failure == 'missing-key':
                    del evidence[name + 'Sha256']
                elif failure == 'wrong-hash':
                    evidence[name + 'Sha256'] = '0' * 64
                elif failure == 'invalid-hash':
                    evidence[name + 'Sha256'] = None
                elif failure == 'invalid-json':
                    path.write_bytes(b'not json')
                    evidence[name + 'Sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
                elif failure == 'invalid-object':
                    self.rewrite_receipt(entry, name, [])
                with self.assertRaises(ValueError, msg=(name, failure)):
                    TOOL.validate_release_ledger(candidate, [entry])

    def test_receipt_identity_must_match_reservation_even_with_valid_hashes(self):
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        for field, value in [('channel', 'beta'), ('version', '1.0.1'), ('tag', 'v1.0.0-other'),
                             ('build', 2026111900), ('helperBuild', 2026111900)]:
            entry = self.reservation()
            entry[field] = value
            with self.assertRaisesRegex(ValueError, 'differs from source/signing', msg=field):
                TOOL.validate_release_ledger(candidate, [entry])
        changes = [('sourceReceipt', ('head',), 'c' * 40),
                   ('sourceReceipt', ('head',), 'not-a-commit'),
                   ('sourceReceipt', ('archive_sha256',), None),
                   ('signingReceipt', ('schema',), 'other'),
                   ('signingReceipt', ('release_identity',), None),
                   ('signingReceipt', ('release_identity', 'source_head'), 'd' * 40),
                   ('signingReceipt', ('verify_signed',), None),
                   ('signingReceipt', ('verify_signed', 'compatibility'), None),
                   ('signingReceipt', ('verify_signed', 'compatibility', 'CoreRevision'), 'e' * 40)]
        for name, keys, value in changes:
            entry = self.reservation()
            receipt = json.loads(Path(entry['reservation'][name]).read_text())
            target = receipt
            for key in keys[:-1]:
                target = target[key]
            target[keys[-1]] = value
            self.rewrite_receipt(entry, name, receipt)
            with self.assertRaises(ValueError, msg=(name, keys)):
                TOOL.validate_release_ledger(candidate, [entry])

    def test_signing_rejects_unproven_reservation_before_private_key_access(self):
        from argparse import Namespace
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name).resolve()
        ledger = root / 'ledger.json'
        entry = self.reservation()
        entry.pop('reservation')
        ledger.write_text(json.dumps([entry]))
        args = Namespace(app=str(root / 'Flash.app'), channel='beta', release_version='1.0.0-beta.1',
                         tag='v1.0.0-beta.1', source_commit='a' * 40, source_branch='release/1.0.0-beta.1',
                         base_url=TOOL.DEFAULT_BASE_URL, release_ledger=str(ledger), out=str(root / 'assets'))
        facts = {'version': '1.0.0-beta.1', 'build': 2026111903, 'helperBuild': 2026111903,
                 'minimumSystemVersion': '12.0', 'channel': 'beta', 'releaseVersion': '1.0.0-beta.1'}
        with patch.object(TOOL, 'check_signature'), patch.object(TOOL, 'bundle_facts', return_value=facts), \
                patch.object(TOOL, 'read_private_key') as private_key, patch.object(TOOL.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'pinned source and signing receipts'):
                TOOL.command_sign(args)
            private_key.assert_not_called()
            command.assert_not_called()
            self.assertFalse((root / 'assets').exists())

    def test_publication_check_rejects_unknown_disposition(self):
        from argparse import Namespace
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name).resolve()
        ledger, manifest = root / 'ledger.json', root / 'manifest.json'
        entry = self.reservation()
        entry['disposition'] = 'unknown'
        ledger.write_text(json.dumps([entry]))
        manifest.write_text('{}')
        args = Namespace(manifest=str(manifest), public_key='unused', release_ledger=str(ledger))
        candidate = self.payload('beta', '1.0.0-beta.1', 2026111903)
        with patch.object(TOOL, 'read_public_key', return_value=b'fake'), \
                patch.object(TOOL, 'open_envelope', return_value=candidate), \
                patch.object(TOOL, 'validate_publication') as publication:
            with self.assertRaisesRegex(ValueError, 'disposition'):
                TOOL.command_check_publication(args)
            publication.assert_not_called()

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
