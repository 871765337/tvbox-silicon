import SwiftUI

/// The built-in Bilibili source's icon: a little TV with antennae, white on Bilibili blue.
/// Drawn rather than bundled, so it stays sharp from a chip to a TV card.
struct BilibiliMark: View {
    static let blue = Color(red: 0, green: 0.682, blue: 0.925)
    var size: CGFloat = 44

    var body: some View {
        #if os(tvOS)
        let size = size >= 44 ? max(size, 56) : size
        #endif
        Canvas { context, canvas in
            let s = canvas.width
            let style = StrokeStyle(lineWidth: max(1.2, s * 0.075), lineCap: .round, lineJoin: .round)
            let screen = CGRect(x: s * 0.17, y: s * 0.33, width: s * 0.66, height: s * 0.47)
            var glyph = Path(roundedRect: screen, cornerRadius: s * 0.1, style: .continuous)
            for (top, foot) in [(CGPoint(x: 0.35, y: 0.16), CGPoint(x: 0.45, y: 0.31)), (CGPoint(x: 0.65, y: 0.16), CGPoint(x: 0.55, y: 0.31)),
                                (CGPoint(x: 0.33, y: 0.51), CGPoint(x: 0.42, y: 0.55)), (CGPoint(x: 0.67, y: 0.51), CGPoint(x: 0.58, y: 0.55))] {
                glyph.move(to: CGPoint(x: top.x * s, y: top.y * s))
                glyph.addLine(to: CGPoint(x: foot.x * s, y: foot.y * s))
            }
            context.stroke(glyph, with: .color(.white), style: style)
        }
        .frame(width: size, height: size)
        .background(Self.blue.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}
