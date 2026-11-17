import Foundation

/// core/mitm_host.go's rules, applied again before the app signs;
/// core/testdata/mitm_hostname_vectors.json holds both sides to them.
enum MitmHostIssue: String {
    case invalid
    case address
    case overBroad = "over-broad"
    case appleService = "apple-service"
}

struct MitmHostEntry: Equatable {
    var exclude = false
    var wildcard = false
    var base = ""

    func matches(_ host: String) -> Bool {
        wildcard ? host.hasSuffix("." + base) : host == base
    }
}

enum MitmHostPolicy {
    /// Decrypting these breaks iCloud, push, App Store, software update and
    /// activation; kept equal to mitmAppleDomains in core/mitm_host.go.
    static let appleDomains = [
        "apple",
        "apple.com",
        "apple.com.cn",
        "apple.co",
        "apple-cloudkit.com",
        "apple-dns.cn",
        "apple-dns.net",
        "apple-livephotoskit.com",
        "apple-mapkit.com",
        "aaplimg.com",
        "appattest.apple.com",
        "appstore.com",
        "cdn-apple.com",
        "icloud.com",
        "icloud.com.cn",
        "icloud-content.com",
        "icloud-content.com.cn",
        "itunes.com",
        "itunes.apple.com",
        "mac.com",
        "me.com",
        "mzstatic.com",
        "push.apple.com",
    ]

    static func normalize(_ host: String) -> String {
        var text = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// An all-digit last label is an address.
    static func validDNSName(_ name: String) -> Bool {
        guard !name.isEmpty, name.utf8.count <= 253 else { return false }
        var letters = false
        for label in name.split(separator: ".", omittingEmptySubsequences: false) {
            let bytes = Array(label.utf8)
            guard let first = bytes.first, let last = bytes.last, bytes.count <= 63,
                  first != UInt8(ascii: "-"), last != UInt8(ascii: "-") else { return false }
            letters = false
            for byte in bytes {
                switch byte {
                case UInt8(ascii: "a")...UInt8(ascii: "z"): letters = true
                case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"): break
                default: return false
                }
            }
        }
        return letters
    }

    static func isAppleDomain(_ host: String) -> Bool {
        appleDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func looksLikeAddress(_ text: String) -> Bool {
        if text.contains(":") { return true }
        var address = in_addr()
        return inet_pton(AF_INET, text, &address) == 1
    }

    /// Exclusions are held only to the syntax: taking a host out is safe however broad.
    static func parse(_ line: String) -> (MitmHostEntry, MitmHostIssue?) {
        var text = normalize(line)
        var entry = MitmHostEntry()
        if text.hasPrefix("-") {
            entry.exclude = true
            text = normalize(String(text.dropFirst()))
        }
        if text == "*" || text == "*." {
            return (entry, entry.exclude ? .invalid : .overBroad)
        }
        if looksLikeAddress(text.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) {
            return (entry, .address)
        }
        if text.hasPrefix("*.") {
            entry.wildcard = true
            text = String(text.dropFirst(2))
        }
        guard validDNSName(text) else { return (entry, .invalid) }
        entry.base = text
        if entry.exclude { return (entry, nil) }
        if MitmPublicSuffix.isPublicSuffix(text) { return (entry, .overBroad) }
        if isAppleDomain(text) { return (entry, .appleService) }
        return (entry, nil)
    }
}

struct MitmHostMatcher {
    let entries: [MitmHostEntry]

    init(_ lines: [String]) {
        entries = lines.compactMap { line in
            let (entry, issue) = MitmHostPolicy.parse(line)
            return issue == nil ? entry : nil
        }
    }

    func matches(_ host: String) -> Bool {
        let host = MitmHostPolicy.normalize(host)
        guard MitmHostPolicy.validDNSName(host), !MitmHostPolicy.isAppleDomain(host) else { return false }
        for entry in entries where entry.matches(host) {
            return !entry.exclude
        }
        return false
    }
}

/// The public suffix algorithm of golang.org/x/net/publicsuffix over the same rules.
enum MitmPublicSuffix {
    private struct Rules {
        var normal = Set<String>()
        var wildcard = Set<String>()
        var exception = Set<String>()
    }

    private static let rules: Rules = {
        var rules = Rules()
        for line in mitmPublicSuffixRules.split(separator: "\n") {
            if line.hasPrefix("!") {
                rules.exception.insert(String(line.dropFirst()))
            } else if line.hasPrefix("*.") {
                rules.wildcard.insert(String(line.dropFirst(2)))
            } else {
                rules.normal.insert(String(line))
            }
        }
        return rules
    }()

    /// The public suffix of a valid DNS name: an exception rule takes its
    /// parent, else the longest matching rule wins, else the last label.
    static func publicSuffix(_ domain: String) -> String {
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let rules = self.rules
        var length = 1
        for count in 1...labels.count {
            let candidate = labels.suffix(count).joined(separator: ".")
            if rules.exception.contains(candidate) {
                length = count - 1
                break
            }
            let parent = labels.suffix(count - 1).joined(separator: ".")
            if rules.normal.contains(candidate) || (count > 1 && rules.wildcard.contains(parent)) {
                length = count
            }
        }
        return labels.suffix(max(length, 1)).joined(separator: ".")
    }

    static func isPublicSuffix(_ name: String) -> Bool {
        publicSuffix(name) == name
    }
}
