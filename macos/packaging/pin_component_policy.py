import plistlib
from pathlib import Path
import sys


def pin_components(components):
    if not isinstance(components, list) or not components:
        raise ValueError('Expected analyzed bundle components')
    for component in components:
        if not isinstance(component, dict) or not isinstance(component.get('RootRelativeBundlePath'), str):
            raise ValueError('Malformed analyzed component')
        path = component['RootRelativeBundlePath']
        if not path or path.startswith('/') or '..' in Path(path).parts:
            raise ValueError('Invalid component path')
        component['BundleIsRelocatable'] = False
        component['BundleIsVersionChecked'] = False
        children = component.get('ChildBundles', [])
        if children:
            pin_components(children)
        elif not isinstance(children, list):
            raise ValueError('Malformed child components')
    return components


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(64)
    path = Path(sys.argv[1])
    components = pin_components(plistlib.loads(path.read_bytes()))
    path.write_bytes(plistlib.dumps(components))
