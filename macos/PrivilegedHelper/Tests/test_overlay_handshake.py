import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TESTS = MACOS / 'PrivilegedHelper/Tests'
REPO = MACOS.parent
PEER_ID = 'com.layoute.flash.test.peer'


def at_tag(tag, path):
    shown = subprocess.run(['git', '-C', str(REPO), 'show', f'{tag}:{path}'], capture_output=True, text=True)
    return shown.stdout if shown.returncode == 0 else None


class OverlayHandshakeTests(unittest.TestCase):
    """Installing this build over dev.6, mitm.1, mitm.3 or mitm.4, as far as it goes without installing anything:
    what each earlier build leaves behind is read from its tag, and the first replies the app then gets are produced
    by real processes (signed, hardened runtime, running from a directory the app cannot read where the launcher's
    copy would be) and judged by the app's own validator (OverlayHandshakeTests.m). SMAppService, launchd, the
    launcher (root) and the pinned certificate are out of reach; the registration side of each overlay is the
    fixture-driven RetiredNameTests / update-recovery tests."""

    def test_what_each_earlier_build_leaves_behind(self):
        header = (MACOS / 'Shared/HelperTrust.h').read_text()
        bridge = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()
        self.assertIn('#define FC_HELPER_LABEL "com.layoute.flash.helperd"', header)
        self.assertIn('#define FC_RETIRED_HELPER_LABEL "com.layoute.flash.daemon"', header)
        # The app only ever connects to the current name, so a daemon of the old name never answers it.
        self.assertEqual(bridge.count('xpc_connection_create_mach_service('), 1)
        self.assertIn('xpc_connection_create_mach_service(FCHelperLabel.UTF8String', bridge)
        checked = 0
        for tag in ('v0.9.15-dev.6', 'v0.9.15-mitm.1', 'v0.9.15-mitm.3', 'v0.9.15-mitm.4'):
            trust = at_tag(tag, 'macos/Shared/HelperTrust.m')
            supervisor = at_tag(tag, 'macos/PrivilegedHelper/Supervisor.m')
            if trust is None or supervisor is None:
                continue
            checked += 1
            # Same wire protocol in both directions.
            self.assertIn('xpc_dictionary_set_int64(reply, "protocol", 1);', supervisor, tag)
            self.assertIn('xpc_dictionary_get_int64(request, "protocol") != 1', supervisor, tag)
            if tag.endswith('mitm.4'):
                self.assertIn('FCHelperCopyPath = @"/Library/Application Support/com.layoute.flash.helperd/FlashHelper"',
                              trust)
                self.assertIn('NSString * const FCHelperLabel = @FC_HELPER_LABEL;', trust)
            else:
                # Old name, daemon run from inside the app bundle, no launcher copy.
                self.assertIn('NSString * const FCHelperLabel = @"com.layoute.flash.daemon";', trust, tag)
                self.assertNotIn('FCHelperCopyPath', trust, tag)
        if checked == 0:
            self.skipTest('release tags not available in this checkout')

    def test_first_replies_after_overlay(self):
        with tempfile.TemporaryDirectory(prefix='flash-overlay-') as scratch:
            root = Path(os.path.realpath(scratch))
            copies = root / 'helperd'           # stands in for /Library/Application Support/com.layoute.flash.helperd
            copies.mkdir(mode=0o700)
            copy = copies / 'FlashHelper'
            bundle = root / 'Flash.app/Contents/Library/HelperTools'
            bundle.mkdir(parents=True)
            sealed = bundle / 'FlashHelper'      # the helper sealed in the newly installed app
            builds = root / 'builds'
            builds.mkdir()
            new, previous = builds / 'new', builds / 'previous'
            checker = root / 'overlay-handshake'
            for binary, options in ((new, []), (previous, ['-O2'])):
                subprocess.run(['clang', '-Werror', *options, str(TESTS / 'UnreadablePeer.c'), '-o', str(binary)],
                               check=True, capture_output=True, text=True)
                subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--identifier', PEER_ID,
                                str(binary)], check=True, capture_output=True, text=True)
            shutil.copy2(new, sealed)
            subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                            '-DFCPinnedRequirement=TestPinnedRequirement', '-DFCPinnedCodePolicy=TestPinnedCodePolicy',
                            str(MACOS / 'Shared/HelperTrust.m'), str(TESTS / 'OverlayHandshakeTests.m'),
                            '-framework', 'Foundation', '-framework', 'Security', '-o', str(checker)],
                           check=True, capture_output=True, text=True)
            # Pinned by identity, not by cdhash, as the app's XPC peer requirement (certificate + identifier).
            requirement = f'identifier "{PEER_ID}"'

            def step(name, running, directory, lock, expected_path=copy):
                try:
                    result = subprocess.run([str(checker), str(directory), str(running), requirement,
                                             str(expected_path), str(sealed), '1' if lock else '0'],
                                            capture_output=True, text=True, timeout=60)
                finally:
                    directory.chmod(0o700 if lock else 0o755)
                report = json.loads(result.stdout.strip().splitlines()[-1])
                print(f'\noverlay {name}:', json.dumps(report, sort_keys=True))
                self.assertEqual(result.returncode, 0, report)
                self.assertEqual(len(report['replies']), 2, report)
                if lock:
                    self.assertTrue(report['peerFileUnreadable'], report)
                return report['replies']

            # dev.6 / mitm.1 / mitm.3: their daemon (old name) is never asked; the first helper on the new name is
            # the launcher's copy of the newly installed helper.
            shutil.copy2(new, copy)
            for reply in step('from dev.6/mitm.1/mitm.3: new copy', copy, copies, True):
                self.assertEqual(reply, {'accepted': True, 'failure': '', 'stale': False, 'code': 'ok'})

            # mitm.4: its copy may still be idling (up to 30 s) when the new app says hello.
            shutil.copy2(previous, copy)
            for reply in step('from mitm.4: previous copy still running', copy, copies, True):
                self.assertFalse(reply['accepted'])
                self.assertTrue(reply['stale'])
                self.assertEqual(reply['code'], 'staleHelper')     # waited out, never untrustedReply
                self.assertTrue(reply['failure'].startswith('failed:cdhash running='), reply)

            # ...and once it has exited, the launcher's next copy is the new helper.
            shutil.copy2(new, copy)
            for reply in step('from mitm.4: after the old copy exited', copy, copies, True):
                self.assertEqual(reply['code'], 'ok')

            # Not reachable (different name), shown for completeness: a daemon of the old layout, running from an
            # app bundle, would be refused on its path (never trusted, never "stale").
            old_bundle = root / 'Old.app/Contents/Library/HelperTools'
            old_bundle.mkdir(parents=True)
            shutil.copy2(previous, old_bundle / 'FlashHelper')
            for reply in step('old layout answering (hypothetical)', old_bundle / 'FlashHelper', old_bundle, False):
                self.assertEqual(reply, {'accepted': False, 'failure': 'failed:path', 'stale': False,
                                         'code': 'untrustedReply'})


if __name__ == '__main__':
    unittest.main()
