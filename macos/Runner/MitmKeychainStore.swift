import Foundation
import Security

/// The root's key in the user's login keychain, created there and never
/// exported: the Core, running as root outside this session, cannot reach it.
final class MitmKeychainStore: MitmCAStore {
    static let label = MitmCertificateBuilder.rootName
    static let tag = Data("com.layoute.flash.mitm.ca".utf8)

    private final class Key: MitmCAKey {
        let privateKey: SecKey
        let publicKeyX963: Data

        init?(_ privateKey: SecKey) {
            guard let publicKey = SecKeyCopyPublicKey(privateKey),
                  let point = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?, point.count == 65 else {
                return nil
            }
            self.privateKey = privateKey
            publicKeyX963 = point
        }

        func sign(_ message: Data) throws -> Data {
            var error: Unmanaged<CFError>?
            guard let signature = SecKeyCreateSignature(
                privateKey, .ecdsaSignatureMessageX962SHA256, message as CFData, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return signature as Data
        }
    }

    private func check(_ status: OSStatus, allowing allowed: Set<OSStatus> = []) throws {
        guard status == errSecSuccess || allowed.contains(status) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private var keyQuery: [String: Any] {
        [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrApplicationTag as String: Self.tag,
        ]
    }

    func loadKey() throws -> MitmCAKey? {
        var query = keyQuery
        query[kSecReturnRef as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return Key(item as! SecKey)
    }

    func createKey() throws -> MitmCAKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrLabel as String: Self.label,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrIsExtractable as String: false,
                kSecAttrApplicationTag as String: Self.tag,
                kSecAttrLabel as String: Self.label,
            ] as [String: Any],
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let key = Key(privateKey) else { throw MitmCertificateError.badKey }
        return key
    }

    /// Every certificate under the label: the one saved here, and a copy the
    /// trust step may have added.
    private func certificates() throws -> [SecCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: Self.label,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true,
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        try check(status)
        return items as? [SecCertificate] ?? []
    }

    func loadCertificate() throws -> Data? {
        guard let key = try loadKey() else { return nil }
        let spki = MitmCertificateBuilder.spki(x963: key.publicKeyX963)
        return try certificates()
            .map { SecCertificateCopyData($0) as Data }
            .first { (try? MitmRootReader.spki(of: $0)) == spki }
    }

    func saveCertificate(_ der: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw MitmCertificateError.signFailed
        }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: Self.label,
        ]
        try check(SecItemAdd(attributes as CFDictionary, nil), allowing: [errSecDuplicateItem])
    }

    func deleteAll() throws {
        for certificate in try certificates() {
            let removed = SecTrustSettingsRemoveTrustSettings(certificate, .user)
            try check(removed, allowing: [errSecItemNotFound])
            let query: [String: Any] = [kSecClass as String: kSecClassCertificate, kSecValueRef as String: certificate]
            try check(SecItemDelete(query as CFDictionary), allowing: [errSecItemNotFound])
        }
        try check(SecItemDelete(keyQuery as CFDictionary), allowing: [errSecItemNotFound])
        var publicQuery = keyQuery
        publicQuery[kSecAttrKeyClass as String] = kSecAttrKeyClassPublic
        publicQuery.removeValue(forKey: kSecAttrApplicationTag as String)
        publicQuery[kSecAttrLabel as String] = Self.label
        try check(SecItemDelete(publicQuery as CFDictionary), allowing: [errSecItemNotFound])
    }
}
