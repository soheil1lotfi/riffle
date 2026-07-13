import AppKit

/// The floating switcher UI: a vertical list of rows, each showing
/// the app icon and window title only (no window previews).
final class SwitcherPanelController {
    private let panel: NSPanel
    private let stack = NSStackView()
    // Sits over the blur; its alpha turns the panel from glassy to solid.
    private let backgroundOverlay = NSView()
    private var rows: [SwitcherRow] = []

    private static let maxVisibleRows = 18

    /// Per-row sizing that grows as the list shrinks, so a couple of windows
    /// fill a comfortable panel instead of a cramped strip. Interpolated
    /// between a roomy layout (one row) and the compact layout (a full list).
    fileprivate struct Metrics {
        let rowWidth: CGFloat
        let rowHeight: CGFloat
        let iconSize: CGFloat
        let titleFontSize: CGFloat
        let cornerRadius: CGFloat

        static let roomy = Metrics(rowWidth: 560, rowHeight: 64, iconSize: 44, titleFontSize: 19, cornerRadius: 12)
        static let compact = Metrics(rowWidth: 460, rowHeight: 34, iconSize: 22, titleFontSize: 13, cornerRadius: 8)

        // `scale` shifts the whole dynamic range up or down (the user setting);
        // corner radius is left unscaled so rounding stays consistent.
        static func forCount(_ count: Int, scale: CGFloat) -> Metrics {
            let span = max(1, maxVisibleRows - 1)
            let t = min(max(CGFloat(count - 1) / CGFloat(span), 0), 1)
            func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * t) * scale }
            return Metrics(
                rowWidth: lerp(roomy.rowWidth, compact.rowWidth),
                rowHeight: lerp(roomy.rowHeight, compact.rowHeight),
                iconSize: lerp(roomy.iconSize, compact.iconSize),
                titleFontSize: lerp(roomy.titleFontSize, compact.titleFontSize),
                cornerRadius: roomy.cornerRadius + (compact.cornerRadius - roomy.cornerRadius) * t
            )
        }
    }

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        panel.contentView = effect

        backgroundOverlay.wantsLayer = true
        backgroundOverlay.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(backgroundOverlay)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            backgroundOverlay.topAnchor.constraint(equalTo: effect.topAnchor),
            backgroundOverlay.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            backgroundOverlay.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            backgroundOverlay.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])
    }

    func show(windows: [WindowInfo], selected: Int, on screen: NSScreen?) {
        rows.forEach { $0.removeFromSuperview() }
        backgroundOverlay.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(CGFloat(Config.shared.backgroundOpacity)).cgColor
        let scale = CGFloat(Config.shared.listScale)
        let metrics = Metrics.forCount(min(windows.count, Self.maxVisibleRows), scale: scale)
        rows = windows.prefix(Self.maxVisibleRows).map { SwitcherRow(window: $0, metrics: metrics) }
        rows.forEach { stack.addArrangedSubview($0) }
        if windows.count > Self.maxVisibleRows {
            let more = NSTextField(labelWithString: "… and \(windows.count - Self.maxVisibleRows) more")
            more.font = .systemFont(ofSize: 11)
            more.textColor = .secondaryLabelColor
            stack.addArrangedSubview(more)
        }
        select(selected)

        stack.layoutSubtreeIfNeeded()
        let size = stack.fittingSize
        let target = screen ?? NSScreen.main
        let screenFrame = target?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func select(_ index: Int) {
        for (i, row) in rows.enumerated() {
            row.isSelected = (i == index)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private final class SwitcherRow: NSView {
    // Same neutral hue for both states: a light wash for the resting row and a
    // darker fill for the selected one (replacing the old accent-blue).
    private static let restingBackground = NSColor.systemGray.withAlphaComponent(0.22)
    private static let selectedBackground = NSColor.systemGray.withAlphaComponent(0.85)

    var isSelected: Bool = false {
        didSet {
            layer?.backgroundColor = isSelected
                ? Self.selectedBackground.cgColor
                : Self.restingBackground.cgColor
            titleLabel.textColor = isSelected ? .black : .labelColor
        }
    }

    private let titleLabel: NSTextField

    init(window: WindowInfo, metrics: SwitcherPanelController.Metrics) {
        titleLabel = NSTextField(labelWithString: window.title)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = metrics.cornerRadius

        let iconView = NSImageView()
        iconView.image = window.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: metrics.titleFontSize)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: metrics.rowWidth),
            heightAnchor.constraint(equalToConstant: metrics.rowHeight),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: metrics.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: metrics.iconSize),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
