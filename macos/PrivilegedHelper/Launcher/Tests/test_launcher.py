import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

LAUNCHER = Path(__file__).resolve().parents[1]
MACOS = LAUNCHER.parents[1]
HELPER_ID = 'com.layoute.flash.helper'
STATE = 'com.layoute.flash.helperd'
STATUS = 'com.layoute.flash.helperd-status'
TOOLS = 'Contents/Library/HelperTools'
BASE, LOWER, HIGHER = 2026111708, 2026111707, 2026111709
CODES = {'ok': 0, 'location': 82, 'copy': 83, 'signature': 84,
         'version_unreadable': 85, 'downgrade': 86, 'exec': 87}
MARKER = b'FLASH-LAUNCHER-TEST-MARKER'

HELPER_SOURCE = r'''
#include <libproc.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char *argv[]) {
    char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
    proc_pidpath(getpid(), path, sizeof(path));
    printf("marker=%s\npath=%s\nenv=%s\n", "FLASH-LAUNCHER-TEST-MARKER", path, getenv("FLASH_LAUNCHER_TEST_ENV"));
    for (int i = 0; i < argc; i++) printf("arg=%s\n", argv[i]);
    return 0;
}
'''


def run(arguments, **options):
    return subprocess.run(arguments, check=True, capture_output=True, timeout=120, **options)


class LauncherTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(tempfile.mkdtemp(prefix='flash-launcher-')).resolve()
        cls.parent = cls.root / 'parent'
        cls.launcher = cls.root / 'FlashHelperLauncher'
        run([str(LAUNCHER / 'build.sh'), str(cls.launcher), '-DFLASH_LAUNCHER_TEST',
             f'-DFL_TEST_UID={os.getuid()}', f'-DFL_TEST_PARENT="{cls.parent}"'])
        source = cls.root / 'helper.c'
        source.write_text(HELPER_SOURCE)
        cls.helpers = {name: cls.build_helper(source, name, version, identity)
                       for name, version, identity in (
                           ('base', str(BASE), HELPER_ID), ('lower', str(LOWER), HELPER_ID),
                           ('higher', str(HIGHER), HELPER_ID), ('dotted', '1.2', HELPER_ID),
                           ('foreign', str(BASE), 'com.example.other'))}
        tampered = cls.root / 'helper-tampered'
        data = bytearray(cls.helpers['base'].read_bytes())
        data[data.index(MARKER)] ^= 0x01
        tampered.write_bytes(bytes(data))
        tampered.chmod(0o755)
        cls.helpers['tampered'] = tampered

    @classmethod
    def build_helper(cls, source, name, version, identity):
        plist = cls.root / f'{name}.plist'
        plist.write_bytes(plistlib.dumps({'CFBundleIdentifier': HELPER_ID, 'CFBundleName': 'FlashHelper',
                                          'CFBundleInfoDictionaryVersion': '6.0', 'CFBundleVersion': version}))
        binary = cls.root / f'helper-{name}'
        run(['/usr/bin/xcrun', 'clang', '-Os', '-sectcreate', '__TEXT', '__info_plist', str(plist),
             str(source), '-o', str(binary)])
        run(['/usr/bin/codesign', '--force', '-s', '-', '-i', identity, str(binary)])
        return binary

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.root, ignore_errors=True)

    def setUp(self):
        for path in (self.parent, self.root / 'case'):
            if path.exists():
                path.chmod(0o755)
                shutil.rmtree(path)
        self.parent.mkdir(mode=0o755)
        self.parent.chmod(0o755)
        self.bundle = self.root / 'case/Flash.app'
        (self.bundle / TOOLS).mkdir(parents=True)
        shutil.copy2(self.launcher, self.bundle / TOOLS / 'FlashHelperLauncher')
        self.install('base')

    def install(self, name):
        target = self.bundle / TOOLS / 'FlashHelper'
        target.unlink(missing_ok=True)
        shutil.copy2(self.helpers[name], target)

    def launch(self, executable=None):
        executable = executable or self.bundle / TOOLS / 'FlashHelperLauncher'
        environment = dict(os.environ, FLASH_LAUNCHER_TEST_ENV='kept')
        return subprocess.run([str(executable)], capture_output=True, text=True, timeout=60, env=environment)

    def status(self):
        return json.loads((self.parent / STATUS / 'launcher.json').read_text())

    def record(self):
        return (self.parent / STATE / 'max-version').read_text()

    def assert_refused(self, result, reason):
        process = self.launch()
        self.assertEqual(process.returncode, CODES[result], process.stderr)
        self.assertEqual(process.stdout, '')
        status = self.status()
        self.assertEqual(status['result'], result)
        self.assertIn(reason, status['detail'])
        return status

    def test_runs_verified_copy_with_bundle_argument(self):
        process = self.launch()
        self.assertEqual(process.returncode, 0, process.stderr)
        copy = self.parent / STATE / 'FlashHelper'
        lines = process.stdout.splitlines()
        self.assertEqual(lines[:3], ['marker=' + MARKER.decode(), f'path={copy}', 'env=kept'])
        self.assertEqual(lines[3:], [f'arg={copy}', 'arg=--flash-bundle', f'arg={self.bundle}'])
        self.assertEqual(copy.read_bytes(), self.helpers['base'].read_bytes())
        self.assertEqual(stat.S_IMODE(copy.lstat().st_mode), 0o500)
        self.assertEqual(stat.S_IMODE((self.parent / STATE).lstat().st_mode), 0o700)
        self.assertEqual(self.record(), f'{BASE}\n')
        self.assertEqual(sorted(p.name for p in (self.parent / STATE).iterdir()), ['FlashHelper', 'max-version'])

    def test_status_file_content_and_modes(self):
        before = int(time.time())
        self.assertEqual(self.launch().returncode, 0)
        status = self.status()
        self.assertEqual(list(status), ['v', 'result', 'detail', 'helperVersion', 'recordedVersion',
                                        'launcherVersion', 'time'])
        self.assertEqual({key: status[key] for key in list(status)[:6]},
                         {'v': 1, 'result': 'ok', 'detail': 'verified', 'helperVersion': BASE,
                          'recordedVersion': None, 'launcherVersion': 1})
        self.assertTrue(before <= status['time'] <= int(time.time()))
        self.assertEqual(stat.S_IMODE((self.parent / STATUS).lstat().st_mode), 0o755)
        self.assertEqual(stat.S_IMODE((self.parent / STATUS / 'launcher.json').lstat().st_mode), 0o644)
        self.assertEqual([p.name for p in (self.parent / STATUS).iterdir()], ['launcher.json'])

    def test_tampered_signature_rejected(self):
        self.install('tampered')
        status = self.assert_refused('signature', 'OSStatus=-')
        self.assertIsNone(status['helperVersion'])
        self.assertFalse((self.parent / STATE / 'max-version').exists())

    def test_requirement_mismatch_rejected(self):
        self.install('foreign')
        self.assert_refused('signature', 'OSStatus=-')

    def test_downgrade_rejected(self):
        self.install('higher')
        self.assertEqual(self.launch().returncode, 0)
        self.install('lower')
        status = self.assert_refused('downgrade', 'older')
        self.assertEqual((status['helperVersion'], status['recordedVersion']), (LOWER, HIGHER))
        self.assertEqual(self.record(), f'{HIGHER}\n')

    def test_same_version_allowed(self):
        self.assertEqual(self.launch().returncode, 0)
        self.assertEqual(self.launch().returncode, 0)
        self.assertEqual((self.status()['helperVersion'], self.status()['recordedVersion']), (BASE, BASE))
        self.assertEqual(self.record(), f'{BASE}\n')

    def test_upgrade_updates_record(self):
        self.assertEqual(self.launch().returncode, 0)
        self.install('higher')
        self.assertEqual(self.launch().returncode, 0)
        self.assertEqual((self.status()['helperVersion'], self.status()['recordedVersion']), (HIGHER, BASE))
        self.assertEqual(self.record(), f'{HIGHER}\n')

    def test_unparsable_version_rejected(self):
        self.install('dotted')
        self.assertIsNone(self.assert_refused('version_unreadable', 'CFBundleVersion')['helperVersion'])

    def test_corrupt_record_rejected(self):
        (self.parent / STATE).mkdir(mode=0o700)
        (self.parent / STATE / 'max-version').write_text('12a\n')
        self.assert_refused('version_unreadable', 'max-version')

    def test_state_directory_symlink_rejected(self):
        elsewhere = self.root / 'case/elsewhere'
        elsewhere.mkdir(mode=0o700)
        (self.parent / STATE).symlink_to(elsewhere)
        self.assert_refused('copy', 'is a symlink')
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_state_directory_mode_too_wide_rejected(self):
        (self.parent / STATE).mkdir()
        (self.parent / STATE).chmod(0o755)
        self.assert_refused('copy', 'mode too wide')
        self.assertEqual(list((self.parent / STATE).iterdir()), [])

    def test_source_symlink_rejected(self):
        target = self.bundle / TOOLS / 'FlashHelper'
        target.unlink()
        target.symlink_to(self.helpers['base'])
        self.assert_refused('copy', f'open source errno={62}')

    def test_unsafe_parent_rejected_without_status(self):
        self.parent.chmod(0o777)
        process = self.launch()
        self.assertEqual((process.returncode, process.stdout), (CODES['copy'], ''))
        self.assertFalse((self.parent / STATUS).exists())

    def test_launcher_outside_bundle_rejected(self):
        loose = self.root / 'case/FlashHelperLauncher'
        shutil.copy2(self.launcher, loose)
        process = self.launch(loose)
        self.assertEqual((process.returncode, process.stdout), (CODES['location'], ''))
        self.assertEqual(self.status()['result'], 'location')


class LauncherSourceTest(unittest.TestCase):
    source = (LAUNCHER / 'main.c').read_text()

    def test_production_requirement_matches_helper_trust(self):
        identity = (MACOS / 'Shared/HelperIdentity.h').read_text()
        pin = re.search(r'#define FC_PINNED_CERTIFICATE_SHA1 "([0-9A-F]{40})"', identity).group(1)
        trust = (MACOS / 'Shared/HelperTrust.m').read_text()
        self.assertIn(r'@"anchor H\"%@\" and certificate leaf = H\"%@\" and identifier \"%@\""', trust)
        expected = f'anchor H"{pin}" and certificate leaf = H"{pin}" and identifier "{HELPER_ID}"'
        production = self.source.split('#else', 1)[1].split('#endif', 1)[0]
        literal = ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', production.split('FL_REQUIREMENT', 1)[1]))
        self.assertEqual(literal.replace('\\"', '"'), expected)

    def test_test_build_changes_constants_only(self):
        self.assertEqual(self.source.count('FLASH_LAUNCHER_TEST'), 1)
        block = self.source.split('#ifdef FLASH_LAUNCHER_TEST', 1)[1].split('#endif', 1)[0]
        lines = [line for line in block.splitlines() if line.strip()]
        self.assertTrue(all(re.match(r'(#define FL_(OWNER|PARENT|REQUIREMENT) |#else$|    ")', line)
                            for line in lines), lines)


if __name__ == '__main__':
    unittest.main()
