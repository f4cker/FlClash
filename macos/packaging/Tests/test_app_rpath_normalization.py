from pathlib import Path
import unittest
from unittest.mock import patch

import test_architecture_policy as fixtures

POLICY = fixtures.POLICY


class AppRpathNormalizationTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.ArchitecturePolicyTests('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.app = self.fixture.app
        self.binary = self.fixture.add_binary(
            POLICY.APP_FRAMEWORK_BINARY, ('arm64', 'x86_64'),
        )
        self.loader = self.binary
        self.paths = {architecture: list(POLICY.REDUNDANT_APP_RPATHS)
                      for architecture in ('arm64', 'x86_64')}
        POLICY.subprocess.check_output.side_effect = self.inspect
        POLICY.subprocess.run.side_effect = self.remove_rpaths
        self.run = POLICY.subprocess.run
        self.inspections = 0

    def inspect(self, arguments, text):
        output = self.fixture.inspect(arguments, text)
        if Path(arguments[-1]) != self.loader or arguments[0] != '/usr/bin/otool':
            return output
        self.inspections += 1
        result = []
        architecture = None
        for line in output.splitlines():
            result.append(line)
            if line.startswith(str(self.loader)):
                architecture = line.rsplit('architecture ', 1)[1][:-2]
                for value in self.paths[architecture]:
                    result.extend(['cmd LC_RPATH', f'path {value} (offset 12)'])
        return '\n'.join(result)

    def remove_rpaths(self, arguments, check):
        self.assertTrue(check)
        self.assertEqual(arguments[0], '/usr/bin/install_name_tool')
        self.assertEqual(arguments[-1], str(self.binary))
        for index in range(1, len(arguments) - 1, 2):
            self.assertEqual(arguments[index], '-delete_rpath')
            for paths in self.paths.values():
                paths.remove(arguments[index + 1])

    def audit(self, mutate=True):
        with patch('builtins.print'):
            POLICY.audit(self.app, mutate=mutate)

    def test_known_absent_paths_removed_and_all_commands_reinspected(self):
        self.audit()
        self.run.assert_called_once_with([
            '/usr/bin/install_name_tool',
            '-delete_rpath', '@executable_path/Frameworks',
            '-delete_rpath', '@loader_path/Frameworks', str(self.binary),
        ], check=True)
        self.assertEqual(self.inspections, 2)
        self.audit(mutate=False)
        self.assertEqual(self.inspections, 3)

    def test_existing_in_bundle_directories_retained_and_validated(self):
        for value in POLICY.REDUNDANT_APP_RPATHS:
            POLICY.expanded(value, self.binary, self.fixture.gui).mkdir()
        with patch.object(POLICY, 'check_rpath', wraps=POLICY.check_rpath) as checked:
            self.audit()
        self.run.assert_not_called()
        for value in POLICY.REDUNDANT_APP_RPATHS:
            checked.assert_any_call(value, self.binary, self.fixture.gui, self.app)

    def test_verify_never_normalizes_invalid_sealed_payload(self):
        with self.assertRaises(FileNotFoundError):
            self.audit(mutate=False)
        self.run.assert_not_called()

    def test_unknown_missing_path_is_not_removed(self):
        self.paths = {architecture: ['@loader_path/UnknownFrameworks']
                      for architecture in self.paths}
        with self.assertRaises(FileNotFoundError):
            self.audit()
        self.run.assert_not_called()

    def test_other_binary_known_missing_paths_are_not_removed(self):
        self.loader = self.fixture.asset('rust_api')
        with self.assertRaises(FileNotFoundError):
            self.audit()
        self.run.assert_not_called()

    def test_unsafe_existing_or_dangling_targets_fail_without_mutation(self):
        target = POLICY.expanded('@loader_path/Frameworks', self.binary, self.fixture.gui)
        for destination in (self.app.parent, self.app.parent / 'missing'):
            with self.subTest(destination=destination):
                target.symlink_to(destination, target_is_directory=True)
                with self.assertRaises((ValueError, FileNotFoundError)):
                    self.audit()
                self.run.assert_not_called()
                target.unlink()

    def test_existing_nondirectory_is_not_removed(self):
        target = POLICY.expanded('@loader_path/Frameworks', self.binary, self.fixture.gui)
        target.write_text('not a directory')
        with self.assertRaisesRegex(ValueError, 'not a directory'):
            self.audit()
        self.run.assert_not_called()

    def test_asymmetric_or_duplicate_slice_rpaths_fail_closed(self):
        for paths in ([], ['@executable_path/Frameworks'] * 2):
            with self.subTest(paths=paths):
                self.paths['x86_64'] = paths
                with self.assertRaisesRegex(ValueError, 'Inconsistent redundant App rpath'):
                    self.audit()
                self.run.assert_not_called()

    def test_reinspection_rejects_incomplete_removal(self):
        self.run.side_effect = None
        with self.assertRaisesRegex(ValueError, 'Incomplete redundant App rpath'):
            self.audit()
        self.assertEqual(self.inspections, 2)

    def test_dependencies_are_reaudited_after_normalization(self):
        self.fixture.dependencies[self.binary, 'arm64'] = ['@rpath/missing.dylib']
        with self.assertRaisesRegex(ValueError, 'Unresolved bundled dependency'):
            self.audit()
        self.run.assert_called_once()
        self.assertEqual(self.inspections, 2)


if __name__ == '__main__':
    unittest.main()
