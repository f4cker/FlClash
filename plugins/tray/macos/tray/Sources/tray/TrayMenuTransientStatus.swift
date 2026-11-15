enum TrayMenuTransientStatus {
    private static func key(_ entry: [String: Any]) -> String? {
        guard entry["type"] as? String == "action",
              entry["enabled"] as? Bool == false,
              let key = entry["transientStatusKey"] as? String, !key.isEmpty else { return nil }
        return key
    }

    static func retained(_ entry: [String: Any], current: [[String: Any]], desired: [[String: Any]]) -> [String: Any]? {
        guard let statusKey = key(entry) else { return nil }
        let matches = desired.filter { key($0) == statusKey }
        if current.filter({ key($0) == statusKey }).count == 1, matches.count == 1 {
            var replacement = matches[0]
            replacement["id"] = entry["id"]
            return replacement
        }
        // Keep tracking geometry, but retire every visible and accessible fragment.
        return [
            "type": "action", "id": entry["id"] ?? 0, "transientStatusKey": statusKey,
            "label": "", "accessibilityLabel": "", "enabled": false
        ]
    }
}
