import CryptoKit
import Foundation

/// Just enough DER to write the two certificates the app signs. Every field
/// is fixed here; the Core supplies only a host and a P-256 public key.
enum DER {
    static func length(_ count: Int) -> Data {
        if count < 0x80 { return Data([UInt8(count)]) }
        var bytes = [UInt8]()
        var rest = count
        while rest > 0 {
            bytes.insert(UInt8(rest & 0xff), at: 0)
            rest >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    static func tlv(_ tag: UInt8, _ content: Data) -> Data {
        Data([tag]) + length(content.count) + content
    }

    static func sequence(_ items: Data...) -> Data { tlv(0x30, items.reduce(Data(), +)) }
    static func sequence(_ items: [Data]) -> Data { tlv(0x30, items.reduce(Data(), +)) }
    static func set(_ items: Data...) -> Data { tlv(0x31, items.reduce(Data(), +)) }
    static func octetString(_ content: Data) -> Data { tlv(0x04, content) }
    static func utf8String(_ text: String) -> Data { tlv(0x0c, Data(text.utf8)) }
    static func boolean(_ value: Bool) -> Data { tlv(0x01, Data([value ? 0xff : 0x00])) }
    static let null = Data([0x05, 0x00])

    static func integer(_ bytes: Data) -> Data {
        var content = Data(bytes.drop { $0 == 0 })
        if content.isEmpty || content[content.startIndex] & 0x80 != 0 { content.insert(0, at: 0) }
        return tlv(0x02, content)
    }

    static func integer(_ value: Int) -> Data {
        var bytes = Data()
        var rest = value
        repeat {
            bytes.insert(UInt8(rest & 0xff), at: 0)
            rest >>= 8
        } while rest > 0
        return integer(bytes)
    }

    static func bitString(_ content: Data, unusedBits: UInt8 = 0) -> Data {
        tlv(0x03, Data([unusedBits]) + content)
    }

    static func oid(_ dotted: String) -> Data {
        let arcs = dotted.split(separator: ".").map { UInt64($0)! }
        var content = Data([UInt8(arcs[0] * 40 + arcs[1])])
        for arc in arcs.dropFirst(2) {
            var chunk = [UInt8(arc & 0x7f)]
            var rest = arc >> 7
            while rest > 0 {
                chunk.insert(UInt8(rest & 0x7f) | 0x80, at: 0)
                rest >>= 7
            }
            content.append(contentsOf: chunk)
        }
        return tlv(0x06, content)
    }

    /// UTCTime through 2049, GeneralizedTime after, as RFC 5280 asks.
    static func time(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let year = Calendar(identifier: .gregorian).dateComponents(in: formatter.timeZone, from: date).year!
        if year < 2050 {
            formatter.dateFormat = "yyMMddHHmmss'Z'"
            return tlv(0x17, Data(formatter.string(from: date).utf8))
        }
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        return tlv(0x18, Data(formatter.string(from: date).utf8))
    }

    static func explicit(_ number: UInt8, _ content: Data) -> Data { tlv(0xa0 | number, content) }
}

enum MitmCertificateError: Error, Equatable {
    case badKey
    case badHost
    case signFailed
}

/// What signs: the keychain key in the app, a software key in tests.
protocol MitmCAKey {
    var publicKeyX963: Data { get }
    /// An X9.62 DER ECDSA signature over SHA-256 of message.
    func sign(_ message: Data) throws -> Data
}

enum MitmCertificateBuilder {
    static let rootName = "Flash 本机解密证书（仅此 Mac）"
    static let rootLifetime: TimeInterval = 365 * 24 * 3600
    static let leafLifetime: TimeInterval = 7 * 24 * 3600
    /// Clocks a little behind still accept a new certificate.
    static let backdate: TimeInterval = 5 * 60

    static let serverAuth = "1.3.6.1.5.5.7.3.1"
    static let ecdsaWithSHA256 = DER.sequence(DER.oid("1.2.840.10045.4.3.2"))
    /// SEQUENCE { id-ecPublicKey, prime256v1 } and the BIT STRING header of a 65-byte point.
    static let p256SPKIPrefix = Data([
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
        0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
    ])

    static func spki(x963: Data) -> Data { p256SPKIPrefix + x963 }

    static func p256Point(spki: Data) throws -> Data {
        let spki = Data(spki)
        guard spki.count == p256SPKIPrefix.count + 65, spki.prefix(p256SPKIPrefix.count) == p256SPKIPrefix else {
            throw MitmCertificateError.badKey
        }
        let point = spki.suffix(65)
        guard (try? P256.Signing.PublicKey(x963Representation: point)) != nil else {
            throw MitmCertificateError.badKey
        }
        return Data(point)
    }

    static func name(commonName: String, organization: String? = nil) -> Data {
        var parts = [Data]()
        if let organization {
            parts.append(DER.set(DER.sequence(DER.oid("2.5.4.10"), DER.utf8String(organization))))
        }
        parts.append(DER.set(DER.sequence(DER.oid("2.5.4.3"), DER.utf8String(commonName))))
        return DER.sequence(parts)
    }

    static var rootSubject: Data { name(commonName: rootName, organization: "Flash") }

    static func keyIdentifier(x963: Data) -> Data {
        Data(Insecure.SHA1.hash(data: x963))
    }

    static func serial() -> Data {
        var bytes = (0..<16).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = (bytes[0] & 0x7f) | 0x40
        return Data(bytes)
    }

    private static func extensionField(_ oid: String, critical: Bool, _ value: Data) -> Data {
        critical
            ? DER.sequence(DER.oid(oid), DER.boolean(true), DER.octetString(value))
            : DER.sequence(DER.oid(oid), DER.octetString(value))
    }

    private static func tbs(serial: Data, issuer: Data, notBefore: Date, notAfter: Date,
                            subject: Data, spki: Data, extensions: [Data]) -> Data {
        DER.sequence(
            DER.explicit(0, DER.integer(2)),
            DER.integer(serial),
            ecdsaWithSHA256,
            issuer,
            DER.sequence(DER.time(notBefore), DER.time(notAfter)),
            subject,
            spki,
            DER.explicit(3, DER.sequence(extensions)))
    }

    private static func signed(_ tbs: Data, with key: MitmCAKey) throws -> Data {
        let signature: Data
        do {
            signature = try key.sign(tbs)
        } catch {
            throw MitmCertificateError.signFailed
        }
        return DER.sequence(tbs, ecdsaWithSHA256, DER.bitString(signature))
    }

    /// Self-signed, one year, a CA that signs only server certificates: path length 0, keyCertSign and
    /// cRLSign, EKU serverAuth. No name constraints: the user's list changes and the root would have to follow.
    static func root(key: MitmCAKey, now: Date = Date(), serial: Data = serial()) throws -> Data {
        let x963 = key.publicKeyX963
        let identifier = keyIdentifier(x963: x963)
        let notBefore = now.addingTimeInterval(-backdate)
        let tbs = tbs(
            serial: serial, issuer: rootSubject, notBefore: notBefore,
            notAfter: notBefore.addingTimeInterval(rootLifetime), subject: rootSubject, spki: spki(x963: x963),
            extensions: [
                extensionField("2.5.29.19", critical: true, DER.sequence(DER.boolean(true), DER.integer(0))),
                extensionField("2.5.29.15", critical: true, DER.bitString(Data([0x06]), unusedBits: 1)),
                extensionField("2.5.29.37", critical: false, DER.sequence(DER.oid(serverAuth))),
                extensionField("2.5.29.14", critical: false, DER.octetString(identifier)),
            ])
        return try signed(tbs, with: key)
    }

    /// A server certificate for host alone, seven days but never past notAfterLimit (the root's), never a CA.
    static func leaf(host: String, spki: Data, key: MitmCAKey, now: Date = Date(), notAfterLimit: Date = .distantFuture,
                     serial: Data = serial()) throws -> Data {
        guard MitmHostPolicy.validDNSName(host), host == MitmHostPolicy.normalize(host) else {
            throw MitmCertificateError.badHost
        }
        let point = try p256Point(spki: spki)
        let notBefore = now.addingTimeInterval(-backdate)
        let tbs = tbs(
            serial: serial, issuer: rootSubject, notBefore: notBefore,
            notAfter: leafNotAfter(now: now, limit: notAfterLimit), subject: name(commonName: host),
            spki: self.spki(x963: point),
            extensions: [
                extensionField("2.5.29.19", critical: true, DER.sequence()),
                extensionField("2.5.29.15", critical: true, DER.bitString(Data([0x80]), unusedBits: 7)),
                extensionField("2.5.29.37", critical: false, DER.sequence(DER.oid(serverAuth))),
                extensionField("2.5.29.17", critical: false, DER.sequence(DER.tlv(0x82, Data(host.utf8)))),
                extensionField("2.5.29.35", critical: false,
                               DER.sequence(DER.tlv(0x80, keyIdentifier(x963: key.publicKeyX963)))),
            ])
        return try signed(tbs, with: key)
    }

    static func leafNotAfter(now: Date, limit: Date) -> Date {
        min(now.addingTimeInterval(leafLifetime - backdate), limit)
    }

    static func pem(_ der: Data) -> String {
        let body = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN CERTIFICATE-----\n\(body)\n-----END CERTIFICATE-----\n"
    }

    static func fingerprint(_ der: Data) -> String {
        SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
