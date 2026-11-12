import Foundation

enum ProcessAppLocator {
    /// The outermost `.app` directory holding [executablePath], so a helper
    /// app nested inside another bundle resolves to the app the user knows.
    static func outermostBundlePath(of executablePath: String) -> String? {
        guard executablePath.hasPrefix("/") else {
            return nil
        }
        let parts = executablePath.split(separator: "/").map(String.init)
        if parts.contains("..") || parts.contains(".") {
            return nil
        }
        for (index, part) in parts.enumerated() where index < parts.count - 1 {
            if part.count > 4 && part.lowercased().hasSuffix(".app") {
                return "/" + parts[0...index].joined(separator: "/")
            }
        }
        return nil
    }

    static func displayName(_ name: String) -> String {
        if name.count > 4 && name.lowercased().hasSuffix(".app") {
            return String(name.dropLast(4))
        }
        return name
    }
}

/// Least recently used entries go first once [capacity] is reached.
final class LRUCache<Key: Hashable, Value> {
    let capacity: Int
    private var values: [Key: Value] = [:]
    private var order: [Key] = []

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    var count: Int { values.count }

    func get(_ key: Key) -> Value? {
        guard let value = values[key] else {
            return nil
        }
        touch(key)
        return value
    }

    func set(_ key: Key, _ value: Value) {
        if values.updateValue(value, forKey: key) != nil {
            touch(key)
            return
        }
        order.append(key)
        if order.count > capacity {
            values.removeValue(forKey: order.removeFirst())
        }
    }

    private func touch(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
    }
}
