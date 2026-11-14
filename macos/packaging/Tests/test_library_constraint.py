import hashlib
import importlib.util
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location('constraint', Path(__file__).parents[1] / 'library_constraint.py')
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
HASHES = [bytes([i]) * 20 for i in range(1, 6)]


def der(tag, body):
    size = len(body)
    length = bytes([size]) if size < 128 else bytes([0x81, size])
    return bytes([tag]) + length + body


def dictionary(values):
    return der(0xb0, b''.join(der(0x30, der(12, k.encode()) + v) for k, v in values.items()))


def encoded(hashes=HASHES, extra=None):
    requirements = {'cdhash': dictionary({'$in': der(0x30, b''.join(der(4, h) for h in hashes))})}
    if extra:
        requirements.update(extra)
    envelope = dictionary({'ccat': der(2, b'\0'), 'comp': der(2, b'\1'),
                           'reqs': dictionary(requirements), 'vers': der(2, b'\1')})
    return der(0x70, der(2, b'\1') + envelope)


def fixture(payload=None, bind=True, slot=11, magic=0xfade8181, cpu=0x100000c):
    payload = encoded() if payload is None else payload
    blob = struct.pack('>II', magic, 8 + len(payload)) + payload
    offset = 88 + 11 * 32
    cd = bytearray(offset)
    struct.pack_into('>9I', cd, 0, 0xfade0c02, len(cd), 0x20400, 0x10000,
                     offset, 88, 11, 0, 48)
    cd[36:38] = bytes([32, 2])
    cd[88:120] = hashlib.sha256(blob).digest() if bind else bytes(32)
    signature = struct.pack('>III', 0xfade0cc0, 28 + len(cd) + len(blob), 2)
    signature += struct.pack('>4I', 0, 28, slot, 28 + len(cd)) + cd + blob
    header = struct.pack('<8I', 0xfeedfacf, cpu, 0, 2, 1, 16, 0, 0)
    return header + struct.pack('<4I', 0x1d, 16, 48, len(signature)) + signature


def fat_fixture(thin=None):
    thin = fixture() if thin is None else thin
    offset = 16384
    table = struct.pack('>7I', 0xcafebabe, 1, 0x100000c, 0, offset, len(thin), 14)
    return table + bytes(offset - len(table)) + thin


class ContainerTests(unittest.TestCase):
    def test_thin_regression_and_single_fat_share_identical_signature_semantics(self):
        thin = fixture()
        fat = fat_fixture(thin)
        self.assertEqual(C.arm64_slice(thin), thin)
        self.assertEqual(C.arm64_slice(fat), thin)
        self.assertEqual(C.cdhash(fat), C.cdhash(thin))
        self.assertEqual(C.signature_slots(fat), C.signature_slots(thin))
        self.assertEqual(C.verify_library_constraint(fat, HASHES), C.verify_library_constraint(thin, HASHES))

    def test_observed_framework_header_bytes_in_single_fat32_layout(self):
        headers = (
            'cffaedfe0c00000100000000060000000a000000300300008500100000000000',
            'cffaedfe0c000001000000000600000034000000401c00008580910200000000',
            'cffaedfe0c000001000000000600000010000000280c00008500100000000000',
            'cffaedfe0c000001000000000600000016000000980a00008500900000000000',
            'cffaedfe0c000001000000000600000012000000800600008500100000000000',
        )
        for header in headers:
            header_bytes = bytes.fromhex(header)
            count, size = struct.unpack_from('<II', header_bytes, 16)
            commands = struct.pack('<II', 0, 8) * (count - 1)
            final_size = size - len(commands)
            commands += struct.pack('<II', 0, final_size) + bytes(final_size - 8)
            thin = header_bytes + commands
            with self.subTest(header=header):
                self.assertEqual(C.inspect_slice(fat_fixture(thin)), thin)

    def test_unsigned_slice_preflight_does_not_require_code_signature(self):
        thin = struct.pack('<8I', 0xfeedfacf, 0x100000c, 0, 2, 1, 24, 0, 0)
        thin += struct.pack('<II', 0x1b, 24) + bytes(16)
        self.assertEqual(C.inspect_slice(thin), thin)
        self.assertEqual(C.inspect_slice(fat_fixture(thin)), thin)
        with self.assertRaises(ValueError):
            C.cdhash(thin)

    def test_preflight_rejects_malformed_unsigned_load_command_tables(self):
        thin = struct.pack('<8I', 0xfeedfacf, 0x100000c, 0, 2, 1, 24, 0, 0)
        thin += struct.pack('<II', 0x1b, 24) + bytes(16)
        for offset, value in ((16, 0), (16, 4097), (20, 4096), (20, 16),
                              (36, 0), (36, 7), (36, 9), (36, 32)):
            malformed = bytearray(thin)
            struct.pack_into('<I', malformed, offset, value)
            for container in (malformed, fat_fixture(malformed)):
                with self.subTest(offset=offset, value=value), self.assertRaises(ValueError):
                    C.inspect_slice(container)

    def test_signature_offsets_are_relative_to_slice_not_outer_container(self):
        thin = bytearray(fixture())
        struct.pack_into('<I', thin, 40, 16384 + 48)
        with self.assertRaises(ValueError):
            C.inspect_slice(fat_fixture(thin))

    def test_rejects_missing_multiple_and_ambiguous_architectures(self):
        for count in (0, 2, 0xffffffff):
            data = bytearray(fat_fixture())
            struct.pack_into('>I', data, 4, count)
            with self.subTest(count=count), self.assertRaises(ValueError):
                C.arm64_slice(data)

    def test_rejects_fat_entry_and_slice_header_disagreement(self):
        for offset, endian, value in ((8, '>', 0x1000007), (12, '>', 2),
                                      (16384 + 4, '<', 0x1000007), (16384 + 8, '<', 2)):
            data = bytearray(fat_fixture())
            struct.pack_into(endian + 'I', data, offset, value)
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                C.arm64_slice(data)

    def test_rejects_bad_alignment_offset_size_and_trailing_data(self):
        valid = fat_fixture()
        for offset, value in ((16, 0), (16, 24), (16, 16385), (16, 0xffffffff),
                              (20, 0), (20, 31), (20, len(valid)), (20, 0xffffffff),
                              (24, 32), (24, 0xffffffff), (24, 15)):
            data = bytearray(valid)
            struct.pack_into('>I', data, offset, value)
            with self.subTest(offset=offset, value=value), self.assertRaises(ValueError):
                C.arm64_slice(data)
        with self.assertRaises(ValueError):
            C.arm64_slice(valid + b'unknown trailing bytes')

    def test_rejects_truncated_tables_and_slices(self):
        data = fat_fixture()
        for end in (*range(28), 16384, 16384 + 31, len(data) - 1):
            with self.subTest(end=end), self.assertRaises(ValueError):
                C.arm64_slice(data[:end])

    def test_rejects_unreviewed_fat_variants_and_nested_container(self):
        for magic in ('bebafeca', 'cafebabf', 'bfbafeca'):
            with self.subTest(magic=magic), self.assertRaises(ValueError):
                C.arm64_slice(bytes.fromhex(magic) + fat_fixture()[4:])
        with self.assertRaises(ValueError):
            C.arm64_slice(fat_fixture(fat_fixture()))

    def test_fat_does_not_relax_constraint_binding_or_allowlist(self):
        with self.assertRaises(ValueError):
            C.verify_library_constraint(fat_fixture(fixture(bind=False)), HASHES)
        with self.assertRaises(ValueError):
            C.verify_library_constraint(fat_fixture(), HASHES[:4] + [b'x' * 20])


class ConstraintTests(unittest.TestCase):
    def test_exact_semantics_and_binding(self):
        result = C.verify_library_constraint(fixture(), reversed(HASHES))
        self.assertEqual(result['framework_cdhashes'], [h.hex() for h in HASHES])
        self.assertFalse(result['native_qualification'])
        self.assertEqual(result['special_slot'], 11)

    def test_cdhash_is_first_twenty_sha256_bytes(self):
        data = fixture()
        self.assertEqual(C.cdhash(data), hashlib.sha256(C.signature_slots(data)[0]).digest()[:20])

    def test_bad_binding_magic_slot_and_architecture(self):
        for kwargs in ({'bind': False}, {'magic': 0xfade8180}, {'slot': 10}, {'cpu': 0x1000007}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                C.verify_library_constraint(fixture(**kwargs), HASHES)

    def test_no_broadening_duplicates_or_non_data(self):
        for payload in (encoded(extra={'team-identifier': der(12, b'any')}),
                        encoded([HASHES[0]] * 5), encoded(HASHES[:4]),
                        encoded([b'x' * 19] + HASHES[1:]), encoded() + b'\0'):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                C.verify_library_constraint(fixture(payload), HASHES)

    def test_wrong_allowlist(self):
        with self.assertRaises(ValueError):
            C.verify_library_constraint(fixture(), HASHES[:4] + [b'x' * 20])

    def test_all_truncations_rejected(self):
        data = fixture()
        for end in range(len(data)):
            with self.assertRaises(ValueError):
                C.verify_library_constraint(data[:end], HASHES)

    def test_duplicate_and_overlapping_superblob_slots(self):
        for offset, value in ((68, 0), (72, 28)):
            data = bytearray(fixture())
            struct.pack_into('>I', data, offset, value)
            with self.assertRaises(ValueError):
                C.verify_library_constraint(data, HASHES)

    def test_minimal_der_and_unknown_tags(self):
        for data in (b'\x30\x80', b'\x30\x81\x01\0', b'\x05\0', b'\x02\x02\0\1'):
            with self.assertRaises(ValueError):
                C.decode_constraint(data)

    def test_plist_is_exact_data_allowlist(self):
        import plistlib
        self.assertEqual(plistlib.loads(C.constraint_plist(HASHES)), {'cdhash': {'$in': HASHES}})


if __name__ == '__main__':
    unittest.main()
