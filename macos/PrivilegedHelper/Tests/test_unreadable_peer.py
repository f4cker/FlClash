import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TESTS = MACOS / 'PrivilegedHelper/Tests'


class UnreadablePeerTests(unittest.TestCase):
    """Real reproduction (no mocks, no root) of mitm.4's reply validation against a daemon whose executable the
    app cannot read, and of the kernel-only check that replaces it (UnreadablePeerTests.m)."""

    def test_reply_from_peer_in_unreadable_directory(self):
        with tempfile.TemporaryDirectory(prefix='flash-unreadable-peer-') as scratch:
            root = Path(os.path.realpath(scratch))
            hidden = root / 'helperd'
            hidden.mkdir(mode=0o755)
            peer = hidden / 'FlashHelper'
            # Readable: the same signed bytes (as the helper sealed in the app is for the launcher's copy), and a
            # different build (as after an app update while the old daemon still runs).
            sealed = root / 'SealedFlashHelper'
            other = root / 'OtherFlashHelper'
            checker = root / 'unreadable-peer'
            try:
                for binary, options in ((peer, []), (other, ['-O2'])):
                    subprocess.run(['clang', '-Werror', *options, str(TESTS / 'UnreadablePeer.c'), '-o', str(binary)],
                                   check=True, capture_output=True, text=True)
                    # Ad hoc, hardened runtime: the kernel then reports CS_VALID | CS_HARD | CS_KILL | CS_RUNTIME.
                    subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime',
                                    '--identifier', 'com.layoute.flash.test.peer', str(binary)],
                                   check=True, capture_output=True, text=True)
                shutil.copy2(peer, sealed)
                shown = subprocess.run(['codesign', '-d', '-vvv', str(peer)], check=True, capture_output=True,
                                       text=True).stderr
                cdhash = re.search(r'^CDHash=([0-9a-f]{40})$', shown, re.M).group(1)
                subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                                '-DFCPinnedRequirement=TestPinnedRequirement',
                                '-DFCPinnedCodePolicy=TestPinnedCodePolicy',
                                str(MACOS / 'Shared/HelperTrust.m'), str(TESTS / 'UnreadablePeerTests.m'),
                                '-framework', 'Foundation', '-framework', 'Security', '-o', str(checker)],
                               check=True, capture_output=True, text=True)
                requirement = f'identifier "com.layoute.flash.test.peer" and cdhash H"{cdhash}"'
                result = subprocess.run([str(checker), str(hidden), str(peer), requirement, str(sealed), str(other)],
                                        capture_output=True, text=True, timeout=60)
            finally:
                hidden.chmod(0o755)
            report = json.loads(result.stdout.strip().splitlines()[-1])
            print('\nunreadable peer:', json.dumps(report, indent=1, sort_keys=True))
            self.assertNotEqual(result.returncode, 3, 'root cause NOT reproduced: Security validated the peer')
            self.assertEqual(result.returncode, 0, report)
            self.assertEqual(report['problems'], [])
            self.assertEqual(report['fix'], 'verified')
            self.assertEqual(report['kernel']['csopsAuditTokenCDHash'], cdhash)
            # The app's own validator: mitm.4's configuration fails at Security, the fixed one accepts real replies.
            self.assertTrue(report['validatorAsMitm4'].startswith('SecCodeCheckValidity OSStatus'))
            self.assertEqual(report['validatorFixed'], 'accepted')
            self.assertEqual(report['validatorFixedSecondReply'], 'accepted')
            self.assertTrue(report['validatorOtherBuild'].startswith('failed:cdhash running='))
            self.assertEqual(report['validatorWrongPath'], 'failed:path')
            # The peer exited after replying: refused as transient (bridge: unavailable, not untrustedReply).
            self.assertEqual(report['validatorAfterExit'], 'failed:status-read errno=3 transient=1')


if __name__ == '__main__':
    unittest.main()
