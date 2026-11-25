import AppKit

/// The Orbitile mark (3x3 tile grid) as a menu bar template image.
/// Template images only keep alpha: the active tile is solid, the others 40%, as in the design.
enum MenuBarIcon {
    static func make(side: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let inset: CGFloat = 1
            let k = (side - 2 * inset) / 100
            let n = 3.0, gap = 7.0, outer = 16.0, inner = 5.0
            let u = 100 / n, last = Int(n) - 1
            // (col0, row0, col1, row1, active)
            let tiles: [(Int, Int, Int, Int, Bool)] = [
                (0, 0, 1, 0, false), (2, 0, 2, 0, false), (2, 1, 2, 1, false),
                (1, 2, 2, 2, false), (0, 2, 0, 2, true), (0, 1, 0, 1, false),
            ]
            for (c0, r0, c1, r1, active) in tiles {
                let rect = CGRect(
                    x: inset + (Double(c0) * u + gap / 2) * k, y: inset + (Double(r0) * u + gap / 2) * k,
                    width: (Double(c1 - c0 + 1) * u - gap) * k, height: (Double(r1 - r0 + 1) * u - gap) * k)
                let radii = (
                    tl: (c0 == 0 && r0 == 0 ? outer : inner) * k, tr: (c1 == last && r0 == 0 ? outer : inner) * k,
                    br: (c1 == last && r1 == last ? outer : inner) * k, bl: (c0 == 0 && r1 == last ? outer : inner) * k)
                NSColor.black.withAlphaComponent(active ? 1 : 0.4).setFill()
                path(rect, radii).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Orbitile"
        return image
    }

    /// Rounded rect with a different radius per corner (view coordinates, y down).
    private static func path(_ r: CGRect, _ c: (tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat)) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: CGPoint(x: r.minX + c.tl, y: r.minY))
        p.line(to: CGPoint(x: r.maxX - c.tr, y: r.minY))
        p.appendArc(from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.maxX, y: r.minY + c.tr), radius: c.tr)
        p.line(to: CGPoint(x: r.maxX, y: r.maxY - c.br))
        p.appendArc(from: CGPoint(x: r.maxX, y: r.maxY), to: CGPoint(x: r.maxX - c.br, y: r.maxY), radius: c.br)
        p.line(to: CGPoint(x: r.minX + c.bl, y: r.maxY))
        p.appendArc(from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.minX, y: r.maxY - c.bl), radius: c.bl)
        p.line(to: CGPoint(x: r.minX, y: r.minY + c.tl))
        p.appendArc(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.minX + c.tl, y: r.minY), radius: c.tl)
        p.close()
        return p
    }
}
