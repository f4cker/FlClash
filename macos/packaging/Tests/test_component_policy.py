import copy
import importlib.util
from pathlib import Path
import plistlib
import unittest

SPEC = importlib.util.spec_from_file_location('component_policy', Path(__file__).parents[1] / 'pin_component_policy.py')
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)


class ComponentPolicyTests(unittest.TestCase):
    def test_analyzed_nested_components_are_explicitly_nonrelocatable_and_unversioned(self):
        fixture = [
            {'RootRelativeBundlePath': 'Library/Application Support/Flash/.incoming/Flash.app',
             'BundleIsRelocatable': True, 'BundleIsVersionChecked': True,
             'ChildBundles': [
                 {'RootRelativeBundlePath': 'Library/Application Support/Flash/.incoming/Flash.app/Contents/Frameworks/FlutterMacOS.framework',
                  'BundleIsRelocatable': True,
                  'ChildBundles': [
                      {'RootRelativeBundlePath': 'Library/Application Support/Flash/.incoming/Flash.app/Contents/Frameworks/FlutterMacOS.framework/Resources/Nested.bundle'},
                  ]},
             ]},
            {'RootRelativeBundlePath': 'Library/Application Support/Flash/.incoming/Flash.app/Contents/Frameworks/sqlite3.framework',
             'BundleIsVersionChecked': True},
        ]
        result = POLICY.pin_components(plistlib.loads(plistlib.dumps(fixture)))

        def verify(components):
            for component in components:
                self.assertIs(component['BundleIsRelocatable'], False)
                self.assertIs(component['BundleIsVersionChecked'], False)
                verify(component.get('ChildBundles', []))

        verify(result)
        self.assertEqual(result[0]['RootRelativeBundlePath'], fixture[0]['RootRelativeBundlePath'])
        self.assertEqual(plistlib.loads(plistlib.dumps(result)), result)
        self.assertEqual(POLICY.pin_components(copy.deepcopy(result)), result)

    def test_malformed_or_unanchored_analysis_fails_closed(self):
        for fixture in ([], {}, [None], [{}], [{'RootRelativeBundlePath': '/tmp/Flash.app'}],
                        [{'RootRelativeBundlePath': '../Flash.app'}],
                        [{'RootRelativeBundlePath': 'Flash.app', 'ChildBundles': {}}],
                        [{'RootRelativeBundlePath': 'Flash.app', 'ChildBundles': [None]}]):
            with self.subTest(fixture=fixture), self.assertRaises(ValueError):
                POLICY.pin_components(fixture)

    def test_payload_pkgbuild_always_uses_processed_component_plist(self):
        source = (Path(__file__).parents[1] / 'build_managed_packages.sh').read_text()
        analyze = source.index('/usr/bin/pkgbuild --analyze --root "$work" "$components"')
        pin = source.index('/usr/bin/python3 "$source_dir/pin_component_policy.py" "$components"')
        build = source.index('/usr/bin/pkgbuild --root "$work" --component-plist "$components"')
        self.assertLess(analyze, pin)
        self.assertLess(pin, build)
        self.assertEqual(source.count('/usr/bin/pkgbuild --root'), 1)


if __name__ == '__main__':
    unittest.main()
