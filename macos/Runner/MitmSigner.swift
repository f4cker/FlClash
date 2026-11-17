import CryptoKit
import Foundation

/// Where the root lives: the login keychain in the app, memory in tests.
protocol MitmCAStore: AnyObject {
    func loadKey() throws -> MitmCAKey?
    /// A new non-extractable key, replacing none: the caller deletes first.
    func createKey() throws -> MitmCAKey
    func loadCertificate() throws -> Data?
    func saveCertificate(_ der: Data) throws
    func deleteAll() throws -> [Error]
}

struct MitmLeftovers: Error, CustomStringConvertible {
    let errors: [Error]
    var description: String { "key deleted; left behind: \(errors.map { String(describing: $0) })" }
}

enum MitmDeletion {
    /// The key goes first: a certificate or trust setting left behind cannot sign anything.
    static func run<Certificate>(
        deleteKey: () throws -> Void, certificates: () throws -> [Certificate],
        removeTrust: (Certificate) throws -> Void, deleteCertificate: (Certificate) throws -> Void
    ) throws -> [Error] {
        try deleteKey()
        var errors = [Error]()
        let found: [Certificate]
        do { found = try certificates() } catch { return [error] }
        for certificate in found {
            do { try removeTrust(certificate) } catch { errors.append(error) }
            do { try deleteCertificate(certificate) } catch { errors.append(error) }
        }
        return errors
    }
}

struct MitmRootInfo: Equatable {
    let der: Data
    let notBefore: Date
    let notAfter: Date

    var pem: String { MitmCertificateBuilder.pem(der) }
    var fingerprint: String { MitmCertificateBuilder.fingerprint(der) }
    var subject: String { MitmCertificateBuilder.rootName }
}

enum MitmSignError: String, Error {
    /// The Core asking is not the one the daemon started with the pinned identity.
    case coreIdentity
    case notListed
    case badKey
    case noRoot
    case rootExpired
    case signFailed
}

/// Signs leaves for the Core from {host, SPKI} alone, after checking who asks
/// and that the user listed the host. Not thread-safe: callers use one queue.
final class MitmSigner {
    /// The trust check's own host, signed for the app and never for the Core.
    static let checkHost = "mitm-check.flclash.invalid"
    static let cacheLimit = 1024
    /// A cached leaf is issued again once less than this is left of it.
    static let leafRenewal: TimeInterval = 24 * 3600

    private let store: MitmCAStore
    private let coreIdentity: () -> String
    private let now: () -> Date
    private var key: MitmCAKey?
    private var root: MitmRootInfo?
    private var leaves = [String: (der: Data, notAfter: Date)]()
    /// What the last sign was told about the Core: "verified", "none" or "failed:<stage>".
    private(set) var lastCoreIdentity = "none"

    init(store: MitmCAStore, coreIdentity: @escaping () -> String, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.coreIdentity = coreIdentity
        self.now = now
    }

    func certificate() throws -> MitmRootInfo? {
        if let root { return root }
        guard let key = try store.loadKey(), let der = try store.loadCertificate(),
              let point = try? MitmCertificateBuilder.p256Point(spki: try MitmRootReader.spki(of: der)),
              point == key.publicKeyX963 else { return nil }
        let validity = try MitmRootReader.validity(of: der)
        self.key = key
        root = MitmRootInfo(der: der, notBefore: validity.notBefore, notAfter: validity.notAfter)
        return root
    }

    func generate() throws -> MitmRootInfo {
        forget()
        _ = try store.deleteAll()
        let key = try store.createKey()
        let issued = now()
        let der = try MitmCertificateBuilder.root(key: key, now: issued)
        try store.saveCertificate(der)
        self.key = key
        root = MitmRootInfo(
            der: der, notBefore: issued.addingTimeInterval(-MitmCertificateBuilder.backdate),
            notAfter: issued.addingTimeInterval(MitmCertificateBuilder.rootLifetime - MitmCertificateBuilder.backdate))
        return root!
    }

    func delete() throws {
        forget()
        let leftovers = try store.deleteAll()
        if !leftovers.isEmpty { throw MitmLeftovers(errors: leftovers) }
    }

    private func forget() {
        key = nil
        root = nil
        leaves.removeAll()
    }

    func sign(host rawHost: String, spki: Data, hostnames: [String]) -> Result<(leaf: Data, ca: Data), MitmSignError> {
        lastCoreIdentity = coreIdentity()
        guard lastCoreIdentity == "verified" else { return .failure(.coreIdentity) }
        let host = MitmHostPolicy.normalize(rawHost)
        guard host != Self.checkHost, MitmHostMatcher(hostnames).matches(host) else { return .failure(.notListed) }
        guard (try? MitmCertificateBuilder.p256Point(spki: spki)) != nil else { return .failure(.badKey) }
        return issue(host: host, spki: spki)
    }

    func checkCertificate() -> Result<(leaf: Data, ca: Data), MitmSignError> {
        let point = P256.Signing.PrivateKey().publicKey.x963Representation
        return issue(host: Self.checkHost, spki: MitmCertificateBuilder.spki(x963: point))
    }

    private func issue(host: String, spki: Data) -> Result<(leaf: Data, ca: Data), MitmSignError> {
        guard let root = try? certificate(), let key else { return .failure(.noRoot) }
        guard now() < root.notAfter else { return .failure(.rootExpired) }
        let cacheKey = host + "\n" + spki.base64EncodedString()
        let issued = now()
        if let cached = leaves[cacheKey],
           cached.notAfter.timeIntervalSince(issued) >= Self.leafRenewal || cached.notAfter >= root.notAfter {
            return .success((cached.der, root.der))
        }
        guard let leaf = try? MitmCertificateBuilder.leaf(
            host: host, spki: spki, key: key, now: issued, notAfterLimit: root.notAfter) else {
            return .failure(.signFailed)
        }
        if leaves.count >= Self.cacheLimit { leaves.removeAll() }
        leaves[cacheKey] = (leaf, MitmCertificateBuilder.leafNotAfter(now: issued, limit: root.notAfter))
        return .success((leaf, root.der))
    }
}

enum MitmRootReader {
    enum Failure: Error { case malformed }

    private static func element(_ data: Data, at offset: inout Int) throws -> (tag: UInt8, range: Range<Int>) {
        let bytes = [UInt8](data)
        guard offset + 2 <= bytes.count else { throw Failure.malformed }
        let tag = bytes[offset]
        var length = Int(bytes[offset + 1])
        var start = offset + 2
        if length & 0x80 != 0 {
            let count = length & 0x7f
            guard count > 0, count <= 3, start + count <= bytes.count else { throw Failure.malformed }
            length = bytes[start..<start + count].reduce(0) { $0 << 8 | Int($1) }
            start += count
        }
        guard start + length <= bytes.count else { throw Failure.malformed }
        offset = start + length
        return (tag, start..<start + length)
    }

    private static func tbsFields(_ der: Data) throws -> [(tag: UInt8, range: Range<Int>)] {
        let data = Data(der)
        var offset = 0
        let certificate = try element(data, at: &offset)
        offset = certificate.range.lowerBound
        let tbs = try element(data, at: &offset)
        var fields = [(tag: UInt8, range: Range<Int>)]()
        offset = tbs.range.lowerBound
        while offset < tbs.range.upperBound {
            let start = offset
            let field = try element(data, at: &offset)
            fields.append((field.tag, start..<offset))
        }
        guard fields.count >= 7, fields[0].tag == 0xa0 else { throw Failure.malformed }
        return fields
    }

    static func spki(of der: Data) throws -> Data {
        let data = Data(der)
        return data.subdata(in: try tbsFields(data)[6].range)
    }

    static func validity(of der: Data) throws -> (notBefore: Date, notAfter: Date) {
        let data = Data(der)
        let field = try tbsFields(data)[4].range
        var offset = field.lowerBound
        let validity = try element(data, at: &offset)
        offset = validity.range.lowerBound
        let notBefore = try element(data, at: &offset)
        let notAfter = try element(data, at: &offset)
        return (try time(data, notBefore), try time(data, notAfter))
    }

    private static func time(_ data: Data, _ element: (tag: UInt8, range: Range<Int>)) throws -> Date {
        let text = String(decoding: data.subdata(in: element.range), as: UTF8.self)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = element.tag == 0x17 ? "yyMMddHHmmss'Z'" : "yyyyMMddHHmmss'Z'"
        // RFC 5280: a two-digit year from 50 is 19xx.
        formatter.twoDigitStartDate = Date(timeIntervalSince1970: -631_152_000)
        guard let date = formatter.date(from: text) else { throw Failure.malformed }
        return date
    }
}
