import AppKit

/// A small floating bubble shown next to the mouse cursor. Never steals focus
/// and lets clicks pass through; any mouse click elsewhere dismisses it.
final class AnswerPanel {
    private let panel: NSPanel
    private let label: NSTextField
    private let background: NSView
    private var hideWorkItem: DispatchWorkItem?
    private var clickMonitor: Any?

    private let maxWidth: CGFloat = 320
    private let padding = CGSize(width: 7, height: 4)
    private let cursorOffset = CGPoint(x: 12, y: 10)

    init() {
        panel = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // Small, low-key tooltip-style chip: translucent dark grey, no shadow, light text.
        background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.72).cgColor
        background.layer?.cornerRadius = 4
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor

        label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = NSColor(white: 1, alpha: 0.88)
        label.isSelectable = false
        label.preferredMaxLayoutWidth = maxWidth - padding.width * 2

        background.addSubview(label)
        panel.contentView = background
    }

    func showLoading() {
        show("…", autoHide: false)
    }

    func showAnswer(_ text: String, hideAfter: Double) {
        show(text, autoHide: hideAfter > 0, delay: hideAfter)
    }

    func showError(_ text: String) {
        show("⚠️ " + text, autoHide: true, delay: 8)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        panel.orderOut(nil)
    }

    private func show(_ text: String, autoHide: Bool, delay: Double = 0) {
        hideWorkItem?.cancel()
        label.stringValue = text

        let textSize = label.sizeThatFits(NSSize(width: maxWidth - padding.width * 2, height: .greatestFiniteMagnitude))
        let size = NSSize(width: ceil(textSize.width) + padding.width * 2, height: ceil(textSize.height) + padding.height * 2)
        label.frame = NSRect(x: padding.width, y: padding.height, width: ceil(textSize.width), height: ceil(textSize.height))

        // Place to the lower-right of the cursor, flipping to stay on screen.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: mouse.x + cursorOffset.x, y: mouse.y - cursorOffset.y - size.height)
        if origin.x + size.width > bounds.maxX { origin.x = mouse.x - cursorOffset.x - size.width }
        if origin.y < bounds.minY { origin.y = mouse.y + cursorOffset.y }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()

        if clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.hide()
            }
        }

        if autoHide {
            let item = DispatchWorkItem { [weak self] in self?.hide() }
            hideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
}
