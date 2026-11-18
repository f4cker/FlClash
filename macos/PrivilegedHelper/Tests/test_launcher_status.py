"""The app's read-only view of FlashHelperLauncher's status file (macos/Shared/LauncherStatus.h).

Real files in a temporary directory stand in for the root-owned status directory (the owner checked is the current
user here, root in the app). Nothing here runs the launcher, the helper or launchd.
"""
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

MACOS = Path(__file__).resolve().parents[2]
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()
FIXTURE = r'''
#import "LauncherStatus.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *problem = nil;
        NSDictionary *status = FCReadLauncherStatus(@(argv[1]), getuid(), &problem);
        NSDictionary *answer = FCLauncherAnswer(status, problem, atof(argv[2]), atof(argv[3]), @"2026111709");
        NSDictionary *output = @{@"read": status ? @YES : @NO, @"problem": problem ?: @"",
            @"code": answer[@"code"] ?: @"", @"detail": answer[@"detail"] ?: @"", @"answer": answer ? @YES : @NO};
        NSData *data = [NSJSONSerialization dataWithJSONObject:output options:0 error:nil];
        fwrite(data.bytes, 1, data.length, stdout);
    }
}
'''


class LauncherStatusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-launcher-status-')
        cls.root = Path(cls.scratch.name).resolve()
        (cls.root / 'fixture.m').write_text(FIXTURE)
        subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Wall', '-Werror', '-I', str(MACOS / 'Shared'),
                        str(cls.root / 'fixture.m'), '-framework', 'Foundation', '-o', str(cls.root / 'fixture')],
                       check=True, capture_output=True, text=True, timeout=120)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def setUp(self):
        self.directory = Path(tempfile.mkdtemp(dir=self.root))
        self.directory.chmod(0o755)
        self.now = int(time.time())

    def status(self, result='signature', **changes):
        data = {'v': 1, 'result': result, 'detail': 'copy rejected OSStatus=-67061', 'helperVersion': 2026111709,
                'recordedVersion': 2026111708, 'launcherVersion': 1, 'time': self.now}
        data.update(changes)
        return data

    def write(self, data, mode=0o644):
        path = self.directory / 'launcher.json'
        path.write_text(data if isinstance(data, str) else json.dumps(data, separators=(',', ':')) + '\n')
        path.chmod(mode)
        return path

    def read(self, started=None, unanswered=0):
        started = self.now - 5 if started is None else started
        output = subprocess.run([str(self.root / 'fixture'), str(self.directory), str(started), str(unanswered)],
                                check=True, capture_output=True, text=True, timeout=20).stdout
        return json.loads(output)

    def test_results_map_to_the_three_cards_with_details(self):
        for result, code in (('signature', 'launcherCheckFailed'), ('location', 'launcherCheckFailed'),
                             ('version_unreadable', 'launcherCheckFailed'), ('downgrade', 'launcherDowngrade'),
                             ('not_root', 'launcherFailed'), ('copy', 'launcherFailed'), ('exec', 'launcherFailed')):
            with self.subTest(result=result):
                self.write(self.status(result, helperVersion=None if result != 'downgrade' else 2026111707))
                answer = self.read()
                self.assertEqual(answer['code'], code)
                self.assertIn('launcher result: ' + result, answer['detail'])
                self.assertIn('launcher detail: copy rejected OSStatus=-67061', answer['detail'])
                self.assertIn('highest version run: 2026111708', answer['detail'])
                self.assertIn('app version: 2026111709', answer['detail'])
                self.assertIn('launcher version: 1', answer['detail'])
                self.assertIn('helper version: ' + ('2026111707' if result == 'downgrade' else 'none'),
                              answer['detail'])

    def test_ok_without_an_answer_is_a_start_failure_only_after_the_grace(self):
        self.write(self.status('ok', detail='verified'))
        waiting = self.read(unanswered=2)
        self.assertEqual(waiting['code'], '')
        self.assertIn('did not answer', waiting['detail'])
        failed = self.read(unanswered=9)
        self.assertEqual(failed['code'], 'launcherFailed')
        self.assertIn('ended it after exec', failed['detail'])

    def test_missing_status_adds_nothing(self):
        self.assertEqual(self.read(), {'read': False, 'problem': '', 'code': '', 'detail': '', 'answer': False})
        self.directory.rmdir()
        self.assertFalse(self.read()['answer'])

    def test_status_from_long_before_this_launch_is_ignored(self):
        self.write(self.status('downgrade', time=self.now - 3600))
        answer = self.read(started=self.now)
        self.assertTrue(answer['read'])
        self.assertFalse(answer['answer'])
        self.write(self.status('downgrade', time=self.now - 300))
        self.assertEqual(self.read(started=self.now)['code'], 'launcherDowngrade')

    def test_untrusted_or_malformed_status_is_an_unreadable_start_failure(self):
        cases = [
            ('group writable', lambda: self.write(self.status(), 0o664)),
            ('other writable', lambda: self.write(self.status(), 0o646)),
            ('symlink', lambda: ((self.directory / 'real.json').write_text(json.dumps(self.status())),
                                 (self.directory / 'launcher.json').symlink_to(self.directory / 'real.json'))),
            ('hard link', lambda: os.link(self.write(self.status()), self.directory / 'alias.json')),
            ('directory writable', lambda: self.write(self.status()) and self.directory.chmod(0o775)),
            ('not json', lambda: self.write('{"v":1,')),
            ('empty', lambda: self.write('')),
            ('array', lambda: self.write([1])),
            ('version 2', lambda: self.write(self.status(v=2))),
            ('boolean version', lambda: self.write(self.status(v=True))),
            ('unknown result', lambda: self.write(self.status('maybe'))),
            ('extra key', lambda: self.write(dict(self.status(), extra=1))),
            ('missing key', lambda: self.write({k: v for k, v in self.status().items() if k != 'time'})),
            ('string version', lambda: self.write(self.status(helperVersion='2026111709'))),
            ('long detail', lambda: self.write(self.status(detail='x' * 201))),
            ('too large', lambda: self.write(json.dumps(self.status()) + ' ' * 5000)),
        ]
        for name, prepare in cases:
            with self.subTest(case=name):
                for child in self.directory.iterdir():
                    child.unlink()
                self.directory.chmod(0o755)
                prepare()
                answer = self.read()
                self.assertFalse(answer['read'])
                self.assertTrue(answer['problem'])
                self.assertEqual(answer['code'], 'launcherFailed')
                self.assertTrue(answer['detail'].startswith('launcher status unreadable: '))

    def test_bridge_reads_status_only_for_an_enabled_helper_that_does_not_answer(self):
        status = BRIDGE.split('- (void)status:', 1)[1].split('- (NSDictionary *)launcherReport', 1)[0]
        self.assertLess(status.index('status[@"code"] = @"registrationStale"'), status.index('[self launcherReport]'))
        self.assertIn('if ([@[@"timeout", @"unavailable"] containsObject:status[@"code"]])', status)
        report = BRIDGE.split('- (NSDictionary *)launcherReport {', 1)[1].split('\n}\n', 1)[0]
        self.assertIn('FCReadLauncherStatus(FCLauncherStatusDirectory, 0, &problem)', report)
        # Display only: the status never reaches the trust gate, the validator or a request.
        self.assertEqual(BRIDGE.count('[self launcherReport]'), 1)
        for name in ('- (NSString *)gate {', '- (NSString *)appGate {', '- (void)request:',
                     '- (void)registerWithCompletion:', '- (NSDictionary *)recoverySequence {'):
            body = BRIDGE.split(name, 1)[1].split('\n}\n', 1)[0]
            for token in ('launcherReport', 'FCReadLauncherStatus', 'FCLauncherAnswer', 'FCLauncherStatusDirectory'):
                self.assertNotIn(token, body)


if __name__ == '__main__':
    unittest.main()
