import CryptoKit
import Foundation

enum UpdateManifestSignature {
    /// The payload of an envelope whose signature verifies with any of `publicKeys` (primary, backup).
    static func open(_ envelope: Data, publicKeys: [String]) -> [String: Any]? {
        for publicKey in publicKeys {
            if let content = open(envelope, publicKey: publicKey) { return content }
        }
        return nil
    }

    /// The payload of a `{schema, payload, signature}` envelope whose signature verifies with `publicKey`.
    static func open(_ envelope: Data, publicKey: String) -> [String: Any]? {
        guard let keyData = Data(base64Encoded: publicKey), keyData.count == 32,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              envelope.count <= 256 * 1024,
              let object = try? JSONSerialization.jsonObject(with: envelope) as? [String: Any],
              Set(object.keys) == ["schema", "payload", "signature"],
              (object["schema"] as? NSNumber)?.intValue == 1,
              let payload = (object["payload"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let signature = (object["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
              signature.count == 64,
              key.isValidSignature(signature, for: payload),
              let content = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              (content["schema"] as? NSNumber)?.intValue == 1,
              content["product"] as? String == "com.layoute.flash"
        else { return nil }
        return content
    }
}
