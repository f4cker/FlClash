from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'macos/Runner'
TESTS = ROOT / 'macos/RunnerTests'
PROJECT = (ROOT / 'macos/Runner.xcodeproj/project.pbxproj').read_text()
SOURCES = [
    RUNNER / 'ProcessAppLocator.swift',
    RUNNER / 'ProcessSourceCatalog.swift',
    RUNNER / 'ProcessSourceResolver.swift',
    TESTS / 'ProcessAppLocatorTests.swift',
    TESTS / 'ProcessSourceCatalogTests.swift',
]


def _xcrun(*args):
    return subprocess.run(['xcrun', *args], capture_output=True, text=True)


class ProcessSourceTests(unittest.TestCase):
    def test_sources_build_into_runner_and_its_tests(self):
        for name in ('ProcessSourceCatalog.swift', 'ProcessSourceResolver.swift'):
            self.assertEqual(PROJECT.count(f'/* {name} in Sources */,'), 2, name)
        self.assertEqual(PROJECT.count('/* ProcessSourceCatalogTests.swift in Sources */,'), 1)

    def test_channel_answers_every_source(self):
        channel = (RUNNER / 'ProcessAppChannel.swift').read_text()
        for status in ('"none"', '"unreadable"', '"app"', '"service"'):
            self.assertIn(f'"status": {status}', channel)
        self.assertIn('answer["launchdLabel"]', channel)

    def test_dart_knows_every_catalog_service(self):
        catalog = (RUNNER / 'ProcessSourceCatalog.swift').read_text()
        swift = dict(
            (m.group(2), m.group(1) == 'shared')
            for m in re.finditer(r'^\s+(service|shared)\("(\w+)"', catalog, re.M))
        dart_source = (ROOT / 'lib/enum/enum.dart').read_text()
        body = dart_source[dart_source.index('enum SystemService {'):]
        body = body[:body.index(';')]
        dart = dict(
            (m.group(1), m.group(2) == 'true')
            for m in re.finditer(r'(\w+)\(shared: (true|false)\)', body))
        self.assertTrue(swift)
        self.assertEqual(swift, dart)

    @unittest.skipUnless(shutil.which('xcrun'), 'needs Xcode')
    def test_xctest_suite_passes(self):
        platform = _xcrun('--show-sdk-platform-path').stdout.strip()
        if not platform:
            self.skipTest('no macOS SDK platform')
        with tempfile.TemporaryDirectory() as tmp:
            bundle = Path(tmp) / 'ProcessSourceTests.xctest'
            binary = bundle / 'Contents/MacOS/ProcessSourceTests'
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
            run = _xcrun('xctest', str(bundle))
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('with 0 failures', run.stderr + run.stdout)


if __name__ == '__main__':
    unittest.main()
