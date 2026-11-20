import CryptoKit
import Security
import XCTest

/// A software key and an in-memory store: these tests never touch a keychain.
private final class MemoryKey: MitmCAKey {
    let privateKey = P256.Signing.PrivateKey()
    var publicKeyX963: Data { privateKey.publicKey.x963Representation }

    func sign(_ message: Data) throws -> Data {
        try privateKey.signature(for: message).derRepresentation
    }
}

private final class MemoryStore: MitmCAStore {
    var key: MemoryKey?
    var certificate: Data?
    var deletes = 0
    var leftovers = [Error]()

    func loadKey() throws -> MitmCAKey? { key }

    func createKey() throws -> MitmCAKey {
        let key = MemoryKey()
        self.key = key
        return key
    }

    func loadCertificate() throws -> Data? { certificate }
    func saveCertificate(_ der: Data) throws { certificate = der }

    func deleteAll() throws -> [Error] {
        deletes += 1
        key = nil
        certificate = nil
        return leftovers
    }
}

private struct HostVectors: Decodable {
    struct Validate: Decodable {
        let line: String
        let issue: String
    }

    struct Match: Decodable {
        let list: [String]
        let host: String
        let decrypt: Bool
    }

    let validate: [Validate]
    let match: [Match]
}

final class MitmSignerTests: XCTestCase {
    private var store: MemoryStore!
    private var identity = "verified"
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var signer: MitmSigner!
    private let list = ["api.example.com", "-private.example.org", "*.example.org"]

    override func setUp() {
        store = MemoryStore()
        identity = "verified"
        clock = Date(timeIntervalSince1970: 1_800_000_000)
        signer = MitmSigner(store: store, coreIdentity: { [unowned self] in identity }, now: { [unowned self] in clock })
    }

    private func leafSPKI() -> Data {
        MitmCertificateBuilder.spki(x963: P256.Signing.PrivateKey().publicKey.x963Representation)
    }

    private func vectors() throws -> HostVectors {
        let path = ProcessInfo.processInfo.environment["MITM_HOSTNAME_VECTORS"]
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../core/testdata/mitm_hostname_vectors.json").path
        return try JSONDecoder().decode(HostVectors.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }

    /// Evaluates the leaf for host against the root alone, at the signer's clock.
    private func evaluate(_ leaf: Data, _ root: Data, host: String, at date: Date? = nil) -> Bool {
        let certificates = [leaf, root].map { SecCertificateCreateWithData(nil, $0 as CFData)! }
        var trust: SecTrust?
        XCTAssertEqual(SecTrustCreateWithCertificates(
            certificates as CFArray, SecPolicyCreateSSL(true, host as CFString), &trust), errSecSuccess)
        SecTrustSetAnchorCertificates(trust!, [certificates[1]] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust!, true)
        SecTrustSetNetworkFetchAllowed(trust!, false)
        SecTrustSetVerifyDate(trust!, (date ?? clock) as CFDate)
        return SecTrustEvaluateWithError(trust!, nil)
    }

    // MARK: host rules, shared with the Core

    func testHostRulesMatchTheCoreVectors() throws {
        let vectors = try vectors()
        XCTAssertGreaterThan(vectors.validate.count, 40)
        for vector in vectors.validate {
            XCTAssertEqual(MitmHostPolicy.parse(vector.line).1?.rawValue ?? "", vector.issue, vector.line)
        }
        for vector in vectors.match {
            XCTAssertEqual(MitmHostMatcher(vector.list).matches(vector.host), vector.decrypt,
                           "\(vector.list) \(vector.host)")
        }
    }

    func testPublicSuffixRulesFollowWildcardsAndExceptions() {
        XCTAssertTrue(MitmPublicSuffix.isPublicSuffix("com"))
        XCTAssertTrue(MitmPublicSuffix.isPublicSuffix("co.uk"))
        XCTAssertTrue(MitmPublicSuffix.isPublicSuffix("b.ck"))
        XCTAssertFalse(MitmPublicSuffix.isPublicSuffix("www.ck"))
        XCTAssertTrue(MitmPublicSuffix.isPublicSuffix("foo.kobe.jp"))
        XCTAssertFalse(MitmPublicSuffix.isPublicSuffix("city.kobe.jp"))
        XCTAssertFalse(MitmPublicSuffix.isPublicSuffix("example.com"))
        XCTAssertTrue(MitmPublicSuffix.isPublicSuffix("unknowntld"))
    }

    // MARK: who may ask and for what

    func testRefusesACoreThatFailedOrSkippedTheIdentityCheck() throws {
        _ = try signer.generate()
        for state in ["failed:cdhash", "failed:status 0x1", "none", "", "verified "] {
            identity = state
            let outcome = signer.signReporting(host: "api.example.com", spki: leafSPKI(), hostnames: list)
            XCTAssertEqual(outcome.result.failure, .coreIdentity, state)
            XCTAssertEqual(outcome.identity, state)
        }
    }

    func testRefusesHostsOffTheList() throws {
        _ = try signer.generate()
        for host in ["www.example.com", "example.org", "private.example.org", "x.api.example.com", "1.2.3.4",
                     "", MitmSigner.checkHost] {
            XCTAssertEqual(signer.sign(host: host, spki: leafSPKI(), hostnames: list).failure, .notListed, host)
        }
        // Over-broad and Apple entries count as not written.
        for (entry, host) in [("*.com", "bank.com"), ("*", "bank.example.net"), ("*.co.uk", "bank.co.uk"),
                              ("*.apple.com", "www.apple.com"), ("*.example.net", "www.icloud.com"),
                              ("*.b.ck", "a.b.ck")] {
            XCTAssertEqual(signer.sign(host: host, spki: leafSPKI(), hostnames: [entry]).failure, .notListed, host)
        }
        XCTAssertEqual(signer.sign(host: MitmSigner.checkHost, spki: leafSPKI(), hostnames: ["*.flclash.invalid",
                       MitmSigner.checkHost]).failure, .notListed)
    }

    func testRefusesAnythingButAP256Key() throws {
        _ = try signer.generate()
        var badPoint = leafSPKI()
        badPoint[badPoint.count - 1] ^= 0xff
        let rsa = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048,
                                         kSecAttrIsPermanent: false] as CFDictionary, nil)!
        let rsaPublic = SecKeyCopyExternalRepresentation(SecKeyCopyPublicKey(rsa)!, nil)! as Data
        for spki in [Data(), leafSPKI().dropLast(), leafSPKI() + Data([0]), badPoint, rsaPublic,
                     // A certificate the Core built is not a key either.
                     store.certificate!] {
            XCTAssertEqual(signer.sign(host: "api.example.com", spki: Data(spki), hostnames: list).failure, .badKey)
        }
    }

    func testRefusesWithoutARootOrPastIt() throws {
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure, .noRoot)
        let root = try signer.generate()
        clock = root.notAfter.addingTimeInterval(1)
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure, .rootExpired)
    }

    // MARK: what gets signed

    func testSignsALeafForTheListedHostAndKeyOnly() throws {
        let root = try signer.generate()
        let spki = leafSPKI()
        let result = signer.sign(host: "API.Example.com.", spki: spki, hostnames: list)
        guard case let .success((leaf, ca)) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(ca, root.der)
        XCTAssertEqual(try MitmRootReader.spki(of: leaf), spki)
        XCTAssertTrue(evaluate(leaf, ca, host: "api.example.com"))
        XCTAssertFalse(evaluate(leaf, ca, host: "www.example.com"))

        let validity = try MitmRootReader.validity(of: leaf)
        XCTAssertEqual(validity.notAfter.timeIntervalSince(validity.notBefore), 7 * 24 * 3600)
        XCTAssertFalse(evaluate(leaf, ca, host: "api.example.com", at: validity.notAfter.addingTimeInterval(60)))

        let certificate = SecCertificateCreateWithData(nil, leaf as CFData)!
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        XCTAssertEqual(commonName as String?, "api.example.com")

        // The leaf cannot sign another certificate.
        let fake = try MitmCertificateBuilder.leaf(
            host: "bank.example.org", spki: leafSPKI(), key: MemoryKey(), now: clock)
        XCTAssertFalse(evaluate(fake, ca, host: "bank.example.org"))
        XCTAssertTrue(leaf.range(of: Data([0x30, 0x03, 0x01, 0x01, 0xff])) == nil, "basicConstraints cA")
    }

    func testWildcardEntriesSignTheExactHostAsked() throws {
        _ = try signer.generate()
        guard case let .success((leaf, ca)) = signer.sign(host: "a.b.example.org", spki: leafSPKI(), hostnames: list)
        else { return XCTFail() }
        XCTAssertTrue(evaluate(leaf, ca, host: "a.b.example.org"))
        XCTAssertFalse(evaluate(leaf, ca, host: "c.b.example.org"))
        XCTAssertNil(leaf.range(of: Data("*.".utf8)))
    }

    func testRootIsAOneYearCAForLeavesOnly() throws {
        let root = try signer.generate()
        XCTAssertEqual(root.notAfter.timeIntervalSince(root.notBefore), 365 * 24 * 3600)
        XCTAssertEqual(root.subject, "Flash 本机解密证书（仅此 Mac）")
        XCTAssertTrue(root.pem.hasPrefix("-----BEGIN CERTIFICATE-----\n"))
        XCTAssertEqual(root.fingerprint.count, 32 * 3 - 1)
        let certificate = SecCertificateCreateWithData(nil, root.der as CFData)
        XCTAssertNotNil(certificate)
        // extKeyUsage: serverAuth alone.
        XCTAssertNotNil(root.der.range(of: Data([0x06, 0x03, 0x55, 0x1d, 0x25, 0x04, 0x0c, 0x30, 0x0a, 0x06, 0x08,
                                                 0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01])))
        // basicConstraints: critical, cA true, pathLen 0.
        XCTAssertNotNil(root.der.range(of: Data([0x01, 0x01, 0xff, 0x04, 0x08, 0x30, 0x06, 0x01, 0x01, 0xff,
                                                 0x02, 0x01, 0x00])))
        XCTAssertEqual(try MitmRootReader.spki(of: root.der), MitmCertificateBuilder.spki(x963: store.key!.publicKeyX963))
    }

    func testCheckCertificateIsForTheCheckHostOnly() throws {
        XCTAssertEqual(signer.checkCertificate().failure, .noRoot)
        _ = try signer.generate()
        identity = "failed"
        guard case let .success((leaf, ca)) = signer.checkCertificate() else { return XCTFail() }
        XCTAssertTrue(evaluate(leaf, ca, host: MitmSigner.checkHost))
    }

    // MARK: lifecycle

    func testGenerateReplacesAndDeleteForgets() throws {
        let first = try signer.generate()
        XCTAssertEqual(try signer.certificate(), first)
        guard case let .success((oldLeaf, _)) = signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list)
        else { return XCTFail() }

        let second = try signer.generate()
        XCTAssertNotEqual(first.der, second.der)
        XCTAssertEqual(store.deletes, 2)
        XCTAssertFalse(evaluate(oldLeaf, second.der, host: "api.example.com"))

        try signer.delete()
        XCTAssertNil(store.key)
        XCTAssertNil(store.certificate)
        XCTAssertNil(try signer.certificate())
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure, .noRoot)
    }

    func testALeftoverCertificateFailsDeleteButNotGenerate() throws {
        _ = try signer.generate()
        store.leftovers = [NSError(domain: NSOSStatusErrorDomain, code: Int(errAuthorizationCanceled))]
        XCTAssertNotNil(try signer.generate().der)
        XCTAssertThrowsError(try signer.delete()) { XCTAssertTrue($0 is MitmLeftovers) }
        XCTAssertNil(store.key)
        XCTAssertNil(try signer.certificate())
    }

    func testDeletionRemovesTheKeyFirstAndTriesEveryCertificate() throws {
        struct Refused: Error {}
        var steps = [String]()
        let errors = try MitmDeletion.run(
            deleteKey: { steps.append("key") },
            certificates: { steps.append("list"); return ["a", "b"] },
            removeTrust: { steps.append("trust " + $0); if $0 == "a" { throw Refused() } },
            deleteCertificate: { steps.append("delete " + $0); if $0 == "b" { throw Refused() } })
        XCTAssertEqual(steps, ["key", "list", "trust a", "delete a", "trust b", "delete b"])
        XCTAssertEqual(errors.count, 2)

        steps = []
        XCTAssertThrowsError(try MitmDeletion.run(
            deleteKey: { throw Refused() }, certificates: { steps.append("list"); return ["a"] },
            removeTrust: { _ in steps.append("trust") }, deleteCertificate: { _ in steps.append("delete") }))
        XCTAssertEqual(steps, [])

        let listing = try MitmDeletion.run(
            deleteKey: {}, certificates: { () throws -> [String] in throw Refused() },
            removeTrust: { _ in }, deleteCertificate: { _ in })
        XCTAssertEqual(listing.count, 1)
    }

    func testCertificateNeedsTheKeyItWasMadeFor() throws {
        _ = try signer.generate()
        let saved = store.certificate
        store.key = MemoryKey()
        let fresh = MitmSigner(store: store, coreIdentity: { "verified" }, now: { [unowned self] in clock })
        XCTAssertNil(try fresh.certificate())
        store.key = nil
        store.certificate = saved
        XCTAssertNil(try fresh.certificate())
    }

    func testExternalKeyOrCertificateRemovalInvalidatesCachedSigner() throws {
        _ = try signer.generate()
        XCTAssertNotNil(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).success)
        store.key = nil
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure, .noRoot)
        XCTAssertEqual(signer.checkCertificate().failure, .noRoot)
        _ = try signer.generate()
        store.certificate = nil
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure, .noRoot)
        XCTAssertNil(try signer.refreshRoot())
    }

    func testCachedLeafIsPerHostAndKey() throws {
        _ = try signer.generate()
        let spki = leafSPKI()
        let first = signer.sign(host: "api.example.com", spki: spki, hostnames: list).success
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success, first)
        XCTAssertNotEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).success, first)
        // A cached leaf still needs the host on the list now.
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: []).failure, .notListed)
    }

    func testCachedLeafIsIssuedAgainBeforeItExpires() throws {
        _ = try signer.generate()
        let spki = leafSPKI()
        let first = try XCTUnwrap(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success)
        let expiry = try MitmRootReader.validity(of: first).notAfter
        clock = expiry.addingTimeInterval(-MitmSigner.leafRenewal - 60)
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success, first)
        clock = expiry.addingTimeInterval(-MitmSigner.leafRenewal + 60)
        let second = try XCTUnwrap(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success)
        XCTAssertNotEqual(second, first)
        XCTAssertGreaterThan(try MitmRootReader.validity(of: second).notAfter, expiry)
        clock = expiry.addingTimeInterval(3600)
        let third = try XCTUnwrap(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success)
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success, third)
    }

    func testLeafNeverOutlivesTheRoot() throws {
        let root = try signer.generate()
        let rootExpiry = try MitmRootReader.validity(of: root.der).notAfter
        clock = rootExpiry.addingTimeInterval(-2 * 24 * 3600)
        let spki = leafSPKI()
        let leaf = try XCTUnwrap(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success)
        XCTAssertEqual(try MitmRootReader.validity(of: leaf).notAfter, rootExpiry)
        // The last day of the root reuses its leaf rather than signing one per request.
        clock = rootExpiry.addingTimeInterval(-3600)
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success, leaf)
    }
}

private extension Result where Success == (leaf: Data, ca: Data), Failure == MitmSignError {
    var failure: MitmSignError? {
        if case let .failure(error) = self { return error }
        return nil
    }

    var success: Data? {
        if case let .success((leaf, _)) = self { return leaf }
        return nil
    }
}

// MARK: - concurrency (MitmSignerDispatcher and a thread-safe MitmSigner)

/// Counts leaf signatures in flight across every key a store made.
private final class SignProbe {
    private let condition = NSCondition()
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var started = 0

    func enter() {
        condition.lock()
        inFlight += 1
        started += 1
        maxInFlight = max(maxInFlight, inFlight)
        condition.broadcast()
        condition.unlock()
    }

    func leave() {
        condition.lock()
        inFlight -= 1
        condition.broadcast()
        condition.unlock()
    }

    var current: Int { condition.lock(); defer { condition.unlock() }; return inFlight }
    var startedCount: Int { condition.lock(); defer { condition.unlock() }; return started }
    var maximum: Int { condition.lock(); defer { condition.unlock() }; return maxInFlight }

    func reset() {
        condition.lock()
        maxInFlight = inFlight
        started = 0
        condition.unlock()
    }

    /// Waits until `count` leaf signatures are in flight at once.
    func await(inFlight count: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while inFlight < count {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }
}

/// A software key whose leaf signatures can be held at a gate. The check
/// leaf (for MitmSigner.checkHost) and a root never wait, nor count.
private final class GatedKey: MitmCAKey {
    let privateKey = P256.Signing.PrivateKey()
    let probe: SignProbe
    let jitter: Bool
    private let gate = NSCondition()
    private var closed = false
    private static let checkHost = Data(MitmSigner.checkHost.utf8)

    init(probe: SignProbe, jitter: Bool) {
        self.probe = probe
        self.jitter = jitter
    }

    var publicKeyX963: Data { privateKey.publicKey.x963Representation }

    func close() { gate.lock(); closed = true; gate.unlock() }
    func open() { gate.lock(); closed = false; gate.broadcast(); gate.unlock() }

    func sign(_ message: Data) throws -> Data {
        // A root's basicConstraints (critical, cA true) marks its own TBS.
        let leaf = message.range(of: Self.checkHost) == nil
            && message.range(of: Data([0x01, 0x01, 0xff, 0x04, 0x08, 0x30, 0x06, 0x01, 0x01, 0xff])) == nil
        if leaf {
            probe.enter()
            gate.lock()
            while closed { gate.wait() }
            gate.unlock()
            if jitter { usleep(UInt32.random(in: 0...4000)) }
        }
        defer { if leaf { probe.leave() } }
        return try privateKey.signature(for: message).derRepresentation
    }
}

/// An in-memory store safe to use from several threads.
private final class LockedStore: MitmCAStore {
    let probe = SignProbe()
    var jitter = false
    private let lock = NSLock()
    private var key: GatedKey?
    private var der: Data?

    var currentKey: GatedKey? { lock.lock(); defer { lock.unlock() }; return key }

    func loadKey() throws -> MitmCAKey? { lock.lock(); defer { lock.unlock() }; return key }

    func createKey() throws -> MitmCAKey {
        lock.lock()
        defer { lock.unlock() }
        key = GatedKey(probe: probe, jitter: jitter)
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

    /// Another root put in place behind the signer's back.
    func replaceExternally() throws {
        let key = GatedKey(probe: probe, jitter: jitter)
        let der = try MitmCertificateBuilder.root(key: key, now: Date())
        lock.lock()
        self.key = key
        self.der = der
        lock.unlock()
    }
}

/// Identity answers, counted, safe to call from several threads.
private final class IdentitySource {
    private let lock = NSLock()
    private var calls = 0
    private(set) var answers = [String]()
    private let answer: (Int) -> String

    init(_ answer: @escaping (Int) -> String = { _ in "verified" }) { self.answer = answer }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
        let value = answer(calls)
        answers.append(value)
        return value
    }

    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return answers }
}

/// Results gathered from several threads.
private final class Collected<T> {
    private let lock = NSLock()
    private var items = [T]()
    func add(_ item: T) { lock.lock(); items.append(item); lock.unlock() }
    var all: [T] { lock.lock(); defer { lock.unlock() }; return items }
}

final class MitmSignerConcurrencyTests: XCTestCase {
    private typealias SignResult = Result<(leaf: Data, ca: Data), MitmSignError>
    private let list = ["*.example.com"]

    private func spki() -> Data {
        MitmCertificateBuilder.spki(x963: P256.Signing.PrivateKey().publicKey.x963Representation)
    }

    private func verifies(_ leaf: Data, _ root: Data, host: String) -> Bool {
        let certificates = [leaf, root].map { SecCertificateCreateWithData(nil, $0 as CFData)! }
        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(
            certificates as CFArray, SecPolicyCreateSSL(true, host as CFString), &trust) == errSecSuccess
        else { return false }
        SecTrustSetAnchorCertificates(trust!, [certificates[1]] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust!, true)
        SecTrustSetNetworkFetchAllowed(trust!, false)
        return SecTrustEvaluateWithError(trust!, nil)
    }

    private func wait(_ group: DispatchGroup, _ seconds: TimeInterval = 10, _ what: String = "work") {
        XCTAssertEqual(group.wait(timeout: .now() + seconds), .success, "\(what) did not finish: deadlock?")
    }

    // 1. Every sign asks who the Core is, and answers with its own account.
    func testEverySignChecksTheCoreAndKeepsItsOwnIdentity() throws {
        let store = LockedStore()
        store.jitter = true
        let identity = IdentitySource { $0 % 2 == 0 ? "failed:stage\($0)" : "verified" }
        let signer = MitmSigner(store: store, coreIdentity: identity.next)
        _ = try signer.generate()
        let dispatcher = MitmSignerDispatcher()
        let outcomes = Collected<MitmSignOutcome>()
        let group = DispatchGroup()
        for index in 0..<64 {
            group.enter()
            dispatcher.run(.sign) {
                outcomes.add(signer.signReporting(host: "h\(index).example.com", spki: self.spki(),
                                                  hostnames: self.list))
                group.leave()
            }
        }
        wait(group)
        XCTAssertEqual(identity.count, 64)
        var failed = [String]()
        for outcome in outcomes.all {
            if outcome.identity == "verified" {
                XCTAssertNotNil(outcome.result.success)
            } else {
                XCTAssertEqual(outcome.result.failure, .coreIdentity)
                failed.append(outcome.identity)
            }
        }
        XCTAssertEqual(failed.count, 32)
        // Each refusal reports the answer its own check got, none twice.
        XCTAssertEqual(Set(failed), Set(identity.all.filter { $0 != "verified" }))
        XCTAssertEqual(Set(failed).count, 32)
    }

    // 2. A new root while signs are in flight: the barrier waits for them, and
    // no sign submitted after it uses the old root.
    func testRotationMidBurstNeverSignsWithTheOldRoot() throws {
        let store = LockedStore()
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        let first = try signer.generate()
        let oldKey = try XCTUnwrap(store.currentKey)
        oldKey.close()
        let dispatcher = MitmSignerDispatcher()
        let before = Collected<(String, SignResult)>()
        let after = Collected<(String, SignResult)>()
        let group = DispatchGroup()
        for index in 0..<4 {
            group.enter()
            dispatcher.run(.sign) {
                let host = "b\(index).example.com"
                before.add((host, signer.sign(host: host, spki: self.spki(), hostnames: self.list)))
                group.leave()
            }
        }
        XCTAssertTrue(store.probe.await(inFlight: 4))
        var second: MitmRootInfo?
        var inFlightAtGenerate = -1
        group.enter()
        dispatcher.run(.barrier) {
            inFlightAtGenerate = store.probe.current
            second = try? signer.generate()
            group.leave()
        }
        for index in 0..<8 {
            group.enter()
            dispatcher.run(.sign) {
                let host = "a\(index).example.com"
                after.add((host, signer.sign(host: host, spki: self.spki(), hostnames: self.list)))
                group.leave()
            }
        }
        usleep(200_000)
        // The barrier holds back every later sign while the first four wait.
        XCTAssertEqual(store.probe.startedCount, 4)
        XCTAssertNil(second)
        oldKey.open()
        wait(group)
        XCTAssertEqual(inFlightAtGenerate, 0, "a sign was in flight while the root changed")
        let newRoot = try XCTUnwrap(second)
        XCTAssertNotEqual(newRoot.der, first.der)
        for (host, result) in before.all {
            guard case let .success((leaf, ca)) = result else { XCTFail("\(result)"); continue }
            XCTAssertEqual(ca, first.der)
            XCTAssertTrue(verifies(leaf, ca, host: host))
        }
        XCTAssertEqual(after.all.count, 8)
        for (host, result) in after.all {
            guard case let .success((leaf, ca)) = result else { XCTFail("\(result)"); continue }
            XCTAssertEqual(ca, newRoot.der)
            XCTAssertTrue(verifies(leaf, ca, host: host))
            XCTAssertFalse(verifies(leaf, first.der, host: host))
        }
    }

    // 2b. The second line, without the barrier: a root replaced in the store
    // while a sign is in flight, seen by any other read, voids that sign.
    func testARootReplacedMidSignRefusesThatSign() throws {
        let store = LockedStore()
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        _ = try signer.generate()
        let key = try XCTUnwrap(store.currentKey)
        key.close()
        var result: SignResult?
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            result = signer.sign(host: "x.example.com", spki: self.spki(), hostnames: self.list)
            group.leave()
        }
        XCTAssertTrue(store.probe.await(inFlight: 1))
        try store.replaceExternally()
        let fresh = try XCTUnwrap(try signer.refreshRoot())
        key.open()
        wait(group)
        XCTAssertEqual(result?.failure, .noRoot)
        // The next sign gets the new root.
        guard case let .success((leaf, ca)) = signer.sign(host: "x.example.com", spki: spki(), hostnames: list)
        else { return XCTFail() }
        XCTAssertEqual(ca, fresh.der)
        XCTAssertTrue(verifies(leaf, ca, host: "x.example.com"))
    }

    // 3. The root deleted from the store (outside the app) mid-sign: once any
    // read sees it gone — here a check on its own lane — the sign refuses.
    func testExternalDeletionMidSignRefuses() throws {
        let store = LockedStore()
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        _ = try signer.generate()
        let key = try XCTUnwrap(store.currentKey)
        key.close()
        let dispatcher = MitmSignerDispatcher()
        let results = Collected<SignResult>()
        let group = DispatchGroup()
        for index in 0..<4 {
            group.enter()
            dispatcher.run(.sign) {
                results.add(signer.sign(host: "d\(index).example.com", spki: self.spki(), hostnames: self.list))
                group.leave()
            }
        }
        XCTAssertTrue(store.probe.await(inFlight: 4))
        _ = try store.deleteAll()
        let checked = expectation(description: "certificate")
        dispatcher.run(.check) {
            XCTAssertNil(try? signer.refreshRoot())
            checked.fulfill()
        }
        wait(for: [checked], timeout: 2)
        key.open()
        wait(group)
        XCTAssertEqual(results.all.map(\.failure), Array(repeating: .noRoot, count: 4))
        XCTAssertEqual(signer.sign(host: "d0.example.com", spki: spki(), hostnames: list).failure, .noRoot)
    }

    // 3b. delete() as a barrier: signs in flight finish first; every sign
    // after it is refused. Called directly mid-sign, it voids that sign too.
    func testDeleteIsABarrierAndRefusesAfter() throws {
        let store = LockedStore()
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        _ = try signer.generate()
        let key = try XCTUnwrap(store.currentKey)
        key.close()
        let dispatcher = MitmSignerDispatcher()
        let before = Collected<SignResult>()
        let after = Collected<SignResult>()
        let group = DispatchGroup()
        for index in 0..<4 {
            group.enter()
            dispatcher.run(.sign) {
                before.add(signer.sign(host: "b\(index).example.com", spki: self.spki(), hostnames: self.list))
                group.leave()
            }
        }
        XCTAssertTrue(store.probe.await(inFlight: 4))
        var inFlightAtDelete = -1
        group.enter()
        dispatcher.run(.barrier) {
            inFlightAtDelete = store.probe.current
            do { try signer.delete() } catch { XCTFail("\(error)") }
            group.leave()
        }
        for index in 0..<4 {
            group.enter()
            dispatcher.run(.sign) {
                after.add(signer.sign(host: "a\(index).example.com", spki: self.spki(), hostnames: self.list))
                group.leave()
            }
        }
        usleep(100_000)
        key.open()
        wait(group)
        XCTAssertEqual(inFlightAtDelete, 0)
        XCTAssertEqual(before.all.compactMap(\.success).count, 4)
        XCTAssertEqual(after.all.map(\.failure), Array(repeating: .noRoot, count: 4))

        // Directly, without the barrier.
        _ = try signer.generate()
        let second = try XCTUnwrap(store.currentKey)
        second.close()
        var result: SignResult?
        let direct = DispatchGroup()
        direct.enter()
        DispatchQueue.global().async {
            result = signer.sign(host: "x.example.com", spki: self.spki(), hostnames: self.list)
            direct.leave()
        }
        XCTAssertTrue(store.probe.await(inFlight: 1))
        try signer.delete()
        second.open()
        wait(direct)
        XCTAssertEqual(result?.failure, .noRoot)
    }

    // 4. Signs finishing out of order still answer their own request.
    func testOutOfOrderCompletionKeepsEachRequestsHostAndKey() throws {
        let store = LockedStore()
        store.jitter = true
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        _ = try signer.generate()
        let dispatcher = MitmSignerDispatcher()
        let answers = Collected<(host: String, spki: Data, result: SignResult)>()
        let order = Collected<Int>()
        let group = DispatchGroup()
        for index in 0..<64 {
            let host = "o\(index).example.com"
            let key = spki()
            group.enter()
            dispatcher.run(.sign) {
                answers.add((host, key, signer.sign(host: host, spki: key, hostnames: self.list)))
                order.add(index)
                group.leave()
            }
        }
        wait(group)
        XCTAssertNotEqual(order.all, Array(0..<64), "completions were expected out of order")
        XCTAssertEqual(answers.all.count, 64)
        for answer in answers.all {
            guard case let .success((leaf, ca)) = answer.result else { XCTFail("\(answer.result)"); continue }
            XCTAssertEqual(try MitmRootReader.spki(of: leaf), answer.spki)
            XCTAssertTrue(verifies(leaf, ca, host: answer.host))
            var name: CFString?
            SecCertificateCopyCommonName(SecCertificateCreateWithData(nil, leaf as CFData)!, &name)
            XCTAssertEqual(name as String?, answer.host)
        }
    }

    // 5. Signs, checks, generate and delete mixed, 50 rounds: no deadlock,
    // and every leaf handed out verifies against the root it came with.
    func testMixedOperationsNeverDeadlock() throws {
        let bridge = DispatchQueue(label: "test.bridge")
        let flooding = DispatchGroup()
        var stop = false
        let stopLock = NSLock()
        // Keeps the bridge busy with a bounded backlog of short jobs.
        let backlog = DispatchSemaphore(value: 8)
        DispatchQueue.global().async(group: flooding) {
            while true {
                stopLock.lock(); let done = stop; stopLock.unlock()
                if done { return }
                backlog.wait()
                bridge.async { usleep(50); backlog.signal() }
            }
        }
        defer {
            stopLock.lock(); stop = true; stopLock.unlock()
            flooding.wait()
        }
        // As the app's identity check does: a sync onto a busy serial queue.
        let identity: () -> String = { bridge.sync { "verified" } }
        let store = LockedStore()
        store.jitter = true
        let signer = MitmSigner(store: store, coreIdentity: identity)
        let dispatcher = MitmSignerDispatcher()
        for round in 0..<50 {
            _ = try? signer.generate()
            let group = DispatchGroup()
            let results = Collected<(String, SignResult)>()
            for index in 0..<16 {
                group.enter()
                dispatcher.run(.sign) {
                    let host = "m\(index).example.com"
                    results.add((host, signer.sign(host: host, spki: self.spki(), hostnames: self.list)))
                    group.leave()
                }
                switch index {
                case 3: group.enter(); dispatcher.run(.barrier) { _ = try? signer.generate(); group.leave() }
                case 6: group.enter(); dispatcher.run(.check) { _ = try? signer.refreshRoot(); group.leave() }
                case 8: group.enter(); dispatcher.run(.check) { _ = signer.checkCertificate(); group.leave() }
                case 10: group.enter(); dispatcher.run(.check) { _ = identity(); group.leave() }
                case 12 where round % 2 == 0:
                    group.enter(); dispatcher.run(.barrier) { try? signer.delete(); group.leave() }
                case 13: group.enter(); dispatcher.run(.barrier) { _ = try? signer.generate(); group.leave() }
                default: break
                }
            }
            XCTAssertEqual(group.wait(timeout: .now() + 5), .success, "round \(round) deadlocked")
            for (host, result) in results.all {
                switch result {
                case let .success((leaf, ca)): XCTAssertTrue(verifies(leaf, ca, host: host))
                case let .failure(error): XCTAssertEqual(error, .noRoot)
                }
            }
        }
    }

    // 6. Width: no more than four leaves at once, and more than one.
    func testSignWidthIsBounded() throws {
        for (width, expected) in [(MitmSignerDispatcher.signWidth, 2...4), (1, 1...1)] {
            let store = LockedStore()
            store.jitter = true
            let signer = MitmSigner(store: store, coreIdentity: { "verified" })
            _ = try signer.generate()
            store.probe.reset()
            let dispatcher = MitmSignerDispatcher(signWidth: width)
            let group = DispatchGroup()
            for index in 0..<64 {
                group.enter()
                dispatcher.run(.sign) {
                    _ = signer.sign(host: "w\(index).example.com", spki: self.spki(), hostnames: self.list)
                    group.leave()
                }
            }
            wait(group)
            XCTAssertTrue(expected.contains(store.probe.maximum), "width \(width): \(store.probe.maximum)")
        }
        XCTAssertEqual(MitmSignerDispatcher.signWidth, 4)
        XCTAssertEqual(MitmSignerDispatcher.lane(for: "sign"), .sign)
        XCTAssertEqual(MitmSignerDispatcher.lane(for: "generate"), .barrier)
        XCTAssertEqual(MitmSignerDispatcher.lane(for: "delete"), .barrier)
        for method in ["certificate", "checkCertificate", "coreIdentity", "unknown"] {
            XCTAssertEqual(MitmSignerDispatcher.lane(for: method), .check, method)
        }
    }

    // 7. The leaf cache hands out a leaf only with the root that signed it,
    // even with a new root arriving amid the requests.
    func testCachedLeavesStayPairedWithTheirRoot() throws {
        let store = LockedStore()
        store.jitter = true
        let signer = MitmSigner(store: store, coreIdentity: { "verified" })
        _ = try signer.generate()
        let dispatcher = MitmSignerDispatcher()
        let key = spki()
        let results = Collected<SignResult>()
        let group = DispatchGroup()
        for index in 0..<48 {
            group.enter()
            dispatcher.run(.sign) {
                results.add(signer.sign(host: "c.example.com", spki: key, hostnames: self.list))
                group.leave()
            }
            if index == 20 {
                group.enter()
                dispatcher.run(.barrier) { _ = try? signer.generate(); group.leave() }
            }
        }
        wait(group)
        var roots = Set<Data>()
        for result in results.all {
            guard case let .success((leaf, ca)) = result else { XCTFail("\(result)"); continue }
            XCTAssertTrue(verifies(leaf, ca, host: "c.example.com"))
            roots.insert(ca)
        }
        XCTAssertTrue((1...2).contains(roots.count))
    }

    // 8. A check sent behind 20 blocked signs (4 in flight, 16 queued) is
    // answered at once, while every sign is still waiting.
    func testChecksAreNotStarvedBySigns() throws {
        let store = LockedStore()
        let identity = IdentitySource()
        let signer = MitmSigner(store: store, coreIdentity: identity.next)
        _ = try signer.generate()
        let key = try XCTUnwrap(store.currentKey)
        key.close()
        let dispatcher = MitmSignerDispatcher()
        let signs = DispatchGroup()
        let done = Collected<Int>()
        for index in 0..<20 {
            signs.enter()
            dispatcher.run(MitmSignerDispatcher.lane(for: "sign")) {
                _ = signer.sign(host: "s\(index).example.com", spki: self.spki(), hostnames: self.list)
                done.add(index)
                signs.leave()
            }
        }
        XCTAssertTrue(store.probe.await(inFlight: 4))
        for method in ["certificate", "checkCertificate", "coreIdentity"] {
            let answered = expectation(description: method)
            let clock = Date()
            dispatcher.run(MitmSignerDispatcher.lane(for: method)) {
                switch method {
                case "certificate": XCTAssertNotNil(try? signer.refreshRoot())
                case "checkCertificate": XCTAssertNotNil(signer.checkCertificate().success)
                default: XCTAssertEqual(identity.next(), "verified")
                }
                answered.fulfill()
            }
            wait(for: [answered], timeout: 2)
            XCTAssertLessThan(Date().timeIntervalSince(clock), 1, method)
        }
        XCTAssertTrue(done.all.isEmpty, "signs finished before the checks: nothing proved")
        XCTAssertEqual(store.probe.current, 4)
        key.open()
        wait(signs)
        XCTAssertEqual(done.all.count, 20)
    }
}
