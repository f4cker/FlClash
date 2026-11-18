"""Administrator repair of FlashHelperLauncher's max-version record (macos/Shared/LauncherRecordRepair.h).

The fixed root script runs here as the current user against a temporary parent directory, with the launcher's test
build (same main.c, owner and parent replaced as in Launcher/Tests) producing the real status file and judging the
result. Nothing runs as root; no launchd, no administrator prompt, no installed Flash.
"""
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
LAUNCHER = MACOS / 'PrivilegedHelper/Launcher'
HEADER = (MACOS / 'Shared/LauncherRecordRepair.h').read_text()
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()
STATE, STATUS, TOOLS = 'com.layoute.flash.helperd', 'com.layoute.flash.helperd-status', 'Contents/Library/HelperTools'
BASE, LOWER, HIGHER = 2026111708, 2026111707, 2026111709
PRODUCTION_ROOT = "base='/Library/Application Support'; owner=0; "
TEST_REQUIREMENT = 'identifier "com.layoute.flash.helper"'
HELPER_SOURCE = 'int main(void) { return 0; }\n'


def repair_script():
    body = re.search(r'NSString \*FCLauncherRecordRepairScript\(void\) \{\n    return\n(.*?);\n\}', HEADER, re.S).group(1)
    literal = ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', body))
    return bytes(literal, 'utf-8').decode('unicode_escape')


def production_requirement():
    main = (LAUNCHER / 'main.c').read_text()
    block = main.split('#else\n', 1)[1].split('#endif', 1)[0]
    define = block.split('#define FL_REQUIREMENT', 1)[1].split('\n#', 1)[0]
    return ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', define)).replace('\\"', '"')


def run(arguments, **options):
    return subprocess.run(arguments, check=True, capture_output=True, timeout=120, **options)


class RecordRepairTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(tempfile.mkdtemp(prefix='flash-record-repair-')).resolve()
        cls.parent = cls.root / 'Application Support'
        cls.launcher = cls.root / 'FlashHelperLauncher'
        run([str(LAUNCHER / 'build.sh'), str(cls.launcher), '-DFLASH_LAUNCHER_TEST',
             f'-DFL_TEST_UID={os.getuid()}', f'-DFL_TEST_PARENT="{cls.parent}"'])
        source = cls.root / 'helper.c'
        source.write_text(HELPER_SOURCE)
        cls.helpers = {name: cls.build_helper(source, name, version)
                       for name, version in (('base', str(BASE)), ('lower', str(LOWER)), ('higher', str(HIGHER)),
                                             ('dotted', '1.2'))}
        tampered = cls.root / 'helper-tampered'
        data = bytearray(cls.helpers['base'].read_bytes())
        index = data.index(b'__TEXT')
        data[index + 200] ^= 0x01
        tampered.write_bytes(bytes(data))
        cls.helpers['tampered'] = tampered

    @classmethod
    def build_helper(cls, source, name, version):
        plist = cls.root / f'{name}.plist'
        plist.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.layoute.flash.helper',
                                          'CFBundleName': 'FlashHelper', 'CFBundleVersion': version}))
        binary = cls.root / f'helper-{name}'
        run(['/usr/bin/xcrun', 'clang', '-Os', '-arch', 'arm64', '-arch', 'x86_64', '-sectcreate', '__TEXT',
             '__info_plist', str(plist), str(source), '-o', str(binary)])
        run(['/usr/bin/codesign', '--force', '-s', '-', '-i', 'com.layoute.flash.helper', str(binary)])
        return binary

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.root, ignore_errors=True)

    def setUp(self):
        for path in (self.parent, self.root / 'case'):
            if path.exists():
                for directory, _, _ in os.walk(path):
                    os.chmod(directory, 0o755)
                shutil.rmtree(path)
        self.parent.mkdir(mode=0o755)
        self.parent.chmod(0o755)
        self.bundle = self.root / 'case/Flash.app'
        (self.bundle / TOOLS).mkdir(parents=True)
        shutil.copy2(self.launcher, self.bundle / TOOLS / 'FlashHelperLauncher')
        self.install('base')
        self.state = self.parent / STATE
        self.record = self.state / 'max-version'

    def install(self, name):
        target = self.bundle / TOOLS / 'FlashHelper'
        target.unlink(missing_ok=True)
        shutil.copy2(self.helpers[name], target)

    def launch(self):
        process = subprocess.run([str(self.bundle / TOOLS / 'FlashHelperLauncher')], capture_output=True, text=True,
                                 timeout=60)
        status = json.loads((self.parent / STATUS / 'launcher.json').read_text())
        return process.returncode, status

    def repair(self, requirement=TEST_REQUIREMENT, shell='/bin/sh'):
        script = repair_script()
        self.assertIn(PRODUCTION_ROOT, script)
        script = script.replace(PRODUCTION_ROOT, f"base='{self.parent}'; owner={os.getuid()}; ", 1)
        if requirement:
            script = script.replace(production_requirement(), requirement, 1)
        process = subprocess.run([shell, '-c', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(process.returncode, 0, process.stderr)
        lines = process.stdout.splitlines()
        self.assertEqual([line.split('=', 1)[0] for line in lines], ['record', 'reason', 'version'], process.stdout)
        return dict(line.split('=', 1) for line in lines)

    def damaged(self, damage):
        """Run once (record BASE), damage the record, and check the launcher now refuses it as unreadable."""
        self.assertEqual(self.launch()[0], 0)
        if self.record.exists() or self.record.is_symlink():
            self.record.unlink()
        damage()
        code, status = self.launch()
        self.assertEqual((code, status['result']), (85, 'version_unreadable'), status)
        self.assertTrue(status['detail'].startswith('max-version '), status)
        self.assertEqual(status['helperVersion'], BASE)
        return status

    def assert_repaired_and_launches(self, report, version=BASE):
        self.assertEqual(report, {'record': 'repaired', 'reason': 'record', 'version': str(version)})
        self.assertFalse(self.record.is_symlink())
        self.assertEqual(self.record.read_bytes(), f'{version}\n'.encode())
        self.assertEqual(stat.S_IMODE(self.record.lstat().st_mode), 0o600)
        self.assertEqual(sorted(p.name for p in self.state.iterdir()), ['FlashHelper', 'max-version'])
        code, status = self.launch()
        self.assertEqual((code, status['result'], status['recordedVersion']), (0, 'ok', version), status)

    def test_every_record_the_launcher_rejects_is_rebuilt_to_the_verified_version(self):
        outside = self.root / 'outside'
        cases = {
            'garbage': lambda: self.record.write_text('12a\n'),
            'empty': lambda: self.record.write_bytes(b''),
            'newline only': lambda: self.record.write_bytes(b'\n'),
            'two newlines': lambda: self.record.write_bytes(b'5\n\n'),
            'nul': lambda: self.record.write_bytes(b'5\x00'),
            'leading space': lambda: self.record.write_bytes(b' 5\n'),
            'overflow': lambda: self.record.write_bytes(b'18446744073709551616\n'),
            '21 digits': lambda: self.record.write_bytes(b'100000000000000000000'),
            'long': lambda: self.record.write_bytes(b'1' * 40),
            'directory': lambda: (self.record.mkdir(), (self.record / 'inner').write_text('x')),
            'symlink': lambda: (outside.write_text(f'{HIGHER}\n'), self.record.symlink_to(outside)),
        }
        for name, damage in cases.items():
            with self.subTest(case=name):
                self.setUp()
                self.damaged(damage)
                self.assert_repaired_and_launches(self.repair())
                if name == 'symlink':
                    self.assertEqual(outside.read_text(), f'{HIGHER}\n')
                    outside.unlink()

    def test_record_owned_by_someone_else_is_rebuilt_without_touching_the_original(self):
        foreign = Path('/private/etc/hosts')
        original = foreign.read_bytes()

        def damage():
            try:
                os.link(foreign, self.record)
            except OSError as error:
                self.skipTest(f'cannot hard-link a foreign-owned file here: {error}')
        self.damaged(damage)
        self.assert_repaired_and_launches(self.repair())
        self.assertEqual(foreign.read_bytes(), original)

    def test_unwritable_record_from_a_stale_temporary_directory_is_cleared(self):
        self.state.mkdir(mode=0o700)
        (self.state / '.max-version.tmp').mkdir()
        code, status = self.launch()
        self.assertEqual((code, status['result']), (85, 'version_unreadable'))
        self.assertTrue(status['detail'].startswith('max-version write errno='), status)
        self.assert_repaired_and_launches(self.repair())

    def test_a_valid_record_is_never_rewritten_and_downgrade_stays_refused(self):
        # The status still says unreadable (stale), but the record now parses: the launcher would accept it, so the
        # repair keeps it byte for byte, whatever its value.
        for value in (f'{HIGHER}\n', f'{LOWER}', '0007\n', '18446744073709551615\n', '00000000000000000001'):
            with self.subTest(value=value):
                self.setUp()
                self.damaged(lambda: self.record.write_text('bad\n'))
                self.record.unlink()
                self.record.write_text(value)
                self.record.chmod(0o600)
                before = self.record.lstat()
                self.assertEqual(self.repair()['record'], 'kept')
                after = self.record.lstat()
                self.assertEqual((after.st_ino, after.st_mtime_ns), (before.st_ino, before.st_mtime_ns))
                self.assertEqual(self.record.read_text(), value)
        code, status = self.launch()
        self.assertEqual(code, 0, status)
        # A record above the helper's version: still a downgrade after the repair ran.
        self.setUp()
        self.damaged(lambda: self.record.write_text('bad\n'))
        self.record.unlink()
        self.record.write_text(f'{HIGHER}\n')
        self.assertEqual(self.repair()['record'], 'kept')
        code, status = self.launch()
        self.assertEqual((code, status['result']), (86, 'downgrade'))
        self.assertEqual(self.record.read_text(), f'{HIGHER}\n')

    def test_refuses_unless_the_launcher_reported_an_unreadable_record(self):
        # A downgrade is not repairable: nothing is written.
        self.install('higher')
        self.assertEqual(self.launch()[0], 0)
        self.install('base')
        self.assertEqual(self.launch()[1]['result'], 'downgrade')
        self.assertEqual(self.repair(), {'record': 'refused', 'reason': 'status', 'version': ''})
        self.assertEqual(self.record.read_text(), f'{HIGHER}\n')
        # The helper's own version unreadable (same exit code, different detail): refused.
        self.setUp()
        self.install('dotted')
        self.assertEqual(self.launch()[1]['result'], 'version_unreadable')
        self.assertEqual(self.repair()['reason'], 'status')
        self.assertFalse(self.record.exists())
        # A healthy launch: refused.
        self.setUp()
        self.assertEqual(self.launch()[0], 0)
        self.assertEqual(self.repair()['reason'], 'status')

    def test_refuses_unsafe_paths_and_an_unverified_copy(self):
        def status_symlink():
            real = self.root / 'case/launcher.json'
            shutil.copy2(self.parent / STATUS / 'launcher.json', real)
            (self.parent / STATUS / 'launcher.json').unlink()
            (self.parent / STATUS / 'launcher.json').symlink_to(real)

        def state_symlink():
            moved = self.root / 'case/state'
            self.state.rename(moved)
            self.state.symlink_to(moved)

        def copy_symlink():
            real = self.root / 'case/FlashHelper'
            shutil.copy2(self.state / 'FlashHelper', real)
            (self.state / 'FlashHelper').unlink()
            (self.state / 'FlashHelper').symlink_to(real)

        def copy_replaced(name):
            def replace():
                (self.state / 'FlashHelper').unlink()
                shutil.copy2(self.helpers[name], self.state / 'FlashHelper')
                (self.state / 'FlashHelper').chmod(0o500)
            return replace

        cases = {
            'parent writable': ('parent', lambda: self.parent.chmod(0o775)),
            'state readable by others': ('state', lambda: self.state.chmod(0o755)),
            'state symlink': ('state', state_symlink),
            'status writable': ('status', lambda: (self.parent / STATUS / 'launcher.json').chmod(0o664)),
            'status symlink': ('status', status_symlink),
            'status two lines': ('status', lambda: (self.parent / STATUS / 'launcher.json').write_text(
                (self.parent / STATUS / 'launcher.json').read_text() * 2)),
            'copy missing': ('copy', lambda: (self.state / 'FlashHelper').unlink()),
            'copy symlink': ('copy', copy_symlink),
            'copy tampered': ('signature', copy_replaced('tampered')),
            'copy of another version': ('version', copy_replaced('lower')),
        }
        for name, (reason, prepare) in cases.items():
            with self.subTest(case=name):
                self.setUp()
                self.damaged(lambda: self.record.write_text('bad\n'))
                prepare()
                report = self.repair()
                self.assertEqual((report['record'], report['reason']), ('refused', reason), report)
                self.state.chmod(0o700) if self.state.is_dir() and not self.state.is_symlink() else None
                self.assertEqual(self.record.read_text(), 'bad\n')

    def test_production_requirement_is_the_launchers_and_rejects_an_ad_hoc_copy(self):
        requirement = production_requirement()
        self.assertIn('anchor H"BBA7F8529FD271B9848EC03A2CE3F4780F585556"', requirement)
        script = repair_script()
        self.assertIn(f"requirement='{requirement}'; ", script)
        self.damaged(lambda: self.record.write_text('bad\n'))
        self.assertEqual(self.repair(requirement=None)['reason'], 'signature')
        self.assertEqual(self.record.read_text(), 'bad\n')

    def test_runs_under_every_shell_bin_sh_may_be(self):
        # do shell script runs /bin/sh, which /private/var/select/sh points at bash or dash.
        for shell in ('/bin/sh', '/bin/bash', '/bin/dash'):
            if not Path(shell).exists():
                continue
            with self.subTest(shell=shell):
                subprocess.run([shell, '-n', '-c', repair_script()], check=True)
                self.setUp()
                self.damaged(lambda: self.record.write_text('bad\n'))
                self.assert_repaired_and_launches(self.repair(shell=shell))

    def test_script_is_fixed_and_touches_only_the_record(self):
        script = repair_script()
        self.assertTrue(script.startswith('set -u; PATH=/usr/bin:/bin:/usr/sbin:/sbin; export PATH;'))
        self.assertEqual(script.count(PRODUCTION_ROOT), 1)
        for forbidden in ('launchctl', '/Applications', 'sudo', 'eval', '$1"/', 'com.layoute.flash.daemon',
                          'curl', 'osascript'):
            self.assertNotIn(forbidden, script)
        removed = re.findall(r'rm -rf ("\$\w+")', script)
        self.assertEqual(sorted(set(removed)), ['"$record"', '"$stale"', '"$temp"'])
        self.assertEqual(re.findall(r'mv -f ("\$\w+" "\$\w+")', script), ['"$temp" "$record"'])
        self.assertIn('valid && report kept record;', script)
        self.assertLess(script.index('valid && report kept record;'), script.index('mv -f'))
        for check in ('report refused status', 'report refused copy', 'report refused signature',
                      'report refused version'):
            self.assertLess(script.index(check), script.index('valid && report kept record;'))


FIXTURE = r'''
#import "LauncherStatus.h"
#import "LauncherRecordRepair.h"
#import <assert.h>
int main(void) {
    @autoreleasepool {
        NSDictionary *(^Status)(NSString *, NSString *, id) = ^NSDictionary *(NSString *result, NSString *detail, id helper) {
            return @{@"v": @1, @"result": result, @"detail": detail, @"helperVersion": helper,
                @"recordedVersion": NSNull.null, @"launcherVersion": @1, @"time": @(NSDate.date.timeIntervalSince1970)};
        };
        NSDictionary *unreadable = Status(@"version_unreadable", @"max-version unreadable errno=0", @2026111708);
        NSDictionary *unwritable = Status(@"version_unreadable", @"max-version write errno=28", @2026111708);
        assert(FCLauncherRecordDamaged(unreadable) && FCLauncherRecordDamaged(unwritable));
        assert(!FCLauncherRecordDamaged(Status(@"version_unreadable", @"CFBundleVersion is not an unsigned integer",
            NSNull.null)));
        assert(!FCLauncherRecordDamaged(Status(@"version_unreadable", @"max-version unreadable errno=0", NSNull.null)));
        assert(!FCLauncherRecordDamaged(Status(@"version_unreadable", @"max-version unreadable errno=0", @YES)));
        assert(!FCLauncherRecordDamaged(Status(@"downgrade", @"max-version unreadable errno=0", @2026111708)));
        assert(!FCLauncherRecordDamaged(nil));
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        assert([FCLauncherAnswer(unreadable, nil, now, 0, @"1")[@"code"] isEqual:@"launcherRecordDamaged"]);
        assert([FCLauncherAnswer(unwritable, nil, now, 0, @"1")[@"code"] isEqual:@"launcherRecordDamaged"]);
        assert([FCLauncherAnswer(Status(@"version_unreadable", @"CFBundleVersion is not an unsigned integer",
            NSNull.null), nil, now, 0, @"1")[@"code"] isEqual:@"launcherCheckFailed"]);
        // A refusal the repair superseded is not a card; any other is, with its exit code.
        NSDictionary *job = @{@"refused": @YES, @"lastExit": @85};
        NSDictionary *superseded = @{@"superseded": @YES, @"detail": @"max-version repaired"};
        assert(FCRefusalExitAnswer(job, superseded) == superseded);
        NSDictionary *card = FCRefusalExitAnswer(job, FCLauncherAnswer(unreadable, nil, now, 0, @"1"));
        assert([card[@"code"] isEqual:@"launcherRecordDamaged"] && [card[@"detail"] containsString:@"last exit code: 85"]);
        assert([FCRefusalExitAnswer(job, nil)[@"code"] isEqual:@"launcherCheckFailed"]);
        NSDictionary *report = FCParseRecordRepairReport(@"record=repaired\rreason=record\rversion=2026111708\rrecord=x\r");
        assert([report isEqual:(@{@"record": @"repaired", @"reason": @"record", @"version": @"2026111708"})]);
        assert([FCRecordRepairOutcome(@"ok", report) isEqual:@"ok"]);
        assert([FCRecordRepairOutcome(@"ok", @{@"record": @"kept"}) isEqual:@"ok"]);
        assert([FCRecordRepairOutcome(@"ok", @{@"record": @"refused"}) isEqual:@"failed"]);
        assert([FCRecordRepairOutcome(@"ok", @{}) isEqual:@"failed"]);
        assert([FCRecordRepairOutcome(@"authorizationCancelled", report) isEqual:@"cancelled"]);
        assert([FCRecordRepairOutcome(@"authorizationDenied", report) isEqual:@"denied"]);
        assert([FCRecordRepairOutcome(@"migrationFailed", report) isEqual:@"failed"]);
        puts("ok");
    }
}
'''


class RecordRepairMappingTests(unittest.TestCase):
    def test_status_mapping_and_report_parsing(self):
        with tempfile.TemporaryDirectory(prefix='flash-record-map-') as scratch:
            source, binary = Path(scratch) / 'fixture.m', Path(scratch) / 'fixture'
            source.write_text(FIXTURE)
            run(['clang', '-fobjc-arc', '-fblocks', '-Wall', '-Werror', '-I', str(MACOS / 'Shared'), str(source),
                 '-framework', 'Foundation', '-o', str(binary)])
            self.assertEqual(run([str(binary)], text=True).stdout, 'ok\n')

    def test_bridge_prompts_only_for_a_damaged_record_then_asks_the_helper(self):
        body = BRIDGE.split('- (void)repairRecordWithArguments:', 1)[1].split('\n}\n', 1)[0]
        order = ['[self confirmed:arguments]', '[self gate]', 'FCLauncherRecordDamaged(FCReadLauncherStatus(',
                 'self.operationInFlight = YES', '[self authorize:FCLauncherRecordRepairScript()',
                 'FCRecordRepairOutcome(authorization, report)', 'self.recordRepairedAt =', '[self resetConnection]']
        positions = [body.index(token) for token in order]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(body.count('[self authorize:'), 1)
        self.assertGreaterEqual(body.count('[self status:'), 2)
        self.assertIn('if ([method isEqualToString:@"repairRecord"])', BRIDGE)
        self.assertIn('with administrator privileges without altering line endings', BRIDGE)
        self.assertIn('[self authorize:FCLegacyCleanupScript() completion:', BRIDGE)
        # Only the record repair supersedes the launcher's refusal, and only until the launcher runs again.
        report = BRIDGE.split('- (NSDictionary *)launcherReport {', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('[launcher[@"time"] doubleValue] < floor(self.recordRepairedAt)', report)
        self.assertIn('self.recordRepairedAt = 0;', report)


if __name__ == '__main__':
    unittest.main()
