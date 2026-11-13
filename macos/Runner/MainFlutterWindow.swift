import Cocoa
import FlutterMacOS
import window
import LaunchAtLogin
import Darwin

enum NativeLoadVerification {
    static let flag = "--flash-verify-native-loads"
    static let arguments = Array(CommandLine.arguments.dropFirst())
    static let requested = arguments.contains { argument in
        let lower = argument.lowercased()
        return lower.hasPrefix("--flash") || lower.hasPrefix("-flash") ||
            lower.hasPrefix("--challenge") || lower.contains("verify-native-load")
    }
    static var challenge: String? {
        guard arguments.count == 2, arguments[0] == flag,
              arguments[1].hasPrefix("--challenge=") else { return nil }
        let token = String(arguments[1].dropFirst("--challenge=".count))
        guard token.range(of: "^[A-Za-z0-9_-]{16,64}$", options: .regularExpression) ==
            (token.startIndex..<token.endIndex) else {
            return nil
        }
        return token
    }

    static func fail(_ code: String) -> Never {
        let result: [String: Any] = [
            "schema": 1,
            "challenge": challenge as Any? ?? NSNull(),
            "ok": false,
            "code": code,
            "probes": [
                "flutter_pixel": false, "rust_utf8": false,
                "objective_c_string": false, "sqlite_memory": false,
            ],
        ]
        if let json = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) {
            let data = Data("FLASH_NATIVE_LOADS ".utf8) + json + Data([10])
            let drained = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInitiated).async {
                FileHandle.standardOutput.write(data)
                drained.signal()
            }
            _ = drained.wait(timeout: .now() + .milliseconds(100))
        }
        Darwin._exit(70)
    }
}

class MainFlutterWindow: NSWindow {
    private var verificationChannel: FlutterMethodChannel?

    private var configured = false

    func configureFlutter() {
        guard !configured else { return }
        configured = true
        if NativeLoadVerification.requested {
            startNativeLoadVerification()
            return
        }
        let project = makeProject()
        let engine = FlashFlutterEngine(name: "io.flutter", project: project, allowHeadlessExecution: false)
        let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        ManagedHelperChannel.register(messenger: flutterViewController.engine.binaryMessenger)
        ProcessAppChannel.register(messenger: flutterViewController.engine.binaryMessenger)
        RegisterGeneratedPlugins(registry: flutterViewController)
    }

    private func makeProject() -> FlutterDartProject {
        guard let frameworks = Bundle.main.privateFrameworksURL,
              let bundle = Bundle(url: frameworks.appendingPathComponent("App.framework")) else {
            if NativeLoadVerification.requested { NativeLoadVerification.fail("app_bundle_missing") }
            fatalError("Missing App.framework")
        }
        return FlutterDartProject(precompiledDartBundle: bundle)
    }

    private func startNativeLoadVerification() {
        guard let challenge = NativeLoadVerification.challenge else {
            NativeLoadVerification.fail("invalid_arguments")
        }
        #if DEBUG
        NativeLoadVerification.fail("unsupported_build")
        #else
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 20) {
            NativeLoadVerification.fail("native_timeout")
        }
        let project = makeProject()
        project.dartEntrypointArguments = NativeLoadVerification.arguments
        let engine = FlashFlutterEngine(name: "io.flutter", project: project, allowHeadlessExecution: false)
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        let channel = FlutterMethodChannel(
            name: "flash/native_load_verification", binaryMessenger: controller.engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "confirm", let token = call.arguments as? String,
                  token == challenge else {
                result(false)
                return
            }
            result(true)
        }
        verificationChannel = channel
        guard controller.engine.run(withEntrypoint: nil) else {
            NativeLoadVerification.fail("engine_start_failed")
        }
        contentViewController = controller
        #endif
    }

    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        if NativeLoadVerification.requested { return }
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}
