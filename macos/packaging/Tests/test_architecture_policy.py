import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'architecture_policy', Path(__file__).parents[1] / 'stage_managed_payload.py',
)
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class ArchitecturePolicyTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.app = Path(directory.name).resolve() / 'Flash.app'
        self.gui = self.app / 'Contents/MacOS/Flash'
        self.architectures = {}
        self.dependencies = {}
        self.manifest = self.app / (
            'Contents/Frameworks/App.framework/Versions/A/Resources/'
            'flutter_assets/NativeAssetsManifest.json'
        )
        self.manifest.parent.mkdir(parents=True)
        self.make_payload(('arm64', 'x86_64'))
        self.output = patch.object(POLICY.subprocess, 'check_output', side_effect=self.inspect)
        self.output.start()
        self.addCleanup(self.output.stop)
        run = patch.object(POLICY.subprocess, 'run', side_effect=AssertionError('No tool execution'))
        run.start()
        self.addCleanup(run.stop)

    def add_binary(self, relative, architectures):
        path = self.app / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(bytes.fromhex('cffaedfe') + b'synthetic-not-executable')
        self.architectures[path] = tuple(architectures)
        return path

    def asset(self, name):
        return self.app / f'Contents/Frameworks/{name}.framework/{name}'

    def make_payload(self, architectures):
        self.add_binary('Contents/MacOS/Flash', architectures)
        for relative in POLICY.FIXED_EXECUTABLES:
            self.add_binary(relative, architectures)
        # The signed launcher master is always universal, whatever the GUI is built for.
        for relative in POLICY.PINNED_EXECUTABLES:
            self.add_binary(relative, ('arm64', 'x86_64'))
        for name in POLICY.ASSETS.values():
            self.add_binary(f'Contents/Frameworks/{name}.framework/{name}', architectures)
        self.write_manifest(architectures)

    def write_manifest(self, architectures):
        self.manifest.write_text(json.dumps({
            'format-version': [1, 0, 0],
            'native-assets': {
                POLICY.PLATFORMS[architecture]: {
                    key: ['absolute', f'@executable_path/../Frameworks/{name}.framework/{name}']
                    for key, name in POLICY.ASSETS.items()
                } for architecture in architectures
            },
        }))

    def inspect(self, arguments, text):
        self.assertTrue(text)
        path = Path(arguments[-1])
        architectures = self.architectures[path]
        if arguments[:2] == ['/usr/bin/lipo', '-archs']:
            return ' '.join(architectures)
        self.assertEqual(arguments[:4], ['/usr/bin/otool', '-arch', 'all', '-l'])
        output = []
        for architecture in architectures:
            output.append(f'{path} (architecture {architecture}):')
            if path == self.gui:
                output.extend(['cmd LC_RPATH', 'path @executable_path/../Frameworks (offset 12)'])
            for dependency in self.dependencies.get((path, architecture), []):
                output.extend(['cmd LC_LOAD_DYLIB', f'name {dependency} (offset 12)'])
        return '\n'.join(output)

    def audit(self):
        with patch('builtins.print'):
            POLICY.audit(self.app)

    def test_matching_thin_and_universal_payloads_pass(self):
        for architectures in (('arm64',), ('x86_64',), ('arm64', 'x86_64')):
            with self.subTest(architectures=architectures):
                self.make_payload(architectures)
                for architecture in architectures:
                    self.dependencies[self.gui, architecture] = [
                        '@rpath/rust_api.framework/rust_api',
                        '@executable_path/../Frameworks/sqlite3.framework/sqlite3',
                        '/usr/lib/libSystem.B.dylib',
                    ]
                self.audit()

    def test_universal_gui_requires_both_manifest_platforms(self):
        for architecture in POLICY.PLATFORMS:
            with self.subTest(architecture=architecture):
                self.write_manifest((architecture,))
                with self.assertRaisesRegex(ValueError, 'platforms do not match'):
                    self.audit()

    def test_thin_gui_rejects_extra_manifest_platform(self):
        self.make_payload(('arm64',))
        self.write_manifest(('arm64', 'x86_64'))
        with self.assertRaisesRegex(ValueError, 'platforms do not match'):
            self.audit()

    def test_every_fixed_native_asset_requires_all_gui_slices(self):
        for name in POLICY.ASSETS.values():
            with self.subTest(name=name):
                path = self.asset(name)
                self.architectures[path] = ('x86_64',)
                with self.assertRaisesRegex(ValueError, 'fixed payload architecture'):
                    self.audit()
                self.architectures[path] = ('arm64', 'x86_64')

    def test_fixed_executables_require_exact_gui_architectures(self):
        for relative in POLICY.FIXED_EXECUTABLES:
            with self.subTest(relative=relative):
                path = self.app / relative
                self.architectures[path] = ('x86_64',)
                with self.assertRaisesRegex(ValueError, 'fixed payload architecture'):
                    self.audit()
                self.architectures[path] = ('arm64', 'x86_64')
        self.make_payload(('arm64',))
        for relative in POLICY.FIXED_EXECUTABLES:
            with self.subTest(extra_architecture=relative):
                path = self.app / relative
                self.architectures[path] = ('arm64', 'x86_64')
                with self.assertRaisesRegex(ValueError, 'fixed payload architecture'):
                    self.audit()
                self.architectures[path] = ('arm64',)

    def test_pinned_launcher_must_cover_the_gui_and_is_never_rewritten(self):
        self.assertEqual(POLICY.PINNED_EXECUTABLES, ('Contents/Library/HelperTools/FlashHelperLauncher',))
        launcher = self.app / POLICY.PINNED_EXECUTABLES[0]
        for architectures in (('arm64',), ('x86_64',)):
            with self.subTest(architectures=architectures):
                self.architectures[launcher] = architectures
                with self.assertRaisesRegex(ValueError, 'launcher does not cover the GUI architectures'):
                    self.audit()
        self.architectures[launcher] = ('arm64', 'x86_64')
        self.audit()
        # Extra slices beyond a thin GUI are fine; the launcher is checked on its own (system libraries only).
        self.make_payload(('arm64',))
        self.dependencies[launcher, 'x86_64'] = ['/usr/lib/libSystem.B.dylib']
        self.audit()
        self.dependencies[launcher, 'x86_64'] = ['@rpath/rust_api.framework/rust_api']
        with self.assertRaisesRegex(ValueError, 'Unresolved bundled dependency'):
            self.audit()
        self.dependencies.pop((launcher, 'x86_64'))
        launcher.unlink()
        with self.assertRaisesRegex(ValueError, 'launcher does not cover'):
            self.audit()

    def test_pinned_launcher_with_external_rpath_fails_even_when_staging(self):
        launcher = self.app / POLICY.PINNED_EXECUTABLES[0]
        original = self.inspect
        def inspect(arguments, text):
            output = original(arguments, text)
            if Path(arguments[-1]) == launcher and arguments[0] == '/usr/bin/otool':
                output = output.replace('(architecture arm64):', '(architecture arm64):\ncmd LC_RPATH\n'
                                        f'path {POLICY.BAD_RPATH} (offset 12)')
            return output
        with patch.object(POLICY.subprocess, 'check_output', side_effect=inspect), patch('builtins.print'):
            with self.assertRaisesRegex(ValueError, 'External rpath'):
                POLICY.audit(self.app, mutate=True)

    def test_missing_fixed_executables_rejected(self):
        for relative in POLICY.FIXED_EXECUTABLES:
            with self.subTest(relative=relative):
                path = self.app / relative
                path.unlink()
                with self.assertRaisesRegex(ValueError, 'fixed payload architecture'):
                    self.audit()
                self.add_binary(relative, ('arm64', 'x86_64'))

    def test_each_dependency_requires_requesting_architecture(self):
        dependency = self.add_binary('Contents/Frameworks/extra.dylib', ('x86_64',))
        for value in ('@rpath/extra.dylib', '@executable_path/../Frameworks/extra.dylib'):
            with self.subTest(value=value):
                self.dependencies[self.gui, 'arm64'] = [value]
                with self.assertRaisesRegex(ValueError, 'dependency architecture'):
                    self.audit()
        self.architectures[dependency] = ('arm64', 'x86_64')
        self.audit()

    def test_transitive_dependency_requires_requesting_architecture(self):
        parent = self.asset('rust_api')
        self.add_binary('Contents/Frameworks/extra.dylib', ('x86_64',))
        self.dependencies[parent, 'arm64'] = ['@loader_path/../extra.dylib']
        with self.assertRaisesRegex(ValueError, 'dependency architecture'):
            self.audit()

    def test_legacy_dependency_call_infers_loader_architectures(self):
        self.add_binary('Contents/Frameworks/extra.dylib', ('x86_64',))
        with self.assertRaisesRegex(ValueError, 'dependency architecture'):
            POLICY.check_dependency(
                '@rpath/extra.dylib', self.gui, self.gui, self.app,
                [self.app / 'Contents/Frameworks'],
            )


if __name__ == '__main__':
    unittest.main()
