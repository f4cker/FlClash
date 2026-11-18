import FlutterMacOS

final class ManagedHelperChannel {
    private static var instance: ManagedHelperChannel?
    // A static let initialises once under a lock, so the signer queue may read it while main registers.
    private static let bridge = FCManagedHelperBridge()
    private var bridge: FCManagedHelperBridge { Self.bridge }
    private let channel: FlutterMethodChannel

    static func register(messenger: FlutterBinaryMessenger) {
        instance = ManagedHelperChannel(messenger: messenger)
    }

    /// Of the Core started through the daemon, checked again on each call; call off the main thread.
    static func coreIdentity() -> String {
        bridge.coreIdentity()
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
                if let frames = payload["frames"] as? [Data] {
                    payload["frames"] = frames.map { FlutterStandardTypedData(bytes: $0) }
                }
                DispatchQueue.main.async { result(payload) }
            }
        }
    }
}
