import Cocoa
import FlutterMacOS

/// Names the Mac app a connection's executable belongs to, read from the
/// bundle on its path alone: no disk scan, no privilege, nothing logged.
final class ProcessAppChannel {
    private static var instance: ProcessAppChannel?
    private static let iconSide = 64

    private enum Lookup {
        case none
        case unreadable
        case app(bundleId: String, name: String, bundlePath: String)
    }

    private let channel: FlutterMethodChannel
    private let queue = DispatchQueue(label: "flash.process-app", qos: .utility)
    private let lookups = LRUCache<String, Lookup>(capacity: 256)
    private let icons = LRUCache<String, Data>(capacity: 64)
    private var missingIcons = Set<String>()

    static func register(messenger: FlutterBinaryMessenger) {
        instance = ProcessAppChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.follow.clash/process_app", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
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
        let lookup: Lookup
        if let cached = lookups.get(path) {
            lookup = cached
        } else {
            lookup = Self.resolve(path)
            lookups.set(path, lookup)
        }
        switch lookup {
        case .none:
            return ["status": "none"]
        case .unreadable:
            return ["status": "unreadable"]
        case let .app(bundleId, name, bundlePath):
            var answer: [String: Any] = [
                "status": "app",
                "bundleId": bundleId,
                "name": name,
                "bundlePath": bundlePath,
            ]
            if let icon = icon(for: bundlePath) {
                answer["icon"] = FlutterStandardTypedData(bytes: icon)
            }
            return answer
        }
    }

    private static func resolve(_ path: String) -> Lookup {
        guard let bundlePath = ProcessAppLocator.outermostBundlePath(of: path) else {
            return .none
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundlePath, isDirectory: &isDirectory),
            isDirectory.boolValue,
            let bundle = Bundle(url: URL(fileURLWithPath: bundlePath, isDirectory: true))
        else {
            return .unreadable
        }
        let name = ProcessAppLocator.displayName(
            FileManager.default.displayName(atPath: bundlePath))
        if name.isEmpty {
            return .unreadable
        }
        return .app(bundleId: bundle.bundleIdentifier ?? "", name: name, bundlePath: bundlePath)
    }

    private func icon(for bundlePath: String) -> Data? {
        if let icon = icons.get(bundlePath) {
            return icon
        }
        if missingIcons.contains(bundlePath) {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: bundlePath)
        guard let png = Self.png(image, side: Self.iconSide) else {
            missingIcons.insert(bundlePath)
            return nil
        }
        icons.set(bundlePath, png)
        return png
    }

    private static func png(_ image: NSImage, side: Int) -> Data? {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else {
            return nil
        }
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero,
            operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
