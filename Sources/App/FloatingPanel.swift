import Cocoa

/// 游標旁邊的小浮動視窗：用來顯示候選字，以及「中／英」模式提示
final class FloatingPanel {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var hideTimer: Timer?

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let box = NSVisualEffectView()
        box.material = .popover
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 7
        box.addSubview(label)
        panel.contentView = box
    }

    /// 顯示在 `rect`（游標位置，螢幕座標）的正下方；`seconds` 有值時會自動消失
    func show(_ text: NSAttributedString, near rect: NSRect, autoHide seconds: TimeInterval? = nil) {
        hideTimer?.invalidate()
        label.attributedStringValue = text
        let pad: CGFloat = 8
        let size = label.fittingSize
        let full = NSSize(width: size.width + pad * 2, height: size.height + pad * 2)
        label.frame = NSRect(x: pad, y: pad, width: size.width, height: size.height)

        var anchor = rect
        if anchor.origin == .zero { anchor = NSRect(origin: NSEvent.mouseLocation, size: .zero) }   // 有些 app 不回報游標位置
        var origin = NSPoint(x: anchor.minX, y: anchor.minY - full.height - 4)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor.origin) })?.visibleFrame {
            if origin.y < screen.minY { origin.y = anchor.maxY + 4 }                 // 下面放不下就放上面
            origin.x = max(screen.minX, min(origin.x, screen.maxX - full.width))
        }
        panel.setFrame(NSRect(origin: origin, size: full), display: true)
        panel.orderFront(nil)
        if let seconds {
            hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.hide() }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        panel.orderOut(nil)
    }
}
