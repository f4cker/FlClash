import os
from pathlib import Path
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET


MACOS = Path(__file__).resolve().parents[1]
RUNNER = MACOS / 'Runner'


def source(name):
    return (RUNNER / name).read_text()


def body(text, signature):
    start = text.index('{', text.index(signature)) + 1
    depth = 1
    for end in range(start, len(text)):
        depth += (text[end] == '{') - (text[end] == '}')
        if depth == 0:
            return text[start:end]
    raise AssertionError(f'Unclosed body: {signature}')


class FlutterBootstrapTests(unittest.TestCase):
    def test_private_loader_is_void_noop_without_super(self):
        implementation = source('FlashFlutterEngine.m')
        loader = body(implementation, '@implementation FlashFlutterEngine')
        self.assertEqual(loader.strip(), '(void)assetsDir;')
        self.assertRegex(implementation, r'-\s*\(void\)loadAOTData:\(NSString\s*\*\)assetsDir')
        self.assertIn('3.50.0 private selector', implementation)
        self.assertIn('@interface FlashFlutterEngine : FlutterEngine', source('FlashFlutterEngine.h'))

    def test_both_paths_use_restricted_engine_and_public_controller_initializer(self):
        window = source('MainFlutterWindow.swift')
        for signature in ('func configureFlutter()', 'func startNativeLoadVerification()'):
            path = body(window, signature)
            self.assertIn('let project = makeProject()', path)
            self.assertIn('FlashFlutterEngine(name: "io.flutter", project: project, allowHeadlessExecution: false)', path)
            self.assertIn('FlutterViewController(engine: engine, nibName: nil, bundle: nil)', path)
        self.assertNotIn('FlutterViewController()', window)
        self.assertNotIn('FlutterViewController(project:', window)
        self.assertNotIn('awakeFromNib', window)

    def test_normal_launch_preserves_deferred_engine_start_and_channels(self):
        normal = body(source('MainFlutterWindow.swift'), 'func configureFlutter()')
        self.assertNotIn('.run(', normal)
        self.assertLess(normal.index('guard !configured'), normal.index('configured = true'))
        self.assertLess(normal.index('startNativeLoadVerification()'), normal.index('let project'))
        for registration in ('"launch_at_startup"', 'ManagedHelperChannel.register',
                             'ProcessAppChannel.register', 'RegisterGeneratedPlugins'):
            self.assertIn(registration, normal)
        self.assertLess(normal.index('self.contentViewController ='), normal.index('RegisterGeneratedPlugins'))

    def test_diagnostic_installs_channel_then_runs_before_attaching_view(self):
        diagnostic = body(source('MainFlutterWindow.swift'), 'func startNativeLoadVerification()')
        expected = ['project.dartEntrypointArguments = NativeLoadVerification.arguments',
                    'FlutterViewController(engine:', 'channel.setMethodCallHandler',
                    'verificationChannel = channel', 'controller.engine.run(withEntrypoint: nil)',
                    'contentViewController = controller']
        positions = [diagnostic.index(value) for value in expected]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn('RegisterGeneratedPlugins', diagnostic)
        self.assertIn('NativeLoadVerification.fail("engine_start_failed")', diagnostic)

    def test_project_selects_app_framework_without_bundle_identifier_fallback(self):
        project = body(source('MainFlutterWindow.swift'), 'func makeProject()')
        self.assertIn('Bundle.main.privateFrameworksURL', project)
        self.assertIn('Bundle(url: frameworks.appendingPathComponent("App.framework"))', project)
        self.assertIn('FlutterDartProject(precompiledDartBundle: bundle)', project)
        self.assertIn('fatalError("Missing App.framework")', project)
        self.assertNotIn('FlutterDartProject()', source('MainFlutterWindow.swift'))

    def test_explicit_main_retains_delegate_without_resource_bootstrap(self):
        delegate = source('AppDelegate.swift')
        main = body(delegate, 'static func main()')
        for call in ('NSApplication.shared', 'AppDelegate()', 'application.delegate = delegate',
                     'withExtendedLifetime(delegate)', 'application.run()'):
            self.assertIn(call, main)
        self.assertNotIn('NSApplicationMain', delegate)
        self.assertNotIn('loadNib', delegate)
        self.assertNotIn('NSStoryboard', delegate)
        plist = plistlib.loads((RUNNER / 'Info.plist').read_bytes())
        self.assertNotIn('NSMainNibFile', plist)
        self.assertNotIn('NSMainStoryboardFile', plist)
        self.assertNotIn('NSPrincipalClass', plist)
        project = (MACOS / 'Runner.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('MainMenu.xib in Resources', project)

    def test_window_is_retained_and_diagnostic_never_orders_it(self):
        delegate = source('AppDelegate.swift')
        setup = body(delegate, 'override func applicationWillFinishLaunching')
        self.assertIn('private var flutterWindow: MainFlutterWindow?', delegate)
        self.assertIn('flutterWindow = window', setup)
        self.assertIn('mainFlutterWindow = window', setup)
        self.assertIn('if !NativeLoadVerification.requested {\n            window.makeKeyAndOrderFront(nil)', setup)
        order = body(source('MainFlutterWindow.swift'), 'override public func order(')
        self.assertLess(order.index('if NativeLoadVerification.requested { return }'), order.index('super.order'))
        # The window plugin's hiddenWindowAtLaunch() went with upstream's
        # rust_api window; the first order hides the window the same way.
        self.assertLess(order.index('super.order'), order.index('setIsVisible(false)'))
        self.assertIn('if !hiddenAtLaunch {', order)

    def test_native_window_and_menu_match_former_xib(self):
        delegate = source('AppDelegate.swift')
        xib = ET.parse(RUNNER / 'Base.lproj/MainMenu.xib')
        window = xib.find('./objects/window')
        rect = window.find('./rect[@key="contentRect"]')
        geometry = ', '.join(f'{key}: {rect.get(key)}' for key in ('x', 'y', 'width', 'height'))
        self.assertIn(f'NSRect({geometry})', delegate)
        self.assertIn('styleMask: [.titled, .closable, .miniaturizable, .resizable]', delegate)
        self.assertIn('window.isReleasedWhenClosed = false', delegate)
        for item in xib.findall('./objects/menu//menuItem'):
            action = item.find('./connections/action')
            if action is not None:
                fragment = f'"{item.get("title")}", "{action.get("selector")}", "{item.get("keyEquivalent", "")}"'
                self.assertIn(fragment, delegate)
        for menu in ('servicesMenu', 'windowsMenu', 'helpMenu'):
            self.assertIn(f'NSApp.{menu} =', delegate)

    def test_objc_engine_is_compiled_and_bridged(self):
        self.assertIn('#import "FlashFlutterEngine.h"', source('Runner-Bridging-Header.h'))
        project = (MACOS / 'Runner.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(project.count('FlashFlutterEngine.m in Sources'), 2)
        sources = project.split('/* Begin PBXSourcesBuildPhase section */')[1]
        self.assertIn('FlashFlutterEngine.m in Sources', sources)


@unittest.skipUnless(os.environ.get('FLUTTER_ENGINE_SOURCE'), 'Set FLUTTER_ENGINE_SOURCE to SDK engine/src/flutter for SDK-pin checks')
class FlutterSDKContractTests(unittest.TestCase):
    def test_private_loader_dispatch_and_nullable_aot_contract(self):
        root = Path(os.environ['FLUTTER_ENGINE_SOURCE'])
        engine = (root / 'shell/platform/darwin/macos/framework/Source/FlutterEngine.mm').read_text()
        self.assertIn('- (void)loadAOTData:(NSString*)assetsDir;', engine)
        self.assertRegex(engine, r'\[self loadAOTData:_project.assetsPath\];\s*if \(_aotData\) \{\s*flutterArguments.aot_data = _aotData;')
        loader = body(engine, '- (void)loadAOTData:(NSString*)assetsDir {')
        self.assertIn('@"app_elf_snapshot.so"', loader)
        self.assertIn('_embedderAPI.CreateAOTData(&source, &_aotData)', loader)

    def test_supplied_controller_engine_still_starts_on_view_will_appear(self):
        root = Path(os.environ['FLUTTER_ENGINE_SOURCE'])
        controller = (root / 'shell/platform/darwin/macos/framework/Source/FlutterViewController.mm').read_text()
        initializer = body(controller, '- (instancetype)initWithEngine:')
        self.assertIn('CommonInit(self, engine)', initializer)
        self.assertNotIn('launchEngine', initializer)
        appear = body(controller, '- (void)viewWillAppear')
        self.assertIn('if (!_engine.running)', appear)
        self.assertIn('[self launchEngine]', appear)
        self.assertIn('[_engine runWithEntrypoint:nil]', body(controller, '- (BOOL)launchEngine {'))

    def test_explicit_project_bundle_loads_through_nsbundle(self):
        root = Path(os.environ['FLUTTER_ENGINE_SOURCE'])
        project = (root / 'shell/platform/darwin/macos/framework/Source/FlutterDartProject.mm').read_text()
        initializer = body(project, '- (instancetype)initWithPrecompiledDartBundle:')
        self.assertIn('_dartBundle = bundle ?:', initializer)
        self.assertIn('[_dartBundle load]', initializer)


if __name__ == '__main__':
    unittest.main()
