import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

PACKAGING = Path(__file__).parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, PACKAGING / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


N = load('package_normalization', 'normalize_package_info.py')
Q = load('package_qualification', 'qualify_native_loads.py')


class PackageNormalizationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        forbidden = patch.object(subprocess, 'Popen', side_effect=AssertionError('No real subprocesses'))
        forbidden.start()
        self.addCleanup(forbidden.stop)

    def info(self, operation='install'):
        return (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<pkg-info format-version="2" identifier="com.layoute.flash.managed.' + operation + '" '
            'install-location="/" auth="root">\n'
            '  <payload numberOfFiles="565" installKBytes="154797"/>\n'
            '  <relocate/>\n  <scripts>\n'
            '    <preinstall file="./preinstall" timeout="600"/>\n'
            '    <postinstall timeout="600" file="./postinstall"/>\n'
            '  </scripts>\n</pkg-info>\n'
        ).encode()

    def raw(self, operation='install'):
        raw = self.root / (operation + '-raw')
        raw.mkdir()
        (raw / 'PackageInfo').write_bytes(self.info(operation))
        (raw / 'Scripts').write_bytes(b'\x1f\x8braw-scripts-archive\x00')
        (raw / 'Bom').write_bytes(b'BOMStore\x00fixture')
        if operation in ('install', 'repair'):
            (raw / 'Payload').write_bytes(b'\x1f\x8braw-signed-payload-archive\x00')
        return raw

    def test_only_validated_timeout_byte_ranges_are_removed(self):
        for operation in N.OPERATIONS:
            data = self.info(operation)
            result = N.normalize_info(data, operation)
            self.assertEqual(result, data.replace(b'timeout="600"', b''))
            self.assertEqual(N.normalize_info(result, operation), result)
        data = self.info().replace(b'file="./preinstall" timeout="600"',
                                   b'timeout="600"\n\t file="./preinstall"')
        self.assertEqual(N.normalize_info(data, 'install'), data.replace(b'timeout="600"', b''))

        data = self.info().replace(b'<relocate/>', '<!-- café timeout="600" -->\n  <relocate/>'.encode())
        expected = data.replace(b' timeout="600"/>', b' />').replace(
            b'<postinstall timeout="600" ', b'<postinstall  ')
        self.assertEqual(N.normalize_info(data, 'install'), expected)

    def test_invalid_attributes_timeouts_paths_identity_and_declarations_fail_closed(self):
        data = self.info()
        mutations = (
            (b'timeout="600"', b'timeout="599"'),
            (b'timeout="600"', b'timeout="0600"'),
            (b'timeout="600"', b'timeout="600.0"'),
            (b'timeout="600"', b"timeout='600'"),
            (b'timeout="600"', b'timeout="&#54;00"'),
            (b'timeout="600"', b'timeout="600" component="other"'),
            (b'timeout="600"', b'timeout="600" timeout="600"'),
            (b'file="./preinstall"', b'file="/tmp/preinstall"'),
            (b'file="./preinstall"', b'file="../preinstall"'),
            (b'file="./preinstall"', b'file="./postinstall"'),
            (b'file="./preinstall"', b''),
            (b'managed.install', b'managed.repair'),
            (b'install-location="/"', b'install-location="/tmp"'),
            (b'install-location="/"', b''),
            (b'<pkg-info ', b'<other-info '),
            (b'<scripts>', b'<scripts timeout="600">'),
            (b'<preinstall file="./preinstall" timeout="600"/>', b''),
            (b'<postinstall timeout="600" file="./postinstall"/>', b''),
            (b'</scripts>', b'<other file="./other"/></scripts>'),
            (b'</scripts>', b'<preinstall file="./preinstall"/></scripts>'),
            (b'</scripts>', b'<scripts/></scripts>'),
            (b'</scripts>', b'</scripts><scripts/>'),
            (b'<relocate/>', b'<nested><scripts/></nested>'),
            (b'<relocate/>', b'<nested><preinstall file="./preinstall"/></nested>'),
            (b'<relocate/>', b'<other timeout="600"/>'),
            (b'<scripts>', b'<scripts>unexpected text'),
            (b'<preinstall file="./preinstall" timeout="600"/>',
             b'<preinstall file="./preinstall" timeout="600">text</preinstall>'),
            (b'<preinstall file="./preinstall" timeout="600"/>',
             b'<preinstall file="./preinstall" timeout="600"><nested/></preinstall>'),
            (b'<scripts>', b'<nested><scripts>'),
            (b'</scripts>', b'</scripts></nested>'),
        )
        for old, new in mutations:
            with self.subTest(old=old, new=new), self.assertRaises(ValueError):
                N.normalize_info(data.replace(old, new), 'install')
        for invalid in (b'', b'<pkg-info>', b'<!DOCTYPE pkg-info []>' + data):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                N.normalize_info(invalid, 'install')
        with self.assertRaises(ValueError):
            N.normalize_info(data, 'unknown')

    def test_raw_archives_preserved_and_final_raw_expansion_matches_exact_metadata(self):
        for operation in N.OPERATIONS:
            raw = self.raw(operation)
            before = {path.name: path.read_bytes() for path in raw.iterdir()}
            snapshot = self.root / (operation + '-members.json')
            N.normalize_raw(raw, snapshot, operation)
            self.assertEqual((raw / 'PackageInfo').read_bytes(),
                             before.pop('PackageInfo').replace(b'timeout="600"', b''))
            for name, original in before.items():
                self.assertEqual((raw / name).read_bytes(), original)
            final_raw = self.root / (operation + '-final-raw')
            shutil.copytree(raw, final_raw)
            N.verify_raw(raw, snapshot, operation)
            N.verify_raw(final_raw, snapshot, operation)
            with self.assertRaises(FileExistsError):
                N.normalize_raw(raw, snapshot, operation)

    def test_member_mutation_addition_removal_and_wrong_operation_are_rejected(self):
        raw = self.raw()
        snapshot = self.root / 'members.json'
        N.normalize_raw(raw, snapshot, 'install')
        for member in ('Payload', 'Scripts', 'Bom', 'PackageInfo'):
            original = (raw / member).read_bytes()
            (raw / member).write_bytes(original + b'changed')
            with self.subTest(member=member), self.assertRaises(ValueError):
                N.verify_raw(raw, snapshot, 'install')
            (raw / member).unlink()
            with self.subTest(missing=member), self.assertRaises(ValueError):
                N.verify_raw(raw, snapshot, 'install')
            (raw / member).write_bytes(original)
        (raw / 'extra').write_bytes(b'extra')
        with self.assertRaises(ValueError):
            N.verify_raw(raw, snapshot, 'install')
        (raw / 'extra').unlink()
        with self.assertRaises(ValueError):
            N.verify_raw(raw, snapshot, 'repair')
        original = (raw / 'Payload').read_bytes()
        (raw / 'Payload').unlink()
        (raw / 'Payload').symlink_to(raw / 'Scripts')
        with self.assertRaises(ValueError):
            N.verify_raw(raw, snapshot, 'install')
        (raw / 'Payload').unlink()
        (raw / 'Payload').mkdir()
        with self.assertRaises(ValueError):
            N.verify_raw(raw, snapshot, 'install')
        (raw / 'Payload').rmdir()
        (raw / 'Payload').write_bytes(original)
        N.verify_raw(raw, snapshot, 'install')

    def test_invalid_raw_input_is_rejected_before_metadata_changes(self):
        for operation in N.OPERATIONS:
            raw = self.raw(operation)
            original = (raw / 'PackageInfo').read_bytes()
            if operation in ('install', 'repair'):
                (raw / 'Bom').unlink()
            else:
                (raw / 'Payload').write_bytes(b'unexpected')
            with self.subTest(operation=operation), self.assertRaises(ValueError):
                N.normalize_raw(raw, self.root / (operation + '-members.json'), operation)
            self.assertEqual((raw / 'PackageInfo').read_bytes(), original)

    def test_only_expected_component_member_sets_are_accepted(self):
        for operation in N.OPERATIONS:
            raw = self.raw(operation)
            snapshot = self.root / (operation + '-members.json')
            original = (raw / 'PackageInfo').read_bytes()
            for extra in ('Distribution', 'ExtraArchive'):
                (raw / extra).write_bytes(b'unreviewed member')
                with self.subTest(operation=operation, extra=extra), self.assertRaises(ValueError):
                    N.normalize_raw(raw, snapshot, operation)
                self.assertFalse(snapshot.exists())
                self.assertEqual((raw / 'PackageInfo').read_bytes(), original)
                (raw / extra).unlink()
            if operation in ('disable', 'remove'):
                (raw / 'Bom').unlink()
            N.normalize_raw(raw, snapshot, operation)
            N.verify_raw(raw, snapshot, operation)

    def test_nonregular_original_scripts_rejected_without_metadata_or_snapshot_writes(self):
        raw = self.raw()
        snapshot = self.root / 'members.json'
        original = (raw / 'PackageInfo').read_bytes()
        scripts = raw / 'Scripts'
        scripts.unlink()
        for kind in ('symlink', 'directory', 'fifo'):
            if kind == 'symlink':
                scripts.symlink_to(raw / 'Bom')
            elif kind == 'directory':
                scripts.mkdir()
            else:
                os.mkfifo(scripts)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                N.normalize_raw(raw, snapshot, 'install')
            self.assertFalse(snapshot.exists())
            self.assertEqual((raw / 'PackageInfo').read_bytes(), original)
            if kind == 'directory':
                scripts.rmdir()
            else:
                scripts.unlink()

    def test_disable_remove_postinstall_is_exact_guarded_noop(self):
        guard = (PACKAGING / 'installer/install/postinstall').read_bytes().splitlines(keepends=True)[:3]
        for operation in ('disable', 'remove'):
            self.assertEqual((PACKAGING / 'installer' / operation / 'postinstall').read_bytes(),
                             b''.join(guard) + b'exit 0\n')

    def test_normalized_metadata_and_actual_hooks_pass_unchanged_expanded_qualifier(self):
        maintenance = b'qualified-signed-maintenance-fixture'
        expected = {'inventory': {'Contents/Library/HelperTools/FlashMaintenance':
                                 {'sha256': hashlib.sha256(maintenance).hexdigest()}}}
        signer = types.SimpleNamespace(read_regular=N.read_regular,
                                       trusted_verifier=lambda: None,
                                       inventory=lambda app, verifier: expected['inventory'])
        for operation in N.OPERATIONS:
            expanded = self.root / (operation + '-expanded')
            expanded.mkdir()
            (expanded / 'PackageInfo').write_bytes(N.normalize_info(self.info(operation), operation))
            shutil.copytree(PACKAGING / 'installer' / operation, expanded / 'Scripts')
            (expanded / 'Scripts/FlashMaintenance').write_bytes(maintenance)
            if operation in ('install', 'repair'):
                (expanded / 'Payload/Library/Application Support/Flash/.incoming/Flash.app').mkdir(parents=True)
            Q.check_expanded(expanded, operation, expected, signer)

    def test_builder_rechecks_raw_members_and_qualifies_final_not_intermediate_package(self):
        source = (PACKAGING / 'build_managed_packages.sh').read_text()
        ordered = (
            'built="$output/$operation-built.pkg"',
            'package="$output/Flash-$operation.pkg"',
            '/usr/bin/xar -xf "$built" -C "$raw"',
            'raw_package normalize "$raw" "$snapshot" "$operation"',
            'raw_package verify "$raw" "$snapshot" "$operation"',
            '(cd "$raw" && /usr/bin/xar -cf "$package" --compression=none *)',
            'raw_package verify "$raw" "$snapshot" "$operation"',
            '/usr/bin/xar -xf "$package" -C "$final_raw"',
            'raw_package verify "$final_raw" "$snapshot" "$operation"',
            '/usr/sbin/pkgutil --expand-full "$package" "$expanded"',
            'verify_evidence --verify-expanded-package "$expanded" --package-operation "$operation"',
        )
        cursor = 0
        for command in ordered:
            cursor = source.index(command, cursor) + len(command)
        self.assertNotIn('--flatten', source)
        self.assertNotIn('/usr/sbin/pkgutil --expand ', source)
        self.assertEqual(source.count('/usr/sbin/pkgutil --expand-full'), 1)
        self.assertIn('for operation in install repair disable remove; do', source)
        self.assertIn('"$source_dir/normalize_package_info.py" "$@"', source)
        self.assertIn('"$source_dir/qualify_native_loads.py" --verify-evidence', source)


if __name__ == '__main__':
    unittest.main()
