import base64
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
ROOT = MACOS.parent
sys.path.insert(0, str(ROOT / 'tool/macos'))
import make_update_manifest as tool  # noqa: E402

HELPER_LABEL = 'com.layoute.flash.helperd'


def run(*command, **options):
    return subprocess.run([str(item) for item in command], check=True, capture_output=True, text=True, **options)


class UpdateInstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-updater-')
        cls.root = Path(os.path.realpath(cls.scratch.name))
        cls.driver = cls.root / 'driver'
        run('clang', '-fobjc-arc', '-Werror', '-Wno-deprecated-declarations',
            MACOS / 'PrivilegedHelper/Tests/UpdateInstallerTests.m', MACOS / 'Runner/UpdateInstaller.m',
            MACOS / 'Shared/HelperTrust.m', '-framework', 'Foundation', '-framework', 'Security',
            '-o', cls.driver)
        source = cls.root / 'stub.c'
        source.write_text('int main(void) { return VARIANT; }\n')
        cls.binaries = {}
        for variant in range(3):
            output = cls.root / f'stub{variant}'
            run('clang', f'-DVARIANT={variant}', source, '-o', output)
            cls.binaries[variant] = output

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def setUp(self):
        self.case = Path(tempfile.mkdtemp(dir=self.root))
        self.applications = self.case / 'Applications'
        self.applications.mkdir()
        self.target = self.applications / 'Flash.app'
        self.status = self.case / 'status'
        self.status.mkdir(mode=0o755)

    def tearDown(self):
        self.applications.chmod(0o755)
        shutil.rmtree(self.case, ignore_errors=True)

    def helper(self, directory, build):
        plist = directory / 'helper-Info.plist'
        plist.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.layoute.flash.helper',
                                          'CFBundleVersion': str(build)}))
        output = directory / f'helper-{build}'
        source = self.root / 'stub.c'
        run('clang', '-DVARIANT=0', source, '-sectcreate', '__TEXT', '__info_plist', plist, '-o', output)
        return output

    def make_app(self, path, build, helper_build, launcher=1, version=None):
        contents = path / 'Contents'
        tools = contents / 'Library/HelperTools'
        daemons = contents / 'Library/LaunchDaemons'
        for directory in (contents / 'MacOS', tools, daemons):
            directory.mkdir(parents=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleExecutable': 'Flash',
            'CFBundlePackageType': 'APPL', 'CFBundleVersion': str(build),
            'CFBundleShortVersionString': version or f'0.9.{build}'}))
        shutil.copy(self.binaries[0], contents / 'MacOS/Flash')
        shutil.copy(self.binaries[2], contents / 'MacOS/FlClashCore')
        shutil.copy(self.helper(self.case, helper_build), tools / 'FlashHelper')
        shutil.copy(self.binaries[launcher], tools / 'FlashHelperLauncher')
        (daemons / f'{HELPER_LABEL}.plist').write_bytes(plistlib.dumps({
            'Label': HELPER_LABEL, 'BundleProgram': 'Contents/Library/HelperTools/FlashHelperLauncher',
            'MachServices': {HELPER_LABEL: True}, 'ProcessType': 'Interactive',
            'AssociatedBundleIdentifiers': ['com.layoute.flash']}))
        for item, identifier in ((tools / 'FlashHelper', 'com.layoute.flash.helper'),
                                 (tools / 'FlashHelperLauncher', 'com.layoute.flash.helper-launcher'),
                                 (contents / 'MacOS/FlClashCore', 'com.layoute.flash.core')):
            run('codesign', '--force', '-s', '-', '-i', identifier, item)
        run('codesign', '--force', '-s', '-', path)
        return path

    def archive(self, build, helper_build, launcher=1, tamper=False):
        source = self.case / f'build-{build}-{helper_build}-{launcher}' / 'Flash.app'
        self.make_app(source, build, helper_build, launcher)
        if tamper:
            (source / 'Contents/MacOS/FlClashCore').write_bytes(b'tampered')
        archive = self.case / f'Flash-0.9.{build}-macos-arm64.zip'
        run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', source, archive)
        return archive

    def call(self, *arguments, env=None):
        result = subprocess.run([str(self.driver), *map(str, arguments)], capture_output=True, text=True,
                                env={**os.environ, **(env or {})})
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def prepare(self, archive, build, helper_build, sha=None, size=None, version=None, pinned=False):
        return self.call('prepare', archive, self.target, self.status, sha or tool.sha256_file(archive),
                         size or archive.stat().st_size, version or f'0.9.{build}', build, helper_build,
                         *(['pinned'] if pinned else []))

    def write_status(self, status):
        path = self.status / 'launcher.json'
        path.write_text(json.dumps(status))
        path.chmod(0o644)
        self.status.chmod(0o755)

    def staging_dirs(self):
        return sorted(item.name for item in self.applications.iterdir() if item.name.startswith('.Flash-update-'))

    def installed_build(self):
        return plistlib.loads((self.target / 'Contents/Info.plist').read_bytes())['CFBundleVersion']

    def test_prepare_install_and_cleanup(self):
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 101)
        prepared = self.prepare(archive, 101, 101)
        self.assertEqual(prepared['code'], 'ok', prepared)
        self.assertFalse(prepared['recordUnreadable'])
        staged = Path(prepared['staged'])
        self.assertEqual(staged.parent.parent, self.applications)
        self.assertEqual(staged.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.installed_build(), '100')
        installed = self.call('install', staged, self.target, self.status)
        self.assertEqual(installed['code'], 'ok', installed)
        self.assertEqual(self.installed_build(), '101')
        replaced = plistlib.loads((Path(installed['replaced']) / 'Contents/Info.plist').read_bytes())
        self.assertEqual(replaced['CFBundleVersion'], '100')
        self.assertEqual(self.call('cleanup', self.target)['code'], 'ok')
        self.assertEqual(self.staging_dirs(), [])
        self.assertTrue(self.target.is_dir())

    def test_rejects_archive_and_manifest_mismatches(self):
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 101)
        cases = {
            'sha256': dict(sha='0' * 64),
            'size': dict(size=archive.stat().st_size + 1),
            'build': dict(build=102),
            'helper build': dict(helper_build=102),
            'version': dict(version='0.9.999'),
        }
        for name, change in cases.items():
            with self.subTest(name):
                answer = self.prepare(archive, change.get('build', 101), change.get('helper_build', 101),
                                      sha=change.get('sha'), size=change.get('size'), version=change.get('version'))
                self.assertEqual(answer['code'], 'rejected', answer)
                self.assertEqual(self.staging_dirs(), [])

    def test_equal_or_older_build_is_not_newer(self):
        self.make_app(self.target, 100, 100)
        archives = {build: self.archive(build, 101) for build in (100, 99)}
        for build, archive in archives.items():
            with self.subTest(build=build):
                self.assertEqual(self.prepare(archive, build, 101)['code'], 'notNewer')
        # The manifest claims a newer build than the app inside the archive.
        archive = archives[100]
        answer = self.prepare(archive, 101, 101, version='0.9.100')
        self.assertEqual(answer['code'], 'rejected', answer)
        self.assertEqual(self.staging_dirs(), [])

    def test_helper_must_be_newer_than_installed_and_recorded(self):
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 100)
        self.assertEqual(self.prepare(archive, 101, 100)['code'], 'helperOlder')
        archive = self.archive(102, 101)
        status = {'v': 1, 'result': 'ok', 'detail': '', 'helperVersion': 150, 'recordedVersion': 150,
                  'launcherVersion': 1, 'time': 1}
        self.write_status(status)
        answer = self.prepare(archive, 102, 101)
        self.assertEqual(answer['code'], 'helperOlder', answer)
        status.update(result='version_unreadable', recordedVersion=None, helperVersion=101)
        self.write_status(status)
        answer = self.prepare(archive, 102, 101)
        self.assertEqual(answer['code'], 'ok', answer)
        self.assertTrue(answer['recordUnreadable'])

    def test_launcher_must_stay_byte_identical(self):
        self.make_app(self.target, 100, 100, launcher=1)
        archive = self.archive(101, 101, launcher=2)
        self.assertEqual(self.prepare(archive, 101, 101)['code'], 'launcherChanged')
        self.assertEqual(self.staging_dirs(), [])

    def test_a_modified_bundle_fails_its_signature(self):
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 101, tamper=True)
        answer = self.prepare(archive, 101, 101)
        self.assertEqual(answer['code'], 'rejected', answer)
        self.assertIn('app signature', answer['detail'])

    def test_production_policy_refuses_an_ad_hoc_app(self):
        # No mock: the pinned certificate requirement, through Security, on a bundle the test policy accepts.
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 101)
        answer = self.prepare(archive, 101, 101, pinned=True)
        self.assertEqual(answer['code'], 'rejected', answer)
        self.assertEqual(answer['detail'], 'app signature: signingRequired')
        self.assertEqual(self.staging_dirs(), [])
        trust = self.call('trust', self.target)
        self.assertEqual(trust, {'candidate': 'signingRequired', 'installed': 'moveRequired', 'test': 'trusted'})
        staged = self.prepare(archive, 101, 101)['staged']
        answer = self.call('install', staged, self.target, self.status, 'pinned')
        self.assertEqual(answer['code'], 'rejected', answer)
        self.assertEqual(self.installed_build(), '100')

    def test_failed_check_after_the_swap_rolls_back(self):
        self.make_app(self.target, 100, 100)
        staged = Path(self.prepare(self.archive(101, 101), 101, 101)['staged'])
        answer = self.call('install', staged, self.target, self.status, env={'FC_TEST_FAIL_INSTALLED': '1'})
        self.assertEqual(answer['code'], 'rolledBack', answer)
        self.assertEqual(self.installed_build(), '100')
        self.assertEqual(plistlib.loads((staged / 'Contents/Info.plist').read_bytes())['CFBundleVersion'], '101')
        run('codesign', '--verify', '--strict', self.target)

    def test_install_only_takes_its_own_staging_directory(self):
        self.make_app(self.target, 100, 100)
        elsewhere = self.make_app(self.case / 'other/Flash.app', 101, 101)
        self.assertEqual(self.call('install', elsewhere, self.target, self.status)['code'], 'rejected')
        self.assertEqual(self.installed_build(), '100')

    def test_unwritable_applications_falls_back(self):
        self.make_app(self.target, 100, 100)
        archive = self.archive(101, 101)
        self.applications.chmod(0o555)
        self.assertEqual(self.prepare(archive, 101, 101)['code'], 'notWritable')
        self.applications.chmod(0o755)
        link = self.case / 'Link.app'
        link.symlink_to(self.target)
        answer = self.call('prepare', archive, link, self.status, tool.sha256_file(archive),
                           archive.stat().st_size, '0.9.101', 101, 101)
        self.assertEqual(answer['code'], 'notInApplications')
        downloads = self.case / 'Downloads'
        downloads.mkdir()
        app = Path(self.call('manual', archive, '0.9.101', downloads)['app'])
        self.assertEqual(app, downloads / 'Flash-0.9.101/Flash.app')
        run('codesign', '--verify', '--strict', app)
        self.assertEqual(self.call('manual', archive, '../x', downloads)['app'], '')


class UpdateManifestSignatureTests(unittest.TestCase):
    def test_cryptokit_verifies_what_the_tool_signs(self):
        seed = bytes(range(32))
        key = base64.b64encode(tool.public_key(seed)).decode()
        other = base64.b64encode(tool.public_key(bytes(32))).decode()
        payload = {'schema': 1, 'product': 'com.layoute.flash', 'version': '1.0.0', 'build': 2}
        good = json.dumps(tool.envelope(payload, seed))
        bad = json.loads(good)
        bad['payload'] = base64.b64encode(base64.b64decode(bad['payload']).replace(b'1.0.0', b'9.0.0')).decode()
        wrong = json.dumps(tool.envelope({**payload, 'product': 'other'}, seed))
        main = '''
import Foundation
let arguments = CommandLine.arguments
let data = try! Data(contentsOf: URL(fileURLWithPath: arguments[1]))
let content = UpdateManifestSignature.open(data, publicKey: arguments[2])
print(content.map { "\\($0["version"] ?? "")" } ?? "nil")
'''
        with tempfile.TemporaryDirectory(prefix='flash-signature-') as scratch:
            scratch = Path(scratch)
            (scratch / 'main.swift').write_text(main)
            binary = scratch / 'verify'
            run('swiftc', '-O', MACOS / 'Runner/UpdateManifestSignature.swift', scratch / 'main.swift',
                '-o', binary)
            for name, text, public, expected in (('good', good, key, '1.0.0'), ('tampered', json.dumps(bad), key, 'nil'),
                                                  ('wrong key', good, other, 'nil'), ('product', wrong, key, 'nil'),
                                                  ('not configured', good, '', 'nil')):
                with self.subTest(name):
                    path = scratch / f'{name}.json'
                    path.write_text(text)
                    self.assertEqual(run(binary, path, public).stdout.strip(), expected)

    def test_the_pinned_keys_agree(self):
        dart = (ROOT / 'lib/common/constant.dart').read_text()
        swift = (MACOS / 'Runner/UpdaterChannel.swift').read_text()
        dart_key = re.search(r"const macUpdatePublicKey = '([^']*)';", dart).group(1)
        swift_key = re.search(r'static let pinnedPublicKey = "([^"]*)"', swift).group(1)
        self.assertEqual(dart_key, swift_key)
        self.assertTrue(dart_key == '' or len(base64.b64decode(dart_key)) == 32)


class UpdateManifestToolTests(unittest.TestCase):
    def test_rfc8032_vector_and_rejections(self):
        seed = bytes.fromhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')
        signature = tool.sign(seed, b'')
        self.assertEqual(tool.public_key(seed).hex(),
                         'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a')
        self.assertEqual(signature.hex()[:16], 'e5564300c360ac72')
        self.assertTrue(tool.verify(tool.public_key(seed), b'', signature))
        self.assertFalse(tool.verify(tool.public_key(seed), b'x', signature))
        self.assertFalse(tool.verify(tool.public_key(bytes(32)), b'', signature))

    def test_refuses_a_key_others_can_read(self):
        with tempfile.TemporaryDirectory(prefix='flash-key-') as scratch:
            tool.generate_key(scratch)
            private = Path(scratch) / tool.PRIVATE_NAME
            self.assertEqual(private.stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(tool.read_private_key(private)), 32)
            for mode in (0o640, 0o604, 0o660):
                with self.subTest(mode=oct(mode)):
                    private.chmod(mode)
                    with self.assertRaises(SystemExit):
                        tool.read_private_key(private)
            with self.assertRaises(SystemExit):
                tool.generate_key(scratch)

    def test_sign_refuses_an_unpinned_app(self):
        with tempfile.TemporaryDirectory(prefix='flash-sign-') as scratch:
            scratch = Path(scratch)
            tool.generate_key(scratch / 'key')
            app = scratch / 'Flash.app/Contents/MacOS'
            app.mkdir(parents=True)
            shutil.copy('/usr/bin/true', app / 'Flash')
            (app.parent / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'com.layoute.flash', 'CFBundleExecutable': 'Flash'}))
            run('codesign', '--force', '-s', '-', '-i', 'com.layoute.flash', scratch / 'Flash.app')
            result = subprocess.run([sys.executable, ROOT / 'tool/macos/make_update_manifest.py', 'sign',
                                     '--key', scratch / 'key' / tool.PRIVATE_NAME, '--app', scratch / 'Flash.app',
                                     '--out', scratch / 'out'], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('not signed with the pinned certificate', result.stderr)
            self.assertFalse((scratch / 'out').exists())


if __name__ == '__main__':
    unittest.main()
