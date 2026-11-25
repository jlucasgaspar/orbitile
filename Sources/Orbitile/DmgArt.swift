import AppKit
import SwiftUI

/// Background of the installer disk image. `Orbitile --dmg-background <dir>` writes
/// `background.png` (1x) and `background@2x.png`; `scripts/release.sh` merges them into one TIFF.
@MainActor
enum DmgArt {
    static let size = CGSize(width: 660, height: 400)
    /// Where the app and the Applications shortcut sit (icon centers), kept in sync with the dmgbuild settings.
    static let appCenter = CGPoint(x: 180, y: 185)
    static let applicationsCenter = CGPoint(x: 480, y: 185)

    static func run(into dir: String) {
        for (name, scale) in [("background", 1.0), ("background@2x", 2.0)] {
            let renderer = ImageRenderer(content: Background())
            renderer.scale = scale
            guard let t = renderer.nsImage?.tiffRepresentation,
                  let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }
}

private struct Background: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.17, green: 0.18, blue: 0.21), Color(red: 0.09, green: 0.10, blue: 0.12)],
                startPoint: .top, endPoint: .bottom)

            Arrow()
                .stroke(Color(red: 10 / 255, green: 132 / 255, blue: 1), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 70, height: 36)
                .position(x: (DmgArt.appCenter.x + DmgArt.applicationsCenter.x) / 2, y: DmgArt.appCenter.y)
                .shadow(color: Color(red: 10 / 255, green: 132 / 255, blue: 1).opacity(0.5), radius: 8)

            Text("Drag Orbitile to Applications")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: DmgArt.size.width)
                .position(x: DmgArt.size.width / 2, y: 330)
        }
        .frame(width: DmgArt.size.width, height: DmgArt.size.height)
    }
}

private struct Arrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.move(to: CGPoint(x: r.maxX - 16, y: r.midY - 16))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - 16, y: r.midY + 16))
        return p
    }
}
