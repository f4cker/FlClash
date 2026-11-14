import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

MACOS = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'constraint_fixtures', MACOS / 'packaging/Tests/test_library_constraint.py')
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)


class NativeConstraintTests(unittest.TestCase):
    def test_bounded_parser_matches_reference_on_synthetic_bytes(self):
        valid = F.fixture()
        cases = [(valid, True), (F.fat_fixture(), True)]
        cases += [(F.fixture(**kwargs), False) for kwargs in (
            {'bind': False}, {'magic': 0xfade8180}, {'slot': 10}, {'cpu': 0x1000007})]
        cases += [(F.fixture(payload), False) for payload in (
            F.encoded(extra={'team-identifier': F.der(12, b'any')}),
            F.encoded([F.HASHES[0]] * 5), F.encoded(F.HASHES[:4]),
            F.encoded([b'x' * 19] + F.HASHES[1:]), F.encoded() + b'\0',
            b'\x30\x80', b'\x30\x81\x01\0', b'\x05\0', b'\x02\x02\0\1')]
        for offset, value in ((68, 0), (72, 28), (52, 0xffffffff), (56, 65),
                              (64, 0xffffffff), (84, 0xffffffff), (92, 0xffffffff),
                              (100, 0xffffffff), (104, 0xffffffff)):
            malformed = bytearray(valid)
            struct.pack_into('>I', malformed, offset, value)
            cases.append((bytes(malformed), False))
        for offset, value in ((16, 0), (16, 4097), (20, 0xffffffff), (36, 0),
                              (36, 9), (40, 0xffffffff), (44, 0xffffffff)):
            malformed = bytearray(valid)
            struct.pack_into('<I', malformed, offset, value)
            cases.append((bytes(malformed), False))
        for end in range(len(valid)):
            cases.append((valid[:end], False))
        fat = F.fat_fixture()
        for offset, value in ((4, 2), (8, 0x1000007), (12, 2), (16, 24),
                              (16, 0xffffffff), (20, 0xffffffff), (24, 32)):
            malformed = bytearray(fat)
            struct.pack_into('>I', malformed, offset, value)
            cases.append((bytes(malformed), False))
        source = r'''
#import "LibraryConstraintPolicy.h"
#import <assert.h>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        NSMutableSet *hashes = [NSMutableSet set];
        for (uint8_t i = 1; i <= 5; i++) {
            uint8_t bytes[20]; memset(bytes, i, 20);
            [hashes addObject:[NSData dataWithBytes:bytes length:20]];
        }
        NSArray *cases = [NSArray arrayWithContentsOfFile:@(argv[1])];
        assert(cases.count > 500);
        for (NSDictionary *test in cases) {
            assert(FCVerifyLibraryConstraint(test[@"data"], hashes) == [test[@"valid"] boolValue]);
        }
        assert(!FCVerifyLibraryConstraint(cases[0][@"data"], [NSSet set]));
        puts("Bounded native parser synthetic-byte cases passed; not dyld qualification");
    }
}
'''
        import plistlib
        with tempfile.TemporaryDirectory(prefix='flash-constraint-unit-') as directory:
            root = Path(directory)
            (root / 'parser.m').write_text(source)
            (root / 'cases.plist').write_bytes(plistlib.dumps([
                {'data': data, 'valid': valid} for data, valid in cases]))
            result = subprocess.run([
                'clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                '-fsanitize=address,undefined', '-I', str(MACOS / 'Shared'),
                str(root / 'parser.m'), '-framework', 'Foundation', '-o', str(root / 'parser'),
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(root / 'parser'), str(root / 'cases.plist')],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_descriptor_reads_only_signature_ranges_and_rejects_short_reads(self):
        source = r'''
#import <Foundation/Foundation.h>
#import <unistd.h>
#import <errno.h>
#import <assert.h>
static NSUInteger calls, bytesRead, shortAt;
static BOOL interrupt;
static ssize_t CountedRead(int fd, void *buffer, size_t length, off_t offset) {
    calls++;
    assert(length <= 4 * 1024 * 1024);
    if (interrupt) { interrupt = NO; errno = EINTR; return -1; }
    ssize_t result = pread(fd, buffer, calls == shortAt ? length - 1 : length, offset);
    if (result > 0) bytesRead += (NSUInteger)result;
    return result;
}
#define pread CountedRead
#import "LibraryConstraintPolicy.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        assert(argc == 2);
        NSString *root = @(argv[1]);
        NSData *reference = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"reference"]];
        NSDictionary *expected = FCSignatureSlots(reference);
        assert(expected);
        for (NSString *name in @[@"thin", @"fat"]) {
            NSString *path = [root stringByAppendingPathComponent:name];
            NSUInteger extra = [name isEqual:@"fat"] ? 32 : 0;
            calls = bytesRead = shortAt = 0;
            assert([FCPolicyFile(path) isEqualToDictionary:expected]);
            assert(calls == (extra ? 4 : 3));
            assert(bytesRead == reference.length + extra && bytesRead < 4096);
            NSUInteger ranges = calls;
            for (NSUInteger i = 1; i <= ranges; i++) {
                calls = bytesRead = 0; shortAt = i;
                assert(!FCPolicyFile(path));
                assert(calls == i);
            }
            calls = bytesRead = shortAt = 0; interrupt = YES;
            assert([FCPolicyFile(path) isEqualToDictionary:expected]);
            assert(calls == ranges + 1 && bytesRead == reference.length + extra);
        }
        for (NSString *name in @[@"link", @"fifo", @"missing", @".", @"oversize", @"bad-commands", @"bad-signature"]) {
            calls = bytesRead = shortAt = 0;
            assert(!FCPolicyFile([root stringByAppendingPathComponent:name]));
            assert(bytesRead <= 48);
        }
        puts("64MiB thin/FAT files: <4096 bytes read; caps, nofollow, short reads and EINTR checked");
    }
}
'''
        with tempfile.TemporaryDirectory(prefix='flash-constraint-ranges-') as directory:
            root = Path(directory)
            reference = F.fixture()
            (root / 'reference').write_bytes(reference)
            signature_offset = 64 * 1024 * 1024
            header = bytearray(reference[:48])
            struct.pack_into('<I', header, 40, signature_offset)
            for name, base in (('thin', 0), ('fat', 16384)):
                with (root / name).open('wb') as output:
                    if base:
                        output.write(struct.pack('>7I', 0xcafebabe, 1, 0x100000c, 0,
                                                 base, signature_offset + len(reference) - 48, 14))
                        output.seek(base)
                    output.write(header)
                    output.seek(base + signature_offset)
                    output.write(reference[48:])
            (root / 'link').symlink_to(root / 'thin')
            os.mkfifo(root / 'fifo')
            with (root / 'oversize').open('wb') as output:
                output.truncate(1 << 32)
            for name, field, value in (('bad-commands', 20, 1024 * 1024 + 8),
                                       ('bad-signature', 44, 4 * 1024 * 1024 + 1)):
                bad = bytearray(header)
                struct.pack_into('<I', bad, field, value)
                with (root / name).open('wb') as output:
                    output.write(bad)
                    output.truncate(128 * 1024 * 1024)
            (root / 'ranges.m').write_text(source)
            result = subprocess.run([
                'clang', '-fobjc-arc', '-fblocks', '-Werror', '-Wno-deprecated-declarations',
                '-fsanitize=address,undefined', '-I', str(MACOS / 'Shared'),
                str(root / 'ranges.m'), '-framework', 'Foundation', '-o', str(root / 'ranges'),
            ], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(root / 'ranges'), str(root)],
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
