import FlutterMacOS

final class ManagedHelperChannel {
    private static var instance: ManagedHelperChannel?
    private let bridge = FCManagedHelperBridge()
    private let channel: FlutterMethodChannel

    static func register(messenger: FlutterBinaryMessenger) {
        instance = ManagedHelperChannel(messenger: messenger)
    }

    /// Of the Core started through the daemon, checked again on each call; call off the main thread.
    static func coreIdentity() -> String {
        instance?.bridge.coreIdentity() ?? "none"
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.layoute.flash/managed_helper", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(["code": "unavailable"]); return }
            var arguments = call.arguments as? [String: Any] ?? [:]
            if let frame = arguments["frame"] as? FlutterStandardTypedData {
                arguments["frame"] = frame.data
            }
            self.bridge.invoke(call.method, arguments: arguments) { answer in
                var payload = answer
                if let frame = payload["frame"] as? Data {
                    payload["frame"] = FlutterStandardTypedData(bytes: frame)
                }
                DispatchQueue.main.async { result(payload) }
            }
        }
    }
}
