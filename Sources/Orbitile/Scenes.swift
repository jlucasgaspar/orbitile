import AppKit
import OrbitileCore
import SwiftUI

/// Offscreen "screen recording" of the real fan over a mock desktop.
/// `Orbitile --scenes <dir>` writes numbered GIF frames (`frames/`) and README stills.
/// It needs no screen access and no permissions: the fan is the same SwiftUI view the app shows.
@MainActor
enum Scenes {
    static let size = CGSize(width: 960, height: 600)
    static let menuBar: CGFloat = 24
    static let startWindow = CGRect(x: 170, y: 100, width: 520, height: 340)
    static let fps = 25.0

    struct Frame {
        var cursor: CGPoint
        var openProgress: Double      // 0 = closed, 1 = fully open
        var dragging: Bool
        var window: CGRect
        var showFan: Bool
    }

    // MARK: Timeline

    static func timeline() -> [Frame] {
        let start = CGPoint(x: 400, y: 290)
        let center = FanGeometry.clampCenter(start, in: CGRect(origin: .zero, size: size))
        let family8 = LayoutFamily.all[3]
        func cellPoint(_ i: Int) -> CGPoint {
            let r = FanGeometry.cellRect(family8, index: i)
            return CGPoint(x: center.x + r.midX, y: center.y + r.midY)
        }
        func ring(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: center.x + dx, y: center.y + dy) }

        var frames: [Frame] = []
        var cursor = start
        var window = startWindow
        func add(_ n: Int, open: Double = 1, drag: Bool = false, fan: Bool = true, window w: CGRect? = nil) {
            for _ in 0..<n { frames.append(Frame(cursor: cursor, openProgress: open, dragging: drag, window: w ?? window, showFan: fan)) }
        }
        func move(to p: CGPoint, frames n: Int, drag: Bool = false) {
            let from = cursor
            for i in 1...n {
                let k = CGFloat(Easing.cubicBezier(0.3, 0, 0.2, 1, Double(i) / Double(n)))
                cursor = CGPoint(x: from.x + (p.x - from.x) * k, y: from.y + (p.y - from.y) * k)
                add(1, drag: drag)
            }
        }

        add(10, open: 0, fan: false)                              // desktop, cursor on the window
        for i in 1...3 { add(1, open: Double(i) / 3) }            // 120 ms pop
        add(12)                                                   // family 8 already active
        move(to: ring(82, 0), frames: 10); add(8)                 // family 4
        move(to: ring(0, 82), frames: 10); add(8)                 // family 6
        move(to: ring(-82, 0), frames: 10); add(6)                // family 8
        move(to: cellPoint(1), frames: 12); add(8)                // hover a cell
        add(4, drag: true)                                        // press
        move(to: cellPoint(2), frames: 6, drag: true); add(16, drag: true)  // merge, preview

        // Release: the fan closes and the window glides to the target (220 ms, same easing as the app).
        let target = mockTarget(family8, 1, 2)
        let from = window
        let steps = 6
        for i in 1...steps {
            let k = CGFloat(Easing.cubicBezier(0.2, 0.8, 0.2, 1, Double(i) / Double(steps)))
            let w = CGRect(
                x: from.minX + (target.minX - from.minX) * k, y: from.minY + (target.minY - from.minY) * k,
                width: from.width + (target.width - from.width) * k, height: from.height + (target.height - from.height) * k)
            add(1, open: 0, fan: false, window: w)
        }
        window = target
        add(30, open: 0, fan: false)
        return frames
    }

    /// Same maths as `FanGeometry.targetRect`, in top-left screen coordinates of the mock.
    static func mockTarget(_ f: LayoutFamily, _ a: Int, _ b: Int) -> CGRect {
        let (ac, ar) = f.position(of: a), (bc, br) = f.position(of: b)
        let area = CGRect(x: 0, y: menuBar, width: size.width, height: size.height - menuBar)
        let w = area.width / CGFloat(f.cols), h = area.height / CGFloat(f.rows)
        return CGRect(
            x: CGFloat(min(ac, bc)) * w, y: area.minY + CGFloat(min(ar, br)) * h,
            width: CGFloat(abs(ac - bc) + 1) * w, height: CGFloat(abs(ar - br) + 1) * h
        ).insetBy(dx: 6, dy: 6)
    }

    // MARK: Rendering

    static func view(for frame: Frame) -> some View {
        let model = FanModel()
        let bounds = CGRect(origin: .zero, size: size)
        // Fan center is fixed when it opens, so derive it from the timeline's first cursor.
        let center = FanGeometry.clampCenter(CGPoint(x: 400, y: 290), in: bounds)
        model.center = center
        var state = FanState(family: 3)
        let rel = CGPoint(x: frame.cursor.x - center.x, y: frame.cursor.y - center.y)
        if frame.dragging {
            // Pressed on cell 1 (see `timeline`); the drag then follows the cursor.
            state.update(.cell(1))
            state.beginDrag()
        }
        state.update(FanGeometry.hit(rel, expanded: state.family))
        model.state = state
        if let span = state.span {
            let r = mockTarget(span.family, span.first, span.last)
            model.preview = r
        }
        return ZStack(alignment: .topLeading) {
            Desktop(window: frame.window)
            if frame.showFan {
                FanView(model: model, startOpened: true)
                    .scaleEffect(0.86 + 0.14 * frame.openProgress, anchor: UnitPoint(x: center.x / size.width, y: center.y / size.height))
                    .opacity(frame.openProgress)
            }
            Pointer().offset(x: frame.cursor.x - 1, y: frame.cursor.y - 1)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    static func write(_ frame: Frame, to url: URL, scale: CGFloat) {
        let renderer = ImageRenderer(content: view(for: frame))
        renderer.scale = scale
        guard let t = renderer.nsImage?.tiffRepresentation,
              let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    static func run(into dir: String) {
        let fm = FileManager.default
        let frames = "\(dir)/frames"
        try? fm.createDirectory(atPath: frames, withIntermediateDirectories: true)
        let all = timeline()
        for (i, f) in all.enumerated() {
            write(f, to: URL(fileURLWithPath: String(format: "\(frames)/f%03d.png", i)), scale: 1)
        }
        // Stills at 2x: pick moments from the timeline.
        func still(_ name: String, where match: (Frame) -> Bool, last: Bool = false) {
            let picks = all.filter(match)
            guard let f = last ? picks.last : picks.first else { return }
            write(f, to: URL(fileURLWithPath: "\(dir)/\(name).png"), scale: 2)
        }
        still("still-open", where: { $0.showFan && !$0.dragging && $0.openProgress == 1 && $0.cursor.x < 330 })
        still("still-click", where: { $0.showFan && $0.dragging })
        still("still-merge", where: { $0.showFan && $0.dragging }, last: true)
        print("frames: \(all.count)")
    }
}

private struct Desktop: View {
    let window: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.21), Color(red: 0.09, green: 0.1, blue: 0.12)],
                           startPoint: .top, endPoint: .bottom)
            // Menu bar
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.8)).frame(width: 11, height: 11)
                Text("Editor").fontWeight(.bold)
                Text("File"); Text("Edit"); Text("View"); Text("Window")
                Spacer()
                Image(nsImage: MenuBarIcon.make()).renderingMode(.template).resizable().frame(width: 15, height: 15)
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 12)
            .frame(width: Scenes.size.width, height: Scenes.menuBar)
            .background(Color(red: 0.06, green: 0.06, blue: 0.07).opacity(0.55))

            MockWindow()
                .frame(width: window.width, height: window.height)
                .offset(x: window.minX, y: window.minY)
        }
    }
}

private struct MockWindow: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
                Spacer()
                Text("Untitled").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                Spacer().frame(width: 56)
            }
            .padding(.horizontal, 12).frame(height: 30)
            .background(Color(red: 0.165, green: 0.165, blue: 0.176))
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([0.7, 0.52, 0.8, 0.6], id: \.self) { w in bar(w, 8, 0.08) }
                }
                .padding(16).frame(width: 150, alignment: .topLeading)
                .background(Color(red: 0.145, green: 0.145, blue: 0.153))
                VStack(alignment: .leading, spacing: 11) {
                    bar(0.38, 14, 0.14)
                    ForEach([0.92, 0.86, 0.9, 0.58], id: \.self) { w in bar(w, 8, 0.07) }
                    Spacer()
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(red: 0.118, green: 0.118, blue: 0.125))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
    }

    private func bar(_ fraction: Double, _ height: CGFloat, _ opacity: Double) -> some View {
        GeometryReader { g in
            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(opacity)).frame(width: g.size.width * fraction, height: height)
        }.frame(height: height)
    }
}

private struct Pointer: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: 1, y: 16.5)); p.addLine(to: CGPoint(x: 4.8, y: 12.9))
            p.addLine(to: CGPoint(x: 7.6, y: 19.2)); p.addLine(to: CGPoint(x: 10.2, y: 18.1)); p.addLine(to: CGPoint(x: 7.5, y: 11.9))
            p.addLine(to: CGPoint(x: 12.6, y: 11.9)); p.closeSubpath()
        }
        .fill(.black)
        .overlay(Path { p in
            p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: 1, y: 16.5)); p.addLine(to: CGPoint(x: 4.8, y: 12.9))
            p.addLine(to: CGPoint(x: 7.6, y: 19.2)); p.addLine(to: CGPoint(x: 10.2, y: 18.1)); p.addLine(to: CGPoint(x: 7.5, y: 11.9))
            p.addLine(to: CGPoint(x: 12.6, y: 11.9)); p.closeSubpath()
        }.stroke(.white, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)))
        .frame(width: 14, height: 21, alignment: .topLeading)
    }
}
