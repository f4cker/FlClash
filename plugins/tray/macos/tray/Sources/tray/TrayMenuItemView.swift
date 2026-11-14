import AppKit

final class TrayMenuItemView: NSView {
    struct Icon {
        let monogram: String
        let background: NSColor
        let foreground: NSColor
        let image: NSImage?

        init(_ entry: [String: Any]) {
            monogram = String((entry["monogram"] as? String ?? "?").prefix(2))
            background = TrayMenuItemView.color(entry["background"], fallback: .quaternaryLabelColor)
            foreground = TrayMenuItemView.color(entry["foreground"], fallback: .secondaryLabelColor)
            if let encoded = entry["png"] as? String, encoded.utf8.count <= 2_800_000,
               let data = Data(base64Encoded: encoded),
               data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
               let bitmap = NSBitmapImageRep(data: data),
               bitmap.pixelsWide > 0, bitmap.pixelsWide <= 4096,
               bitmap.pixelsHigh > 0, bitmap.pixelsHigh <= 4096 {
                let image = NSImage(size: NSSize(width: 16, height: 16))
                bitmap.size = image.size
                image.addRepresentation(bitmap)
                image.isTemplate = false
                self.image = image
            } else {
                image = nil
            }
        }
    }

    struct Badge {
        let label: String
        let background: NSColor
        let foreground: NSColor

        init(_ entry: [String: Any]) {
            label = entry["label"] as? String ?? ""
            background = TrayMenuItemView.color(entry["background"], fallback: .quaternaryLabelColor)
            foreground = TrayMenuItemView.color(entry["foreground"], fallback: .labelColor)
        }
    }

    struct Content {
        let label: String
        let detail: String?
        let icon: Icon?
        let badge: Badge?
        let accessibilityLabel: String?
        let isCheckbox: Bool
        let checked: Bool
        let enabled: Bool
        let hasSubmenu: Bool

        var fullLabel: String {
            accessibilityLabel ?? [label, detail, badge?.label].compactMap { $0 }.joined(separator: ", ")
        }
    }

    private struct Metrics {
        let height: CGFloat
        let leadingX: CGFloat = 12
        let leadingWidth: CGFloat = 16
        let titleGap: CGFloat = 8
        var titleX: CGFloat { leadingX + leadingWidth + titleGap }
        let trailing: CGFloat = 18
        let highlightInset: CGFloat = 5
        let font: NSFont

        static var current: Metrics {
            let font = NSFont.menuFont(ofSize: max(13, NSFont.menuFont(ofSize: 0).pointSize))
            let height: CGFloat
            if #available(macOS 26, *) {
                height = 28
            } else {
                height = 26
            }
            return Metrics(height: max(height, font.pointSize + 10), font: font)
        }
    }

    private static let metrics = Metrics.current
    private static let detailGap: CGFloat = 12
    private static let arrowGap: CGFloat = 8
    private static let detailFont = NSFont.monospacedDigitSystemFont(ofSize: metrics.font.pointSize, weight: .regular)
    private static let badgeFont = NSFont.monospacedDigitSystemFont(ofSize: max(12, metrics.font.pointSize - 1), weight: .medium)
    private static let checkmark = symbol("checkmark", weight: .medium)
    private static let arrow = symbol("chevron.right", weight: .semibold)

    private var content: Content
    private let selection = SelectionView()
    private let canvas = Canvas()

    static func preferredWidth(_ content: Content) -> CGFloat {
        var width = metrics.titleX + Self.width(content.label) + metrics.trailing
        if let detail = content.detail {
            width += min(110, Self.width(detail, font: detailFont)) + detailGap
        }
        if let badge = content.badge {
            width += badgeWidth(badge.label) + detailGap
        }
        if content.hasSubmenu {
            width += arrow.size.width + arrowGap
        }
        return ceil(width)
    }

    init(content: Content, width: CGFloat) {
        self.content = content
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.metrics.height))
        autoresizingMask = [.width]
        selection.material = .selection
        selection.blendingMode = .withinWindow
        selection.state = .active
        selection.isEmphasized = true
        selection.isHidden = true
        selection.wantsLayer = true
        selection.layer?.cornerRadius = 5
        selection.layer?.cornerCurve = .continuous
        selection.layer?.masksToBounds = true
        addSubview(selection)
        canvas.render = { [weak self] in self?.drawContent() }
        addSubview(canvas)
        updateAccessibility()
    }

    func update(content: Content) {
        let previous = self.content
        self.content = content
        updateAccessibility()
        updateHighlight(enclosingMenuItem?.isHighlighted == true)
        canvas.needsDisplay = true
        if previous.fullLabel != content.fullLabel {
            NSAccessibility.post(element: self, notification: .titleChanged)
        }
        if previous.checked != content.checked || previous.enabled != content.enabled || previous.badge?.label != content.badge?.label {
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }

    private func updateAccessibility() {
        toolTip = content.fullLabel
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(content.fullLabel)
        setAccessibilityEnabled(content.enabled)
        if content.isCheckbox {
            setAccessibilityValue(content.checked ? 1 : 0)
            setAccessibilitySelected(content.checked)
        }
        if content.hasSubmenu {
            setAccessibilityRoleDescription(NSLocalizedString("submenu", comment: "Menu item with a submenu"))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let submenu = enclosingMenuItem?.submenu {
            setAccessibilityChildren([submenu])
        }
    }

    override func layout() {
        super.layout()
        selection.frame = bounds.insetBy(dx: Self.metrics.highlightInset, dy: 0)
        canvas.frame = bounds
    }

    func updateHighlight(_ highlighted: Bool) {
        selection.isHidden = !(content.enabled && highlighted)
        canvas.needsDisplay = true
    }

    private var isHighlighted: Bool {
        content.enabled && !selection.isHidden
    }

    private func drawContent() {
        let metrics = Self.metrics
        let highlighted = isHighlighted
        let primary: NSColor = highlighted ? .selectedMenuItemTextColor : content.enabled ? .labelColor : .disabledControlTextColor
        if content.checked {
            drawSymbol(Self.checkmark, x: metrics.leadingX + (metrics.leadingWidth - min(12, Self.checkmark.size.width)) / 2, color: primary, maxWidth: 12)
        } else if !content.isCheckbox, let icon = content.icon {
            let rect = NSRect(x: metrics.leadingX, y: (bounds.height - metrics.leadingWidth) / 2, width: metrics.leadingWidth, height: metrics.leadingWidth)
            if let image = icon.image {
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: content.enabled ? 1 : 0.45, respectFlipped: true, hints: nil)
            } else {
                let background = highlighted ? NSColor.white.withAlphaComponent(0.12) : icon.background
                background.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
                let color = highlighted ? NSColor.selectedMenuItemTextColor : Self.readable(icon.foreground, on: background)
                drawText(icon.monogram, x: rect.minX, width: 16, color: content.enabled ? color : .disabledControlTextColor,
                         font: .systemFont(ofSize: 10, weight: .semibold), alignment: .center)
            }
        }
        var trailingX = bounds.width - metrics.trailing
        if content.hasSubmenu {
            drawSymbol(Self.arrow, x: trailingX - Self.arrow.size.width, color: primary)
            trailingX -= Self.arrow.size.width + Self.arrowGap
        }
        if let badge = content.badge {
            let width = min(Self.badgeWidth(badge.label), max(46, trailingX - metrics.titleX))
            let height = ceil(Self.badgeFont.ascender - Self.badgeFont.descender) + 4
            let rect = NSRect(x: trailingX - width, y: (bounds.height - height) / 2, width: width, height: height)
            let background = highlighted ? NSColor.white.withAlphaComponent(0.12) : badge.background
            background.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
            let color = highlighted ? NSColor.selectedMenuItemTextColor : Self.readable(badge.foreground, on: background)
            drawText(badge.label, x: rect.minX + 6, width: width - 12, color: content.enabled ? color : .disabledControlTextColor,
                     font: Self.badgeFont, alignment: .right, lineBreakMode: .byTruncatingMiddle)
            trailingX -= width + Self.detailGap
        }
        if let detail = content.detail {
            let color: NSColor = highlighted ? .selectedMenuItemTextColor : content.enabled ? .secondaryLabelColor : .disabledControlTextColor
            let width = min(110, Self.width(detail, font: Self.detailFont), max(0, trailingX - metrics.titleX))
            drawText(detail, x: trailingX - width, width: width, color: color, font: Self.detailFont, alignment: .right)
            trailingX -= width + Self.detailGap
        }
        drawText(content.label, x: metrics.titleX, width: trailingX - metrics.titleX, color: primary, font: metrics.font)
    }

    private static func badgeWidth(_ label: String) -> CGFloat {
        let isDelay = label.range(of: #"^\d+\s*ms$"#, options: .regularExpression) != nil
        let measured = width(label, font: badgeFont) + 12
        if isDelay { return max(label.filter(\.isNumber).count >= 5 ? 76 : 60, measured) }
        return max(46, min(110, measured))
    }

    override func mouseUp(with event: NSEvent) {
        _ = activate()
    }

    override func accessibilityPerformPress() -> Bool {
        content.hasSubmenu ? accessibilityPerformShowMenu() : activate()
    }

    override func accessibilityPerformShowMenu() -> Bool {
        guard content.enabled, let item = enclosingMenuItem, item.isEnabled,
              let submenu = item.submenu else { return false }
        return submenu.popUp(positioning: nil, at: NSPoint(x: bounds.maxX, y: 0), in: self)
    }

    private func activate() -> Bool {
        guard content.enabled, !content.hasSubmenu, let item = enclosingMenuItem,
              item.isEnabled, let action = item.action else { return false }
        var root = item.menu
        while let parent = root?.supermenu { root = parent }
        root?.cancelTracking()
        return NSApp.sendAction(action, to: item.target, from: item)
    }

    private func drawText(_ text: String, x: CGFloat, width: CGFloat, color: NSColor, font: NSFont, alignment: NSTextAlignment = .left, lineBreakMode: NSLineBreakMode = .byTruncatingTail) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = lineBreakMode
        style.alignment = alignment
        let height = ceil(font.ascender - font.descender)
        let rect = NSRect(x: x, y: (bounds.height - height) / 2, width: max(width, 0), height: height)
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin],
                               attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    private func drawSymbol(_ image: NSImage, x: CGFloat, color: NSColor, maxWidth: CGFloat = .infinity) {
        let scale = min(1, maxWidth / max(1, image.size.width))
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = NSRect(x: x, y: ((bounds.height - size.height) / 2).rounded(), width: size.width, height: size.height)
        let tinted = NSImage(size: size, flipped: false) { bounds in
            image.draw(in: bounds)
            color.setFill()
            bounds.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func width(_ text: String, font: NSFont = metrics.font) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func symbol(_ name: String, weight: NSFont.Weight) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: metrics.font.pointSize, weight: weight)) ?? NSImage()
    }

    private static func color(_ value: Any?, fallback: NSColor) -> NSColor {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              number.doubleValue >= 0, number.doubleValue <= 4_294_967_295 else { return fallback }
        let argb = number.uint32Value
        return NSColor(srgbRed: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255,
                       blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
    }

    private static func readable(_ foreground: NSColor, on background: NSColor) -> NSColor {
        guard let fg = foreground.usingColorSpace(.sRGB), let bg = background.usingColorSpace(.sRGB) else { return .labelColor }
        func luminance(_ color: NSColor) -> CGFloat {
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
        }
        guard bg.alphaComponent > 0.5 else { return .labelColor }
        let f = luminance(fg), b = luminance(bg)
        return fg.alphaComponent > 0.5 && (max(f, b) + 0.05) / (min(f, b) + 0.05) >= 3 ? foreground : b > 0.4 ? .black : .white
    }

    private final class SelectionView: NSVisualEffectView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private final class Canvas: NSView {
        var render: (() -> Void)?
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func draw(_ dirtyRect: NSRect) { render?() }
    }
}
