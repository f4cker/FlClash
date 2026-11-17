import FlutterMacOS
import Foundation

/// The app's MITM root on the Flutter side: generate, read, delete, and sign
/// a leaf the Core asks for. Work runs on one serial queue off the main thread.
final class MitmSignerChannel {
    private static var instance: MitmSignerChannel?
    private let channel: FlutterMethodChannel
    private let queue = DispatchQueue(label: "com.layoute.flash.mitm.signer")
    private let signer = MitmSigner(store: MitmKeychainStore(), coreIdentity: ManagedHelperChannel.coreIdentity)

    static func register(messenger: FlutterBinaryMessenger) {
        instance = MitmSignerChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.layoute.flash/mitm_signer", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(nil); return }
            let arguments = call.arguments as? [String: Any] ?? [:]
            self.queue.async {
                let answer = self.handle(call.method, arguments)
                DispatchQueue.main.async { result(answer) }
            }
        }
    }

    private static func millis(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

    private static func encode(_ root: MitmRootInfo) -> [String: Any] {
        [
            "pem": root.pem, "fingerprint": root.fingerprint, "subject": root.subject,
            "notBefore": millis(root.notBefore), "notAfter": millis(root.notAfter),
        ]
    }

    private static func encode(_ result: Result<(leaf: Data, ca: Data), MitmSignError>) -> [String: Any] {
        switch result {
        case let .success((leaf, ca)):
            return ["cert": FlutterStandardTypedData(bytes: leaf), "ca": FlutterStandardTypedData(bytes: ca)]
        case let .failure(error):
            return ["error": error.rawValue]
        }
    }

    private func failure(_ error: Error) -> FlutterError {
        FlutterError(code: "mitmSigner", message: String(describing: error), details: nil)
    }

    private func handle(_ method: String, _ arguments: [String: Any]) -> Any? {
        switch method {
        case "certificate":
            do { return try signer.certificate().map(Self.encode) } catch { return failure(error) }
        case "generate":
            do { return Self.encode(try signer.generate()) } catch { return failure(error) }
        case "delete":
            do { try signer.delete(); return nil } catch { return failure(error) }
        case "coreIdentity":
            return ManagedHelperChannel.coreIdentity()
        case "sign":
            guard let host = arguments["host"] as? String,
                  let spki = arguments["spki"] as? FlutterStandardTypedData,
                  let hostnames = arguments["hostnames"] as? [String] else {
                return ["error": MitmSignError.badKey.rawValue]
            }
            return Self.encode(signer.sign(host: host, spki: spki.data, hostnames: hostnames))
        case "checkCertificate":
            switch signer.checkCertificate() {
            case let .success((leaf, _)): return MitmCertificateBuilder.pem(leaf)
            case let .failure(error): return FlutterError(code: error.rawValue, message: nil, details: nil)
            }
        default:
            return FlutterMethodNotImplemented
        }
    }
}
