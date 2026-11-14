import re
import subprocess
import tempfile
import unittest
from pathlib import Path


MACOS = Path(__file__).resolve().parents[2]
TRUST = (MACOS / 'Shared/HelperTrust.m').read_text()
MAINTENANCE = (MACOS / 'PrivilegedHelper/Maintenance.m').read_text()
SUPERVISOR = (MACOS / 'PrivilegedHelper/Supervisor.m').read_text()


def function(source, declaration):
    start = source.index(declaration)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class RuntimePathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='flash-runtime-pure-')
        cls.addClassCleanup(cls.scratch.cleanup)
        source = r'''
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <errno.h>
#import <stdio.h>
#import <assert.h>
#import <sys/un.h>

static NSMutableDictionary<NSString *, NSValue *> *nodes;
static NSMutableDictionary<NSString *, NSNumber *> *errors;
static NSString *aclRejected;
static int FixtureLstat(const char *path, struct stat *state) {
    NSString *key = @(path);
    if (errors[key]) { errno = errors[key].intValue; return -1; }
    NSValue *value = nodes[key];
    if (!value) { errno = ENOENT; return -1; }
    [value getValue:state size:sizeof(*state)];
    return 0;
}
#define lstat FixtureLstat
static BOOL FCPathACLEmpty(const char *path, const struct stat *state) {
    return ![aclRejected isEqual:@(path)];
}
static void Node(NSString *path, mode_t mode, uid_t uid, nlink_t links) {
    struct stat state = {.st_mode = mode, .st_uid = uid, .st_nlink = links};
    nodes[path] = [NSValue value:&state withObjCType:@encode(struct stat)];
}
'''
        for name in ('FCInstalledBundle', 'FCRuntimeDirectory', 'FCLegacyRuntimeDirectory'):
            source += re.search(r'NSString \* const ' + name + r' = @"[^"]+";', TRUST)[0] + '\n'
        for declaration in ('BOOL FCLegacyRuntimeAbsent(void)',
                            'static BOOL FCProtectedNode(NSString *path)',
                            'static BOOL FCProtectedFrameworkLink(NSString *path, NSString *bundle)',
                            'BOOL FCProtectedTree(NSString *path, BOOL recursive)'):
            source += function(TRUST, declaration) + '\n'
        for declaration in ('static BOOL FCAbsent(NSString *path)',
                            'static BOOL FCPreflightFailure(const char *diagnostic)',
                            'static int FCResult(BOOL success, const char *diagnostic)',
                            'static BOOL FCPrivateRuntimeNode(NSString *path, BOOL directory)',
                            'static BOOL FCParentsSafe(void)'):
            source += function(MAINTENANCE, declaration) + '\n'
        source += r'''
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        nodes = [NSMutableDictionary dictionary];
        errors = [NSMutableDictionary dictionary];
        for (NSString *path in @[@"/", @"/Library", @"/Library/LaunchDaemons",
                @"/Library/Application Support", @"/Library/Application Support/Flash",
                @"/private", @"/private/var"])
            Node(path, S_IFDIR | 0755, 0, 1);
        Node(@"/private/var/run", S_IFDIR | 0775, 0, 1);
        NSString *scenario = @(argv[1]);
        NSString *base = FCRuntimeDirectory.stringByDeletingLastPathComponent;
        NSString *marker = [FCRuntimeDirectory stringByAppendingPathComponent:@"maintenance"];
        if ([scenario isEqual:@"parents-valid"]) {
            assert(!FCProtectedTree(@"/private/var/run", NO));
            assert(FCParentsSafe());
            Node(FCRuntimeDirectory, S_IFDIR | 0700, 0, 1);
            Node([FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"], S_IFREG | 0600, 0, 1);
            NSDictionary *before = nodes.copy;
            assert(FCParentsSafe());
            assert([nodes isEqual:before]);
        } else if ([scenario isEqual:@"parents-before-base"]) {
            [nodes removeObjectForKey:base];
            assert(FCParentsSafe());
        } else if ([scenario isEqual:@"bad-owned-base"]) {
            Node(base, S_IFDIR | 0775, 0, 1);
            assert(!FCParentsSafe());
        } else if ([scenario isEqual:@"bad-owned-base-parent"]) {
            [nodes removeObjectForKey:base];
            Node(base.stringByDeletingLastPathComponent, S_IFDIR | 0775, 0, 1);
            assert(!FCParentsSafe());
        } else if ([scenario isEqual:@"bad-daemon-parent"]) {
            Node(@"/Library/LaunchDaemons", S_IFDIR | 0775, 0, 1);
            assert(!FCParentsSafe());
        } else if ([scenario isEqual:@"bad-runtime-root"]) {
            for (NSNumber *mode in @[@(S_IFDIR | 0755), @(S_IFREG | 0700), @(S_IFLNK | 0700)]) {
                Node(FCRuntimeDirectory, mode.unsignedShortValue, 0, 1);
                assert(!FCParentsSafe());
            }
            [nodes removeObjectForKey:FCRuntimeDirectory];
            errors[FCRuntimeDirectory] = @(EACCES);
            assert(!FCParentsSafe());
        } else if ([scenario isEqual:@"private-nodes"]) {
            Node(FCRuntimeDirectory, S_IFDIR | 0700, 0, 1);
            assert(FCPrivateRuntimeNode(FCRuntimeDirectory, YES));
            Node(marker, S_IFREG | 0600, 0, 1);
            assert(FCPrivateRuntimeNode(marker, NO));
            for (NSNumber *mode in @[@(S_IFREG | 0644), @(S_IFREG | 0660), @(S_IFREG | 04600),
                    @(S_IFDIR | 0600), @(S_IFLNK | 0600)]) {
                Node(marker, mode.unsignedShortValue, 0, 1);
                assert(!FCPrivateRuntimeNode(marker, NO));
            }
            Node(marker, S_IFREG | 0600, 501, 1);
            assert(!FCPrivateRuntimeNode(marker, NO));
            Node(marker, S_IFREG | 0600, 0, 2);
            assert(!FCPrivateRuntimeNode(marker, NO));
            Node(marker, S_IFREG | 0600, 0, 1);
            aclRejected = marker;
            assert(!FCPrivateRuntimeNode(marker, NO));
        } else if ([scenario isEqual:@"legacy-absence"]) {
            assert(FCLegacyRuntimeAbsent());
            for (NSNumber *mode in @[@(S_IFDIR | 0700), @(S_IFREG | 0600), @(S_IFLNK | 0777)]) {
                Node(FCLegacyRuntimeDirectory, mode.unsignedShortValue, 0, 1);
                errno = ENOENT;
                assert(!FCLegacyRuntimeAbsent());
            }
            [nodes removeObjectForKey:FCLegacyRuntimeDirectory];
            for (NSNumber *error in @[@EACCES, @EPERM, @EIO, @ENOTDIR, @ELOOP, @EINVAL]) {
                errors[FCLegacyRuntimeDirectory] = error;
                assert(!FCLegacyRuntimeAbsent());
            }
        } else if ([scenario isEqual:@"socket-length"]) {
            NSString *path = [FCRuntimeDirectory stringByAppendingPathComponent:
                @"01234567-89AB-CDEF-0123-456789ABCDEF.sock"];
            assert(strlen(path.fileSystemRepresentation) + 1 <= 104);
            assert(strlen(path.fileSystemRepresentation) + 1 <= sizeof(((struct sockaddr_un *)0)->sun_path));
            assert([FCRuntimeDirectory.stringByDeletingLastPathComponent isEqual:FCInstalledBundle.stringByDeletingLastPathComponent]);
            assert(![FCRuntimeDirectory hasPrefix:[FCInstalledBundle stringByAppendingString:@"/"]]);
        } else if ([scenario isEqual:@"root-diagnostic"]) {
            assert(FCResult(NO, "root-required") == 78);
            assert(FCResult(YES, "must-not-print") == 0);
        } else assert(NO);
    }
}
'''
        fixture = Path(cls.scratch.name) / 'RuntimePathFixture.m'
        fixture.write_text(source)
        cls.binary = Path(cls.scratch.name) / 'RuntimePathFixture'
        subprocess.run(['clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                        '-Wno-incompatible-pointer-types', '-framework', 'Foundation',
                        str(fixture), '-o', str(cls.binary)], check=True, capture_output=True, text=True)

    def fixture(self, scenario, diagnostic=''):
        result = subprocess.run([str(self.binary), scenario], check=True, capture_output=True, text=True)
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, diagnostic)

    def test_owned_parent_ignores_system_run_permissions(self):
        self.fixture('parents-valid')
        self.fixture('parents-before-base')

    def test_parent_diagnostics(self):
        for scenario, diagnostic in [('bad-owned-base', 'owned-base-unsafe'),
                                     ('bad-owned-base-parent', 'owned-base-parent-unsafe'),
                                     ('bad-daemon-parent', 'launch-daemon-parent-unsafe')]:
            with self.subTest(scenario=scenario):
                self.fixture(scenario, f'FlashMaintenance: {diagnostic}\n')
        self.fixture('bad-runtime-root', 'FlashMaintenance: runtime-root-unsafe\n' * 4)
        self.fixture('root-diagnostic', 'FlashMaintenance: root-required\n')

    def test_private_runtime_metadata(self):
        self.fixture('private-nodes')

    def test_legacy_runtime_must_be_proven_absent(self):
        self.fixture('legacy-absence')
        main = function(MAINTENANCE, 'int main(int argc, const char *argv[])')
        self.assertLess(main.index('if (!FCLegacyRuntimeAbsent())'), main.index('NSString *action'))
        self.assertIn('legacy-runtime-recovery-required', main)
        self.assertIn('preserve journals and recover before retry', main)
        helper_main = function(SUPERVISOR, 'int main(void)')
        self.assertLess(helper_main.index('if (!FCLegacyRuntimeAbsent())'),
                        helper_main.index('[FCSupervisor new]'))
        self.assertLess(helper_main.index('if (!FCLegacyRuntimeAbsent())'),
                        helper_main.index('xpc_connection_create_mach_service'))
        self.assertIn('legacy-runtime-recovery-required', helper_main)
        self.assertIn('preserve journals and recover before retry', helper_main)
        self.assertEqual(TRUST.count('FCLegacyRuntimeDirectory.fileSystemRepresentation'), 1)
        self.assertNotIn('/private/var/run', MAINTENANCE)

    def test_uuid_socket_fits_darwin_limit(self):
        self.fixture('socket-length')

    def test_persistent_journal_uncertainty_is_not_reset(self):
        init = function(SUPERVISOR, '- (instancetype)init')
        self.assertIn('lstat(journal.fileSystemRepresentation, &state) == 0 || errno != ENOENT', init)
        self.assertIn('_ownershipUncertain = YES;', init)
        self.assertIn('_child = -1;', init)
        self.assertNotIn('unlink(', init)
        removal = function(MAINTENANCE, 'static BOOL FCRemovalQuiescent(void)')
        self.assertIn('FCAbsent([FCRuntimeDirectory stringByAppendingPathComponent:@"child-owned"])', removal)
        self.assertNotIn('unlink(', removal)


if __name__ == '__main__':
    unittest.main()
