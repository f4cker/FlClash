#!/usr/bin/env python3
"""Embed verified packages of an immutable released service before GUI signing."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import sys

PACKAGING = Path(__file__).resolve().parent
RESOURCE = Path('Contents/Resources/HelperInstaller')
PACKAGES = {operation: 'Flash-helper-' + operation + '.pkg' for operation in ('install', 'repair')}
CORE = 'Contents/MacOS/FlClashCore'


def module(name):
    spec = importlib.util.spec_from_file_location('_embedded_' + name, PACKAGING / (name + '.py'))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1, 'Expected single-link regular package resource')
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_service(gui, service, receipt, receipt_sha256, core_sha256, service_build):
    gate = module('verify_split_service')
    stage = module('stage_split_payload')
    info = plistlib.loads((service / 'Contents/Info.plist').read_bytes())
    require(str(info.get('CFBundleVersion')) == service_build, 'Released helper build changed')
    require(sha(service / CORE) == core_sha256 == sha(gui / CORE), 'Released service/Core changed')
    stage.check_layout(gui, 'gui')
    stage.compatible_pair(gui, service)
    return gate.verify_bundle(service, 'service', receipt, receipt_sha256,
                              module('sign_split_payload'), stage)


def verify(gui):
    directory = gui / RESOURCE
    require(directory.resolve(strict=True) == directory, 'Embedded installer directory must not contain links')
    require({path.name for path in directory.iterdir()} == {'manifest.json', *PACKAGES.values()},
            'Unexpected embedded installer resources')
    manifest_path = directory / 'manifest.json'
    sha(manifest_path)
    manifest = json.loads(manifest_path.read_text())
    require(isinstance(manifest, dict) and manifest.keys() == {'schema', 'packages'} and
            type(manifest['schema']) is int and manifest['schema'] == 1 and
            isinstance(manifest['packages'], dict) and manifest['packages'].keys() == PACKAGES.keys(),
            'Unsupported embedded installer manifest')
    for operation, name in PACKAGES.items():
        entry = manifest['packages'][operation]
        require(entry == {'file': name, 'sha256': sha(directory / name)},
                'Embedded installer package differs from manifest')
    return manifest


def stage(gui, service, output, receipt, receipt_sha256, core_sha256, service_build):
    require(not (gui / 'Contents/_CodeSignature').exists(), 'Embed installers before GUI signing')
    destination = gui / RESOURCE
    require(not destination.exists() and not destination.is_symlink(), 'Embedded installer resources already exist')
    resources = destination.parent
    require(resources.resolve() == resources, 'GUI resources must not contain links')
    require(not output.exists() and not output.is_symlink(), 'Package output must be new')
    verify_service(gui, service, receipt, receipt_sha256, core_sha256, service_build)
    subprocess.run(['/bin/bash', str(PACKAGING / 'build_split_packages.sh'), 'embedded-released-service',
                    str(gui), str(service), str(output), str(receipt), receipt_sha256,
                    core_sha256, service_build], check=True,
                   env={'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'})
    verifier = module('stage_split_payload')
    packages = {}
    for operation, name in PACKAGES.items():
        verifier.verify_expanded(service, output / (operation + '-expanded'), operation)
        packages[operation] = {'file': name, 'sha256': sha(output / name)}
    verify_service(gui, service, receipt, receipt_sha256, core_sha256, service_build)
    resources.mkdir(exist_ok=True, mode=0o755)
    destination.mkdir(mode=0o755)
    resources.chmod(0o755)
    destination.chmod(0o755)
    for name in PACKAGES.values():
        shutil.copyfile(output / name, destination / name)
        (destination / name).chmod(0o644)
    manifest = {'schema': 1, 'packages': packages}
    with (destination / 'manifest.json').open('x') as stream:
        json.dump(manifest, stream, sort_keys=True, indent=2)
        stream.write('\n')
    (destination / 'manifest.json').chmod(0o644)
    require(verify(gui) == manifest, 'Embedded installer copy changed')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('command', choices=('verify-service',))
    for name in ('gui', 'service', 'receipt'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('receipt-sha256', 'core-sha256', 'service-build'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        verify_service(args.gui, args.service, args.receipt, args.receipt_sha256,
                       args.core_sha256, args.service_build)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f'Embedded released service verification failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
