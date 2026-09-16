import AppKit

/// Original asymmetric loop geometry, shared by native UI and the icon-export tool.
@MainActor enum BrandArt {
    private static func loop(in rect: NSRect) -> NSBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = NSBezierPath()
        path.move(to: point(0.48, 0.50))
        path.curve(
            to: point(0.08, 0.50), controlPoint1: point(0.22, 0.95),
            controlPoint2: point(0.02, 0.85))
        path.curve(
            to: point(0.53, 0.51), controlPoint1: point(0.15, 0.05),
            controlPoint2: point(0.35, 0.18))
        path.curve(
            to: point(0.93, 0.55), controlPoint1: point(0.79, 0.89),
            controlPoint2: point(0.96, 0.84))
        path.curve(
            to: point(0.62, 0.37), controlPoint1: point(0.90, 0.23),
            controlPoint2: point(0.78, 0.19))
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }

    static let menuIdle = menuImage(active: false)
    static let menuActive = menuImage(active: true)

    private static func menuImage(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = loop(in: NSRect(x: 1, y: 1, width: 21, height: 16))
            path.lineWidth = 1.8
            path.stroke()
            if active {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 20, y: 0, width: 3, height: 3)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Limitless"
        return image
    }

    static func appIcon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { bounds in
            let frame = bounds.insetBy(dx: size * 0.08, dy: size * 0.08)
            let tile = NSBezierPath(roundedRect: frame, xRadius: size * 0.19, yRadius: size * 0.19)
            NSGradient(
                starting: NSColor(srgbRed: 0.24, green: 0.35, blue: 0.73, alpha: 1),
                ending: NSColor(srgbRed: 0.09, green: 0.13, blue: 0.40, alpha: 1))?
                .draw(in: tile, angle: -90)
            NSColor.white.withAlphaComponent(0.30).setStroke()
            tile.lineWidth = max(1, size * 0.003)
            tile.stroke()
            let mark = loop(in: frame.insetBy(dx: size * 0.13, dy: size * 0.18))
            mark.lineWidth = size * 0.055
            NSColor(srgbRed: 0.92, green: 0.96, blue: 1, alpha: 1).setStroke()
            mark.stroke()
            return true
        }
    }
}
