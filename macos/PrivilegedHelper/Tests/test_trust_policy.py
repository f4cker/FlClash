import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]


class TrustPolicyFixtureTests(unittest.TestCase):
    """Runs the pure TrustPolicyTests.m fixture (daemon plist schema, requirements, entitlements, layout)."""

    def test_trust_policy_fixture_in_both_candidate_modes(self):
        with tempfile.TemporaryDirectory(prefix='flash-trust-policy-') as scratch:
            for defines in ([], ['-DFC_MANAGED_CANDIDATE_ENABLED=1', '-DFC_TRUST_TEST_EXPECT_CANDIDATE_ENABLED=1']):
                with self.subTest(defines=defines):
                    binary = Path(scratch) / 'trust'
                    subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                                    f'-DFC_SOURCE_ROOT="{MACOS}"', *defines,
                                    str(MACOS / 'Shared/HelperTrust.m'),
                                    str(MACOS / 'PrivilegedHelper/Tests/TrustPolicyTests.m'),
                                    '-framework', 'Foundation', '-framework', 'Security', '-o', str(binary)],
                                   check=True, capture_output=True, text=True)
                    result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_core_guest_check_over_kernel_answers(self):
        with tempfile.TemporaryDirectory(prefix='flash-core-guest-') as scratch:
            binary = Path(scratch) / 'guest'
            subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                            '-DFCCodeOps=FixtureCodeOps',
                            str(MACOS / 'Shared/HelperTrust.m'),
                            str(MACOS / 'PrivilegedHelper/Tests/CoreGuestTests.m'),
                            '-framework', 'Foundation', '-framework', 'Security', '-o', str(binary)],
                           check=True, capture_output=True, text=True)
            result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_c_policy_fixtures(self):
        with tempfile.TemporaryDirectory(prefix='flash-c-policy-') as scratch:
            for name in ('ProtectedPathPolicyTests', 'SessionPolicyTests'):
                with self.subTest(name=name):
                    binary = Path(scratch) / name
                    subprocess.run(['clang', '-Werror', str(MACOS / f'PrivilegedHelper/Tests/{name}.c'),
                                    '-framework', 'CoreFoundation', '-o', str(binary)],
                                   check=True, capture_output=True, text=True)
                    subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=20)

    def test_daemon_plist_file(self):
        for name in ('com.layoute.flash.helperd.plist', 'com.layoute.flash.daemon.plist'):
            plist = MACOS / 'PrivilegedHelper' / name
            subprocess.run(['plutil', '-lint', str(plist)], check=True, capture_output=True, text=True)
        self.assertFalse((MACOS / 'PrivilegedHelper/com.layoute.flash.helper.plist').exists())


if __name__ == '__main__':
    unittest.main()
