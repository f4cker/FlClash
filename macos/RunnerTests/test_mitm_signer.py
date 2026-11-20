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
        # The Flutter stand-in and the channel harness stay out of every target.
        for name in ('FlutterMacOSStub.swift', 'MitmSignerChannelHarness.swift'):
            self.assertNotIn(name, PROJECT)
        self.assertNotIn('PBXFileSystemSynchronizedRootGroup', PROJECT)

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
        self.assertLess(body.index('let identity = coreIdentity()'), body.index('identity == "verified"'))
        self.assertLess(body.index('identity == "verified"'), body.index('MitmHostMatcher'))
        channel = (RUNNER / 'MitmSignerChannel.swift').read_text()
        self.assertIn('coreIdentity: ManagedHelperChannel.coreIdentity', channel)

    def test_channel_runs_on_the_dispatcher_lanes(self):
        channel = (RUNNER / 'MitmSignerChannel.swift').read_text()
        self.assertIn('self.dispatcher.run(MitmSignerDispatcher.lane(for: call.method))', channel)
        self.assertNotIn('DispatchQueue(label:', channel)
        # Each sign reports the identity its own check got.
        self.assertIn('answer["identity"] = outcome.identity', channel)
        self.assertNotIn('lastCoreIdentity', channel + (RUNNER / 'MitmSigner.swift').read_text())

    def _flutter_stub(self, tmp):
        """Builds the FlutterMacOS stand-in as a module and a library in tmp."""
        build = _xcrun('swiftc', '-emit-module', '-emit-library', '-parse-as-library', '-module-name', 'FlutterMacOS',
                       '-emit-module-path', str(Path(tmp, 'FlutterMacOS.swiftmodule')),
                       '-Xlinker', '-install_name', '-Xlinker', '@rpath/libFlutterMacOS.dylib',
                       str(TESTS / 'FlutterMacOSStub.swift'), '-o', str(Path(tmp, 'libFlutterMacOS.dylib')))
        self.assertEqual(build.returncode, 0, build.stderr)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_channel_typechecks_against_a_flutter_stub(self):
        # Compile-only, with the real keychain store: nothing runs.
        with tempfile.TemporaryDirectory() as tmp:
            self._flutter_stub(tmp)
            Path(tmp, 'Helper.swift').write_text(
                'enum ManagedHelperChannel { static func coreIdentity() -> String { "none" } }\n')
            check = _xcrun('swiftc', '-typecheck', '-I', tmp,
                           *[str(RUNNER / name) for name in SHARED + APP_ONLY], str(Path(tmp, 'Helper.swift')))
            self.assertEqual(check.returncode, 0, check.stderr)

    def _run_channel(self, sanitize):
        # The real channel with an in-memory store in place of
        # MitmKeychainStore and a stub ManagedHelperChannel: no app, no keychain.
        with tempfile.TemporaryDirectory() as tmp:
            self._flutter_stub(tmp)
            harness = Path(tmp, 'harness')
            build = _xcrun('swiftc', *(['-sanitize=thread'] if sanitize else []),
                           '-parse-as-library', '-I', tmp, '-L', tmp,
                           '-lFlutterMacOS', '-Xlinker', '-rpath', '-Xlinker', tmp,
                           *[str(RUNNER / name) for name in SHARED + ['MitmSignerChannel.swift']],
                           str(TESTS / 'MitmSignerChannelHarness.swift'), '-o', str(harness))
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(harness)], capture_output=True, text=True, timeout=120)
            output = run.stdout + run.stderr
            self.assertEqual(run.returncode, 0, output)
            self.assertEqual(run.stdout.strip(), 'PASS', output)
            self.assertNotIn('ThreadSanitizer', output)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_channel_runs_against_a_flutter_stub(self):
        self._run_channel(sanitize=False)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_channel_runs_against_a_flutter_stub_under_thread_sanitizer(self):
        self._run_channel(sanitize=True)

    def _run_xctest(self, sanitize=False):
        platform = _xcrun('--show-sdk-platform-path').stdout.strip()
        if not platform:
            self.skipTest('no macOS SDK platform')
        env = {'MITM_HOSTNAME_VECTORS': str(VECTORS), 'PATH': '/usr/bin:/bin'}
        if sanitize:
            # xcrun is SIP-protected and would drop DYLD_*: run xctest itself.
            xctest = _xcrun('-f', 'xctest').stdout.strip()
            toolchain = Path(_xcrun('-f', 'swiftc').stdout.strip()).parents[1]
            runtime = sorted(toolchain.glob('lib/clang/*/lib/darwin/libclang_rt.tsan_osx_dynamic.dylib'))
            if not xctest or not runtime:
                self.skipTest('no Thread Sanitizer runtime')
            env['DYLD_INSERT_LIBRARIES'] = str(runtime[-1])
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / 'MitmSignerTests.xctest'
            binary = bundle / 'Contents/MacOS/MitmSignerTests'
            binary.parent.mkdir(parents=True)
            frameworks = f'{platform}/Developer/Library/Frameworks'
            libraries = f'{platform}/Developer/usr/lib'
            build = _xcrun(
                'swiftc', *(['-sanitize=thread'] if sanitize else []),
                '-parse-as-library', '-emit-library', '-module-name', 'RunnerTests',
                '-F', frameworks, '-I', libraries, '-L', libraries, '-framework', 'XCTest',
                '-Xlinker', '-bundle', '-Xlinker', '-rpath', '-Xlinker', frameworks,
                '-Xlinker', '-rpath', '-Xlinker', libraries,
                *map(str, SOURCES), '-o', str(binary))
            self.assertEqual(build.returncode, 0, build.stderr)
            if sanitize:
                run = subprocess.run([xctest, str(bundle)], capture_output=True, text=True, env=env)
            else:
                run = _xcrun('xctest', str(bundle), env=env)
            output = run.stdout + run.stderr
            self.assertEqual(run.returncode, 0, output)
            self.assertIn('with 0 failures', output)
            self.assertIn('MitmSignerConcurrencyTests', output)
            self.assertNotIn('ThreadSanitizer', output)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_xctest_suite_passes(self):
        self._run_xctest()

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_xctest_suite_passes_under_thread_sanitizer(self):
        self._run_xctest(sanitize=True)


if __name__ == '__main__':
    unittest.main()
