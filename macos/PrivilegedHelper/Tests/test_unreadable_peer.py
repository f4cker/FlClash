import json
import os
import re
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
            checker = root / 'unreadable-peer'
            try:
                subprocess.run(['clang', '-Werror', str(TESTS / 'UnreadablePeer.c'), '-o', str(peer)],
                               check=True, capture_output=True, text=True)
                # Ad hoc, hardened runtime: the kernel then reports CS_VALID | CS_HARD | CS_KILL | CS_RUNTIME.
                subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime',
                                '--identifier', 'com.layoute.flash.test.peer', str(peer)],
                               check=True, capture_output=True, text=True)
                shown = subprocess.run(['codesign', '-d', '-vvv', str(peer)], check=True, capture_output=True,
                                       text=True).stderr
                cdhash = re.search(r'^CDHash=([0-9a-f]{40})$', shown, re.M).group(1)
                subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                                str(MACOS / 'Shared/HelperTrust.m'), str(TESTS / 'UnreadablePeerTests.m'),
                                '-framework', 'Foundation', '-framework', 'Security', '-o', str(checker)],
                               check=True, capture_output=True, text=True)
                requirement = f'identifier "com.layoute.flash.test.peer" and cdhash H"{cdhash}"'
                result = subprocess.run([str(checker), str(hidden), str(peer), requirement],
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


if __name__ == '__main__':
    unittest.main()
