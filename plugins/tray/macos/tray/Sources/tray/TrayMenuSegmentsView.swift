import AppKit

final class TrayMenuSegmentsView: NSView {
    private static let font = NSFont.menuFont(ofSize: max(13, NSFont.menuFont(ofSize: 0).pointSize))
    private static let trackHeight = max(30, ceil(font.ascender - font.descender) + 12)
    private let track = NSView()
    private let onSelect: (Int) -> Void
    private var entries: [[String: Any]]
    private var segments: [Segment] = []
    private var keyMonitor: Any?
    private var highlighted = false
    private var keyboardNavigation = false
    private var focusedSegment = 0
    private var enabled = true

    init(entries: [[String: Any]], width: CGFloat, onSelect: @escaping (Int) -> Void) {
        self.entries = entries
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.trackHeight + 8))
        autoresizingMask = [.width]
        track.wantsLayer = true
        track.layer?.cornerRadius = 8
        track.layer?.cornerCurve = .continuous
        addSubview(track)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        update(entries: entries, enabled: true)
        focusedSegment = entries.firstIndex { $0["checked"] as? Bool == true } ?? 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        track.frame = bounds.insetBy(dx: 5, dy: 4)
        guard !segments.isEmpty else { return }
        let width = (track.bounds.width - 6 - CGFloat(segments.count - 1) * 2) / CGFloat(segments.count)
        for (index, segment) in segments.enumerated() {
            segment.frame = NSRect(x: 3 + CGFloat(index) * (width + 2), y: 3,
                                   width: max(0, width), height: Self.trackHeight - 6)
        }
    }

    func update(entries: [[String: Any]], enabled: Bool) {
        let previousError = self.entries.first?["segmentError"] as? String
        self.entries = entries
        self.enabled = enabled
        if segments.count != entries.count {
            segments.forEach { $0.removeFromSuperview() }
            segments = entries.indices.map { index in
                let segment = Segment { [weak self] in self?.activate(index) }
                track.addSubview(segment)
                return segment
            }
            setAccessibilityChildren(segments)
        }
        for (index, entry) in entries.enumerated() {
            let segment = segments[index]
            segment.label = entry["label"] as? String ?? ""
            segment.selected = entry["checked"] as? Bool == true
            segment.enabled = enabled && (entry["enabled"] as? Bool ?? true)
            segment.toolTip = [segment.label, entry["detail"] as? String].compactMap { $0 }.joined(separator: ", ")
            segment.refresh()
        }
        setAccessibilityLabel(segments.map { $0.label }.joined(separator: ", "))
        refreshAppearance()
        needsLayout = true
        if let error = entries.first?["segmentError"] as? String, !error.isEmpty,
           error != previousError, window != nil {
            var menu = enclosingMenuItem?.menu
            while let parent = menu?.supermenu { menu = parent }
            menu?.cancelTracking()
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = error
                alert.runModal()
            }
        }
    }

    private var isDark: Bool { effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }

    private func refreshAppearance() {
        track.layer?.backgroundColor = (isDark ? NSColor.white.withAlphaComponent(0.07) : NSColor.black.withAlphaComponent(0.05)).cgColor
        segments.forEach { $0.refresh() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func activate(_ index: Int) {
        guard enabled, entries.indices.contains(index),
              entries[index]["enabled"] as? Bool != false,
              entries[index]["checked"] as? Bool != true,
              let id = entries[index]["id"] as? Int else { return }
        focusedSegment = index
        refreshFocus()
        onSelect(id)
    }

    func activateFocused() { activate(focusedSegment) }

    func updateHighlight(_ value: Bool) {
        highlighted = value
        keyboardNavigation = value && NSApp.currentEvent?.type == .keyDown
        if value {
            focusedSegment = entries.firstIndex { $0["checked"] as? Bool == true } ?? 0
            window?.makeFirstResponder(self)
        }
        refreshFocus()
    }

    private func refreshFocus() {
        for (index, segment) in segments.enumerated() {
            segment.keyboardFocused = highlighted && keyboardNavigation && index == focusedSegment
            segment.refresh()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        guard window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.highlighted, !self.entries.isEmpty,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 123, 124:
                self.keyboardNavigation = true
                let direction = event.keyCode == 123 ? -1 : 1
                self.focusedSegment = min(max(0, self.focusedSegment + direction), self.entries.count - 1)
                self.refreshFocus()
                return nil
            case 36, 49, 76:
                self.activateFocused()
                return nil
            default:
                return event
            }
        }
    }

    deinit {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
    }

    private final class Segment: NSView {
        var label = ""
        var selected = false
        var enabled = true
        var keyboardFocused = false
        private var hovered = false
        private let onPress: () -> Void

        init(onPress: @escaping () -> Void) {
            self.onPress = onPress
            super.init(frame: .zero)
            wantsLayer = true
            layer?.cornerRadius = 5
            layer?.cornerCurve = .continuous
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func refresh() {
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color: NSColor = selected
                ? NSColor.white.withAlphaComponent(dark ? 0.17 : 0.82)
                : hovered && enabled
                    ? (dark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.04))
                    : .clear
            layer?.backgroundColor = color.cgColor
            layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
            layer?.borderWidth = keyboardFocused ? 2 : 0
            setAccessibilityLabel(label)
            setAccessibilitySelected(selected)
            setAccessibilityValue(selected ? 1 : 0)
            setAccessibilityEnabled(enabled)
            NSAccessibility.post(element: self, notification: .valueChanged)
            needsDisplay = true
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) { hovered = true; refresh() }
        override func mouseExited(with event: NSEvent) { hovered = false; refresh() }
        override func mouseUp(with event: NSEvent) { if enabled { onPress() } }
        override func accessibilityPerformPress() -> Bool {
            guard enabled else { return false }
            onPress()
            return true
        }

        override func draw(_ dirtyRect: NSRect) {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byTruncatingTail
            let height = ceil(TrayMenuSegmentsView.font.ascender - TrayMenuSegmentsView.font.descender)
            (label as NSString).draw(with: NSRect(x: 2, y: (bounds.height - height) / 2, width: max(0, bounds.width - 4), height: height),
                                    options: [.usesLineFragmentOrigin],
                                    attributes: [.font: TrayMenuSegmentsView.font, .foregroundColor: NSColor.labelColor, .paragraphStyle: style])

        }
    }
}
