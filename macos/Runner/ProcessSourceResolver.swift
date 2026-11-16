import AppKit

/// Who a connection's executable works for, as far as its path tells.
enum ProcessSource: Equatable {
    case none
    case unreadable
    /// [launchdLabel] is set when a launchd job, not a bundle on the path,
    /// tied the executable to the app.
    case app(bundleId: String, name: String, bundlePath: String, launchdLabel: String?)
    case service(SystemService, iconPath: String?)
}

final class ProcessSourceResolver {
    private let launchd: LaunchdIndex
    private let fileExists: (String) -> Bool
    private let appURL: (String) -> URL?

    init(
        launchd: LaunchdIndex = LaunchdIndex(),
        fileExists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        appURL: @escaping (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) {
        self.launchd = launchd
        self.fileExists = fileExists
        self.appURL = appURL
    }

    var generation: Int {
        launchd.refreshIfNeeded()
        return launchd.generation
    }

    func resolve(_ path: String) -> ProcessSource {
        if let service = serviceOf(path) {
            return .service(service, iconPath: service.iconPaths.first(where: fileExists))
        }
        if let bundlePath = ProcessAppLocator.outermostBundlePath(of: path) {
            return Self.app(at: bundlePath, launchdLabel: nil) ?? .unreadable
        }
        if let job = launchd.job(forExecutable: path) {
            for bundleId in job.bundleIds {
                if let url = appURL(bundleId),
                    case let .app(_, name, bundlePath, _)? = Self.app(
                        at: url.path, launchdLabel: job.label)
                {
                    return .app(
                        bundleId: bundleId, name: name, bundlePath: bundlePath,
                        launchdLabel: job.label)
                }
            }
        }
        return .none
    }

    private func serviceOf(_ path: String) -> SystemService? {
        if let service = ProcessSourceCatalog.service(forExecutable: path) {
            return service
        }
        guard path.hasPrefix("/System/") || path.hasPrefix("/usr/") else {
            return nil
        }
        let resolved = (path as NSString).resolvingSymlinksInPath
        return resolved == path ? nil : ProcessSourceCatalog.service(forExecutable: resolved)
    }

    private static func app(at bundlePath: String, launchdLabel: String?) -> ProcessSource? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundlePath, isDirectory: &isDirectory),
            isDirectory.boolValue,
            let bundle = Bundle(url: URL(fileURLWithPath: bundlePath, isDirectory: true))
        else {
            return nil
        }
        let name = ProcessAppLocator.displayName(
            FileManager.default.displayName(atPath: bundlePath))
        if name.isEmpty {
            return nil
        }
        return .app(
            bundleId: bundle.bundleIdentifier ?? "", name: name, bundlePath: bundlePath,
            launchdLabel: launchdLabel)
    }

    /// Links are followed first: Safari's bundle links into the app cryptex,
    /// and Finder badges a link's icon as an alias.
    static func icon(at path: String) -> NSImage? {
        let target = (path as NSString).resolvingSymlinksInPath
        if target.lowercased().hasSuffix(".icns") {
            return NSImage(contentsOfFile: target)
        }
        return NSWorkspace.shared.icon(forFile: target)
    }

    static func png(_ image: NSImage, side: Int) -> Data? {
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
