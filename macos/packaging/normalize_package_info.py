#!/usr/bin/env python3
"""Remove pkgbuild's default hook timeouts without rewriting raw package archives."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import sys
from xml.parsers import expat

OPERATIONS = ('install', 'repair', 'disable', 'remove')
HOOKS = {'preinstall', 'postinstall'}


def normalize_info(data, operation):
    if operation not in OPERATIONS:
        raise ValueError('Unknown package operation')
    parser = expat.ParserCreate()
    stack, hooks, removals = [], set(), []
    declarations = 0

    def start(name, attributes):
        nonlocal declarations
        if not stack and (name != 'pkg-info' or attributes.get('identifier') !=
                          'com.layoute.flash.managed.' + operation or
                          attributes.get('install-location') != '/'):
            raise ValueError('Package identity/install location mismatch')
        if stack and stack[-1] in HOOKS:
            raise ValueError('Nested hook content')
        if stack == ['pkg-info', 'scripts'] and name not in HOOKS:
            raise ValueError('Unexpected hook declaration')
        if name == 'scripts':
            declarations += 1
            if stack != ['pkg-info'] or attributes or declarations != 1:
                raise ValueError('Unexpected scripts declaration')
        if name in HOOKS:
            if stack != ['pkg-info', 'scripts'] or name in hooks:
                raise ValueError('Unexpected or duplicate hook')
            hooks.add(name)
            expected = {'file': './' + name}
            if attributes not in (expected, dict(expected, timeout='600')):
                raise ValueError('Unexpected hook attributes/path/timeout')
            if 'timeout' in attributes:
                begin = parser.CurrentByteIndex
                end = data.index(b'>', begin) + 1
                matches = list(re.finditer(rb'(?<=[\t\r\n ])timeout="600"(?=[\t\r\n />])',
                                           data[begin:end]))
                if len(matches) != 1:
                    raise ValueError('Timeout must use the exact pkgbuild spelling')
                removals.append((begin + matches[0].start(), begin + matches[0].end()))
        elif 'timeout' in attributes:
            raise ValueError('Timeout outside direct hook declaration')
        stack.append(name)

    def text(value):
        if stack and stack[-1] in HOOKS | {'scripts'} and value.strip():
            raise ValueError('Unexpected script declaration content')

    def reject_doctype(*unused):
        raise ValueError('PackageInfo must not declare a DTD')

    parser.StartElementHandler = start
    parser.EndElementHandler = lambda name: stack.pop()
    parser.CharacterDataHandler = text
    parser.StartDoctypeDeclHandler = reject_doctype
    try:
        parser.Parse(data, True)
    except expat.ExpatError as error:
        raise ValueError('Malformed PackageInfo') from error
    if declarations != 1 or hooks != HOOKS:
        raise ValueError('Missing script declarations')
    for begin, end in reversed(removals):
        data = data[:begin] + data[end:]
    return data


def read_regular(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise ValueError('Raw package member must be a regular file')
    return path.read_bytes()


def raw_members(raw):
    if not stat.S_ISDIR(raw.lstat().st_mode):
        raise ValueError('Raw expansion must be a directory')
    return {path.name: hashlib.sha256(read_regular(path)).hexdigest()
            for path in raw.iterdir()}


def verify_raw(raw, snapshot, operation):
    expected = json.loads(read_regular(snapshot))
    if expected['operation'] != operation or raw_members(raw) != expected['members']:
        raise ValueError('Raw package member set or bytes changed')
    data = read_regular(raw / 'PackageInfo')
    if normalize_info(data, operation) != data:
        raise ValueError('PackageInfo is not normalized')


def normalize_raw(raw, snapshot, operation):
    members = raw_members(raw)
    if operation in ('install', 'repair'):
        allowed_sets = ({'PackageInfo', 'Scripts', 'Payload', 'Bom'},)
    else:
        allowed_sets = ({'PackageInfo', 'Scripts'}, {'PackageInfo', 'Scripts', 'Bom'})
    if members.keys() not in allowed_sets:
        raise ValueError('Unexpected or missing raw component package members')
    normalized = normalize_info(read_regular(raw / 'PackageInfo'), operation)
    members['PackageInfo'] = hashlib.sha256(normalized).hexdigest()
    with snapshot.open('x', encoding='utf-8') as stream:
        json.dump({'operation': operation, 'members': members}, stream, sort_keys=True)
        stream.write('\n')
    (raw / 'PackageInfo').write_bytes(normalized)
    verify_raw(raw, snapshot, operation)


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('mode', choices=('normalize', 'verify'))
    parser.add_argument('raw', type=Path)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('operation', choices=OPERATIONS)
    args = parser.parse_args()
    try:
        if args.mode == 'normalize':
            normalize_raw(args.raw, args.snapshot, args.operation)
        else:
            verify_raw(args.raw, args.snapshot, args.operation)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'Raw package normalization failed closed: {type(error).__name__}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
