import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TRUST = (MACOS / 'Shared/HelperTrust.m').read_text()
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()
STAGING = (MACOS / 'PrivilegedHelper/CoreStaging.h').read_text()


def function(source, declaration):
    start = source.index(declaration)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


FIXTURE = r'''
#import "../Shared/HelperTrust.h"
#import "CoreStaging.h"
#import <assert.h>
#import <sys/un.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 4);
        NSString *scenario = @(argv[1]), *directory = @(argv[2]), *source = @(argv[3]);
        if ([scenario isEqual:@"constants"]) {
            assert([FCRuntimeDirectory isEqual:@"/Library/Application Support/com.layoute.flash.daemon"]);
            NSString *path = [FCRuntimeDirectory stringByAppendingPathComponent:
                @"01234567-89AB-CDEF-0123-456789ABCDEF.sock"];
            assert(strlen(path.fileSystemRepresentation) + 1 <= sizeof(((struct sockaddr_un *)0)->sun_path));
            path = [FCRuntimeDirectory stringByAppendingPathComponent:
                @"core-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"];
            assert(strlen(path.fileSystemRepresentation) < PATH_MAX);
        } else if ([scenario isEqual:@"prepare-refuses-user-owned"]) {
            // Running unprivileged: a directory we own is never accepted as the root-only runtime directory.
            assert(!FCPrepareRuntimeDirectory(directory));
        } else if ([scenario isEqual:@"stage"]) {
            NSString *hash = FCSHA256(source);
            assert(hash.length == 64);
            NSString *staged = FCStageCore(source, directory, hash);
            assert([staged isEqual:[directory stringByAppendingPathComponent:[@"core-" stringByAppendingString:hash]]]);
            assert([FCSHA256(staged) isEqual:hash]);
            struct stat state;
            assert(lstat(staged.fileSystemRepresentation, &state) == 0 && S_ISREG(state.st_mode));
            assert((state.st_mode & 07777) == 0500);
            printf("%s\n", staged.fileSystemRepresentation);
        } else if ([scenario isEqual:@"stage-wrong-hash"]) {
            assert(!FCStageCore(source, directory, [@"" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]));
            assert(!FCStageCore(source, directory, @"short"));
        } else if ([scenario isEqual:@"stage-symlink"]) {
            assert(!FCStageCore(source, directory, FCSHA256(source)));
        } else if ([scenario isEqual:@"remove"]) {
            FCRemoveStagedCores(directory);
        } else assert(NO);
    }
}
'''


class RuntimePathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-runtime-pure-')
        cls.addClassCleanup(cls.scratch.cleanup)
        root = Path(cls.scratch.name)
        fixture = root / 'RuntimeFixture.m'
        fixture.write_text(FIXTURE)
        cls.binary = root / 'RuntimeFixture'
        subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-unused-function',
                        '-I', str(MACOS / 'PrivilegedHelper'), '-framework', 'Foundation', '-framework', 'Security',
                        str(fixture), str(MACOS / 'Shared/HelperTrust.m'), '-o', str(cls.binary)],
                       check=True, capture_output=True, text=True, cwd=str(MACOS / 'PrivilegedHelper'))

    def run_fixture(self, scenario, directory='/nonexistent', source='/nonexistent'):
        return subprocess.run([str(self.binary), scenario, str(directory), str(source)],
                              check=True, capture_output=True, text=True, timeout=20)

    def test_runtime_directory_is_new_and_fits_limits(self):
        self.run_fixture('constants')
        self.assertNotIn('/Library/Application Support/Flash/', TRUST.split('FCRuntimeDirectory = ', 1)[1].split(';', 1)[0])
        self.assertNotIn('com.layoute.flash.helper', TRUST.split('FCRuntimeDirectory = ', 1)[1].split(';', 1)[0])

    def test_user_owned_directory_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            os.chmod(directory, 0o700)
            self.run_fixture('prepare-refuses-user-owned', directory)

    def test_core_copy_is_hashed_while_copied_and_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(os.path.realpath(directory))
            runtime = work / 'run'
            runtime.mkdir(mode=0o700)
            core = work / 'FlClashCore'
            core.write_bytes(os.urandom(300_000))
            staged = Path(self.run_fixture('stage', runtime, core).stdout.strip())
            self.assertEqual(staged.read_bytes(), core.read_bytes())
            self.assertEqual(stat.S_IMODE(staged.stat().st_mode), 0o500)
            self.run_fixture('stage-wrong-hash', runtime, core)
            self.assertEqual(sorted(p.name for p in runtime.iterdir()), [staged.name])
            link = work / 'link'
            link.symlink_to(core)
            self.run_fixture('stage-symlink', runtime, link)
            (runtime / 'child-owned').write_text('owned\n')
            self.run_fixture('remove', runtime)
            self.assertEqual(sorted(p.name for p in runtime.iterdir()), ['child-owned'])

    def test_supervisor_spawns_only_the_verified_copy(self):
        start = function(SUPERVISOR, '- (NSString *)start:')
        self.assertIn('FCStageCore([FCGUIBundle stringByAppendingPathComponent:FCCoreRelativePath]', start)
        self.assertIn('FCCheckStatic(staged, FCCoreIdentifier)', start)
        self.assertIn('FCSpawnCore(staged.fileSystemRepresentation', start)
        self.assertNotIn('FCSpawnCore(core', start)
        self.assertIn('O_RDONLY | O_NOFOLLOW', STAGING)
        self.assertIn('CC_SHA256_Update(&context, buffer', STAGING)
        self.assertIn('fchmod(output, 0500)', STAGING)

    def test_persistent_journal_uncertainty_is_not_reset_blindly(self):
        init = function(SUPERVISOR, '- (instancetype)init')
        self.assertIn('lstat(journal.fileSystemRepresentation, &state) == 0 || errno != ENOENT', init)
        # The journal is released only after every Flash Core, found by signature, is stopped and confirmed gone.
        self.assertLess(init.index('_lastSweep = FCRetireFlashCores(0);'), init.index('unlink(journal'))
        self.assertIn('[_lastSweep[@"outcome"] isEqual:@"unconfirmed"]', init)
        self.assertIn('if (_ownershipUncertain) _child = -1;', init)

    def test_daemon_refuses_before_serving(self):
        main = function(SUPERVISOR, 'int main(void)')
        self.assertLess(main.index('FCHelperSelfCheck(FCRunningExecutable())'), main.index('[FCSupervisor new]'))
        self.assertLess(main.index('FCHelperSelfCheck(FCRunningExecutable())'),
                        main.index('xpc_connection_create_mach_service'))
        self.assertIn('return EX_CONFIG;', main)
        self.assertIn('geteuid() != 0', main)


if __name__ == '__main__':
    unittest.main()
