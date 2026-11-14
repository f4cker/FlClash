"""Fail-closed arm64 CodeDirectory and library-constraint inspection (no tools)."""
import hashlib
from pathlib import Path
import plistlib
import struct


def require(condition, message):
    if not condition:
        raise ValueError(message)


def allowlist(hashes):
    values = list(hashes)
    require(len(values) == 5 and all(type(v) is bytes and len(v) == 20 for v in values),
            'Expected exactly five DATA20 CDHashes')
    require(len(set(values)) == 5, 'Duplicate framework CDHash')
    return sorted(values)


def constraint_plist(hashes):
    return plistlib.dumps({'cdhash': {'$in': allowlist(hashes)}})


def _der(data, depth=0):
    require(depth < 16 and len(data) >= 2, 'Truncated or deep DER')
    tag, size = data[0], data[1]
    offset = 2
    if size & 128:
        count = size & 127
        require(0 < count <= 4 and len(data) >= 2 + count, 'Invalid DER length')
        require(data[2] != 0, 'Nonminimal DER length')
        size = int.from_bytes(data[2:2 + count], 'big')
        require(size >= 128, 'Nonminimal long DER length')
        offset += count
    end = offset + size
    require(end <= len(data), 'DER outside blob')
    body = data[offset:end]
    if tag in (0x70, 0xb0, 0x30):
        children = []
        while body:
            child, consumed = _der(body, depth + 1)
            children.append(child)
            body = body[consumed:]
        value = children
    elif tag == 0x0c:
        value = body.decode('utf-8', errors='strict')
    elif tag == 0x04:
        value = body
    elif tag == 0x02:
        require(size > 0 and not body[0] & 128, 'Invalid DER integer')
        require(size == 1 or body[0] != 0 or body[1] & 128, 'Nonminimal DER integer')
        value = int.from_bytes(body, 'big')
    else:
        raise ValueError('Unsupported DER tag')
    return (tag, value), end


def _dictionary(node):
    require(node[0] == 0xb0, 'Expected DER dictionary')
    result = {}
    for pair in node[1]:
        require(pair[0] == 0x30 and len(pair[1]) == 2, 'Expected DER dictionary pair')
        key, value = pair[1]
        require(key[0] == 0x0c and key[1] not in result, 'Invalid or duplicate DER key')
        result[key[1]] = value
    return result


def decode_constraint(data):
    node, consumed = _der(data)
    require(consumed == len(data) and node[0] == 0x70 and len(node[1]) == 2,
            'Invalid constraint envelope')
    require(node[1][0] == (2, 1), 'Unsupported DER format version')
    envelope = _dictionary(node[1][1])
    require(set(envelope) == {'ccat', 'comp', 'reqs', 'vers'}, 'Unexpected envelope keys')
    require(envelope['ccat'] == (2, 0) and envelope['comp'] == (2, 1)
            and envelope['vers'] == (2, 1), 'Unsupported constraint category/version')
    requirements = _dictionary(envelope['reqs'])
    require(set(requirements) == {'cdhash'}, 'Constraint must only test cdhash')
    operators = _dictionary(requirements['cdhash'])
    require(set(operators) == {'$in'} and operators['$in'][0] == 0x30,
            'Constraint must use only $in')
    values = operators['$in'][1]
    require(all(value[0] == 4 for value in values), 'CDHashes must be DER DATA')
    return allowlist(value[1] for value in values)


def inspect_slice(data):
    """Return the sole arm64 ALL slice after container and load-command preflight."""
    if data[:4] == b'\xca\xfe\xba\xbe':
        require(len(data) >= 28, 'Truncated FAT32 architecture table')
        count, cpu, subtype, offset, size, alignment = struct.unpack_from('>6I', data, 4)
        require(count == 1, 'Only one FAT32 architecture entry is supported')
        require(cpu == 0x100000c and subtype == 0, 'FAT32 entry must be arm64 ALL')
        require(alignment <= 31 and offset >= 28 and offset % (1 << alignment) == 0,
                'Invalid FAT32 slice offset/alignment')
        require(size >= 32 and offset + size == len(data), 'Invalid FAT32 slice size/bounds')
        data = data[offset:offset + size]
    require(len(data) >= 32 and data[:4] == b'\xcf\xfa\xed\xfe',
            'Only thin arm64 or single-arm64 FAT32 Mach-O supported')
    cpu, subtype, _, count, size = struct.unpack_from('<IIIII', data, 4)
    require(cpu == 0x100000c and subtype == 0, 'Slice header must agree on arm64 ALL')
    require(0 < count <= 4096 and count * 8 <= size and 32 + size <= len(data),
            'Invalid slice load-command table')
    offset, signature_seen = 32, False
    for _ in range(count):
        require(offset + 8 <= 32 + size, 'Truncated slice load command')
        command, length = struct.unpack_from('<II', data, offset)
        require(length >= 8 and length % 8 == 0 and offset + length <= 32 + size,
                'Invalid slice load-command size')
        if command == 0x1d:
            require(length == 16 and not signature_seen, 'Invalid duplicate slice signature command')
            start, signature_size = struct.unpack_from('<II', data, offset + 8)
            require(start >= 32 + size and signature_size >= 12
                    and start + signature_size <= len(data), 'Slice signature outside slice')
            signature_seen = True
        offset += length
    require(offset == 32 + size, 'Slice load-command size mismatch')
    return data


def arm64_slice(data):
    return inspect_slice(data)


def signature_slots(data):
    data = inspect_slice(data)
    cpu, subtype, _, count, size = struct.unpack_from('<IIIII', data, 4)
    require(cpu == 0x100000c and subtype == 0, 'Only arm64 ALL supported')
    require(0 < count <= 4096 and 32 + size <= len(data), 'Invalid load commands')
    offset, signature = 32, None
    for _ in range(count):
        require(offset + 8 <= 32 + size, 'Truncated load command')
        command, length = struct.unpack_from('<II', data, offset)
        require(length >= 8 and length % 8 == 0 and offset + length <= 32 + size,
                'Invalid load command length')
        if command == 0x1d:
            require(length == 16 and signature is None, 'Duplicate or invalid LC_CODE_SIGNATURE')
            start, length_signature = struct.unpack_from('<II', data, offset + 8)
            require(start >= 32 + size and length_signature >= 12
                    and start + length_signature <= len(data), 'Signature outside Mach-O')
            signature = data[start:start + length_signature]
        offset += length
    require(offset == 32 + size and signature is not None, 'Missing signature or command mismatch')
    magic, length, count = struct.unpack_from('>III', signature)
    require(magic == 0xfade0cc0 and 12 <= length <= len(signature)
            and 0 < count <= 64 and 12 + count * 8 <= length, 'Invalid signature superblob')
    slots, ranges = {}, []
    for index in range(count):
        slot, start = struct.unpack_from('>II', signature, 12 + index * 8)
        require(slot not in slots and start >= 12 + count * 8 and start + 8 <= length,
                'Duplicate slot or invalid blob offset')
        blob_length = struct.unpack_from('>I', signature, start + 4)[0]
        end = start + blob_length
        require(blob_length >= 8 and end <= length, 'Invalid subblob size')
        require(all(end <= a or start >= b for a, b in ranges), 'Overlapping signature blobs')
        ranges.append((start, end))
        slots[slot] = signature[start:end]
    return slots


def code_directory(slots):
    require(0 in slots and not any(0x1000 <= slot < 0x1006 for slot in slots),
            'Expected one primary CodeDirectory, no alternate directories')
    cd = slots[0]
    require(len(cd) >= 44, 'Truncated CodeDirectory')
    magic, length, version, flags, hash_offset, _, special, code, limit = struct.unpack_from('>9I', cd)
    hash_size, hash_type = cd[36:38]
    require(magic == 0xfade0c02 and length == len(cd) and 0x20400 <= version <= 0x20600,
            'Unsupported CodeDirectory')
    require(hash_size == 32 and hash_type == 2, 'Only full SHA256 CodeDirectory supported')
    header = {0x20400: 88, 0x20500: 96, 0x20600: 108}.get(version)
    require(header is not None and hash_offset - special * 32 >= header
            and hash_offset + code * 32 <= len(cd), 'Invalid CodeDirectory hash slots')
    return cd, hash_offset, special, flags


def cdhash(data):
    cd, _, _, _ = code_directory(signature_slots(data))
    # XNU cs_blobs.h: SHA256 CDhash is the first CS_CDHASH_LEN (20) bytes.
    return hashlib.sha256(cd).digest()[:20]


def verify_library_constraint(data, hashes):
    expected = allowlist(hashes)
    slots = signature_slots(data)
    require(11 in slots, 'Missing library-constraint signature slot 11')
    blob = slots[11]
    require(struct.unpack_from('>I', blob)[0] == 0xfade8181, 'Wrong library-constraint magic')
    actual = decode_constraint(blob[8:])
    require(actual == expected, 'Library constraint CDHash allowlist mismatch')
    cd, offset, count, flags = code_directory(slots)
    require(count >= 11 and flags & 0x10000, 'Missing runtime or CodeDirectory special slot 11')
    require(cd[offset - 11 * 32:offset - 10 * 32] == hashlib.sha256(blob).digest(),
            'Library constraint is not bound by CodeDirectory special slot 11')
    return {'architecture': 'arm64', 'cdhash': hashlib.sha256(cd).digest()[:20].hex(),
            'framework_cdhashes': [value.hex() for value in actual],
            'constraint_sha256': hashlib.sha256(blob).hexdigest(), 'special_slot': 11,
            'native_qualification': False}


def verify_file(path, hashes):
    return verify_library_constraint(Path(path).read_bytes(), hashes)
