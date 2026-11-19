import CryptoKit
import Foundation
import CoreFoundation

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
              let schema = UpdateReleasePolicy.integer(object["schema"]), [1, 2].contains(schema),
              let payload = (object["payload"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let signature = (object["signature"] as? String).flatMap({ Data(base64Encoded: $0) }),
              signature.count == 64,
              key.isValidSignature(signature, for: payload),
              let content = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              UpdateReleasePolicy.integer(content["schema"]) == schema,
              content["product"] as? String == "com.layoute.flash"
        else { return nil }
        return content
    }
}


enum UpdateReleasePolicy {
    static let legacyCeiling = 2026111901

    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              !["f", "d"].contains(String(cString: number.objCType)),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              number.doubleValue > 0, number.doubleValue < 1e18, number.int64Value <= 999999999999999999
        else { return nil }
        return number.intValue
    }

    static func text(_ value: Any?, _ pattern: String, limit: Int = 128) -> String? {
        guard let value = value as? String, !value.isEmpty, value.utf8.count <= limit,
              value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return value
    }

    static func semantic(_ value: String) -> ([UInt64], [String])? {
        let pattern = "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$"
        guard value.utf8.count <= 128, value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let main = value.split(separator: "+", maxSplits: 1)[0].split(separator: "-", maxSplits: 1)
        let numbers = main[0].split(separator: ".").compactMap { UInt64($0) }
        guard numbers.count == 3, numbers.allSatisfy({ $0 <= UInt64(Int64.max) }) else { return nil }
        let pre = main.count > 1 ? main[1].split(separator: ".").map(String.init) : []
        guard !pre.contains(where: { $0.range(of: "^0[0-9]+$", options: .regularExpression) != nil }) else { return nil }
        return (numbers, pre)
    }

    static func compare(_ left: String, _ right: String) -> Int? {
        guard let (a, ap) = semantic(left), let (b, bp) = semantic(right) else { return nil }
        for i in 0..<3 where a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
        if ap.isEmpty || bp.isEmpty { return ap.isEmpty == bp.isEmpty ? 0 : (ap.isEmpty ? 1 : -1) }
        for i in 0..<min(ap.count, bp.count) where ap[i] != bp[i] {
            let an = ap[i].allSatisfy({ $0.isNumber }), bn = bp[i].allSatisfy({ $0.isNumber })
            if an != bn { return an ? -1 : 1 }
            if an && ap[i].count != bp[i].count { return ap[i].count < bp[i].count ? -1 : 1 }
            return ap[i] < bp[i] ? -1 : 1
        }
        return ap.count == bp.count ? 0 : (ap.count < bp.count ? -1 : 1)
    }

    static func identity(_ info: [String: Any]) -> [String: Any]? {
        guard let buildText = info["CFBundleVersion"] as? String, let build = Int(buildText), build > 0,
              let bundleVersion = info["CFBundleShortVersionString"] as? String else { return nil }
        if let channel = info["FlashReleaseChannel"] as? String,
           ["stable", "beta"].contains(channel), let version = info["FlashReleaseVersion"] as? String,
           semantic(version) != nil {
            return ["channel": channel, "version": version, "build": build]
        }
        guard build <= legacyCeiling, semantic(bundleVersion) != nil,
              info["FlashReleaseChannel"] == nil, info["FlashReleaseVersion"] == nil else { return nil }
        return ["version": bundleVersion, "build": build]
    }

    static func validate(_ payload: [String: Any], allowBeta: Bool, installed: [String: Any]) -> Bool {
        guard let schema = integer(payload["schema"]), let channel = payload["channel"] as? String,
              (schema == 1 && channel == "stable") || (schema == 2 && channel == "beta" && allowBeta),
              payload["product"] as? String == "com.layoute.flash", payload["platform"] as? String == "macos",
              let release = payload["release"] as? [String: Any],
              release["repository"] as? String == "f4cker/flash-releases",
              release["sourceRepository"] as? String == "f4cker/FlClash",
              let tag = text(release["tag"], "^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$"),
              let version = release["version"] as? String,
              text(release["sourceCommit"], "^[0-9a-f]{40}$") != nil,
              text(release["sourceBranch"], "^[A-Za-z0-9][A-Za-z0-9/._+-]{0,127}$") != nil,
              let bundleVersion = text(payload["version"], "^[0-9A-Za-z.+-]{1,64}$"),
              let build = integer(payload["build"]), integer(payload["helperBuild"]) != nil,
              let current = identity(installed), let currentBuild = current["build"] as? Int,
              let currentVersion = current["version"] as? String, build > currentBuild,
              let order = compare(version, currentVersion), order >= 0,
              text(payload["minimumSystemVersion"], "^[0-9]{1,3}(\\.[0-9]{1,3}){0,2}$") != nil,
              let notes = payload["notes"] as? String, notes.count <= 20000,
              text(payload["published"], "^.+$", limit: 64) != nil,
              let assets = payload["assets"] as? [[String: Any]], !assets.isEmpty, assets.count <= 8
        else { return false }
        let minimum = (payload["minimumSystemVersion"] as! String).split(separator: ".").compactMap { Int($0) }
        let required = OperatingSystemVersion(majorVersion: minimum[0], minorVersion: minimum.count > 1 ? minimum[1] : 0,
                                              patchVersion: minimum.count > 2 ? minimum[2] : 0)
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(required) else { return false }
        var arches = Set<String>()
        for asset in assets {
            guard let arch = asset["arch"] as? String, ["arm64", "amd64"].contains(arch), arches.insert(arch).inserted,
                  let name = asset["name"] as? String, name == "Flash-\(bundleVersion)-macos-\(arch).zip",
                  let url = asset["url"] as? String,
                  url == "https://github.com/f4cker/flash-releases/releases/download/\(tag)/\(name)",
                  let size = integer(asset["size"]), size <= 2 * 1024 * 1024 * 1024,
                  text(asset["sha256"], "^[0-9a-f]{64}$") != nil else { return false }
        }
        return true
    }
}

final class UpdatePreparedTickets {
    struct Ticket {
        let staged: String
        let manifest: Data
        let seal: Data
        let expected: [String: Any]
        let payload: [String: Any]
    }
    private var tickets: [String: Ticket] = [:]

    func issue(_ ticket: Ticket) -> String {
        tickets.removeAll()
        let token = UUID().uuidString
        tickets[token] = ticket
        return token
    }

    func consume(_ token: String, staged: String, seal: Data, allowBeta: Bool,
                 installed: [String: Any]) -> Ticket? {
        guard let ticket = tickets.removeValue(forKey: token), ticket.staged == staged,
              ticket.seal == seal, UpdateReleasePolicy.validate(ticket.payload, allowBeta: allowBeta, installed: installed)
        else { return nil }
        return ticket
    }

    func clear() { tickets.removeAll() }
}
