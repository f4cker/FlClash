// A stand-in for the parts of FlutterMacOS that MitmSignerChannel uses, so
// test_mitm_signer.py can type-check and run the channel without the app.
// Not part of any Xcode target.
import Foundation

public protocol FlutterBinaryMessenger: AnyObject {}

public typealias FlutterResult = (Any?) -> Void

public final class FlutterMethodCall {
    public let method: String
    public let arguments: Any?

    public init(method: String, arguments: Any?) {
        self.method = method
        self.arguments = arguments
    }
}

public final class FlutterMethodChannel {
    /// Every handler set, by channel name, for the harness to call.
    public private(set) static var handlers = [String: (FlutterMethodCall, @escaping FlutterResult) -> Void]()
    private let name: String

    public init(name: String, binaryMessenger: FlutterBinaryMessenger) {
        self.name = name
    }

    public func setMethodCallHandler(_ handler: ((FlutterMethodCall, @escaping FlutterResult) -> Void)?) {
        Self.handlers[name] = handler
    }
}

public final class FlutterStandardTypedData {
    public let data: Data

    public init(bytes: Data) {
        data = bytes
    }
}

public final class FlutterError {
    public let code: String

    public init(code: String, message: String?, details: Any?) {
        self.code = code
    }
}

public let FlutterMethodNotImplemented = NSObject()
