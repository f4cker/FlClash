import FlutterMacOS
import Foundation
import Security

/// The app's MITM root on the Flutter side: generate, read, delete, and sign
/// a leaf the Core asks for. Work runs off the main thread on the lanes of
/// MitmSignerDispatcher: signs side by side, checks on their own lane, and
/// generate/delete alone.
final class MitmSignerChannel {
    private static var instance: MitmSignerChannel?
    private let channel: FlutterMethodChannel
    private let dispatcher = MitmSignerDispatcher()
    private let signer = MitmSigner(store: MitmKeychainStore(), coreIdentity: ManagedHelperChannel.coreIdentity)
    /// Replaced by tests before register(messenger:), so none opens a keychain.
    static var makePassphraseStore: () -> MitmPassphraseStore = { MitmKeychainPassphraseStore() }
    private let passphrases = MitmSignerChannel.makePassphraseStore()
    private let activityLock = NSLock()
    private var activity: NSObjectProtocol?

    static func register(messenger: FlutterBinaryMessenger) {
        instance = MitmSignerChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.layoute.flash/mitm_signer", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(nil); return }
            let arguments = call.arguments as? [String: Any] ?? [:]
            self.dispatcher.run(MitmSignerDispatcher.lane(for: call.method)) {
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

    /// Errors name the operation only: the passphrase is never in one.
    private func passphrase(_ method: String, _ arguments: [String: Any]) -> Any? {
        guard let fingerprint = arguments["fingerprint"] as? String, !fingerprint.isEmpty else {
            return FlutterError(code: "mitmPassphrase", message: "no fingerprint", details: nil)
        }
        do {
            switch method {
            case "passphrase.read": return try passphrases.read(fingerprint: fingerprint)
            case "passphrase.write":
                guard let value = arguments["passphrase"] as? String, !value.isEmpty else {
                    return FlutterError(code: "mitmPassphrase", message: "no passphrase", details: nil)
                }
                try passphrases.write(fingerprint: fingerprint, passphrase: value)
            default: try passphrases.delete(fingerprint: fingerprint)
            }
            return nil
        } catch {
            return FlutterError(code: "mitmPassphrase", message: "\(method) failed", details: nil)
        }
    }

    private func hold(_ on: Bool) {
        activityLock.lock()
        defer { activityLock.unlock() }
        if on, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "HTTPS decryption renews its trust lease")
        } else if !on, let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
    }

    private func handle(_ method: String, _ arguments: [String: Any]) -> Any? {
        switch method {
        case "certificate":
            do { return try signer.refreshRoot().map(Self.encode) } catch { return failure(error) }
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
            let outcome = signer.signReporting(host: host, spki: spki.data, hostnames: hostnames)
            var answer = Self.encode(outcome.result)
            if answer["error"] as? String == MitmSignError.coreIdentity.rawValue {
                answer["identity"] = outcome.identity
            }
            return answer
        case "deleteLegacy":
            guard let fingerprint = arguments["fingerprint"] as? String else { return false }
            do { return try signer.deleteLegacy(fingerprint: fingerprint) } catch { return failure(error) }
        case "passphrase.read", "passphrase.write", "passphrase.delete":
            return passphrase(method, arguments)
        case "activity":
            hold(arguments["hold"] as? Bool == true)
            return nil
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

/// Generic passwords in the login keychain, one per CA fingerprint.
final class MitmKeychainPassphraseStore: MitmPassphraseStore {
    static let service = "com.layoute.flash.mitm.ca-passphrase"

    private func loginKeychain() throws -> SecKeychain {
        var keychain: SecKeychain?
        try check(SecKeychainCopyDomainDefault(.user, &keychain))
        guard let keychain else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecNoSuchKeychain)) }
        return keychain
    }

    private func query(_ fingerprint: String) throws -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service,
         kSecAttrAccount as String: fingerprint, kSecMatchSearchList as String: [try loginKeychain()]]
    }

    private func check(_ status: OSStatus, allowing allowed: Set<OSStatus> = []) throws {
        guard status == errSecSuccess || allowed.contains(status) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func read(fingerprint: String) throws -> String? {
        var item: CFTypeRef?
        var search = try query(fingerprint)
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(search as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    func write(fingerprint: String, passphrase: String) throws {
        let data = Data(passphrase.utf8)
        let status = SecItemUpdate(try query(fingerprint) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status != errSecItemNotFound { return try check(status) }
        var item = try query(fingerprint)
        item.removeValue(forKey: kSecMatchSearchList as String)
        item[kSecUseKeychain as String] = try loginKeychain()
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = "Flash decryption certificate password"
        try check(SecItemAdd(item as CFDictionary, nil))
    }

    func delete(fingerprint: String) throws {
        try check(SecItemDelete(try query(fingerprint) as CFDictionary), allowing: [errSecItemNotFound])
    }
}
