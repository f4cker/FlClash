import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import types
import unittest
from unittest.mock import Mock, patch

PACKAGING = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


EMBED = load('embedded_installer', PACKAGING / 'embedded_helper_installer.py')
PAYLOAD = load('payload_fixtures', Path(__file__).with_name('test_split_payload.py'))


class EmbeddedInstallerTests(unittest.TestCase):
    def setUp(self):
        self.fixture = PAYLOAD.SplitPayloadTests('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.stage_pair()
        self.root, self.gui, self.service = self.fixture.root, self.fixture.gui, self.fixture.service
        self.output = self.root / 'helper-packages'
        self.receipt = self.root / 'service-receipt.json'
        self.receipt.write_text('{}')
        self.core_sha256 = EMBED.sha(self.service / EMBED.CORE)
        self.receipt_sha256 = EMBED.sha(self.receipt)
        self.gate = types.SimpleNamespace(verify_bundle=Mock(return_value={'phase': 'service'}))
        self.signer = object()
        self.modules = {'verify_split_service': self.gate, 'stage_split_payload': PAYLOAD.SPLIT,
                        'sign_split_payload': self.signer}
        patch.object(EMBED, 'module', side_effect=self.modules.__getitem__).start()
        self.addCleanup(patch.stopall)

    def package(self, argv, **kwargs):
        self.assertEqual(argv, ['/bin/bash', str(PACKAGING / 'build_split_packages.sh'),
                         'embedded-released-service', str(self.gui), str(self.service), str(self.output),
                         str(self.receipt), self.receipt_sha256, self.core_sha256, '42'])
        self.assertTrue(kwargs['check'])
        self.output.mkdir()
        for operation, name in EMBED.PACKAGES.items():
            (self.output / name).write_bytes(('synthetic-package-' + operation).encode())
            expanded = self.output / (operation + '-expanded')
            (expanded / 'Scripts').mkdir(parents=True)
            info = ('<pkg-info identifier="com.layoute.flash.managed.' + operation + '" install-location="/">'
                    '<scripts><preinstall file="./preinstall"/><postinstall file="./postinstall"/></scripts></pkg-info>')
            (expanded / 'PackageInfo').write_text(info)
            for source in (PACKAGING / 'installer' / operation).iterdir():
                shutil.copyfile(source, expanded / 'Scripts' / source.name)
            shutil.copyfile(self.service / PAYLOAD.SPLIT.MAINTENANCE, expanded / 'Scripts/FlashMaintenance')
            for source in (expanded / 'Scripts').iterdir():
                source.chmod(0o755)
            target = expanded / 'Payload/Library/Application Support/Flash/.incoming/Flash.app'
            target.parent.mkdir(parents=True)
            shutil.copytree(self.service, target)
        return subprocess.CompletedProcess(argv, 0)

    def stage(self):
        return EMBED.stage(self.gui, self.service, self.output, self.receipt, self.receipt_sha256,
                           self.core_sha256, '42')

    def test_embeds_only_install_repair_and_manifest_before_signing(self):
        before = PAYLOAD.SPLIT.inventory(self.service)
        previous_umask = os.umask(0o077)
        try:
            with patch.object(EMBED.subprocess, 'run', side_effect=self.package) as run:
                manifest = self.stage()
        finally:
            os.umask(previous_umask)
        run.assert_called_once()
        self.assertEqual(manifest, {'schema': 1, 'packages': {
            operation: {'file': name, 'sha256': EMBED.sha(self.output / name)}
            for operation, name in EMBED.PACKAGES.items()}})
        self.assertEqual(EMBED.verify(self.gui), manifest)
        resources = self.gui / EMBED.RESOURCE
        self.assertEqual(resources.stat().st_mode & 0o777, 0o755)
        self.assertEqual(resources.parent.stat().st_mode & 0o777, 0o755)
        for path in resources.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o644)
        self.assertEqual(PAYLOAD.SPLIT.inventory(self.service), before)
        self.assertEqual(self.gate.verify_bundle.call_count, 2)
        self.gate.verify_bundle.assert_called_with(self.service, 'service', self.receipt,
                                                  self.receipt_sha256, self.signer, PAYLOAD.SPLIT)
        self.assertFalse((self.gui / 'Contents/Library').exists())
        copied = self.root / 'copy/Flash.app'
        shutil.copytree(self.gui, copied, symlinks=True)
        PAYLOAD.SPLIT.verify_copy(self.gui, copied, 'gui')
        (copied / EMBED.RESOURCE / EMBED.PACKAGES['install']).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Copied payload differs'):
            PAYLOAD.SPLIT.verify_copy(self.gui, copied, 'gui')

    def test_released_service_gate_rejects_wrong_build_or_core_before_packaging(self):
        for core, build in [('0' * 64, '42'), (self.core_sha256, '2026111403')]:
            with self.subTest(core=core, build=build), self.assertRaisesRegex(ValueError, 'changed'):
                EMBED.verify_service(self.gui, self.service, self.receipt, self.receipt_sha256, core, build)
        self.gate.verify_bundle.assert_not_called()
        self.gate.verify_bundle.side_effect = ValueError('invalid released signing receipt')
        with patch.object(EMBED.subprocess, 'run') as run, self.assertRaisesRegex(ValueError, 'receipt'):
            self.stage()
        run.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_unsigned_gui_core_must_be_exact_released_core(self):
        (self.gui / EMBED.CORE).write_bytes(b'other core')
        with self.assertRaisesRegex(ValueError, 'service/Core changed'):
            self.stage()
        self.gate.verify_bundle.assert_not_called()

    def test_package_failure_never_creates_embedded_resources(self):
        with patch.object(EMBED.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'pkgbuild')):
            with self.assertRaises(subprocess.CalledProcessError):
                self.stage()
        self.assertFalse((self.gui / EMBED.RESOURCE).exists())

    def test_expanded_scripts_maintenance_payload_and_modes_are_exact(self):
        for mutation in ('script', 'maintenance', 'payload', 'mode', 'extra-script'):
            def command(argv, **kwargs):
                self.package(argv, **kwargs)
                expanded = self.output / 'install-expanded'
                if mutation == 'script':
                    (expanded / 'Scripts/preinstall').write_bytes(b'changed transaction')
                elif mutation == 'maintenance':
                    (expanded / 'Scripts/FlashMaintenance').write_bytes(b'changed signed maintenance')
                elif mutation == 'payload':
                    (expanded / 'Payload/extra').write_bytes(b'extra payload')
                elif mutation == 'mode':
                    (expanded / 'Scripts/postinstall').chmod(0o700)
                else:
                    (expanded / 'Scripts/extra').write_bytes(b'extra script')
            with self.subTest(mutation=mutation), patch.object(EMBED.subprocess, 'run', side_effect=command):
                with self.assertRaises(ValueError):
                    self.stage()
            self.assertFalse((self.gui / EMBED.RESOURCE).exists())
            shutil.rmtree(self.output)

    def test_changed_service_after_packaging_stops_before_embedding(self):
        self.gate.verify_bundle.side_effect = [{'phase': 'service'}, ValueError('service changed')]
        with patch.object(EMBED.subprocess, 'run', side_effect=self.package), self.assertRaisesRegex(ValueError, 'changed'):
            self.stage()
        self.assertFalse((self.gui / EMBED.RESOURCE).exists())

    def test_signed_or_preexisting_outputs_are_never_overwritten(self):
        seal = self.gui / 'Contents/_CodeSignature'
        seal.mkdir()
        with self.assertRaisesRegex(ValueError, 'before GUI signing'):
            self.stage()
        seal.rmdir()
        self.output.mkdir()
        with self.assertRaisesRegex(ValueError, 'output must be new'):
            self.stage()
        self.output.rmdir()
        resources = self.gui / 'Contents/Resources'
        resources.mkdir(exist_ok=True)
        (resources / 'HelperInstaller').mkdir()
        with self.assertRaisesRegex(ValueError, 'already exist'):
            self.stage()
        self.gate.verify_bundle.assert_not_called()

    def test_manifest_rejects_changed_hash_paths_schema_and_extra_resources(self):
        with patch.object(EMBED.subprocess, 'run', side_effect=self.package):
            manifest = self.stage()
        directory = self.gui / EMBED.RESOURCE
        manifest_path = directory / 'manifest.json'
        for mutation in ('hash', 'path', 'schema', 'missing', 'extra'):
            data = copy.deepcopy(manifest)
            if mutation == 'hash':
                data['packages']['install']['sha256'] = '0' * 64
            elif mutation == 'path':
                data['packages']['install']['file'] = '../Flash-helper-install.pkg'
            elif mutation == 'schema':
                data['schema'] = True
            elif mutation == 'missing':
                del data['packages']['repair']
            else:
                data['packages']['disable'] = data['packages']['install']
            manifest_path.write_text(json.dumps(data))
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                EMBED.verify(self.gui)
        manifest_path.write_text(json.dumps(manifest))
        extra = directory / 'Flash-helper-remove.pkg'
        extra.write_bytes(b'extra')
        with self.assertRaisesRegex(ValueError, 'Unexpected embedded'):
            EMBED.verify(self.gui)
        extra.unlink()
        package = directory / EMBED.PACKAGES['install']
        package.unlink()
        package.symlink_to(self.output / package.name)
        with self.assertRaisesRegex(ValueError, 'regular package'):
            EMBED.verify(self.gui)

    def test_embedded_shell_route_reuses_package_loop_without_compile_or_dmg(self):
        source = (PACKAGING / 'build_split_packages.sh').read_text()
        self.assertIn('"$mode" != embedded-released-service', source)
        self.assertIn('operations=(install repair)', source)
        self.assertIn('if [[ "$mode" == helper-update ]]; then\n  operations+=(disable remove)', source)
        embedded_gate = source.split('verify_evidence() {')[1].split('  else')[0]
        self.assertIn('embedded_helper_installer.py', embedded_gate)
        self.assertNotIn('compile', embedded_gate)
        self.assertNotIn('gui-receipt', embedded_gate)
        self.assertEqual(source.count('/usr/bin/pkgbuild --root'), 1)
        self.assertIn('split verify-expanded', source)
        self.assertIn('raw_package verify "$final_raw"', source)
        self.assertNotIn('codesign --sign', source)


if __name__ == '__main__':
    unittest.main()
