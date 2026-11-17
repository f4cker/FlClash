from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'macos/Runner'
TESTS = ROOT / 'macos/RunnerTests'
PROJECT = (ROOT / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
VECTORS = ROOT / 'core/testdata/mitm_hostname_vectors.json'
# Everything the signer needs, without Flutter: the channel and the keychain store stay out.
SHARED = ['MitmCertificate.swift', 'MitmHostPolicy.swift', 'MitmPublicSuffixList.swift', 'MitmSigner.swift']
APP_ONLY = ['MitmKeychainStore.swift', 'MitmSignerChannel.swift']
SOURCES = [RUNNER / name for name in SHARED] + [TESTS / 'MitmSignerTests.swift']


def _xcrun(*args, **kwargs):
    return subprocess.run(['xcrun', *args], capture_output=True, text=True, **kwargs)


class MitmSignerTests(unittest.TestCase):
    def test_sources_build_into_runner_and_its_tests(self):
        for name in SHARED:
            self.assertEqual(PROJECT.count(f'/* {name} in Sources */,'), 2, name)
        for name in APP_ONLY:
            self.assertEqual(PROJECT.count(f'/* {name} in Sources */,'), 1, name)
        self.assertEqual(PROJECT.count('/* MitmSignerTests.swift in Sources */,'), 1)

    def test_apple_domains_match_the_core(self):
        swift = (RUNNER / 'MitmHostPolicy.swift').read_text()
        swift = swift[swift.index('static let appleDomains = ['):]
        swift = re.findall(r'"([^"]+)"', swift[:swift.index(']')])
        go = (ROOT / 'core/mitm_host.go').read_text()
        go = go[go.index('mitmAppleDomains = '):]
        go = re.findall(r'"([^"]+)"', go[:go.index('}')])
        self.assertTrue(swift)
        self.assertEqual(sorted(swift), sorted(go))

    def test_public_suffix_list_is_the_cores(self):
        if not shutil.which('go'):
            self.skipTest('needs Go')
        check = subprocess.run(
            [sys.executable, str(ROOT / 'tool/macos/gen_mitm_public_suffix.py'), '--check'],
            capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)

    def test_keys_stay_in_the_login_keychain(self):
        store = (RUNNER / 'MitmKeychainStore.swift').read_text()
        self.assertIn('kSecAttrIsExtractable as String: false', store)
        self.assertIn('SecTrustSettingsRemoveTrustSettings', store)
        self.assertEqual(store.count('kSecMatchSearchList as String: [try loginKeychain()]'), 2)
        self.assertEqual(store.count('kSecUseKeychain as String: try loginKeychain()'), 2)
        self.assertIn('MitmDeletion.run(', store)
        load = store[store.index('func loadKey()'):store.index('func createKey()')]
        self.assertIn('query[kSecAttrApplicationLabel as String] = label', load)
        self.assertIn('defaults.string(forKey: Self.certificateDefault)', store)
        for forbidden in ('SecKeyCopyExternalRepresentation(privateKey', 'kSecAttrIsExtractable as String: true',
                          'SecItemExport'):
            self.assertNotIn(forbidden, store)

    def test_signing_needs_the_verified_core(self):
        signer = (RUNNER / 'MitmSigner.swift').read_text()
        body = signer[signer.index('func sign(host'):]
        body = body[:body.index('return issue(')]
        self.assertLess(body.index('lastCoreIdentity == "verified"'), body.index('MitmHostMatcher'))
        channel = (RUNNER / 'MitmSignerChannel.swift').read_text()
        self.assertIn('coreIdentity: ManagedHelperChannel.coreIdentity', channel)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_xctest_suite_passes(self):
        platform = _xcrun('--show-sdk-platform-path').stdout.strip()
        if not platform:
            self.skipTest('no macOS SDK platform')
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / 'MitmSignerTests.xctest'
            binary = bundle / 'Contents/MacOS/MitmSignerTests'
            binary.parent.mkdir(parents=True)
            frameworks = f'{platform}/Developer/Library/Frameworks'
            libraries = f'{platform}/Developer/usr/lib'
            build = _xcrun(
                'swiftc', '-parse-as-library', '-emit-library', '-module-name', 'RunnerTests',
                '-F', frameworks, '-I', libraries, '-L', libraries, '-framework', 'XCTest',
                '-Xlinker', '-bundle', '-Xlinker', '-rpath', '-Xlinker', frameworks,
                '-Xlinker', '-rpath', '-Xlinker', libraries,
                *map(str, SOURCES), '-o', str(binary))
            self.assertEqual(build.returncode, 0, build.stderr)
            env = {'MITM_HOSTNAME_VECTORS': str(VECTORS), 'PATH': '/usr/bin:/bin'}
            run = _xcrun('xctest', str(bundle), env=env)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('with 0 failures', run.stderr + run.stdout)


if __name__ == '__main__':
    unittest.main()
