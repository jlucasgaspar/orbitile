import OrbitileCore
import SwiftUI

@MainActor
final class FanModel: ObservableObject {
    /// Fan center in view coordinates (origin top-left, same as the overlay).
    @Published var center: CGPoint = .zero
    @Published var state = FanState()
    /// Blue preview rectangle in view coordinates.
    @Published var preview: CGRect?
}

private let accent = Color(red: 10 / 255, green: 132 / 255, blue: 1)

struct FanView: View {
    @ObservedObject var model: FanModel
    @State private var opened: Bool

    init(model: FanModel, startOpened: Bool = false) {
        self.model = model
        _opened = State(initialValue: startOpened)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let r = model.preview {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.85), lineWidth: 1))
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.11), value: r)
            }
            Fan(state: model.state)
                .scaleEffect(opened ? 1 : 0.86, anchor: .center)
                .opacity(opened ? 1 : 0)
                .frame(width: 0, height: 0)
                .offset(x: model.center.x, y: model.center.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.12)) { opened = true }
        }
    }
}

/// Drawn around its own origin (0, 0), y down, matching `FanGeometry`.
private struct Fan: View {
    let state: FanState
    private static let bladeBox: CGFloat = 260

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 22 / 255, green: 22 / 255, blue: 25 / 255).opacity(0.9))
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 14)
                .frame(width: FanGeometry.discDiameter, height: FanGeometry.discDiameter)


            ForEach(Array(LayoutFamily.all.enumerated()), id: \.offset) { i, family in
                let on = state.familyIndex == i
                Blade(r0: FanGeometry.ringInner, r1: FanGeometry.ringOuter, angle: family.angle, gap: 2.5)
                    .fill(on ? Color(red: 0x3E / 255, green: 0x3F / 255, blue: 0x45 / 255) : Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2E / 255))
                    .frame(width: Self.bladeBox, height: Self.bladeBox)
                if on {
                    Blade(r0: 153, r1: FanGeometry.ringOuter, angle: family.angle, gap: 3).fill(accent).frame(width: Self.bladeBox, height: Self.bladeBox)
                }
                Glyph(family: family, size: CGSize(width: 18, height: 12), color: .white.opacity(on ? 1 : 0.62))
                    .offset(polar(132, family.angle))
            }

            if let family = state.family {
                MiniScreen(
                    family: family, hovered: state.cell,
                    span: state.isDragging ? state.span.map { ($0.first, $0.last) } : nil)
                    .id(state.familyIndex)
                    .transition(.opacity.animation(.easeOut(duration: 0.11)))
            }

            Text(hint)
                .animation(nil, value: state)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .offset(y: 69)
        }
        .animation(.easeOut(duration: 0.07), value: state.familyIndex)
    }

    private var hint: String {
        if state.family == nil { return "Move to a layout" }
        if state.isDragging { return "Release to apply" }
        return "Click or drag"
    }
}

private func polar(_ r: CGFloat, _ degrees: Double) -> CGSize {
    let a = degrees * .pi / 180
    return CGSize(width: r * cos(a), height: r * sin(a))
}

/// Annular sector centered on `angle`, covering the family's share of the ring, with a constant gap between neighbours.
private struct Blade: Shape {
    let r0: CGFloat, r1: CGFloat, angle: Double, gap: CGFloat

    func path(in rect: CGRect) -> Path {
        let o = CGPoint(x: rect.midX, y: rect.midY)
        let half = LayoutFamily.halfSpan
        let a0 = angle - half, a1 = angle + half, h = gap / 2
        let dO = asin(min(0.99, h / r1)) * 180 / .pi
        let dI = asin(min(0.99, h / r0)) * 180 / .pi
        let n = 12
        var p = Path()
        for j in 0...n {
            let a = a0 + dO + (a1 - a0 - 2 * dO) * Double(j) / Double(n)
            let s = polar(r1, a)
            j == 0 ? p.move(to: CGPoint(x: o.x + s.width, y: o.y + s.height)) : p.addLine(to: CGPoint(x: o.x + s.width, y: o.y + s.height))
        }
        for j in 0...n {
            let a = a1 - dI - (a1 - a0 - 2 * dI) * Double(j) / Double(n)
            let s = polar(r0, a)
            p.addLine(to: CGPoint(x: o.x + s.width, y: o.y + s.height))
        }
        p.closeSubpath()
        return p
    }
}

private struct Glyph: View {
    let family: LayoutFamily
    let size: CGSize
    let color: Color

    var body: some View {
        let g: CGFloat = 1.5
        let cw = (size.width - CGFloat(family.cols - 1) * g) / CGFloat(family.cols)
        let ch = (size.height - CGFloat(family.rows - 1) * g) / CGFloat(family.rows)
        ZStack(alignment: .topLeading) {
            ForEach(0..<family.cellCount, id: \.self) { i in
                let (c, r) = family.position(of: i)
                let last = (c: family.cols - 1, r: family.rows - 1)
                UnevenRoundedRectangle(
                    topLeadingRadius: c == 0 && r == 0 ? 3 : 1,
                    bottomLeadingRadius: c == 0 && r == last.r ? 3 : 1,
                    bottomTrailingRadius: c == last.c && r == last.r ? 3 : 1,
                    topTrailingRadius: c == last.c && r == 0 ? 3 : 1)
                    .fill(color)
                    .frame(width: cw, height: ch)
                    .offset(x: CGFloat(c) * (cw + g), y: CGFloat(r) * (ch + g))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.08), value: color)
    }
}

private struct MiniScreen: View {
    let family: LayoutFamily
    /// Cell under the pointer: lighter, not blue.
    let hovered: Int?
    /// Cells being dragged (or pressed): one blue rectangle that slides between selections.
    let span: (Int, Int)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<family.cellCount, id: \.self) { i in
                let r = FanGeometry.cellRect(family, index: i)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(i == hovered && span == nil ? 0.17 : 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
                    .animation(.easeOut(duration: 0.06), value: hovered)
            }
            if let (a, b) = span {
                let r = FanGeometry.cellRect(family, from: a, to: b)
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                    .frame(width: r.width, height: r.height)
                    .offset(x: r.minX, y: r.minY)
                    .animation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.11), value: r)
                    .transition(.opacity)
            }
        }
        .frame(width: 0, height: 0, alignment: .topLeading)
    }
}
