import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Names the app or Apple system service an executable works for; nothing logged.
final class ProcessAppChannel {
    private static var instance: ProcessAppChannel?
    private static let iconSide = 64

    private let channel: FlutterMethodChannel
    private let queue = DispatchQueue(label: "flash.process-app", qos: .utility)
    private let resolver = ProcessSourceResolver()
    private let lookups = LRUCache<String, (source: ProcessSource, generation: Int)>(capacity: 256)
    private let icons = LRUCache<String, Data>(capacity: 64)
    private var missingIcons = Set<String>()
    private var genericIcon: Data?

    static func register(messenger: FlutterBinaryMessenger) {
        instance = ProcessAppChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.follow.clash/process_app", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "genericIcon" {
                guard let self else {
                    result(nil)
                    return
                }
                self.queue.async {
                    let icon = self.genericApplicationIcon()
                    DispatchQueue.main.async {
                        result(icon.map { FlutterStandardTypedData(bytes: $0) })
                    }
                }
                return
            }
            guard call.method == "lookup",
                let arguments = call.arguments as? [String: Any],
                let path = arguments["path"] as? String
            else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let self else {
                result(nil)
                return
            }
            self.queue.async {
                let answer = self.answer(for: path)
                DispatchQueue.main.async { result(answer) }
            }
        }
    }

    private func answer(for path: String) -> [String: Any] {
        let generation = resolver.generation
        let source: ProcessSource
        if let cached = lookups.get(path), cached.generation == generation {
            source = cached.source
        } else {
            source = resolver.resolve(path)
            lookups.set(path, (source, generation))
        }
        switch source {
        case .none:
            return ["status": "none"]
        case .unreadable:
            return ["status": "unreadable"]
        case let .app(bundleId, name, bundlePath, launchdLabel):
            var answer: [String: Any] = [
                "status": "app",
                "bundleId": bundleId,
                "name": name,
                "bundlePath": bundlePath,
            ]
            if let launchdLabel {
                answer["launchdLabel"] = launchdLabel
            }
            if let icon = icon(for: bundlePath) {
                answer["icon"] = FlutterStandardTypedData(bytes: icon)
            }
            return answer
        case let .service(service, iconPath):
            var answer: [String: Any] = [
                "status": "service",
                "serviceId": service.id,
                "shared": service.shared,
            ]
            if let iconPath, let icon = icon(for: iconPath) {
                answer["icon"] = FlutterStandardTypedData(bytes: icon)
            }
            return answer
        }
    }

    private func icon(for bundlePath: String) -> Data? {
        if let icon = icons.get(bundlePath) {
            return icon
        }
        if missingIcons.contains(bundlePath) {
            return nil
        }
        guard let image = ProcessSourceResolver.icon(at: bundlePath),
            let png = ProcessSourceResolver.png(image, side: Self.iconSide)
        else {
            missingIcons.insert(bundlePath)
            return nil
        }
        icons.set(bundlePath, png)
        return png
    }

    /// Finder's plain application icon, for a process nothing else names.
    private func genericApplicationIcon() -> Data? {
        if let genericIcon {
            return genericIcon
        }
        genericIcon = ProcessSourceResolver.png(
            NSWorkspace.shared.icon(for: UTType.application), side: Self.iconSide)
        return genericIcon
    }
}
