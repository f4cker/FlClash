import Foundation

@main
struct UpdateChannelPolicyTests {
    static func main() throws {
        let installed: [String: Any] = ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "2026111902",
                                        "FlashReleaseChannel": "stable", "FlashReleaseVersion": "1.0.0"]
        func payload(_ channel: String = "stable", version: String = "1.1.0", build: Int = 2026111903) -> [String: Any] {
            let tag = "v" + version, name = "Flash-1.1.0-macos-arm64.zip"
            return ["schema": channel == "beta" ? 2 : 1, "channel": channel, "product": "com.layoute.flash",
                    "platform": "macos", "version": "1.1.0", "build": build, "helperBuild": build,
                    "minimumSystemVersion": "12.0", "notes": "fixture", "published": "2026-11-19T00:00:00Z",
                    "release": ["repository": "f4cker/flash-releases", "tag": tag, "version": version,
                                "sourceRepository": "f4cker/FlClash", "sourceCommit": String(repeating: "a", count: 40),
                                "sourceBranch": "release/1.1"],
                    "assets": [["arch": "arm64", "name": name, "size": 4, "sha256": String(repeating: "a", count: 64),
                                "url": "https://github.com/f4cker/flash-releases/releases/download/\(tag)/\(name)"]]]
        }
        func accepts(_ candidate: [String: Any], beta: Bool = false, current: [String: Any]? = nil) -> Bool {
            UpdateReleasePolicy.validate(candidate, allowBeta: beta, installed: current ?? installed)
        }
        precondition(accepts(payload()))
        precondition(accepts(payload("beta", version: "1.1.0-beta.1"), beta: true))
        precondition(!accepts(payload("beta")))
        for (key, value) in [("schema", 2 as Any), ("schema", true), ("schema", 1.0), ("schema", 1.1),
                             ("channel", "beta"), ("channel", NSNull()), ("channel", "dev"),
                             ("product", "other"), ("platform", "ios"), ("build", true),
                             ("build", 2026111902), ("helperBuild", 0), ("minimumSystemVersion", "999.0")] {
            var candidate = payload(); candidate[key] = value
            precondition(!accepts(candidate), "accepted invalid \(key): \(value)")
        }
        var missing = payload(); missing.removeValue(forKey: "channel")
        precondition(!accepts(missing))
        precondition(!accepts(payload(version: "0.9.0", build: 2026111999)))
        precondition(UpdateReleasePolicy.compare("1.1.0-beta.10", "1.1.0-beta.2") == 1)
        precondition(UpdateReleasePolicy.compare("1.1.0", "1.1.0-beta.10") == 1)
        precondition(UpdateReleasePolicy.compare("1.0.0+2", "1.0.0+1") == 0)
        precondition(UpdateReleasePolicy.compare("1.0.0-beta.01", "1.0.0") == nil)
        for (key, value) in [("repository", "other/other"), ("tag", "../v1"), ("sourceCommit", String(repeating: "A", count: 40)),
                             ("sourceRepository", "other/source"), ("version", "01.0.0")] {
            var candidate = payload(), release = candidate["release"] as! [String: Any]
            release[key] = value; candidate["release"] = release
            precondition(!accepts(candidate), "accepted invalid release \(key)")
        }
        for url in ["https://evil.invalid/a", "https://github.com/f4cker/flash-releases/releases/download/v1.1.0/Flash-1.1.0-macos-arm64.zip?x=1",
                    "https://github.com/f4cker/flash-releases/releases/download/wrong/Flash-1.1.0-macos-arm64.zip"] {
            var candidate = payload(), assets = candidate["assets"] as! [[String: Any]]
            assets[0]["url"] = url; candidate["assets"] = assets
            precondition(!accepts(candidate))
        }
        var betaInstalled = installed
        betaInstalled["FlashReleaseChannel"] = "beta"
        betaInstalled["FlashReleaseVersion"] = "1.2.0-beta.1"
        precondition(UpdateReleasePolicy.identity(betaInstalled)?["channel"] as? String == "beta")
        precondition(!accepts(payload(version: "1.1.0", build: 2026111999), current: betaInstalled))
        var unsealed = installed; unsealed.removeValue(forKey: "FlashReleaseChannel")
        precondition(UpdateReleasePolicy.identity(unsealed) == nil)
        let tickets = UpdatePreparedTickets(), stage = "/fixture/staged/Flash.app", seal = Data([1, 2, 3])
        func issue(_ candidate: [String: Any]? = nil) -> String {
            tickets.issue(.init(staged: stage, manifest: Data([4, 5]), seal: seal, expected: ["build": 2026111903], payload: candidate ?? payload()))
        }
        func consume(_ token: String, path: String = stage, hash: Data = seal, beta: Bool = false) -> Bool {
            tickets.consume(token, staged: path, seal: hash, allowBeta: beta, installed: installed) != nil
        }
        let success = issue(); precondition(consume(success)); precondition(!consume(success))
        precondition(!consume(issue(), path: "/fixture/other/Flash.app"))
        precondition(!consume(issue(), hash: Data([9])))
        precondition(!consume(issue(payload("beta"))))
        precondition(consume(issue(payload("beta")), beta: true))
        let cleared = issue(); tickets.clear(); precondition(!consume(cleared))
        let restarted = issue()
        precondition(UpdatePreparedTickets().consume(restarted, staged: stage, seal: seal, allowBeta: true, installed: installed) == nil)
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
        let key = try String(contentsOf: fixtures.appendingPathComponent("test_public_key.txt"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let legacy = try Data(contentsOf: fixtures.appendingPathComponent("newer.json"))
        let authenticatedLegacy = UpdateManifestSignature.open(legacy, publicKeys: ["", key])!
        precondition(!accepts(authenticatedLegacy, beta: true))
        precondition(UpdateManifestSignature.open(legacy, publicKey: String(repeating: "A", count: 44)) == nil)
        var object = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        var bytes = Data(base64Encoded: object["payload"] as! String)!
        bytes[bytes.startIndex] ^= 1; object["payload"] = bytes.base64EncodedString()
        let tampered = try JSONSerialization.data(withJSONObject: object)
        precondition(UpdateManifestSignature.open(tampered, publicKey: key) == nil)
        print("Update channel policy, prepared-ticket, semantic floor and existing signature fixtures passed")
    }
}
