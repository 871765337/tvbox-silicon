import SwiftUI
import AVFoundation
import CoreText
import TVCore

/// Bullet comments over the video. Positions come from the player's clock on every frame, so the
/// comments pause, seek and change speed with the video; each comment's text is drawn once.
struct DanmakuOverlay: View {
    let player: AVPlayer
    let comments: [Danmaku]
    @State private var engine = DanmakuEngine()
    @Environment(\.displayScale) private var scale

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Reading the timeline's date makes every tick a new drawing; the clock itself is the player's.
                _ = timeline.date
                let time = player.currentTime().seconds
                guard time.isFinite else { return }
                for sprite in engine.frame(time: time, size: size, scale: scale) {
                    context.draw(Image(decorative: sprite.image, scale: scale), in: sprite.frame)
                }
            }
        }
        .opacity(0.9)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: comments.count) { engine.load(comments) }
    }
}

/// Whether comments are shown, from Settings and the player's own toggle.
enum DanmakuPreference {
    static let key = "danmakuEnabled"
}

final class DanmakuEngine: @unchecked Sendable {
    struct Sprite { let image: CGImage; let frame: CGRect }
    private struct Active { let placement: DanmakuLayout.Placement; let image: CGImage; let size: CGSize }
    private let lock = NSLock()
    private var comments: [Danmaku] = []
    private var layout: DanmakuLayout?
    private var size = CGSize.zero
    private var fontSize: CGFloat = 24
    private var next = 0
    private var active: [Active] = []
    private var lastTime = -1.0

    func load(_ comments: [Danmaku]) {
        lock.withLock {
            // Live comments only grow at the end: keep the layout and what is already on screen.
            if !self.comments.isEmpty, comments.count > self.comments.count, comments.first == self.comments.first {
                self.comments = comments; return
            }
            self.comments = comments; layout = nil
        }
    }

    func frame(time: Double, size: CGSize, scale: CGFloat) -> [Sprite] {
        lock.withLock {
            guard !comments.isEmpty, size.width > 0, size.height > 0 else { return [] }
            // A new size, or a seek (any jump the clock would not make by itself), starts over at `time`.
            if layout == nil || size != self.size || time < lastTime - 0.3 || time > lastTime + 2 { restart(at: time, size: size) }
            lastTime = time
            while next < comments.count, comments[next].time <= time {
                let comment = comments[next]; next += 1
                // Comments passed over (a stall, a skipped frame) are not shown late.
                guard time - comment.time < 1, var layout else { continue }
                let font = fontSize * comment.scale
                let width = DanmakuText.width(comment.text, size: font)
                guard let placement = layout.place(comment, width: width, at: comment.time),
                      let image = DanmakuText.image(comment.text, color: comment.color, size: font, scale: scale) else { self.layout = layout; continue }
                self.layout = layout
                active.append(Active(placement: placement, image: image, size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)))
            }
            guard let layout else { return [] }
            active.removeAll { time - $0.placement.start > layout.duration($0.placement) }
            let lane = layout.laneHeight
            let top = size.height * 0.04
            return active.map { item in
                let placement = item.placement
                let x: Double, y: Double
                switch placement.comment.position {
                case .scroll: x = layout.width - (time - placement.start) * placement.speed; y = top + Double(placement.lane) * lane
                case .top: x = (layout.width - item.size.width) / 2; y = top + Double(placement.lane) * lane
                case .bottom: x = (layout.width - item.size.width) / 2; y = size.height * 0.92 - Double(placement.lane + 1) * lane
                }
                return Sprite(image: item.image, frame: CGRect(x: x, y: y + (lane - item.size.height) / 2, width: item.size.width, height: item.size.height))
            }
        }
    }

    private func restart(at time: Double, size: CGSize) {
        self.size = size
        // About 43pt on a 1080p TV, 22pt in a small Mac window.
        fontSize = min(44, max(15, size.height * 0.04))
        layout = DanmakuLayout(width: size.width, height: size.height * 0.96, laneHeight: fontSize * 1.35)
        active = []
        var low = 0, high = comments.count
        while low < high { let mid = (low + high) / 2; if comments[mid].time < time { low = mid + 1 } else { high = mid } }
        next = low
    }
}

/// Comment text as an image: semibold system type with a thin contrasting outline, as Bilibili draws it.
enum DanmakuText {
    private static func font(_ size: CGFloat) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base
    }
    private static func line(_ text: String, _ attributes: [NSAttributedString.Key: Any]) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }
    private static let padding: CGFloat = 3

    static func width(_ text: String, size: CGFloat) -> Double {
        Double(CTLineGetTypographicBounds(line(text, [.init(kCTFontAttributeName as String): font(size)]), nil, nil, nil)) + Double(padding * 2)
    }

    static func image(_ text: String, color: UInt32, size: CGFloat, scale: CGFloat) -> CGImage? {
        let font = font(size)
        let red = CGFloat(color >> 16 & 0xFF) / 255, green = CGFloat(color >> 8 & 0xFF) / 255, blue = CGFloat(color & 0xFF) / 255
        // Dark comments get a light outline so they stay readable.
        let dark = 0.299 * red + 0.587 * green + 0.114 * blue < 0.25
        let fill = line(text, [.init(kCTFontAttributeName as String): font, .init(kCTForegroundColorAttributeName as String): CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)])
        let outline = line(text, [.init(kCTFontAttributeName as String): font, .init(kCTStrokeWidthAttributeName as String): 6,
                                  .init(kCTStrokeColorAttributeName as String): CGColor(gray: dark ? 1 : 0, alpha: dark ? 0.8 : 0.7)])
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(fill, &ascent, &descent, nil)
        let pixelsWide = Int(((width + padding * 2) * scale).rounded(.up)), pixelsHigh = Int(((ascent + descent + padding * 2) * scale).rounded(.up))
        guard pixelsWide > 0, pixelsHigh > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setLineJoin(.round)
        for drawn in [outline, fill] {
            context.textPosition = CGPoint(x: padding, y: padding + descent)
            CTLineDraw(drawn, context)
        }
        return context.makeImage()
    }
}

/// Every comment in time order, starting at the current moment. Choosing one plays from just before it.
struct DanmakuListView: View {
    let player: AVPlayer
    let comments: [Danmaku]
    var chosen: () -> Void = {}
    @State private var query = ""
    private var shown: [(offset: Int, element: Danmaku)] {
        let all = Array(comments.enumerated())
        let text = query.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? all : all.filter { $0.element.text.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if !os(tvOS)
            TextField(L10n.text("Filter comments"), text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.top, 14)
            #endif
            ScrollViewReader { proxy in
                List(shown, id: \.offset) { item in
                    Button { jump(to: item.element) } label: { row(item.element) }
                        .id(item.offset)
                }
                #if os(tvOS)
                // A focused row grows past its frame; inset the rows so the info panel does not cut it off.
                .contentMargins(.horizontal, 56, for: .scrollContent)
                .contentMargins(.vertical, 24, for: .scrollContent)
                #endif
                .onAppear {
                    let now = player.currentTime().seconds
                    if now.isFinite, let target = comments.firstIndex(where: { $0.time >= now - 1 }) { proxy.scrollTo(target, anchor: .top) }
                }
            }
        }
    }

    private func row(_ comment: Danmaku) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(Duration.seconds(Int(comment.time)).formatted(.time(pattern: comment.time >= 3600 ? .hourMinuteSecond : .minuteSecond)))
                .monospacedDigit().foregroundStyle(.secondary)
            Circle().fill(Color(red: Double(comment.color >> 16 & 0xFF) / 255, green: Double(comment.color >> 8 & 0xFF) / 255, blue: Double(comment.color & 0xFF) / 255))
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.25)) }
                .frame(width: 10, height: 10)
            Text(comment.text).lineLimit(2).foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func jump(to comment: Danmaku) {
        player.seek(to: CMTime(seconds: max(0, comment.time - 1), preferredTimescale: 600))
        player.play()
        chosen()
    }
}
