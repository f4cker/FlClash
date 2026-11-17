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

    func loadKey() throws -> MitmCAKey? { key }

    func createKey() throws -> MitmCAKey {
        let key = MemoryKey()
        self.key = key
        return key
    }

    func loadCertificate() throws -> Data? { certificate }
    func saveCertificate(_ der: Data) throws { certificate = der }

    func deleteAll() throws {
        deletes += 1
        key = nil
        certificate = nil
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
        for state in ["failed", "none", ""] {
            identity = state
            XCTAssertEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).failure,
                           .coreIdentity, state)
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

    func testCachedLeafIsPerHostAndKey() throws {
        _ = try signer.generate()
        let spki = leafSPKI()
        let first = signer.sign(host: "api.example.com", spki: spki, hostnames: list).success
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: list).success, first)
        XCTAssertNotEqual(signer.sign(host: "api.example.com", spki: leafSPKI(), hostnames: list).success, first)
        // A cached leaf still needs the host on the list now.
        XCTAssertEqual(signer.sign(host: "api.example.com", spki: spki, hostnames: []).failure, .notListed)
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
