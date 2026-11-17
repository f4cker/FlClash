import Foundation
import Security

/// The root's key in the user's login keychain, created there and never
/// exported: the Core, running as root outside this session, cannot reach it.
final class MitmKeychainStore: MitmCAStore {
    static let label = MitmCertificateBuilder.rootName
    static let tag = Data("com.layoute.flash.mitm.ca".utf8)
    /// What was made here, so a same-user process adding its own tagged key or certificate is not picked up.
    static let keyLabelDefault = "mitmCAKeyApplicationLabel"
    static let certificateDefault = "mitmCACertificateFingerprint"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

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

    private func loginKeychain() throws -> SecKeychain {
        var keychain: SecKeychain?
        try check(SecKeychainCopyDomainDefault(.user, &keychain))
        guard let keychain else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecNoSuchKeychain)) }
        return keychain
    }

    private func keyQuery() throws -> [String: Any] {
        [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrApplicationTag as String: Self.tag,
            kSecMatchSearchList as String: [try loginKeychain()],
        ]
    }

    func loadKey() throws -> MitmCAKey? {
        guard let label = defaults.data(forKey: Self.keyLabelDefault) else { return nil }
        var query = try keyQuery()
        query[kSecAttrApplicationLabel as String] = label
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
            kSecUseKeychain as String: try loginKeychain(),
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
        guard let key = Key(privateKey),
              let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any],
              let label = attributes[kSecAttrApplicationLabel as String] as? Data else {
            throw MitmCertificateError.badKey
        }
        defaults.set(label, forKey: Self.keyLabelDefault)
        return key
    }

    /// Every certificate under the label: the one saved here, and a copy the
    /// trust step may have added.
    private func certificates() throws -> [SecCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: Self.label,
            kSecMatchSearchList as String: [try loginKeychain()],
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
        guard let key = try loadKey(), let fingerprint = defaults.string(forKey: Self.certificateDefault) else {
            return nil
        }
        let spki = MitmCertificateBuilder.spki(x963: key.publicKeyX963)
        return try certificates()
            .map { SecCertificateCopyData($0) as Data }
            .first { MitmCertificateBuilder.fingerprint($0) == fingerprint && (try? MitmRootReader.spki(of: $0)) == spki }
    }

    func saveCertificate(_ der: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw MitmCertificateError.signFailed
        }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: Self.label,
            kSecUseKeychain as String: try loginKeychain(),
        ]
        try check(SecItemAdd(attributes as CFDictionary, nil), allowing: [errSecDuplicateItem])
        defaults.set(MitmCertificateBuilder.fingerprint(der), forKey: Self.certificateDefault)
    }

    func deleteAll() throws -> [Error] {
        let keyQuery = try keyQuery()
        return try MitmDeletion.run(
            deleteKey: {
                try check(SecItemDelete(keyQuery as CFDictionary), allowing: [errSecItemNotFound])
                defaults.removeObject(forKey: Self.keyLabelDefault)
                defaults.removeObject(forKey: Self.certificateDefault)
                var publicQuery = keyQuery
                publicQuery[kSecAttrKeyClass as String] = kSecAttrKeyClassPublic
                publicQuery.removeValue(forKey: kSecAttrApplicationTag as String)
                publicQuery[kSecAttrLabel as String] = Self.label
                try? check(SecItemDelete(publicQuery as CFDictionary), allowing: [errSecItemNotFound])
            },
            certificates: certificates,
            removeTrust: { try check(SecTrustSettingsRemoveTrustSettings($0, .user), allowing: [errSecItemNotFound]) },
            deleteCertificate: { certificate in
                let query: [String: Any] = [kSecClass as String: kSecClassCertificate, kSecValueRef as String: certificate]
                try check(SecItemDelete(query as CFDictionary), allowing: [errSecItemNotFound])
            })
    }
}
