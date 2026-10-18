import AppKit
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case noPermission
    case noDisplay
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .noPermission: return "Screen Recording permission needed. Enable ScreenAnswer in System Settings → Privacy & Security → Screen Recording, then relaunch."
        case .noDisplay: return "Couldn't find a display to capture."
        case .encodeFailed: return "Couldn't encode the screenshot."
        }
    }
}

enum ScreenCapture {
    /// Longest edge sent to the model. Big enough to read small text, small enough to be fast.
    static let maxLongEdge: CGFloat = 2048

    /// Captures the display the mouse is on (excluding this app's own windows) and returns JPEG data.
    static func captureScreenUnderCursor() async throws -> Data {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let screenID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID

        // Don't gate on CGPreflightScreenCaptureAccess(): it can report "denied" even after the
        // user has granted access, which made the system prompt reappear. Just try; macOS
        // shows its own prompt the first time, and we only report a problem if capture fails.
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch let error as NSError where error.domain == SCStreamErrorDomain
                                       && error.code == SCStreamError.userDeclined.rawValue {
            throw CaptureError.noPermission
        }
        guard let display = content.displays.first(where: { $0.displayID == screenID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let scale = screen?.backingScaleFactor ?? 2
        var width = CGFloat(display.width) * scale
        var height = CGFloat(display.height) * scale
        let longEdge = max(width, height)
        if longEdge > maxLongEdge {
            let factor = maxLongEdge / longEdge
            width *= factor
            height *= factor
        }

        let config = SCStreamConfiguration()
        config.width = Int(width)
        config.height = Int(height)
        config.showsCursor = false

        let captured = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let frame = screen?.frame ?? CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
        let image = markCursor(on: captured, mouse: mouse, screenFrame: frame) ?? captured
        let rep = NSBitmapImageRep(cgImage: image)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw CaptureError.encodeFailed
        }
        return jpeg
    }

    /// Draws a red ring where the mouse is, so the model knows which question you're pointing at.
    private static func markCursor(on image: CGImage, mouse: NSPoint, screenFrame: CGRect) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Both AppKit screen coordinates and CGContext use a bottom-left origin.
        let x = (mouse.x - screenFrame.minX) / screenFrame.width * w
        let y = (mouse.y - screenFrame.minY) / screenFrame.height * h
        let radius = max(w, h) * 0.012
        ctx.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(max(3, radius * 0.25))
        ctx.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        return ctx.makeImage()
    }
}
