#!/usr/bin/env python3
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ASSETS = {
    'package:objective_c/objective_c.dylib': 'objective_c',
    'package:rust_api/src/rust/frb_generated.io.dart': 'rust_api',
    'package:sqlite3/src/ffi/libsqlite3.g.dart': 'sqlite3',
}
MACH_MAGIC = {bytes.fromhex(value) for value in (
    'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
    'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca',
)}
SYSTEM = ('/usr/lib/', '/System/Library/')
BAD_RPATH = '/usr/local/lib/.'
APP_FRAMEWORK_BINARY = 'Contents/Frameworks/App.framework/Versions/A/App'
REDUNDANT_APP_RPATHS = ('@executable_path/Frameworks', '@loader_path/Frameworks')
PLATFORMS = {'arm64': 'macos_arm64', 'x86_64': 'macos_x64'}
FIXED_EXECUTABLES = (
    'Contents/MacOS/FlClashCore',
    'Contents/Library/HelperTools/FlashHelper',
    'Contents/Library/HelperTools/FlashMaintenance',
)


def inside(path, root):
    canonical = path.resolve(strict=True)
    if not canonical.is_relative_to(root.resolve(strict=True)):
        raise ValueError(f'External load path: {path}')
    return canonical


def validate_links(app):
    frameworks = app / 'Contents/Frameworks'
    for directory, names, files in os.walk(app, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            if not path.is_symlink():
                continue
            relative = path.relative_to(frameworks).parts
            if len(relative) < 2 or not relative[0].endswith('.framework'):
                raise ValueError(f'Unexpected link: {path}')
            entry = '/'.join(relative[1:])
            target = os.readlink(path)
            binary = relative[0][:-len('.framework')]
            permitted = (
                entry == 'Versions/Current' and '/' not in target and target not in ('.', '..')
            ) or (
                entry in ('Resources', 'Headers', 'Modules', binary)
                and target == f'Versions/Current/{entry}'
            )
            if not permitted or target.startswith('/'):
                raise ValueError(f'Unsafe framework link: {path}')
            inside(path, frameworks / relative[0])


def rewrite_manifest(data, app):
    if set(data) != {'format-version', 'native-assets'} or data['format-version'] != [1, 0, 0]:
        raise ValueError('Unknown native asset manifest schema')
    platforms = data['native-assets']
    if not platforms or not set(platforms) <= {'macos_arm64', 'macos_x64'}:
        raise ValueError('Unexpected native asset platforms')
    for assets in platforms.values():
        if set(assets) != set(ASSETS):
            raise ValueError('Unknown or missing native assets')
        for key, name in ASSETS.items():
            old = ['absolute', f'{name}.framework/{name}']
            anchored = ['absolute', f'@executable_path/../Frameworks/{name}.framework/{name}']
            if assets[key] not in (old, anchored):
                raise ValueError(f'Unexpected native asset load type/path: {key}')
            framework = app / f'Contents/Frameworks/{name}.framework'
            binary = inside(framework / name, framework)
            if not binary.is_file():
                raise ValueError(f'Missing native asset: {key}')
            assets[key] = anchored
    return data


def expanded(path, loader, executable):
    if path.startswith('@loader_path/'):
        return loader.parent / path[len('@loader_path/'):]
    if path.startswith('@executable_path/'):
        return executable.parent / path[len('@executable_path/'):]
    raise ValueError(f'Unanchored loader path: {path}')


def check_rpath(value, loader, executable, app):
    if value.startswith(SYSTEM):
        if '..' in Path(value).parts:
            raise ValueError(f'Noncanonical system rpath: {value}')
        return None
    path = expanded(value, loader, executable)
    canonical = inside(path, app)
    if not canonical.is_dir():
        raise ValueError(f'Rpath is not a directory: {value}')
    return canonical


def check_dependency(value, loader, executable, app, rpaths, architecture=None, commands=None):
    if value.startswith(SYSTEM) and '..' not in Path(value).parts:
        return
    if value.startswith('@rpath/'):
        relative = value[len('@rpath/'):]
        if '..' in Path(relative).parts:
            raise ValueError(f'Escaping dependency: {value}')
        candidates = [path / relative for path in rpaths if path is not None]
        canonical = next((inside(path, app) for path in candidates if path.exists()), None)
        if canonical is None:
            raise ValueError(f'Unresolved bundled dependency: {value}')
    else:
        canonical = inside(expanded(value, loader, executable), app)
    if not canonical.is_file():
        raise ValueError(f'Dependency is not a file: {value}')
    required = {architecture} if architecture is not None else set(load_commands(loader))
    slices = commands.get(canonical) if commands is not None else None
    if slices is None:
        slices = load_commands(canonical)
    if not required <= set(slices):
        raise ValueError(f'Mismatched dependency architecture coverage: {value}')


def load_commands(binary):
    output = subprocess.check_output(['/usr/bin/otool', '-arch', 'all', '-l', str(binary)], text=True)
    slices = []
    slice_names = []
    rpaths, dependencies = [], []
    command = None
    for raw in output.splitlines():
        line = raw.strip()
        if line.startswith(str(binary)) and line.endswith(':'):
            if slices:
                rpaths, dependencies = [], []
            match = re.search(r'\(architecture (arm64|x86_64)\):$', line)
            slice_names.append(match.group(1) if match else None)
            slices.append((rpaths, dependencies))
            command = None
        elif line.startswith('cmd '):
            command = line[4:]
        elif command == 'LC_RPATH' and line.startswith('path '):
            rpaths.append(line[5:].rsplit(' (offset ', 1)[0])
        elif command in {'LC_LOAD_DYLIB', 'LC_LOAD_WEAK_DYLIB', 'LC_REEXPORT_DYLIB', 'LC_LAZY_LOAD_DYLIB', 'LC_LOAD_UPWARD_DYLIB'} and line.startswith('name '):
            dependencies.append(line[5:].rsplit(' (offset ', 1)[0])
        elif command in {'LC_DYLD_ENVIRONMENT', 'LC_LOAD_DYLINKER'} and line.startswith('name '):
            value = line[5:].rsplit(' (offset ', 1)[0]
            if command == 'LC_DYLD_ENVIRONMENT' or value != '/usr/lib/dyld':
                raise ValueError(f'Unsafe dynamic loader command in {binary}')
    architectures = subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).split()
    if not architectures or not set(architectures) <= {'arm64', 'x86_64'} or len(slices) != len(architectures):
        raise ValueError(f'Uninspected Mach-O slices: {binary}')
    if len(slices) == 1 and slice_names == [None]:
        slice_names = architectures
    if set(slice_names) != set(architectures) or len(set(slice_names)) != len(slices):
        raise ValueError(f'Ambiguous Mach-O architecture headers: {binary}')
    return dict(zip(slice_names, slices))


def normalize_app_rpaths(binary, slices, gui, app):
    if binary != app / APP_FRAMEWORK_BINARY:
        return slices
    removals = []
    for value in REDUNDANT_APP_RPATHS:
        counts = [paths.count(value) for paths, _ in slices.values()]
        if not any(counts):
            continue
        target = expanded(value, binary, gui)
        inside(target.parent, app)
        try:
            target.lstat()
        except FileNotFoundError:
            if any(count != 1 for count in counts):
                raise ValueError(f'Inconsistent redundant App rpath slices: {value}')
            removals.append(value)
        else:
            check_rpath(value, binary, gui, app)
    if not removals:
        return slices
    arguments = ['/usr/bin/install_name_tool']
    for value in removals:
        arguments += ['-delete_rpath', value]
    subprocess.run(arguments + [str(binary)], check=True)
    updated = load_commands(binary)
    if set(updated) != set(slices) or any(
        value in paths for paths, _ in updated.values() for value in removals
    ):
        raise ValueError(f'Incomplete redundant App rpath normalization: {binary}')
    return updated


def stage(source, destination):
    source = source.resolve(strict=True)
    if destination.exists() or destination.is_symlink() or destination.resolve().is_relative_to(source):
        raise ValueError('Staging requires a new directory outside the original artifact')
    shutil.copytree(source, destination, symlinks=True)
    audit(destination, mutate=True)


def audit(destination, mutate=False):
    app = destination.resolve(strict=True)
    validate_links(app)
    manifests = list(app.glob('Contents/Frameworks/App.framework/Versions/*/Resources/flutter_assets/NativeAssetsManifest.json'))
    manifests = list({path.resolve(strict=True) for path in manifests})
    if len(manifests) != 1:
        raise ValueError('Expected exactly one sealed native asset manifest')
    manifest = manifests[0]
    original = json.loads(manifest.read_text())
    patched = rewrite_manifest(json.loads(manifest.read_text()), app)
    if mutate:
        manifest.write_text(json.dumps(patched))
    elif original != patched:
        raise ValueError('Sealed manifest still contains unanchored native assets')
    binaries = []
    for directory, _, files in os.walk(app, followlinks=False):
        for name in files:
            path = Path(directory) / name
            if path.is_symlink():
                continue
            with path.open('rb') as file:
                if file.read(4) in MACH_MAGIC:
                    binaries.append(path)
    gui = app / 'Contents/MacOS/Flash'
    if gui not in binaries:
        raise ValueError('Missing fixed GUI executable')
    commands = {}
    for binary in binaries:
        slices = load_commands(binary)
        if any(BAD_RPATH in rpaths for rpaths, _ in slices.values()):
            if not mutate:
                raise ValueError('External rpath remains in sealed artifact')
            subprocess.run(['/usr/bin/install_name_tool', '-delete_rpath', BAD_RPATH, str(binary)], check=True)
            slices = load_commands(binary)
        if mutate:
            slices = normalize_app_rpaths(binary, slices, gui, app)
        commands[binary] = slices
    required = set(commands[gui])
    platforms = {PLATFORMS[architecture] for architecture in required}
    if set(patched['native-assets']) != platforms:
        raise ValueError('Native asset platforms do not match GUI architectures')
    fixed = {app / relative for relative in FIXED_EXECUTABLES}
    native_assets = {
        inside(app / f'Contents/Frameworks/{name}.framework/{name}', app)
        for name in ASSETS.values()
    }
    for binary in fixed | native_assets:
        if binary not in commands or set(commands[binary]) != required:
            raise ValueError(f'Mismatched fixed payload architecture coverage: {binary}')
    for binary, slices in commands.items():
        standalone = binary in fixed
        executable = binary if standalone else gui
        for architecture, (paths, dependencies) in slices.items():
            rpaths = [check_rpath(path, binary, executable, app) for path in paths]
            if not standalone:
                gui_slices = commands[gui]
                if architecture not in gui_slices:
                    raise ValueError(f'Mismatched Mach-O architecture coverage: {binary}')
                rpaths += [check_rpath(path, gui, gui, app) for path in gui_slices[architecture][0]]
            for dependency in dependencies:
                check_dependency(dependency, binary, executable, app, rpaths, architecture, commands)
    print('Load-boundary audit passed; this is not signed-artifact runtime acceptance.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('usage: stage_managed_payload.py ORIGINAL_APP NEW_STAGED_APP')
    if sys.argv[1] == '--verify':
        audit(Path(sys.argv[2]))
    else:
        stage(Path(sys.argv[1]), Path(sys.argv[2]))
