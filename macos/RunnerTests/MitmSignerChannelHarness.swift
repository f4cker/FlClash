// Runs MitmSignerChannel itself against the FlutterMacOS stub: an in-memory
// store stands in for MitmKeychainStore (no keychain is opened) and a stub
// for ManagedHelperChannel. Built and run by test_mitm_signer.py; not part
// of any Xcode target. Prints "PASS" and exits 0, or names what failed.
import CryptoKit
import FlutterMacOS
import Foundation

enum ManagedHelperChannel {
    private static let lock = NSLock()
    private static var answer = "verified"

    static var identity: String {
        get { lock.lock(); defer { lock.unlock() }; return answer }
        set { lock.lock(); answer = newValue; lock.unlock() }
    }

    static func coreIdentity() -> String { identity }
}

/// A software key whose leaf signatures can be held; roots and the check
/// leaf never wait.
final class HarnessKey: MitmCAKey {
    static let gate = NSCondition()
    private static var closed = false
    private static var holding = 0
    private static var maxHolding = 0

    /// The most leaf signatures ever in flight at once.
    static var peak: Int { gate.lock(); defer { gate.unlock() }; return maxHolding }
    let privateKey = P256.Signing.PrivateKey()
    var publicKeyX963: Data { privateKey.publicKey.x963Representation }

    static func close() { gate.lock(); closed = true; gate.unlock() }
    static func open() { gate.lock(); closed = false; gate.broadcast(); gate.unlock() }

    static func await(holding count: Int) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        gate.lock()
        defer { gate.unlock() }
        while holding < count { if !gate.wait(until: deadline) { return false } }
        return true
    }

    func sign(_ message: Data) throws -> Data {
        let leaf = message.range(of: Data(MitmSigner.checkHost.utf8)) == nil
            && message.range(of: Data([0x01, 0x01, 0xff, 0x04, 0x08, 0x30, 0x06, 0x01, 0x01, 0xff])) == nil
        if leaf {
            Self.gate.lock()
            Self.holding += 1
            Self.maxHolding = max(Self.maxHolding, Self.holding)
            Self.gate.broadcast()
            while Self.closed { Self.gate.wait() }
            Self.holding -= 1
            Self.gate.unlock()
        }
        return try privateKey.signature(for: message).derRepresentation
    }
}

/// Stands in for the keychain store: memory only.
final class MitmKeychainStore: MitmCAStore {
    private let lock = NSLock()
    private var key: HarnessKey?
    private var der: Data?

    func loadKey() throws -> MitmCAKey? { lock.lock(); defer { lock.unlock() }; return key }

    func createKey() throws -> MitmCAKey {
        lock.lock()
        defer { lock.unlock() }
        key = HarnessKey()
        return key!
    }

    func loadCertificate() throws -> Data? { lock.lock(); defer { lock.unlock() }; return der }
    func saveCertificate(_ der: Data) throws { lock.lock(); self.der = der; lock.unlock() }

    func deleteAll() throws -> [Error] {
        lock.lock()
        key = nil
        der = nil
        lock.unlock()
        return []
    }
}

/// Stands in for the login keychain's generic passwords.
final class MemoryPassphrases: MitmPassphraseStore {
    private let lock = NSLock()
    private var values = [String: String]()

    func read(fingerprint: String) throws -> String? { lock.lock(); defer { lock.unlock() }; return values[fingerprint] }
    func write(fingerprint: String, passphrase: String) throws { lock.lock(); values[fingerprint] = passphrase; lock.unlock() }
    func delete(fingerprint: String) throws { lock.lock(); values[fingerprint] = nil; lock.unlock() }
}

final class Messenger: FlutterBinaryMessenger {}

/// One call through the channel, answered later on some thread.
final class Pending {
    private(set) var value: Any?
    private(set) var done = false
    private(set) var onMain = false

    func finish(_ value: Any?) {
        self.value = value
        onMain = Thread.isMainThread
        done = true
    }
}

@main
enum Harness {
    static var failures = [String]()
    static var handler: ((FlutterMethodCall, @escaping FlutterResult) -> Void)!

    static func check(_ condition: Bool, _ what: String) {
        if !condition { failures.append(what) }
    }

    static func send(_ method: String, _ arguments: [String: Any]? = nil) -> Pending {
        let pending = Pending()
        handler(FlutterMethodCall(method: method, arguments: arguments)) { pending.finish($0) }
        return pending
    }

    /// Spins the main run loop, where the channel delivers results.
    @discardableResult
    static func settle(_ calls: [Pending], timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while calls.contains(where: { !$0.done }) {
            if Date() > deadline { return false }
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        return true
    }

    static func call(_ method: String, _ arguments: [String: Any]? = nil) -> Any? {
        let pending = send(method, arguments)
        check(settle([pending]), "\(method) answered")
        check(pending.onMain, "\(method) answered on the main thread")
        return pending.value
    }

    static func signArguments(_ host: String = "api.example.com") -> [String: Any] {
        let point = P256.Signing.PrivateKey().publicKey.x963Representation
        return ["host": host, "spki": FlutterStandardTypedData(bytes: MitmCertificateBuilder.spki(x963: point)),
                "hostnames": ["*.example.com", "api.example.com"]]
    }

    static func fingerprint(_ value: Any?) -> String? { (value as? [String: Any])?["fingerprint"] as? String }

    static func signedRoot(_ value: Any?) -> String? {
        ((value as? [String: Any])?["ca"] as? FlutterStandardTypedData).map { MitmCertificateBuilder.fingerprint($0.data) }
    }

    static func main() {
        MitmSignerChannel.makePassphraseStore = { MemoryPassphrases() }
        MitmSignerChannel.register(messenger: Messenger())
        guard let registered = FlutterMethodChannel.handlers["com.layoute.flash/mitm_signer"] else {
            print("FAIL: no handler"); exit(1)
        }
        handler = registered

        // Unknown methods, identity, an empty store.
        check(call("nonsense") as AnyObject? === FlutterMethodNotImplemented, "unknown -> notImplemented")
        check(call("coreIdentity") as? String == "verified", "coreIdentity")
        check(call("certificate") == nil, "no root yet")
        check((call("sign", signArguments()) as? [String: Any])?["error"] as? String == "noRoot", "sign without a root")

        // Generate, read, check, sign.
        let first = fingerprint(call("generate"))
        check(first != nil, "generate")
        check(fingerprint(call("certificate")) == first, "certificate is the generated root")
        check((call("checkCertificate") as? String)?.hasPrefix("-----BEGIN CERTIFICATE-----") == true, "check leaf")
        let signed = call("sign", signArguments())
        check((signed as? [String: Any])?["cert"] is FlutterStandardTypedData, "sign returns a leaf")
        check(signedRoot(signed) == first, "sign returns the root")

        // Refusals: each sign reports its own identity; bad arguments.
        ManagedHelperChannel.identity = "failed:cdhash"
        let refused = call("sign", signArguments()) as? [String: Any]
        check(refused?["error"] as? String == "coreIdentity" && refused?["identity"] as? String == "failed:cdhash",
              "refused Core with its identity")
        ManagedHelperChannel.identity = "verified"
        check((call("sign", ["host": "api.example.com"]) as? [String: Any])?["error"] as? String == "badKey",
              "missing arguments")

        // Lanes: checks answer while signs are held; generate waits for them.
        HarnessKey.close()
        let held = (0..<8).map { send("sign", signArguments("h\($0).example.com")) }
        check(HarnessKey.await(holding: MitmSignerDispatcher.signWidth), "four signs in flight")
        let checks = [send("certificate"), send("checkCertificate"), send("coreIdentity")]
        check(settle(checks, timeout: 2), "checks answered behind held signs")
        check(HarnessKey.peak == MitmSignerDispatcher.signWidth, "no more than four signs at once: \(HarnessKey.peak)")
        check(held.allSatisfy { !$0.done }, "signs still held while checks answered")
        let rotation = send("generate")
        let after = send("sign", signArguments("late.example.com"))
        settle([rotation], timeout: 0.3)
        check(!rotation.done, "generate waits for signs in flight")
        HarnessKey.open()
        check(settle(held + [rotation, after]), "everything answered once released")
        let second = fingerprint(rotation.value)
        check(second != nil && second != first, "generate made a new root")
        // The four in flight finish with the root they read; the four still
        // queued when generate was sent run after it, with the new one.
        let roots = held.map { signedRoot($0.value) }
        check(held.allSatisfy(\.onMain), "held signs answered on the main thread")
        check(roots.filter { $0 == first }.count >= MitmSignerDispatcher.signWidth, "signs in flight kept their root")
        check(roots.allSatisfy { $0 == first || $0 == second }, "every held sign used the old or the new root")
        check(signedRoot(after.value) == second, "a sign sent after generate uses the new root")

        // Generate or delete, then sign at once, with idle lanes.
        for round in 0..<200 {
            let before = fingerprint(call("certificate"))
            let barrier = send(round % 2 == 0 ? "generate" : "delete")
            let sign = send("sign", signArguments())
            check(settle([barrier, sign]), "round \(round) answered")
            if let root = signedRoot(sign.value) {
                check(root != before, "round \(round): a sign after \(round % 2 == 0 ? "generate" : "delete") used the old root")
            } else {
                check((sign.value as? [String: Any])?["error"] as? String == "noRoot", "round \(round): noRoot")
            }
            if round % 2 == 1 { _ = call("generate") }
        }

        // Passphrases by fingerprint; errors never carry one.
        check(call("passphrase.read", ["fingerprint": "AA"]) == nil, "no passphrase yet")
        check(call("passphrase.write", ["fingerprint": "AA", "passphrase": "s3cret"]) == nil, "write a passphrase")
        check(call("passphrase.read", ["fingerprint": "AA"]) as? String == "s3cret", "read it back")
        check(call("passphrase.read", ["fingerprint": "BB"]) == nil, "another fingerprint has none")
        let empty = call("passphrase.write", ["fingerprint": "AA", "passphrase": ""]) as? FlutterError
        check(empty?.code == "mitmPassphrase", "an empty passphrase is refused")
        check(call("passphrase.delete", ["fingerprint": "AA"]) == nil, "delete a passphrase")
        check(call("passphrase.read", ["fingerprint": "AA"]) == nil, "deleted")
        check(call("passphrase.read") is FlutterError, "no fingerprint")
        check(call("activity", ["hold": true]) == nil && call("activity", ["hold": false]) == nil, "activity")

        // The legacy root goes only by its own fingerprint.
        let legacy = fingerprint(call("certificate"))
        check(call("deleteLegacy", ["fingerprint": "00:11"]) as? Bool == false, "another fingerprint keeps the root")
        check(fingerprint(call("certificate")) == legacy, "kept")
        check(call("deleteLegacy", ["fingerprint": legacy ?? ""]) as? Bool == true, "the named root is deleted")
        check(call("certificate") == nil, "legacy deleted")
        check(call("deleteLegacy", ["fingerprint": legacy ?? ""]) as? Bool == false, "nothing left to delete")
        _ = call("generate")

        check(call("delete") == nil, "delete")
        check(call("certificate") == nil, "deleted")
        check((call("sign", signArguments()) as? [String: Any])?["error"] as? String == "noRoot", "sign after delete")

        if failures.isEmpty {
            print("PASS")
            exit(0)
        }
        print("FAIL:\n" + failures.joined(separator: "\n"))
        exit(1)
    }
}
