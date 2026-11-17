import Cocoa
import FlutterMacOS
import ServiceManagement
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
    private var hiddenAtLaunch = false

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
            MainAppLoginItem.handle(call, result: result)
        }

        ManagedHelperChannel.register(messenger: flutterViewController.engine.binaryMessenger)
        ProcessAppChannel.register(messenger: flutterViewController.engine.binaryMessenger)
        MitmSignerChannel.register(messenger: flutterViewController.engine.binaryMessenger)
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
        // Only the first order hides the window, which Dart shows once it is configured.
        if !hiddenAtLaunch {
            hiddenAtLaunch = true
            setIsVisible(false)
        }
    }
}

private enum MainAppLoginItem {
    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "launchAtStartupIsEnabled" ||
              call.method == "launchAtStartupSetEnabled" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard #available(macOS 13, *) else {
            handleLegacy(call, result: result)
            return
        }
        let service = SMAppService.mainApp
        if call.method == "launchAtStartupIsEnabled" {
            switch service.status {
            case .enabled: result(true)
            case .notRegistered: result(false)
            default: result(statusError(service.status, operation: "read"))
            }
            return
        }
        guard let arguments = call.arguments as? [String: Any],
              let enabled = arguments["setEnabledValue"] as? Bool else {
            result(FlutterError(code: "invalid_arguments",
                                message: "setEnabledValue must be a Boolean.", details: nil))
            return
        }
        let before = service.status
        if enabled && before == .enabled {
            result(nil)
            return
        }
        if before == .notFound || (enabled && before == .requiresApproval) {
            result(statusError(before, operation: enabled ? "enable" : "disable"))
            return
        }
        do {
            switch before {
            case .enabled:
                if !enabled { try service.unregister() }
            case .requiresApproval:
                if enabled {
                    result(statusError(before, operation: "enable"))
                    return
                }
                try service.unregister()
            case .notRegistered:
                if enabled { try service.register() }
            case .notFound:
                result(statusError(before, operation: enabled ? "enable" : "disable"))
                return
            @unknown default:
                result(statusError(before, operation: enabled ? "enable" : "disable"))
                return
            }
        } catch {
            let native = error as NSError
            result(FlutterError(
                code: "login_item_operation_failed", message: native.localizedDescription,
                details: ["operation": enabled ? "enable" : "disable",
                          "status": statusName(service.status),
                          "domain": native.domain, "nativeCode": native.code]
            ))
            return
        }
        let after = service.status
        guard enabled ? after == .enabled : after == .notRegistered else {
            result(statusError(after, operation: enabled ? "enable" : "disable"))
            return
        }
        result(nil)
    }

    // SMAppService.mainApp needs macOS 13; on macOS 12 there is no login item
    // API this app can drive, so the toggle reads off and a change is refused.
    private static func handleLegacy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "launchAtStartupIsEnabled" {
            result(false)
            return
        }
        guard let arguments = call.arguments as? [String: Any],
              let enabled = arguments["setEnabledValue"] as? Bool else {
            result(FlutterError(code: "invalid_arguments",
                                message: "setEnabledValue must be a Boolean.", details: nil))
            return
        }
        if !enabled {
            result(nil)
            return
        }
        result(FlutterError(
            code: "login_item_operation_failed",
            message: "Open at Login needs macOS 13 or later.",
            details: ["operation": "enable", "status": "unsupported"]
        ))
    }

    @available(macOS 13, *)
    private static func statusName(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notRegistered: return "notRegistered"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }

    @available(macOS 13, *)
    private static func statusError(_ status: SMAppService.Status, operation: String) -> FlutterError {
        let code: String
        let message: String
        switch status {
        case .requiresApproval:
            code = "login_item_requires_approval"
            message = "Approve Flash in System Settings > General > Login Items to open it at login."
        case .notFound:
            code = "login_item_not_found"
            message = "macOS could not find this application as a login item."
        default:
            code = "login_item_unexpected_status"
            message = "Open at Login did not reach the requested state."
        }
        return FlutterError(code: code, message: message,
                            details: ["status": statusName(status), "operation": operation])
    }

}
