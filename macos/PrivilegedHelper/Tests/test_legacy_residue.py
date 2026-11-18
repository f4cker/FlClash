import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
RESIDUE = (MACOS / 'Shared/LegacyResidue.m').read_text()
BRIDGE = (MACOS / 'Runner/ManagedHelperBridge.m').read_text()


def cleanup_script():
    body = re.search(r'NSString \*FCLegacyCleanupScript\(void\) \{\n    return\n(.*?);\n\}', RESIDUE, re.S).group(1)
    literal = ''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', body))
    return bytes(literal, 'utf-8').decode('unicode_escape')


class LegacyResidueTests(unittest.TestCase):
    def test_pure_detection_and_step_attribution(self):
        with tempfile.TemporaryDirectory(prefix='flash-residue-') as scratch:
            binary = Path(scratch) / 'residue'
            subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror',
                            str(MACOS / 'PrivilegedHelper/Tests/LegacyResidueTests.m'),
                            str(MACOS / 'Shared/LegacyResidue.m'), '-framework', 'Foundation',
                            '-o', str(binary)], check=True, capture_output=True, text=True)
            subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=10)

    def test_cleanup_script_dry_run_with_stubbed_commands(self):
        script = cleanup_script()
        self.assertIn('PATH=/usr/bin:/bin:/usr/sbin:/sbin;', script)
        subprocess.run(['/bin/sh', '-n', '-c', script], check=True)
        with tempfile.TemporaryDirectory(prefix='flash-cleanup-dry-') as scratch:
            stubs = Path(scratch) / 'bin'
            stubs.mkdir()
            log = Path(scratch) / 'calls.log'
            for name in ('launchctl', 'pkill', 'pgrep', 'rm', 'pkgutil', 'sleep'):
                status = 1 if name in ('pgrep', 'pkill') or name == 'launchctl' else 0
                (stubs / name).write_text(f'#!/bin/sh\necho "{name} $*" >> "{log}"\nexit {status}\n')
                os.chmod(stubs / name, 0o755)
            for name in ('tr', 'cut'):
                os.symlink(f'/usr/bin/{name}', stubs / name)
            dry = script.replace('PATH=/usr/bin:/bin:/usr/sbin:/sbin;', f'PATH={stubs};', 1)
            result = subprocess.run(['/bin/sh', '-c', dry], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = result.stdout.splitlines()
            self.assertEqual([line.split('=', 1)[0] for line in lines], ['stop', 'remove', 'receipts', 'detail'])
            self.assertIn(lines[0], ('stop=ok', 'stop=fail'))
            calls = log.read_text().splitlines()
            self.assertEqual(calls[0], 'launchctl bootout system/com.layoute.flash.helper')
            removed = [call for call in calls if call.startswith('rm ')]
            self.assertEqual(removed[0], 'rm -f /Library/LaunchDaemons/com.layoute.flash.helper.plist')
            self.assertEqual(removed[1], 'rm -rf /Library/Application Support/Flash /private/var/run/com.layoute.flash.helper')
            self.assertEqual([c for c in calls if c.startswith('pkgutil')],
                             [f'pkgutil --forget com.layoute.flash.managed.{op}'
                              for op in ('install', 'repair', 'remove', 'disable')])
            for call in calls:
                self.assertNotIn('/Applications', call)
                self.assertNotIn('com.layoute.flash.daemon', call)
                self.assertNotIn('com.layoute.flash.helperd', call)

    def test_bridge_runs_only_the_constant_script_and_reports_steps(self):
        migrate = BRIDGE.split('- (void)migrateWithArguments:', 1)[1].split('#pragma mark', 1)[0]
        self.assertIn('FCLegacyCleanupScript()', BRIDGE)
        self.assertNotIn('stringWithFormat:@"do shell script \\"%@\\" with administrator privileges", escaped', BRIDGE)
        self.assertIn('with administrator privileges without altering line endings', BRIDGE)
        self.assertIn('FCMigrationFailedStep(report, residue)', migrate)
        self.assertIn('migrationFailure:@"registerNew"', migrate)
        self.assertIn('@"authorizationCancelled"', migrate)
        self.assertLess(migrate.index('FCDetectLegacyResidue()'), migrate.index('registerWithCompletion'))


if __name__ == '__main__':
    unittest.main()
