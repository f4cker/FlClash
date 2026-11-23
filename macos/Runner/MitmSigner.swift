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

/// The passphrase of each p12 CA the Core signs with, by its fingerprint:
/// the login keychain in the app, memory in tests.
protocol MitmPassphraseStore: AnyObject {
    func read(fingerprint: String) throws -> String?
    func write(fingerprint: String, passphrase: String) throws
    func delete(fingerprint: String) throws
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

/// What one sign was told about the Core ("verified", "none" or
/// "failed:<stage>") with its result: each sign carries its own, so
/// concurrent signs never read another's.
struct MitmSignOutcome {
    let result: Result<(leaf: Data, ca: Data), MitmSignError>
    let identity: String
}

/// Signs leaves for the Core from {host, SPKI} alone, after checking who asks
/// and that the user listed the host.
///
/// Thread model: safe to call from several threads. Keychain reads and the
/// ECDSA of a leaf run outside `lock`; the root, its key, the leaf cache and
/// `generation` change only under it. Every sign re-reads the root from the
/// store (no root cache), signs with that snapshot, and refuses with .noRoot
/// when the root it read was replaced or removed before it finished.
/// generate() and delete() hold `lock` throughout; MitmSignerDispatcher also
/// runs them alone, with no sign in flight.
final class MitmSigner {
    /// The trust check's own host, signed for the app and never for the Core.
    static let checkHost = "mitm-check.flclash.invalid"
    static let cacheLimit = 1024
    /// A cached leaf is issued again once less than this is left of it.
    static let leafRenewal: TimeInterval = 24 * 3600

    private struct Snapshot {
        let key: MitmCAKey
        let root: MitmRootInfo
        let generation: UInt64
    }

    private let store: MitmCAStore
    private let coreIdentity: () -> String
    private let now: () -> Date
    private let lock = NSLock()
    private var key: MitmCAKey?
    private var root: MitmRootInfo?
    private var leaves = [String: (der: Data, notAfter: Date)]()
    /// Moves whenever the root held here changes or goes.
    private var generation: UInt64 = 0
    /// Store reads are numbered; an older read never overwrites a newer one.
    private var nextRead: UInt64 = 1
    private var appliedRead: UInt64 = 0

    init(store: MitmCAStore, coreIdentity: @escaping () -> String, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.coreIdentity = coreIdentity
        self.now = now
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    /// The root this signer holds, read from the store when it holds none.
    func certificate() throws -> MitmRootInfo? {
        if let root = locked({ root }) { return root }
        return try refresh()?.root
    }

    /// The key and root in the store, if they belong together. No lock held.
    private func readStore() throws -> (key: MitmCAKey, root: MitmRootInfo)? {
        guard let key = try store.loadKey(), let der = try store.loadCertificate(),
              let point = try? MitmCertificateBuilder.p256Point(spki: try MitmRootReader.spki(of: der)),
              point == key.publicKeyX963 else { return nil }
        let validity = try MitmRootReader.validity(of: der)
        return (key, MitmRootInfo(der: der, notBefore: validity.notBefore, notAfter: validity.notAfter))
    }

    /// Reads the store and adopts what it found, unless a later read already
    /// spoke: then this read stands only if it found the same root.
    private func refresh() throws -> Snapshot? {
        let ticket = locked { () -> UInt64 in
            defer { nextRead += 1 }
            return nextRead
        }
        let fresh = try readStore()
        return locked { () -> Snapshot? in
            if ticket < appliedRead {
                guard let fresh, let key, let root, root.der == fresh.root.der else { return nil }
                return Snapshot(key: key, root: root, generation: generation)
            }
            appliedRead = ticket
            guard let fresh else {
                if root != nil { generation &+= 1 }
                key = nil
                root = nil
                leaves.removeAll()
                return nil
            }
            if root?.der != fresh.root.der {
                generation &+= 1
                leaves.removeAll()
            }
            key = fresh.key
            root = fresh.root
            return Snapshot(key: fresh.key, root: fresh.root, generation: generation)
        }
    }

    /// Holds `lock` throughout, keychain calls included (delete, create,
    /// sign the root, save; in the app these go to securityd and may be slow
    /// or prompt). That stalls no sign or check only because
    /// MitmSignerDispatcher runs generate and delete exclusively, with none
    /// in flight; called beside signs directly, they would wait on it.
    func generate() throws -> MitmRootInfo {
        lock.lock()
        defer { lock.unlock() }
        forget()
        _ = try store.deleteAll()
        let key = try store.createKey()
        let issued = now()
        let der = try MitmCertificateBuilder.root(key: key, now: issued)
        try store.saveCertificate(der)
        let root = MitmRootInfo(
            der: der, notBefore: issued.addingTimeInterval(-MitmCertificateBuilder.backdate),
            notAfter: issued.addingTimeInterval(MitmCertificateBuilder.rootLifetime - MitmCertificateBuilder.backdate))
        self.key = key
        self.root = root
        return root
    }

    /// Holds `lock` across the keychain deletion; see generate().
    func delete() throws {
        let leftovers = try locked { () throws -> [Error] in
            forget()
            return try store.deleteAll()
        }
        if !leftovers.isEmpty { throw MitmLeftovers(errors: leftovers) }
    }

    /// The legacy root goes only while it is the one named: a root generated
    /// since, or none, is left alone. The p12 CA lives under another name.
    func deleteLegacy(fingerprint: String) throws -> Bool {
        let leftovers = try locked { () throws -> [Error]? in
            guard let found = try readStore(), found.root.fingerprint == fingerprint else { return nil }
            forget()
            return try store.deleteAll()
        }
        guard let leftovers else { return false }
        if !leftovers.isEmpty { throw MitmLeftovers(errors: leftovers) }
        return true
    }

    /// Under `lock`: drops the root, and any read begun before now.
    private func forget() {
        key = nil
        root = nil
        leaves.removeAll()
        generation &+= 1
        appliedRead = nextRead
        nextRead += 1
    }

    // A retained SecKey and root do not prove that either item is still in
    // the login keychain. Re-read both before every approval or trust probe.
    func refreshRoot() throws -> MitmRootInfo? {
        try refresh()?.root
    }

    func sign(host rawHost: String, spki: Data, hostnames: [String]) -> Result<(leaf: Data, ca: Data), MitmSignError> {
        signReporting(host: rawHost, spki: spki, hostnames: hostnames).result
    }

    /// The Core's identity is checked on every sign, before anything else.
    func signReporting(host rawHost: String, spki: Data, hostnames: [String]) -> MitmSignOutcome {
        let identity = coreIdentity()
        func outcome(_ result: Result<(leaf: Data, ca: Data), MitmSignError>) -> MitmSignOutcome {
            MitmSignOutcome(result: result, identity: identity)
        }
        guard identity == "verified" else { return outcome(.failure(.coreIdentity)) }
        let host = MitmHostPolicy.normalize(rawHost)
        guard host != Self.checkHost, MitmHostMatcher(hostnames).matches(host) else {
            return outcome(.failure(.notListed))
        }
        guard (try? MitmCertificateBuilder.p256Point(spki: spki)) != nil else { return outcome(.failure(.badKey)) }
        guard let snapshot = try? refresh() else { return outcome(.failure(.noRoot)) }
        return outcome(issue(host: host, spki: spki, snapshot))
    }

    func checkCertificate() -> Result<(leaf: Data, ca: Data), MitmSignError> {
        guard let snapshot = try? refresh() else { return .failure(.noRoot) }
        let point = P256.Signing.PrivateKey().publicKey.x963Representation
        return issue(host: Self.checkHost, spki: MitmCertificateBuilder.spki(x963: point), snapshot)
    }

    /// Signs with the snapshot's key outside the lock, then keeps the leaf
    /// only if the snapshot's root is still the one held.
    private func issue(host: String, spki: Data, _ snapshot: Snapshot) -> Result<(leaf: Data, ca: Data), MitmSignError> {
        let root = snapshot.root
        guard now() < root.notAfter else { return .failure(.rootExpired) }
        let cacheKey = host + "\n" + spki.base64EncodedString()
        let issued = now()
        var replaced = false
        let hit = locked { () -> (der: Data, notAfter: Date)? in
            guard generation == snapshot.generation else { replaced = true; return nil }
            return leaves[cacheKey]
        }
        if replaced { return .failure(.noRoot) }
        if let hit, hit.notAfter.timeIntervalSince(issued) >= Self.leafRenewal || hit.notAfter >= root.notAfter {
            return .success((hit.der, root.der))
        }
        guard let leaf = try? MitmCertificateBuilder.leaf(
            host: host, spki: spki, key: snapshot.key, now: issued, notAfterLimit: root.notAfter) else {
            return .failure(.signFailed)
        }
        return locked {
            // Replaced or removed while this leaf was being signed: refuse it.
            guard generation == snapshot.generation, self.root?.der == root.der else { return .failure(.noRoot) }
            if leaves.count >= Self.cacheLimit { leaves.removeAll() }
            leaves[cacheKey] = (leaf, MitmCertificateBuilder.leafNotAfter(now: issued, limit: root.notAfter))
            return .success((leaf, root.der))
        }
    }
}

/// Shared/exclusive admission: any number of shared holders at once, or one
/// exclusive holder alone. An exclusive turn is reserved when it is asked for
/// (reserveExclusive, on the submitting thread), and from then on no new
/// shared holder is admitted: work submitted after a generate or delete never
/// overtakes it, and a stream of signs never starves it.
final class MitmSignerGate {
    /// One reserved exclusive turn: used once, or given back unused.
    final class Reservation {
        fileprivate let gate: MitmSignerGate
        fileprivate var state = 0 // 0 reserved, 1 running or done, 2 given back

        fileprivate init(gate: MitmSignerGate) { self.gate = gate }

        /// Runs body exclusively, after the shared holders in flight finish.
        func run<T>(_ body: () throws -> T) rethrows -> T {
            gate.condition.lock()
            precondition(state == 0, "an exclusive reservation runs once")
            state = 1
            while gate.exclusive || gate.shared > 0 { gate.condition.wait() }
            gate.exclusiveWaiting -= 1
            gate.exclusive = true
            gate.condition.unlock()
            defer {
                gate.condition.lock()
                gate.exclusive = false
                gate.condition.broadcast()
                gate.condition.unlock()
            }
            return try body()
        }

        /// Gives the turn back if it never ran (its operation was cancelled).
        func releaseUnused() {
            gate.condition.lock()
            defer { gate.condition.unlock() }
            guard state == 0 else { return }
            state = 2
            gate.exclusiveWaiting -= 1
            gate.condition.broadcast()
        }
    }

    fileprivate let condition = NSCondition()
    fileprivate var shared = 0
    fileprivate var exclusive = false
    fileprivate var exclusiveWaiting = 0

    func withShared<T>(_ body: () throws -> T) rethrows -> T {
        condition.lock()
        while exclusive || exclusiveWaiting > 0 { condition.wait() }
        shared += 1
        condition.unlock()
        defer {
            condition.lock()
            shared -= 1
            if shared == 0 { condition.broadcast() }
            condition.unlock()
        }
        return try body()
    }

    /// Holds back new shared holders from now on, until the turn has run or
    /// been given back.
    func reserveExclusive() -> Reservation {
        condition.lock()
        exclusiveWaiting += 1
        condition.unlock()
        return Reservation(gate: self)
    }

    func withExclusive<T>(_ body: () throws -> T) rethrows -> T {
        try reserveExclusive().run(body)
    }
}

/// Where the signer channel's calls run, off the main thread:
/// - sign: up to `signWidth` at once;
/// - check (certificate, checkCertificate, coreIdentity, anything else): one
///   at a time on a lane of their own, so they never queue behind signs;
/// - barrier (generate, delete): alone. Reserved when submitted, it waits
///   for the signs and checks already running, and none starts until it is
///   done (including ones submitted earlier but not yet started), so a root
///   is never replaced or removed under a sign, and a sign submitted after
///   it never uses the root it replaced.
/// Flutter-free, so the tests run it without the app.
final class MitmSignerDispatcher {
    enum Lane { case sign, check, barrier }

    static let signWidth = 4

    static func lane(for method: String) -> Lane {
        switch method {
        case "sign": return .sign
        case "generate", "delete", "deleteLegacy": return .barrier
        default: return .check
        }
    }

    private let gate = MitmSignerGate()
    private let signs = OperationQueue()
    private let checks = OperationQueue()
    private let barriers = OperationQueue()

    init(signWidth: Int = MitmSignerDispatcher.signWidth) {
        for (queue, width, name) in [(signs, max(1, signWidth), "sign"), (checks, 1, "check"),
                                     (barriers, 1, "barrier")] {
            queue.name = "com.layoute.flash.mitm.signer." + name
            queue.maxConcurrentOperationCount = width
            queue.qualityOfService = .userInitiated
        }
    }

    func run(_ lane: Lane, _ work: @escaping () -> Void) {
        switch lane {
        case .sign: signs.addOperation { [gate] in gate.withShared(work) }
        case .check: checks.addOperation { [gate] in gate.withShared(work) }
        case .barrier:
            // Reserved here, on the submitting thread, so a sign or check
            // submitted after this call waits for it even while lanes idle.
            let reservation = gate.reserveExclusive()
            let operation = BlockOperation { reservation.run(work) }
            // Runs after the block, or instead of it when cancelled.
            operation.completionBlock = { reservation.releaseUnused() }
            barriers.addOperation(operation)
        }
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
