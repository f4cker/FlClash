import AppKit

enum TrayMenuTopology {
    static func grouped(_ entries: [[String: Any]]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for entry in entries {
            if entry["type"] as? String == "checkbox", let group = entry["segmentGroup"] as? String {
                if let last = result.last, last["type"] as? String == "segments", last["label"] as? String == group {
                    var children = last["items"] as? [[String: Any]] ?? []
                    children.append(entry)
                    result[result.count - 1]["items"] = children
                } else {
                    result.append(["type": "segments", "label": group, "id": entry["id"] ?? 0, "items": [entry]])
                }
            } else {
                result.append(entry)
            }
        }
        return result
    }

    static func sharedIndex(_ entry: [String: Any], current: [[String: Any]], desired: [[String: Any]]) -> Int? {
        func sameIdentity(_ other: [String: Any]) -> Bool {
            entry["type"] as? String == other["type"] as? String &&
                entry["transientStatusKey"] as? String == other["transientStatusKey"] as? String &&
                entry["label"] as? String == other["label"] as? String
        }
        guard current.filter(sameIdentity).count == 1 else { return nil }
        let matches = desired.indices.filter { sameIdentity(desired[$0]) }
        return matches.count == 1 ? matches[0] : nil
    }

    static func matches(_ current: [[String: Any]], _ desired: [[String: Any]]) -> Bool {
        guard current.count == desired.count else { return false }
        return zip(current, desired).allSatisfy { old, new in
            let type = old["type"] as? String ?? ""
            guard type == new["type"] as? String,
                  old["id"] as? Int == new["id"] as? Int,
                  old["transientStatusKey"] as? String == new["transientStatusKey"] as? String else { return false }
            if type == "separator" { return true }
            guard old["label"] as? String == new["label"] as? String else { return false }
            return (type != "submenu" && type != "segments") || matches(
                old["items"] as? [[String: Any]] ?? [],
                new["items"] as? [[String: Any]] ?? []
            )
        }
    }
}

final class TrayMenu: NSMenu, NSMenuDelegate {
    private let onSelect: (Int, Int) -> Void
    private let onClose: ((Int) -> Void)?
    private let maximumWidth: CGFloat
    private var entries: [[String: Any]]
    private var initiallyEnabled: [Bool] = []
    private var contents: [TrayMenuItemView.Content?] = []
    private(set) var generation: Int

    init(items: [[String: Any]], generation: Int, onSelect: @escaping (Int, Int) -> Void,
         onClose: ((Int) -> Void)? = nil, isSubmenu: Bool = false) {
        self.onSelect = onSelect
        self.onClose = onClose
        self.generation = generation
        let items = TrayMenuTopology.grouped(items)
        entries = items
        maximumWidth = isSubmenu ? 420 : 380
        super.init(title: "")
        autoenablesItems = false
        delegate = self
        showsStateColumn = false
        font = .menuFont(ofSize: max(13, NSFont.menuFont(ofSize: 0).pointSize))
        for entry in items {
            let item = makeItem(entry)
            addItem(item)
            initiallyEnabled.append(item.isEnabled)
            contents.append(item.isSeparatorItem ? nil : TrayMenu.content(entry, item))
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reconcile(items: [[String: Any]], generation: Int) -> Bool {
        let items = TrayMenuTopology.grouped(items)
        if TrayMenuTopology.matches(entries, items) {
            apply(items: items, generation: generation)
            return true
        }
        reconcileRetained(items: items)
        return false
    }

    private func reconcileRetained(items desired: [[String: Any]]) {
        let original = entries
        for (index, item) in items.enumerated() {
            guard !item.isSeparatorItem else { continue }
            var entry = original[index]
            if let status = TrayMenuTransientStatus.retained(entry, current: original, desired: desired) {
                entry = status
                TrayMenu.configure(item, entry)
            } else if let match = TrayMenuTopology.sharedIndex(entry, current: original, desired: desired) {
                entry = desired[match]
                entry["id"] = original[index]["id"]
                entry["enabled"] = (entry["enabled"] as? Bool ?? true) && initiallyEnabled[index]
                if entry["type"] as? String == "segments" {
                    let oldChildren = original[index]["items"] as? [[String: Any]] ?? []
                    let newChildren = entry["items"] as? [[String: Any]] ?? []
                    entry["items"] = oldChildren.map { old -> [String: Any] in
                        var child = old
                        if let match = TrayMenuTopology.sharedIndex(old, current: oldChildren, desired: newChildren) {
                            child = newChildren[match]
                            child["id"] = old["id"]
                        } else {
                            child["enabled"] = false
                        }
                        return child
                    }
                }
                TrayMenu.configure(item, entry)
                (item.submenu as? TrayMenu)?.reconcileRetained(items: entry["items"] as? [[String: Any]] ?? [])
            } else {
                entry["enabled"] = false
                item.isEnabled = false
                (item.submenu as? TrayMenu)?.reconcileRetained(items: [])
            }
            if let submenu = item.submenu as? TrayMenu { entry["items"] = submenu.entries }
            entries[index] = entry
            let content = TrayMenu.content(entry, item)
            contents[index] = content
            (item.view as? TrayMenuItemView)?.update(content: content)
            (item.view as? TrayMenuSegmentsView)?.update(entries: entry["items"] as? [[String: Any]] ?? [], enabled: item.isEnabled)
        }
    }

    private func apply(items entries: [[String: Any]], generation: Int) {
        self.entries = entries
        self.generation = generation
        initiallyEnabled = entries.map { $0["enabled"] as? Bool ?? true }
        for (index, pair) in zip(items, entries).enumerated() {
            let (item, entry) = pair
            guard !item.isSeparatorItem else { continue }
            TrayMenu.configure(item, entry)
            if let submenu = item.submenu as? TrayMenu {
                submenu.apply(items: entry["items"] as? [[String: Any]] ?? [], generation: generation)
            }
            let content = TrayMenu.content(entry, item)
            contents[index] = content
            (item.view as? TrayMenuItemView)?.update(content: content)
            (item.view as? TrayMenuSegmentsView)?.update(entries: entry["items"] as? [[String: Any]] ?? [], enabled: item.isEnabled)
        }
    }

    func prepareForOpening() {
        for item in items {
            item.view = nil
            (item.submenu as? TrayMenu)?.prepareForOpening()
        }
    }

    private static func detail(_ entry: [String: Any]) -> String? {
        guard let detail = entry["detail"] as? String, !detail.isEmpty else { return nil }
        return detail
    }

    private static func configure(_ item: NSMenuItem, _ entry: [String: Any]) {
        let type = entry["type"] as? String ?? ""
        item.title = entry["label"] as? String ?? ""
        if type == "segments" {
            item.title = (entry["items"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String }.joined(separator: ", ")
        }
        item.tag = entry["id"] as? Int ?? 0
        item.isEnabled = entry["enabled"] as? Bool ?? true
        item.toolTip = entry["accessibilityLabel"] as? String ?? [item.title, detail(entry)].compactMap { $0 }.joined(separator: ", ")
        item.state = type == "checkbox" && entry["checked"] as? Bool == true ? .on : .off
    }

    private func makeItem(_ entry: [String: Any]) -> NSMenuItem {
        let type = entry["type"] as? String ?? ""
        if type == "separator" { return NSMenuItem.separator() }
        let item = NSMenuItem()
        TrayMenu.configure(item, entry)
        if type == "submenu" {
            let children = entry["items"] as? [[String: Any]] ?? []
            setSubmenu(TrayMenu(items: children, generation: generation, onSelect: onSelect, isSubmenu: true), for: item)
        } else {
            item.target = self
            item.action = #selector(didSelectItem(_:))
        }
        return item
    }

    private static func content(_ entry: [String: Any], _ item: NSMenuItem) -> TrayMenuItemView.Content {
        TrayMenuItemView.Content(
            label: item.title,
            detail: detail(entry),
            icon: (entry["icon"] as? [String: Any]).map { TrayMenuItemView.Icon($0) },
            badge: (entry["badge"] as? [String: Any]).map { TrayMenuItemView.Badge($0) },
            accessibilityLabel: entry["accessibilityLabel"] as? String,
            isCheckbox: entry["type"] as? String == "checkbox",
            checked: item.state == .on,
            enabled: item.isEnabled,
            hasSubmenu: item.hasSubmenu
        )
    }

    // AppKit does not support resizing custom row views during tracking.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard items.contains(where: { !$0.isSeparatorItem && $0.view == nil }) else { return }
        let measuredContents = zip(entries, contents).flatMap { entry, content -> [TrayMenuItemView.Content] in
            if entry["type"] as? String == "segments" {
                return (entry["items"] as? [[String: Any]] ?? []).map { child in
                    let item = NSMenuItem()
                    TrayMenu.configure(item, child)
                    return TrayMenu.content(child, item)
                }
            }
            return content.map { [$0] } ?? []
        }
        let width = min(maximumWidth, measuredContents.map {
            TrayMenuItemView.preferredWidth($0)
        }.max() ?? 0)
        for (index, pair) in zip(items, contents).enumerated() {
            let (item, content) = pair
            if entries[index]["type"] as? String == "segments" {
                if item.view == nil {
                    item.view = TrayMenuSegmentsView(entries: entries[index]["items"] as? [[String: Any]] ?? [], width: width) { [weak self] id in
                        guard let self = self else { return }
                        self.onSelect(id, self.generation)
                    }
                }
            } else if item.view == nil, let content = content {
                item.view = TrayMenuItemView(content: content, width: width)
            }
        }
    }

    // AppKit does not redraw an item's view when its highlight changes.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        (highlightedItem?.view as? TrayMenuItemView)?.updateHighlight(false)
        (item?.view as? TrayMenuItemView)?.updateHighlight(true)
        (highlightedItem?.view as? TrayMenuSegmentsView)?.updateHighlight(false)
        (item?.view as? TrayMenuSegmentsView)?.updateHighlight(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        for item in items { (item.view as? TrayMenuSegmentsView)?.updateHighlight(false) }
        onClose?(generation)
    }

    @objc private func didSelectItem(_ sender: NSMenuItem) {
        guard sender.isEnabled else { return }
        if let segments = sender.view as? TrayMenuSegmentsView {
            segments.activateFocused()
            return
        }
        onSelect(sender.tag, generation)
    }
}
