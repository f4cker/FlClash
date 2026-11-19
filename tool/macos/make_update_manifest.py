#!/usr/bin/env python3
"""Packages a signed Flash.app for the in-app updater and writes its signed manifest.json.

usage:
  tool/macos/make_update_manifest.py genkey DIR
  tool/macos/make_update_manifest.py sign --key PRIVATE_KEY --app Flash.app --out DIR
      [--notes-file NOTES] [--base-url URL] [--tag TAG] [--arch arm64]
  tool/macos/make_update_manifest.py verify --public-key PUBLIC_KEY --manifest manifest.json [--archive ZIP]

genkey writes DIR/update_ed25519_private.key (0600, base64 32-byte seed) and DIR/update_ed25519_public.txt
(base64 32-byte key to pin in lib/common/mac_update.dart and macos/Runner/UpdaterChannel.swift).

sign refuses a private key readable by group or others, an app not signed with the pinned certificate as
com.layoute.flash, and a launcher that differs from FlashHelperLauncher.pin.json (every release must carry the
same launcher, or the in-app updater refuses it). It writes Flash-<version>-macos-<arch>.zip (ditto, keeps the
signature) and manifest.json into DIR, then verifies both again. The archive is downloaded from
BASE_URL/TAG/<name>; TAG defaults to v<CFBundleShortVersionString>, so a prerelease such as v0.9.15-mitm.7
(whose bundle version is 0.9.15) must pass --tag. The asset name always follows the bundle version, as the
updater requires.

The Ed25519 here is RFC 8032's reference arithmetic: not constant time, so run it only on the offline machine
that holds the key.
"""

import argparse
import base64
import datetime
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
from pathlib import Path
from functools import cmp_to_key

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER_PIN = ROOT / 'macos/PrivilegedHelper/Launcher/FlashHelperLauncher.pin.json'
DEFAULT_BASE_URL = 'https://github.com/f4cker/flash-releases/releases/download'
PINNED_CERTIFICATE = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'
APP_IDENTIFIER = 'com.layoute.flash'
HELPER = 'Contents/Library/HelperTools/FlashHelper'
LAUNCHER = 'Contents/Library/HelperTools/FlashHelperLauncher'
PRIVATE_NAME = 'update_ed25519_private.key'
PUBLIC_NAME = 'update_ed25519_public.txt'

_P = 2 ** 255 - 19
_Q = 2 ** 252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, _P - 2, _P) % _P
_SQRT_M1 = pow(2, (_P - 1) // 4, _P)


def _add(a, b):
    x = (a[1] - a[0]) * (b[1] - b[0]) % _P
    y = (a[1] + a[0]) * (b[1] + b[0]) % _P
    c = 2 * a[3] * b[3] * _D % _P
    d = 2 * a[2] * b[2] % _P
    e, f, g, h = y - x, d - c, d + c, y + x
    return e * f % _P, g * h % _P, f * g % _P, e * h % _P


def _mul(scalar, point):
    result = (0, 1, 1, 0)
    while scalar:
        if scalar & 1:
            result = _add(result, point)
        point = _add(point, point)
        scalar >>= 1
    return result


def _recover_x(y, sign):
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, _P - 2, _P)
    if x2 % _P == 0:
        return None if sign else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P:
        x = x * _SQRT_M1 % _P
    if (x * x - x2) % _P:
        return None
    return _P - x if (x & 1) != sign else x


_GY = 4 * pow(5, _P - 2, _P) % _P
_GX = _recover_x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)


def _compress(point):
    zinv = pow(point[2], _P - 2, _P)
    x, y = point[0] * zinv % _P, point[1] * zinv % _P
    return (y | (x & 1) << 255).to_bytes(32, 'little')


def _decompress(data):
    if len(data) != 32:
        return None
    y = int.from_bytes(data, 'little')
    sign, y = y >> 255, y & ((1 << 255) - 1)
    x = _recover_x(y, sign)
    return None if x is None else (x, y, 1, x * y % _P)


def _equal(a, b):
    return (a[0] * b[2] - b[0] * a[2]) % _P == 0 and (a[1] * b[2] - b[1] * a[2]) % _P == 0


def _expand(seed):
    digest = hashlib.sha512(seed).digest()
    scalar = int.from_bytes(digest[:32], 'little') & ((1 << 254) - 8) | (1 << 254)
    return scalar, digest[32:]


def _hash_mod_q(data):
    return int.from_bytes(hashlib.sha512(data).digest(), 'little') % _Q


def public_key(seed):
    return _compress(_mul(_expand(seed)[0], _G))


def sign(seed, message):
    scalar, prefix = _expand(seed)
    key = _compress(_mul(scalar, _G))
    r = _hash_mod_q(prefix + message)
    encoded_r = _compress(_mul(r, _G))
    s = (r + _hash_mod_q(encoded_r + key + message) * scalar) % _Q
    return encoded_r + s.to_bytes(32, 'little')


def verify(key, message, signature):
    if len(key) != 32 or len(signature) != 64:
        return False
    point_a, point_r = _decompress(key), _decompress(signature[:32])
    s = int.from_bytes(signature[32:], 'little')
    if point_a is None or point_r is None or s >= _Q or _equal(_mul(8, point_a), (0, 1, 1, 0)):
        return False
    h = _hash_mod_q(signature[:32] + key + message)
    return _equal(_mul(s, _G), _add(point_r, _mul(h, point_a)))


def read_private_key(path):
    path = Path(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise SystemExit(f'{path}: not a regular file')
    if info.st_mode & 0o077:
        raise SystemExit(f'{path}: readable or writable by group/others (mode {oct(info.st_mode & 0o777)}); '
                         'run chmod 600 on it first')
    if info.st_uid != os.getuid():
        raise SystemExit(f'{path}: not owned by the current user')
    seed = base64.b64decode(path.read_text().strip(), validate=True)
    if len(seed) != 32:
        raise SystemExit(f'{path}: not a base64 32-byte Ed25519 seed')
    return seed


def read_public_key(path):
    key = base64.b64decode(Path(path).read_text().strip(), validate=True)
    if len(key) != 32:
        raise SystemExit(f'{path}: not a base64 32-byte Ed25519 public key')
    return key


def generate_key(directory):
    directory = Path(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    private, public = directory / PRIVATE_NAME, directory / PUBLIC_NAME
    if private.exists() or public.exists():
        raise SystemExit(f'{directory}: a key is already there; refusing to overwrite it')
    seed = os.urandom(32)
    descriptor = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as handle:
        handle.write(base64.b64encode(seed).decode() + '\n')
    public.write_text(base64.b64encode(public_key(seed)).decode() + '\n')
    return public.read_text().strip()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def embedded_plist(executable):
    data = Path(executable).read_bytes()
    start = data.find(b'<?xml')
    end = data.find(b'</plist>', start)
    if start < 0 or end < 0:
        raise SystemExit(f'{executable}: no embedded Info.plist')
    return plistlib.loads(data[start:end + len(b'</plist>')])


def build_number(value, what):
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', value):
        raise SystemExit(f'{what}: CFBundleVersion {value!r} is not a build number')
    return int(value)


def check_signature(app):
    requirement = (f'anchor H"{PINNED_CERTIFICATE}" and certificate leaf = H"{PINNED_CERTIFICATE}" '
                   f'and identifier "{APP_IDENTIFIER}"')
    result = subprocess.run(['/usr/bin/codesign', '--verify', '--strict', '--deep', f'-R={requirement}', str(app)],
                            capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(f'{app}: not signed with the pinned certificate as {APP_IDENTIFIER}: {result.stderr.strip()}')


def bundle_facts(app):
    app = Path(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != APP_IDENTIFIER:
        raise SystemExit(f'{app}: bundle identifier is {info.get("CFBundleIdentifier")!r}')
    version = info.get('CFBundleShortVersionString')
    if not isinstance(version, str) or not re.fullmatch(r'[0-9A-Za-z.+-]{1,64}', version):
        raise SystemExit(f'{app}: bad CFBundleShortVersionString {version!r}')
    pin = json.loads(LAUNCHER_PIN.read_text())
    if sha256_file(app / LAUNCHER) != pin['sha256']:
        raise SystemExit(f'{app}: FlashHelperLauncher differs from {LAUNCHER_PIN.name}; the updater would refuse it')
    return {
        'version': version,
        'build': build_number(info.get('CFBundleVersion'), 'Flash.app'),
        'helperBuild': build_number(embedded_plist(app / HELPER).get('CFBundleVersion'), 'FlashHelper'),
        'minimumSystemVersion': info.get('LSMinimumSystemVersion', '14.0'),
        'channel': info.get('FlashReleaseChannel'),
        'releaseVersion': info.get('FlashReleaseVersion'),
    }


def make_payload(facts, asset, notes, published=None):
    metadata = facts.get('releaseMetadata', {})
    return {
        'schema': 2 if metadata.get('channel') == 'beta' else 1,
        **metadata,
        'product': APP_IDENTIFIER,
        'version': facts['version'],
        'build': facts['build'],
        'helperBuild': facts['helperBuild'],
        'minimumSystemVersion': facts['minimumSystemVersion'],
        'published': published or datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'notes': notes,
        'assets': [asset],
    }


def envelope(payload, seed):
    data = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    return {
        'schema': payload['schema'],
        'payload': base64.b64encode(data).decode(),
        'signature': base64.b64encode(sign(seed, data)).decode(),
    }


def open_envelope(manifest, key):
    if set(manifest) != {'schema', 'payload', 'signature'} or type(manifest.get('schema')) is not int or manifest['schema'] not in (1, 2):
        raise SystemExit('manifest: unknown schema')
    data = base64.b64decode(manifest['payload'], validate=True)
    if not verify(key, data, base64.b64decode(manifest['signature'], validate=True)):
        raise SystemExit('manifest: signature does not verify with this public key')
    payload = json.loads(data)
    if payload.get('schema') != manifest['schema']:
        raise SystemExit('manifest: inner and outer schemas differ')
    validate_channel_payload(payload)
    return payload


def release_tag(tag, version):
    tag = tag or f'v{version}'
    if not re.fullmatch(r'v[0-9A-Za-z.+-]{1,64}', tag) or not tag.startswith(f'v{version}'):
        raise SystemExit(f'{tag!r}: the release tag must be v{version} or start with it')
    return tag


SEMVER = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?')


def semantic(value):
    match = SEMVER.fullmatch(value) if isinstance(value, str) and len(value) <= 128 else None
    if not match:
        raise ValueError('Invalid release SemVer')
    pre = match[4].split('.') if match[4] else []
    if any(re.fullmatch(r'0[0-9]+', part) for part in pre):
        raise ValueError('Noncanonical prerelease number')
    return tuple(int(match[i]) for i in (1, 2, 3)), pre


def compare_semantic(left, right):
    a, ap = semantic(left)
    b, bp = semantic(right)
    if a != b:
        return (a > b) - (a < b)
    if not ap or not bp:
        return (not ap) - (not bp)
    for a, b in zip(ap, bp):
        if a == b:
            continue
        if a.isdigit() and b.isdigit():
            return (int(a) > int(b)) - (int(a) < int(b))
        if a.isdigit() != b.isdigit():
            return -1 if a.isdigit() else 1
        return (a > b) - (a < b)
    return (len(ap) > len(bp)) - (len(ap) < len(bp))


def channel_metadata(facts, channel, version, tag, source_commit, source_branch):
    if channel not in ('stable', 'beta') or facts.get('channel') != channel or facts.get('releaseVersion') != version:
        raise ValueError('Bundle must seal matching FlashReleaseChannel and FlashReleaseVersion before signing')
    semantic(version)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,127}', tag or '') or \
            not re.fullmatch(r'[0-9a-f]{40}', source_commit or '') or \
            not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9/._+-]{0,127}', source_branch or ''):
        raise ValueError('Invalid signed release/source identity')
    return {'channel': channel, 'platform': 'macos', 'release': {
        'repository': 'f4cker/flash-releases', 'tag': tag, 'version': version,
        'sourceRepository': 'f4cker/FlClash', 'sourceCommit': source_commit, 'sourceBranch': source_branch}}


def validate_channel_payload(payload):
    channel = payload.get('channel')
    if channel is None and 'channel' not in payload and payload.get('schema') == 1 and \
            type(payload.get('build')) is int and 0 < payload['build'] <= 2026111901:
        return
    if type(payload.get('schema')) is not int or (payload['schema'], channel) not in ((1, 'stable'), (2, 'beta')):
        raise ValueError('Invalid schema/channel matrix')
    release = payload.get('release', {})
    metadata = channel_metadata({'channel': channel, 'releaseVersion': release.get('version')}, channel,
                                release.get('version'), release.get('tag'), release.get('sourceCommit'), release.get('sourceBranch'))
    if payload.get('platform') != 'macos' or payload.get('product') != APP_IDENTIFIER or release != metadata['release']:
        raise ValueError('Invalid release repository/platform/product')
    for field in ('build', 'helperBuild'):
        if type(payload.get(field)) is not int or not 0 < payload[field] < 10 ** 18:
            raise ValueError('Invalid release build')
    for asset in payload.get('assets', []):
        if asset.get('url') != f'{DEFAULT_BASE_URL}/{release["tag"]}/{asset["name"]}':
            raise ValueError('Asset URL is not bound to signed tag')


def validate_unpublished_reservation(entry):
    evidence = entry.get('reservation')
    fields = {'sourceReceipt', 'sourceReceiptSha256', 'signingReceipt', 'signingReceiptSha256'}
    if not isinstance(evidence, dict) or set(evidence) != fields:
        raise ValueError('Unpublished reservation requires pinned source and signing receipts')
    receipts = []
    for kind in ('sourceReceipt', 'signingReceipt'):
        path, digest = evidence[kind], evidence[kind + 'Sha256']
        if not isinstance(path, str) or not Path(path).is_absolute() or \
                not isinstance(digest, str) or not re.fullmatch(r'[0-9a-f]{64}', digest):
            raise ValueError('Invalid unpublished reservation receipt binding')
        try:
            data = Path(path).read_bytes()
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError('Unpublished reservation receipt hash differs')
            receipt = json.loads(data)
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise ValueError('Unpublished reservation receipt cannot be read') from error
        if not isinstance(receipt, dict):
            raise ValueError('Invalid unpublished reservation receipt')
        receipts.append(receipt)
    source, signing = receipts
    head = source.get('head')
    archive = source.get('archive_sha256')
    identity = signing.get('release_identity')
    verified = signing.get('verify_signed')
    if not isinstance(head, str) or not re.fullmatch(r'[0-9a-f]{40}', head) or \
            not isinstance(archive, str) or not re.fullmatch(r'[0-9a-f]{64}', archive) or \
            signing.get('schema') != 'flash-mitm4-bundle-signing-v1' or \
            not isinstance(identity, dict) or not isinstance(verified, dict):
        raise ValueError('Invalid unpublished reservation source identity')
    compatibility = verified.get('compatibility')
    if identity.get('source_head') != head or identity.get('channel') != entry['channel'] or \
            identity.get('releaseVersion') != entry['version'] or identity.get('build') != str(entry['build']) or \
            verified.get('helper_version') != str(entry['helperBuild']) or \
            entry.get('tag') != 'v' + entry['version'] or not isinstance(compatibility, dict) or \
            compatibility.get('CoreRevision') != head:
        raise ValueError('Unpublished reservation differs from source/signing receipts')


def validate_release_ledger(payload, history):
    validate_channel_payload(payload)
    if not isinstance(history, list) or not history:
        raise ValueError('A complete approved global build ledger is required')
    builds, helpers, versions = [], [], []
    for entry in history:
        if not isinstance(entry, dict) or entry.get('channel') not in ('stable', 'beta') or \
                type(entry.get('build')) is not int or type(entry.get('helperBuild')) is not int:
            raise ValueError('Invalid global release ledger')
        if entry.get('tag') == payload['release']['tag']:
            raise ValueError('Release tags are immutable and cannot be reused')
        builds.append(entry['build'])
        helpers.append(entry['helperBuild'])
        semantic(entry['version'])
        disposition = entry.get('disposition', 'published')
        if disposition == 'unpublished-reservation':
            validate_unpublished_reservation(entry)
        elif disposition == 'published':
            versions.append(entry['version'])
        else:
            raise ValueError('Invalid global release ledger disposition')
    if payload['build'] <= max(builds) or payload['helperBuild'] <= max(helpers):
        raise ValueError('App and helper builds must grow across all channels')
    if versions and compare_semantic(payload['release']['version'], max(versions, key=cmp_to_key(compare_semantic))) < 0:
        raise ValueError('Release semantic version cannot fall behind approved history')


def publication_policy(payload):
    validate_channel_payload(payload)
    if payload.get('channel') not in ('stable', 'beta'):
        raise ValueError('Legacy manifests cannot authorize a new publication')
    beta = payload['channel'] == 'beta'
    return {'repository': 'f4cker/flash-releases', 'tag': payload['release']['tag'],
            'prerelease': beta, 'make_latest': 'false' if beta else 'true'}


def assert_stable_latest_unchanged(before, after):
    for snapshot in (before, after):
        if set(snapshot) != {'id', 'tag', 'manifest_sha256'} or not re.fullmatch(r'[0-9a-f]{64}', snapshot['manifest_sha256']):
            raise ValueError('Invalid stable latest snapshot')
    if before != after:
        raise ValueError('Beta publication changed stable latest; stop release processing')


def validate_publication(payload, release, before=None, after=None):
    policy = publication_policy(payload)
    if release.get('tag_name') != policy['tag'] or release.get('prerelease') is not policy['prerelease'] or \
            release.get('draft') is not False or release.get('repository') != policy['repository']:
        raise ValueError('Published GitHub metadata differs from signed channel identity')
    if policy['prerelease']:
        if before is None or after is None:
            raise ValueError('Beta publication requires both stable latest snapshots')
        assert_stable_latest_unchanged(before, after)
    return policy


def command_check_publication(arguments):
    payload = open_envelope(json.loads(Path(arguments.manifest).read_text()),
                            read_public_key(arguments.public_key))
    validate_release_ledger(payload, json.loads(Path(arguments.release_ledger).read_text()))
    snapshot = lambda path: json.loads(Path(path).read_text()) if path else None
    policy = validate_publication(payload, snapshot(arguments.release),
                                  snapshot(arguments.latest_before), snapshot(arguments.latest_after))
    print(json.dumps(policy, sort_keys=True))


def command_sign(arguments):
    app = Path(arguments.app).resolve()
    if app.name != 'Flash.app':
        raise SystemExit(f'{app}: expected a bundle named Flash.app')
    check_signature(app)
    facts = bundle_facts(app)
    tag = arguments.tag
    facts['releaseMetadata'] = channel_metadata(facts, arguments.channel, arguments.release_version, tag,
                                                arguments.source_commit, arguments.source_branch)
    if arguments.base_url.rstrip('/') != DEFAULT_BASE_URL:
        raise ValueError('Release assets must stay in the approved repository')
    candidate = make_payload(facts, {}, '')
    candidate['assets'] = []
    validate_release_ledger(candidate, json.loads(Path(arguments.release_ledger).read_text()))
    out = Path(arguments.out)
    out.mkdir(parents=True, exist_ok=True)
    name = f'Flash-{facts["version"]}-macos-{arguments.arch}.zip'
    archive = out / name
    if archive.exists():
        raise SystemExit(f'{archive}: already exists')
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(archive)],
                   check=True)
    asset = {
        'arch': arguments.arch,
        'name': name,
        'url': f'{arguments.base_url.rstrip("/")}/{tag}/{name}',
        'size': archive.stat().st_size,
        'sha256': sha256_file(archive),
    }
    notes = Path(arguments.notes_file).read_text().strip() if arguments.notes_file else ''
    seed = read_private_key(arguments.key)
    manifest = envelope(make_payload(facts, asset, notes), seed)
    payload = open_envelope(manifest, public_key(seed))
    if payload['assets'][0]['sha256'] != sha256_file(archive):
        raise SystemExit('self-check failed')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def command_verify(arguments):
    payload = open_envelope(json.loads(Path(arguments.manifest).read_text()), read_public_key(arguments.public_key))
    if arguments.archive:
        asset = next((item for item in payload['assets'] if item['name'] == Path(arguments.archive).name), None)
        if asset is None or asset['sha256'] != sha256_file(arguments.archive) or \
                asset['size'] != Path(arguments.archive).stat().st_size:
            raise SystemExit(f'{arguments.archive}: does not match the manifest')
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    genkey = commands.add_parser('genkey')
    genkey.add_argument('directory')
    signing = commands.add_parser('sign')
    signing.add_argument('--key', required=True)
    signing.add_argument('--app', required=True)
    signing.add_argument('--out', required=True)
    signing.add_argument('--notes-file')
    signing.add_argument('--base-url', default=DEFAULT_BASE_URL)
    signing.add_argument('--tag', required=True)
    signing.add_argument('--channel', required=True, choices=['stable', 'beta'])
    signing.add_argument('--release-version', required=True)
    signing.add_argument('--source-commit', required=True)
    signing.add_argument('--source-branch', required=True)
    signing.add_argument('--release-ledger', required=True, help='Approved complete stable+beta build history JSON')
    signing.add_argument('--arch', default='arm64', choices=['arm64', 'amd64'])
    checking = commands.add_parser('verify')
    checking.add_argument('--public-key', required=True)
    checking.add_argument('--manifest', required=True)
    checking.add_argument('--archive')
    publication = commands.add_parser('check-publication', help='Offline post-publication channel/latest gate; never writes releases')
    publication.add_argument('--manifest', required=True)
    publication.add_argument('--public-key', required=True)
    publication.add_argument('--release-ledger', required=True)
    publication.add_argument('--release', required=True, help='Captured GitHub metadata plus repository')
    publication.add_argument('--latest-before')
    publication.add_argument('--latest-after')
    arguments = parser.parse_args(argv)
    if arguments.command == 'genkey':
        print(generate_key(arguments.directory))
    elif arguments.command == 'sign':
        command_sign(arguments)
    elif arguments.command == 'check-publication':
        command_check_publication(arguments)
    else:
        command_verify(arguments)


if __name__ == '__main__':
    sys.exit(main())
