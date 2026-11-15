#!/usr/bin/env python3
"""Local Mac release with embedded helper installers and protected GUI signing."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = 'f4cker/FlClash'
CORE_SHA256 = 'PENDING_SIGNED_CORE_1503'
CORE_REVISION = 'PENDING_BUILT_WRAPPER_REVISION'
SERVICE_RECEIPT_SHA256 = 'PENDING_SIGNED_SERVICE_1503'
IDENTITY = 'BBA7F8529FD271B9848EC03A2CE3F4780F585556'
CORE = 'Contents/MacOS/FlClashCore'
SERVICE_BUILD = '2026111503'
BEGIN = '<!-- flclash:changelog:begin -->'
END = '<!-- flclash:changelog:end -->'
JSON_BEGIN = '<!-- flclash:changelog:json'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_nlink == 1,
            'Expected a single-link regular file: ' + str(path))
    with path.open('rb') as stream:
        result = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def pinned(path, digest):
    require(re.fullmatch('[0-9a-f]{64}', digest or '') and sha(path) == digest,
            'File hash differs from pinned receipt: ' + str(path))
    return json.loads(path.read_text())


def save(path, data):
    require(not path.exists() and not path.is_symlink(), 'Refusing to overwrite evidence: ' + str(path))
    with path.open('x') as stream:
        json.dump(data, stream, sort_keys=True, indent=2)
        stream.write('\n')


def command(argv, *, env=None):
    return subprocess.run([str(arg) for arg in argv], cwd=ROOT, env=env, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.rstrip('\n')


def git(*args):
    return command(['git', '--no-optional-locks', *args])


def module(name):
    path = ROOT / 'macos/packaging' / (name + '.py')
    spec = importlib.util.spec_from_file_location('_local_release_' + name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def static_dependencies():
    return module('verify_split_service').static_dependencies(module('sign_split_payload'))


def source_identity(tag):
    require(re.fullmatch(r'v\d+\.\d+\.\d+', tag), 'A stable vX.Y.Z tag is required')
    require(git('branch', '--show-current') == 'main', 'Release only from merged main')
    require(not git('status', '--porcelain', '--untracked-files=all', '--ignore-submodules=none'), 'Release requires a clean checkout')
    for line in git('submodule', 'status', '--recursive').splitlines():
        require(line.startswith(' '), 'Submodules must be initialized at their exact pins')
    head = git('rev-parse', 'HEAD')
    require(git('rev-parse', tag + '^{commit}') == head, 'Tag must already point at main HEAD; this tool never pushes tags')
    text = (ROOT / 'pubspec.yaml').read_text()
    match = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)\s*$', text, re.M)
    require(match and 'v' + match[1] == tag, 'Tag and pubspec version differ')
    for package in ('setup', 'rust_api'):
        require(re.search(r'^    ' + package + r':\s*\n      build_assets: true\s*$', text, re.M),
                'Both native build hooks must stay enabled')
    return {'head': head, 'tag': tag, 'version': match[1], 'build': match[2]}


def configuration(path):
    path = path.absolute()
    require(path.resolve() == path and path.is_relative_to(ROOT / '.airbuild'),
            'Local config must be a real ignored file inside .airbuild')
    require(git('check-ignore', str(path)) != '', 'Local config must be ignored')
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and
            info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600,
            'Local config must be an owned single-link regular file with mode 0600')
    data = json.loads(path.read_text())
    require(set(data) == {'schema', 'sdk', 'signer', 'signer_sha256', 'service',
                          'service_receipt', 'service_receipt_sha256'}, 'Unexpected local config fields')
    require(data['schema'] == 1, 'Unsupported config schema')
    for key in ('sdk', 'signer', 'service', 'service_receipt'):
        item = Path(data[key])
        require(item.is_absolute() and item.resolve(strict=True) == item, 'Noncanonical configured path: ' + key)
    signer = Path(data['signer'])
    require(os.access(signer, os.X_OK) and sha(signer) == data['signer_sha256'], 'Protected adapter pin changed')
    if signer.is_relative_to(ROOT):
        require(git('ls-files', '--', str(signer)) == '', 'Protected adapter must not be tracked')
    sdk_version = json.loads((Path(data['sdk']) / 'bin/cache/flutter.version.json').read_text())
    require(sdk_version.get('flutterVersion') == '3.47.4', 'This local route requires Flutter 3.47.4')
    return data


def check_service(config):
    require(re.fullmatch('[0-9a-f]{64}', CORE_SHA256) and
            re.fullmatch('[0-9a-f]{40}', CORE_REVISION) and
            re.fullmatch('[0-9a-f]{64}', SERVICE_RECEIPT_SHA256),
            'New signed Core/service pins are pending')
    base = ROOT / '.airbuild/local-release/service-core-1503'
    app = base / 'service-payload/Flash.app'
    receipt_path = base / 'service-current-schema.json'
    require(config['service'] == str(app) and config['service_receipt'] == str(receipt_path) and
            config['service_receipt_sha256'] == SERVICE_RECEIPT_SHA256,
            'Only the exact reviewed 1503 service is supported')
    receipt = pinned(receipt_path, SERVICE_RECEIPT_SHA256)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(info.get('CFBundleVersion') == SERVICE_BUILD and
            info.get('CFBundleShortVersionString') == '0.9.14', 'Service version differs')
    require(sha(app / CORE) == CORE_SHA256, 'Released service/Core changed')
    require(type(receipt.get('schema')) is int and receipt['schema'] == 1 and
            receipt.get('phase') == 'service' and receipt.get('app') == str(app) and
            receipt.get('static_verification') is True and 'signing_scope' not in receipt and
            'wrapper_derivation' not in receipt and
            receipt.get('reused_signed_core_sha256') == CORE_SHA256 and
            receipt.get('before', {}).get('entries', {}).get(CORE, {}).get('sha256') == CORE_SHA256 and
            receipt.get('compatibility') == {
                'CallerPolicy': 2, 'ServiceAPI': 1, 'CoreAPI': 1, 'CoreSHA256': CORE_SHA256,
                'CoreVersion': 'v1.19.33', 'CoreRevision': CORE_REVISION},
            'Exact ordinary new-Core service signing evidence required')
    gate = module('verify_split_service')
    stage = module('stage_split_payload')
    gate.verify_bundle(app, 'service', receipt_path, SERVICE_RECEIPT_SHA256,
                       module('sign_split_payload'), stage)
    return stage.inventory(app)


def check_version(app, identity):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(info.get('CFBundleShortVersionString') == identity['version'] and
            str(info.get('CFBundleVersion')) == identity['build'], 'Built bundle version differs from source')
    require(not (app / 'Contents/Library').exists(), 'GUI must not embed helper tools')
    require(not (app / CORE).exists() and not (app / CORE).is_symlink(), 'GUI must not contain a loose Core')
    stage = module('stage_split_payload')
    require(info.get(stage.MINIMUM_SERVICE_BUILD_KEY) == SERVICE_BUILD, 'GUI minimum service build differs')
    require(CORE_SHA256 in stage.read_compatibility(app, 'gui')['AcceptedCoreSHA256'],
            'GUI must accept the released service Core')


def notes(identity):
    data = json.loads((ROOT / 'changelog.json').read_text())
    require(data.get('schemaVersion') == 2, 'Unsupported structured changelog')
    versions = [version for version in data['versions'] if version['tag'] == identity['tag']]
    require(len(versions) == 1 and versions[0]['version'] == identity['version'] and
            versions[0]['prerelease'] is False, 'Missing stable structured changelog for tag')
    version = versions[0]
    titles = {'breaking': 'Breaking Changes', 'feat': 'Features', 'fix': 'Bug Fixes',
              'perf': 'Performance', 'revert': 'Reverts'}
    lines = [BEGIN]
    for group in version['groups']:
        lines += ['### ' + titles[group['type']]]
        for entry in group['entries']:
            prefix = '**' + entry['scope'] + '** ' if entry.get('scope') else ''
            lines.append('- ' + prefix + entry['text'])
        lines.append('')
    payload = json.dumps({'schemaVersion': 2, 'versions': [version]}, ensure_ascii=False,
                         separators=(',', ':')).replace('>', '\\u003e')
    lines += [END, '', JSON_BEGIN, payload, '-->', '',
              '## macOS release scope', '',
              'Apple Silicon (arm64) release with one embedded install package for '
              'service build **2026111503**, retaining helper binary build **2026111402**. Install the helper from the app '
              'with macOS administrator authorization; no separate helper download is required.', '',
              'Self-signed with the existing Flash identity; **not Apple Developer ID signed '
              'and not notarized**. The helper remains unchanged; the Core is newly built and signed. Packaging '
              'and static signature checks are not a claim of full test-suite or runtime acceptance.', '']
    return '\n'.join(lines)


@contextmanager
def release_lock(directory):
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(directory / 'lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        os.close(descriptor)


class Release:
    def __init__(self, identity, config, directory):
        self.identity, self.config, self.directory = identity, config, directory
        self.app = directory / 'gui/Flash.app'
        self.request = directory / 'sign-request.json'
        self.response = directory / 'sign-response.json'
        self.state_path = directory / 'state.json'
        binding = {'schema': 1, 'source': identity, 'config_sha256': hashlib.sha256(
            json.dumps(config, sort_keys=True).encode()).hexdigest()}
        if self.state_path.exists():
            self.state = json.loads(self.state_path.read_text())
            require(all(self.state.get(k) == v for k, v in binding.items()), 'Resume source/config changed')
        else:
            directory.mkdir(mode=0o700)
            self.state = binding
            self.checkpoint()

    def checkpoint(self):
        temporary = self.directory / 'state.new'
        save(temporary, self.state)
        os.replace(temporary, self.state_path)

    def unchanged(self):
        require(source_identity(self.identity['tag']) == self.identity, 'Source changed during release')
        require(check_service(self.config) == self.state['service_inventory'], 'Immutable helper changed')

    def build(self):
        if 'request_sha256' in self.state:
            pinned(self.request, self.state['request_sha256'])
            return
        self.state['service_inventory'] = check_service(self.config)
        self.checkpoint()
        output = self.directory / 'build'
        command(['/bin/bash', ROOT / 'macos/packaging/build_local_gui.sh', self.config['sdk'], output,
                 self.identity['version'], self.identity['build']])
        fresh = output / 'new-xcode-macos/Build/Products/Release/Flash.app'
        stage = module('stage_split_payload')
        stage.stage_gui(fresh, self.app, Path(self.config['service']) / CORE, CORE_SHA256)
        module('embedded_helper_installer').stage(
            self.app, Path(self.config['service']), self.directory / 'helper-packages',
            Path(self.config['service_receipt']), self.config['service_receipt_sha256'],
            CORE_SHA256, SERVICE_BUILD)
        check_version(self.app, self.identity)
        fixed, _ = static_dependencies()
        entries = fixed.inventory(self.app, fixed.trusted_verifier())
        self.unchanged()
        request = {'schema': 'flash-local-gui-sign-v1', 'source': self.identity,
                   'app': str(self.app), 'run': str(self.directory), 'mode': 'gui-only',
                   'certificate_sha1': IDENTITY, 'core_sha256': CORE_SHA256,
                   'service': self.config['service'], 'service_receipt': self.config['service_receipt'],
                   'service_receipt_sha256': self.config['service_receipt_sha256'],
                   'unsigned_entries': entries, 'build_log_sha256': sha(output / 'build.log'),
                   'public_sources': {str(p.relative_to(ROOT)): sha(p) for p in sorted(
                       (ROOT / 'macos/packaging').glob('*.py'))}}
        save(self.request, request)
        self.state['request_sha256'] = sha(self.request)
        self.checkpoint()

    def verify(self):
        self.unchanged()
        request = pinned(self.request, self.state['request_sha256'])
        response = pinned(self.response, self.state['response_sha256'])
        require(set(response) == {'schema', 'request_sha256', 'gui_receipt', 'gui_receipt_sha256'} and
                response['schema'] == 1 and response['request_sha256'] == self.state['request_sha256'],
                'Signer response is not bound to this fresh build')
        path = Path(response['gui_receipt'])
        require(path.resolve() == path and path.is_relative_to(self.directory), 'Signing receipt must stay inside this run')
        receipt = pinned(path, response['gui_receipt_sha256'])
        require(receipt.get('before', {}).get('entries') == request['unsigned_entries'],
                'Signing receipt does not match fresh unsigned code')
        check_version(self.app, self.identity)
        module('embedded_helper_installer').verify(self.app)
        result = module('verify_split_service').verify(
            self.app, Path(self.config['service']), path, response['gui_receipt_sha256'],
            Path(self.config['service_receipt']), self.config['service_receipt_sha256'])
        require(result['delivery_mode'] == 'gui-only', 'Unexpected helper-update mode')
        return response

    def sign(self):
        require('request_sha256' in self.state, 'Build phase required')
        self.unchanged()
        request = pinned(self.request, self.state['request_sha256'])
        if 'response_sha256' not in self.state:
            require(not self.response.exists(), 'Unrecorded signer response: inspect failed run; do not silently retry')
            fixed, _ = static_dependencies()
            require(fixed.inventory(self.app, fixed.trusted_verifier()) == request['unsigned_entries'],
                    'Unsigned input changed before protected signing')
            require(sha(Path(self.config['signer'])) == self.config['signer_sha256'], 'Protected adapter changed')
            command([self.config['signer'], '--request', self.request, '--request-sha256',
                     self.state['request_sha256'], '--response', self.response])
            self.state['response_sha256'] = sha(self.response)
            self.verify()
            self.checkpoint()
        else:
            self.verify()

    def assets(self):
        manifest = pinned(self.directory / 'manifest.json', self.state['manifest_sha256'])
        expected = {'Flash-' + self.identity['version'] + '-macos-arm64.dmg', 'SHA256SUMS'}
        require(manifest.get('source') == self.identity and set(manifest.get('assets', {})) == expected,
                'Release manifest does not match exact public allowlist')
        public = self.directory / 'public'
        require(public.resolve() == public, 'Public asset directory must not be a symlink')
        require({p.name for p in public.iterdir()} == expected, 'Unexpected public output; never upload provenance')
        paths = []
        for name in sorted(expected):
            path = public / name
            require(sha(path) == manifest['assets'][name], 'Release asset changed: ' + name)
            paths.append(path)
        dmg = next(path for path in paths if path.suffix == '.dmg')
        require((public / 'SHA256SUMS').read_text() == sha(dmg) + '  ' + dmg.name + '\n', 'Invalid checksum manifest')
        return paths

    def package(self):
        response = self.verify()
        if 'manifest_sha256' in self.state:
            self.assets()
            return
        output = self.directory / 'packages'
        command(['/bin/bash', ROOT / 'macos/packaging/build_split_packages.sh', 'gui-only', self.app,
                 self.config['service'], output, response['gui_receipt'], response['gui_receipt_sha256'],
                 self.config['service_receipt'], self.config['service_receipt_sha256']])
        self.verify()
        dmg = output / 'Flash.dmg'
        command(['/usr/bin/hdiutil', 'verify', dmg])
        mount = Path(tempfile.mkdtemp(prefix='verify-dmg-', dir=self.directory))
        attached = False
        try:
            command(['/usr/bin/hdiutil', 'attach', '-readonly', '-nobrowse', '-noautoopen',
                     '-mountpoint', mount, dmg])
            attached = True
            module('stage_split_payload').verify_copy(self.app, mount / 'Flash.app', 'gui')
        finally:
            if attached:
                command(['/usr/bin/hdiutil', 'detach', mount])
            mount.rmdir()
        public = self.directory / 'public'
        public.mkdir(mode=0o700)
        asset = public / ('Flash-' + self.identity['version'] + '-macos-arm64.dmg')
        shutil.copyfile(dmg, asset)
        (public / 'SHA256SUMS').write_text(sha(asset) + '  ' + asset.name + '\n')
        manifest = {'schema': 1, 'source': self.identity, 'assets': {
            p.name: sha(p) for p in sorted(public.iterdir())}}
        save(self.directory / 'manifest.json', manifest)
        self.state['manifest_sha256'] = sha(self.directory / 'manifest.json')
        self.checkpoint()
        self.assets()

    def remote(self):
        self.verify()
        assets = self.assets()
        for ref in ('main', self.identity['tag']):
            result = json.loads(command(['gh', 'api', 'repos/' + REPOSITORY + '/commits/' + ref]))
            require(result['sha'] == self.identity['head'], 'Remote main/tag differs from frozen release source')
        return assets

    def view_draft(self):
        draft = json.loads(command(['gh', 'release', 'view', self.identity['tag'], '--repo', REPOSITORY,
                                    '--json', 'isDraft,tagName,targetCommitish,assets,body']))
        require(draft['isDraft'] and draft['tagName'] == self.identity['tag'] and
                draft['targetCommitish'] == self.identity['head'], 'Not this source-bound draft release')
        require(draft['body'] == (self.directory / 'release-notes.md').read_text(), 'Draft notes changed')
        assets = self.assets()
        require(len(draft['assets']) == len(assets) and {a['name'] for a in draft['assets']} ==
                {a.name for a in assets}, 'Remote draft asset allowlist differs')
        with tempfile.TemporaryDirectory(prefix='verify-assets-', dir=self.directory) as temporary:
            for path in assets:
                command(['gh', 'release', 'download', self.identity['tag'], '--repo', REPOSITORY,
                         '--pattern', path.name, '--dir', temporary])
                require(sha(Path(temporary) / path.name) == sha(path), 'Remote uploaded bytes differ')

    def draft(self):
        assets = self.remote()
        if 'notes_sha256' not in self.state:
            generated = json.loads(command(['gh', 'api', '--method', 'POST',
                'repos/' + REPOSITORY + '/releases/generate-notes', '-f', 'tag_name=' + self.identity['tag'],
                '-f', 'target_commitish=' + self.identity['head']]))
            body = notes(self.identity) + '\n## GitHub-generated changes\n\n' + generated['body'] + '\n'
            path = self.directory / 'release-notes.md'
            with path.open('x') as stream:
                stream.write(body)
            self.state['notes_sha256'] = sha(path)
            self.checkpoint()
        require(sha(self.directory / 'release-notes.md') == self.state['notes_sha256'], 'Release notes changed')
        if not self.state.get('draft_created'):
            command(['gh', 'release', 'create', self.identity['tag'], '--repo', REPOSITORY, '--verify-tag',
                     '--target', self.identity['head'], '--title', 'Flash ' + self.identity['version'],
                     '--draft', '--notes-file', self.directory / 'release-notes.md', *assets])
            self.state['draft_created'] = True
            self.checkpoint()
        self.view_draft()

    def publish(self):
        require(self.state.get('draft_created'), 'Create and verify the draft first')
        self.remote()
        require(sha(self.directory / 'release-notes.md') == self.state['notes_sha256'], 'Release notes changed')
        self.view_draft()
        command(['gh', 'release', 'edit', self.identity['tag'], '--repo', REPOSITORY, '--draft=false', '--latest'])
        self.state['published'] = True
        self.checkpoint()


def main(argv=None):
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('phase', choices=('check', 'build', 'sign', 'package', 'draft', 'publish', 'run'))
    parser.add_argument('--tag', required=True)
    parser.add_argument('--config', type=Path, default=ROOT / '.airbuild/local-release/config.json')
    parser.add_argument('--run', required=True, help='New/resumed run name, not a filesystem path')
    parser.add_argument('--publish', action='store_true', help='Publish after run; otherwise run stops at draft')
    args = parser.parse_args(argv)
    try:
        require(sys.platform == 'darwin' and os.getuid() != 0 and os.uname().machine == 'arm64', 'Release requires a non-root local Mac session')
        require(re.fullmatch('[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}', args.run), 'Invalid run name')
        require(not args.publish or args.phase == 'run', '--publish is only valid with run')
        identity = source_identity(args.tag)
        config = configuration(args.config)
        notes(identity)
        base = ROOT / '.airbuild/local-release/runs'
        require(base.resolve() == base, 'Release output ancestors must not be symlinks')
        with release_lock(base.parent):
            base.mkdir(mode=0o700, exist_ok=True)
            require((base / args.run).resolve() == base / args.run, 'Run must not be a symlink')
            if args.phase == 'check':
                check_service(config)
                print('Local source/config checks passed; no build, signing or network performed.')
                return 0
            release = Release(identity, config, base / args.run)
            phases = ('build', 'sign', 'package', 'draft') if args.phase == 'run' else (args.phase,)
            for phase in phases:
                getattr(release, phase)()
            if args.publish:
                release.publish()
            print('Completed ' + args.phase + '; local receipts: ' + str(release.directory))
    except (ValueError, OSError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print('Release stopped; partial local evidence/draft retained, no automatic retry: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
