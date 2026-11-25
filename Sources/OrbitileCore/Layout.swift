import CoreGraphics
import Foundation

/// A tiling family: how many cells the screen is divided into.
/// Placed on the fan at 12h (2), 3h (4), 6h (6) and 9h (8).
public struct LayoutFamily: Equatable, Sendable {
    public let id: Int
    public let cols: Int
    public let rows: Int
    /// Angle on the fan in degrees, screen space (y down): -90 is 12 o'clock.
    public let angle: Double

    public var cellCount: Int { cols * rows }

    public func position(of index: Int) -> (col: Int, row: Int) {
        (index % cols, index / cols)
    }

    public static let all: [LayoutFamily] = [
        LayoutFamily(id: 2, cols: 2, rows: 1, angle: -90),
        LayoutFamily(id: 4, cols: 2, rows: 2, angle: 0),
        LayoutFamily(id: 6, cols: 3, rows: 2, angle: 90),
        LayoutFamily(id: 8, cols: 4, rows: 2, angle: 180),
    ]
}

public enum FanHit: Equatable, Sendable {
    case none
    case family(Int)
    case cell(Int)
}

/// Fan geometry in points, relative to the fan center (y grows down).
public enum FanGeometry {
    public static let discDiameter: CGFloat = 202
    public static let ringInner: CGFloat = 65
    public static let ringOuter: CGFloat = 97
    public static let hitInner: CGFloat = 62
    public static let hitOuter: CGFloat = 118
    public static let gridRect = CGRect(x: -48, y: -30, width: 96, height: 58)
    public static let gridGap: CGFloat = 2.5
    /// Outer radius used to keep the whole fan on screen.
    public static let extent: CGFloat = 119

    public static func cellRect(_ family: LayoutFamily, index: Int) -> CGRect {
        let g = gridRect
        let cw = (g.width - CGFloat(family.cols - 1) * gridGap) / CGFloat(family.cols)
        let ch = (g.height - CGFloat(family.rows - 1) * gridGap) / CGFloat(family.rows)
        let (c, r) = family.position(of: index)
        return CGRect(
            x: g.minX + CGFloat(c) * (cw + gridGap),
            y: g.minY + CGFloat(r) * (ch + gridGap),
            width: cw, height: ch)
    }

    /// Hit test for a pointer position relative to the fan center.
    /// Cells only count once a family is expanded.
    public static func hit(_ p: CGPoint, expanded: LayoutFamily?) -> FanHit {
        if let f = expanded {
            let pad = gridGap / 2 + 1
            for i in 0..<f.cellCount where cellRect(f, index: i).insetBy(dx: -pad, dy: -pad).contains(p) {
                return .cell(i)
            }
        }
        let d = hypot(p.x, p.y)
        guard d >= hitInner, d <= hitOuter else { return .none }
        let a = atan2(p.y, p.x) * 180 / .pi
        var best = 0
        var bestDiff = Double.infinity
        for (i, f) in LayoutFamily.all.enumerated() {
            let diff = abs((a - f.angle + 540).truncatingRemainder(dividingBy: 360) - 180)
            if diff < bestDiff { bestDiff = diff; best = i }
        }
        return .family(best)
    }

    /// Window frame for a cell inside `area` (AppKit coordinates, origin bottom-left).
    public static func targetRect(
        _ family: LayoutFamily, cell index: Int, in area: CGRect, inset: CGFloat = 6
    ) -> CGRect {
        let w = area.width / CGFloat(family.cols)
        let h = area.height / CGFloat(family.rows)
        let (c, r) = family.position(of: index)
        return CGRect(
            x: area.minX + CGFloat(c) * w,
            y: area.maxY - CGFloat(r + 1) * h,
            width: w, height: h
        ).insetBy(dx: inset, dy: inset)
    }

    /// Window frame for the bounding box of two cells (drag merge), same space as `targetRect`.
    public static func targetRect(
        _ family: LayoutFamily, from a: Int, to b: Int, in area: CGRect, inset: CGFloat = 6
    ) -> CGRect {
        let (ac, ar) = family.position(of: a)
        let (bc, br) = family.position(of: b)
        let c0 = min(ac, bc), c1 = max(ac, bc), r0 = min(ar, br), r1 = max(ar, br)
        let w = area.width / CGFloat(family.cols)
        let h = area.height / CGFloat(family.rows)
        return CGRect(
            x: area.minX + CGFloat(c0) * w,
            y: area.maxY - CGFloat(r1 + 1) * h,
            width: CGFloat(c1 - c0 + 1) * w, height: CGFloat(r1 - r0 + 1) * h
        ).insetBy(dx: inset, dy: inset)
    }

    /// Fan-space rect of the cells between two cells (mini-screen highlight).
    public static func cellRect(_ family: LayoutFamily, from a: Int, to b: Int) -> CGRect {
        cellRect(family, index: a).union(cellRect(family, index: b))
    }

    /// Slides the fan center so the whole disc fits inside `bounds`.
    public static func clampCenter(_ p: CGPoint, in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(p.x, bounds.minX + extent), bounds.maxX - extent),
            y: min(max(p.y, bounds.minY + extent), bounds.maxY - extent))
    }
}

/// Hover state while the button is held.
public struct FanState: Equatable, Sendable {
    public private(set) var familyIndex: Int?
    public private(set) var cell: Int?
    /// First cell of a drag (merge). While set, the family cannot change.
    public private(set) var anchor: Int?

    public init(family: Int? = nil) {
        if let family, LayoutFamily.all.indices.contains(family) { familyIndex = family }
    }

    public var family: LayoutFamily? { familyIndex.map { LayoutFamily.all[$0] } }

    /// Only a hovered cell of an expanded family is a valid selection.
    public var selection: (family: LayoutFamily, cell: Int)? {
        guard let f = family, let c = cell else { return nil }
        return (f, c)
    }

    /// Cells to apply: the dragged range's endpoints, or the hovered cell twice.
    public var span: (family: LayoutFamily, first: Int, last: Int)? {
        guard let f = family, let c = cell else { return nil }
        return (f, anchor ?? c, c)
    }

    public var isDragging: Bool { anchor != nil }

    /// Starts a drag on the hovered cell. No-op without one.
    public mutating func beginDrag() { anchor = cell }
    public mutating func endDrag() { anchor = nil }

    /// Keyboard shortcut: jump straight to a family.
    public mutating func select(family i: Int) {
        guard LayoutFamily.all.indices.contains(i), anchor == nil else { return }
        if i != familyIndex { familyIndex = i; cell = nil }
    }

    public mutating func update(_ hit: FanHit) {
        switch hit {
        case .family(let i):
            if anchor == nil, i != familyIndex { familyIndex = i; cell = nil }
        case .cell(let i):
            cell = i
        case .none:
            cell = nil
        }
    }
}

/// CSS-style cubic-bezier easing: maps linear time `t` in 0...1 to progress.
public enum Easing {
    public static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        func coord(_ a: Double, _ b: Double, _ u: Double) -> Double {
            3 * a * (1 - u) * (1 - u) * u + 3 * b * (1 - u) * u * u + u * u * u
        }
        var lo = 0.0, hi = 1.0, u = t
        for _ in 0..<24 {
            u = (lo + hi) / 2
            if coord(x1, x2, u) < t { lo = u } else { hi = u }
        }
        return coord(y1, y2, u)
    }
}
