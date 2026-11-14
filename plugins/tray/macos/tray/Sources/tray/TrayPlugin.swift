import Cocoa
import FlutterMacOS

public class TrayPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel!
    private var statusItem: TrayStatusItem?
    private var menu: TrayMenu?
    private var trackingMenu: TrayMenu?
    private var closedMenu: TrayMenu?
    private var closedGeneration: Int?
    private var menuOpenScheduled = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tray", binaryMessenger: registrar.messenger)
        let instance = TrayPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "show":
            result(show(call.arguments as? [String: Any]))
        case "setTitle":
            result(setTitle(call.arguments as? [String: Any]))
        case "hide":
            hide()
            result(true)
        case "openMenu":
            result(openMenu())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func show(_ arguments: [String: Any]?) -> Bool {
        guard let arguments = arguments else {
            return false
        }

        guard let item = statusItem ?? makeStatusItem() else {
            return false
        }

        if let icon = arguments["icon"] as? [String: Any] {
            guard let image = makeImage(icon) else {
                return false
            }
            item.setImage(image, position: icon["position"] as? String ?? "leading")
        }

        item.setTitle(arguments["title"] as? String ?? "")

        if let items = arguments["menu"] as? [[String: Any]] {
            let generation = arguments["menuGeneration"] as? Int ?? 0
            if let active = trackingMenu, active.reconcile(items: items, generation: generation) {
                menu = active
            } else {
                menu = TrayMenu(
                    items: items,
                    generation: generation,
                    onSelect: { [weak self] id, selectedGeneration in
                        self?.channel.invokeMethod("onMenuItemSelected", arguments: ["id": id, "menuGeneration": selectedGeneration])
                    },
                    onClose: { [weak self] generation in
                        self?.closeMenu(generation: generation)
                    }
                )
            }
            publishMenuGenerations()
        }

        return true
    }

    private func setTitle(_ arguments: [String: Any]?) -> Bool {
        guard let statusItem = statusItem else {
            return false
        }
        statusItem.setTitle(arguments?["title"] as? String ?? "")
        return true
    }

    private func hide() {
        menuOpenScheduled = false
        trackingMenu?.cancelTracking()
        statusItem?.remove()
        statusItem = nil
        menu = nil
        trackingMenu = nil
        closedMenu = nil
        closedGeneration = nil
        publishMenuGenerations()
    }

    private func publishMenuGenerations() {
        let generations = Set([menu?.generation, trackingMenu?.generation, closedGeneration].compactMap { $0 })
        var arguments: [String: Any] = ["generations": generations.sorted()]
        if let active = trackingMenu { arguments["trackingGeneration"] = active.generation }
        channel.invokeMethod("onMenuGenerations", arguments: arguments)
    }

    private func closeMenu(generation: Int) {
        guard let active = trackingMenu, active.generation == generation else { return }
        closedMenu = active
        closedGeneration = generation
        trackingMenu = nil
        statusItem?.closeMenu()
        publishMenuGenerations()
    }

    private func openMenu() -> Bool {
        guard statusItem != nil, menu != nil else { return false }
        guard trackingMenu == nil, !menuOpenScheduled else { return true }
        menuOpenScheduled = true
        DispatchQueue.main.async { [weak self] in self?.presentMenu() }
        return true
    }

    private func presentMenu() {
        guard menuOpenScheduled else { return }
        menuOpenScheduled = false
        guard let statusItem = statusItem, let menu = menu else { return }
        menu.prepareForOpening()
        trackingMenu = menu
        publishMenuGenerations()
        statusItem.openMenu(menu)
    }

    private func makeStatusItem() -> TrayStatusItem? {
        guard let item = TrayStatusItem(onMenuRequested: { [weak self] in
            self?.channel.invokeMethod("onMenuRequested", arguments: nil)
        }) else {
            return nil
        }
        statusItem = item
        return item
    }

    private func makeImage(_ icon: [String: Any]) -> NSImage? {
        let size = icon["size"] as? Int ?? 18
        let pointSize = NSSize(width: size, height: size)
        let image = NSImage(size: pointSize)
        for rep in icon["reps"] as? [[String: Any]] ?? [] {
            guard let encoded = rep["bytes"] as? String,
                  let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
                  let bitmap = NSBitmapImageRep(data: data) else {
                continue
            }
            bitmap.size = pointSize
            image.addRepresentation(bitmap)
        }
        guard !image.representations.isEmpty else {
            return nil
        }
        image.isTemplate = icon["isTemplate"] as? Bool ?? false
        return image
    }
}
