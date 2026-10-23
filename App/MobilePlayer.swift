#if os(iOS)
import SwiftUI
import AVKit
import MediaPlayer
import TVCore

/// The iPhone and iPad player. The picture plays in a layer of our own and every control is drawn here: AVKit's
/// controls on iOS keep AirPlay and volume in a row of their own above anything laid over them and take no buttons
/// of ours, so the title, our buttons, AirPlay and Picture in Picture couldn't share one row. Back and the title sit
/// on the left of the top row, the buttons on the right, play and skip in the middle, and the seek bar at the bottom.
struct MobilePlayerView: View {
    let channel: Channel
    let session: PlaybackSession
    @Binding var showsDanmaku: Bool
    @Binding var upscalesVideo: Bool
    @Binding var smoothsVideo: Bool
    var waiting: PlaybackWaitContent?
    /// Whether the controls show. The player screen runs the timer that hides them.
    let chromeVisible: Bool
    /// A tap on the picture shows or hides the controls.
    let toggleChrome: () -> Void
    /// A control was used: the controls stay up a while longer.
    let poke: () -> Void
    /// The seek bar is held (true) or let go (false): the controls stay up until it is let go.
    let hold: (Bool) -> Void
    let close: () -> Void

    @Environment(Store.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pip = PictureInPicture()
    @State private var clock = PlayerClock()
    @State private var tracks = MediaTracks()
    @State private var nowPlaying = VideoNowPlaying()
    @State private var fillsScreen = false
    @State private var speed: Float = 1
    @State private var showsDanmakuList = false

    var body: some View {
        ZStack {
            PlayerLayerView(player: session.player, fills: fillsScreen, pip: pip).ignoresSafeArea()
            // The enhanced picture covers the layer's own, under everything else.
            EnhancedVideoSurface(enhancer: session.enhancer, fills: fillsScreen)
            if showsDanmaku && !session.danmaku.isEmpty {
                DanmakuOverlay(player: session.player, comments: session.danmaku, opacity: session.danmakuOpacity, revision: session.danmakuRevision)
                    .ignoresSafeArea()
            }
            // The artwork dissolves into the first frame.
            if let waiting { waiting.view.ignoresSafeArea().transition(.opacity) }
            if pip.active { pipPlaceholder }
            // A tap on the picture shows or hides the controls; a tap on a control keeps them up (see `rows`).
            Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                .onTapGesture(perform: toggleChrome)
                .accessibilityHidden(true)
            controls.opacity(chromeVisible ? 1 : 0).allowsHitTesting(chromeVisible)
        }
        .animation(.easeInOut(duration: 0.7), value: waiting == nil)
        .animation(.easeInOut(duration: 0.4), value: waiting?.starting)
        .onAppear {
            clock.attach(session.player)
            speed = session.player.defaultRate
            nowPlaying.start(session)
            nowPlaying.update(title: channel.name, session: session)
        }
        .onDisappear { clock.detach(); nowPlaying.stop() }
        .onChange(of: nowPlayingState, initial: true) { nowPlaying.update(title: channel.name, session: session) }
        .task(id: clock.item.map(ObjectIdentifier.init)) { await tracks.load(clock.item) }
        .sheet(isPresented: $showsDanmakuList) {
            DanmakuListView(player: session.player, comments: session.danmaku) { showsDanmakuList = false }
                .danmakuListPresentation()
        }
    }

    /// What the Lock Screen's Now Playing shows, besides the position the system runs on from the rate.
    private struct NowPlayingState: Equatable {
        var title: String
        var paused: Bool
        var live: Bool
        var timeline: Bool
        var duration: Double
        var speed: Float
    }

    private var nowPlayingState: NowPlayingState {
        NowPlayingState(title: channel.name, paused: session.paused, live: session.isLive, timeline: session.hasTimeline,
                        duration: clock.duration, speed: speed)
    }

    /// Play, skip and the seek bar wait for the stream: while it connects or after it fails, only the top row shows.
    private var showsTransport: Bool { !session.loading && session.error == nil }
    private var seekable: Bool { session.hasTimeline && !session.isLive }

    private var controls: some View {
        ZStack {
            // Scrims, so white controls read over a bright picture.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: 150)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).frame(height: 150)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            VStack(spacing: 0) {
                topRow
                Spacer(minLength: 0)
                if showsTransport { bottomRow }
            }
            .padding(16)
            if showsTransport { centerRow }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Top row

    /// One row when it fits; on a phone held upright, Back and the buttons share the first row and the title has the
    /// next one to itself, as in YouTube's player.
    private var topRow: some View {
        PlayerTopBar {
            Button(action: close) { Image(systemName: "chevron.backward").font(.headline).frame(width: 22, height: 22) }
                .chromeButton()
                .accessibilityLabel(L10n.text("Back"))
                .accessibilityIdentifier("player.close")
                .keyboardShortcut(.cancelAction)
            Text(channel.name).font(.headline).lineLimit(1)
                .shadow(color: .black.opacity(0.6), radius: 4)
            HStack(spacing: 10) { toolbar; optionsMenu }
        }
        .simultaneousGesture(TapGesture().onEnded { poke() })
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            AirPlayButton()
                .frame(width: 44, height: 44)
                .glassSurface(.regular.interactive(), in: Circle())
                .contentShape(Circle())
            if pip.supported {
                Button { pip.toggle() } label: {
                    Image(systemName: pip.active ? "pip.exit" : "pip.enter").font(.headline).frame(width: 22, height: 22)
                }
                .chromeButton()
                .disabled(!pip.possible && !pip.active)
                .accessibilityLabel(L10n.text("Picture in Picture"))
                .accessibilityIdentifier("player.pip")
            }
            CatalogPlaybackActions(channel: channel, session: session)
            // One button for danmaku: show or hide them, or open the list.
            if !session.danmaku.isEmpty {
                Menu {
                    Toggle(isOn: $showsDanmaku) { Label(L10n.text("Show Danmaku"), systemImage: "text.bubble") }
                    Button { showsDanmakuList = true } label: { Label(L10n.text("Danmaku List"), systemImage: "list.bullet.rectangle") }
                } label: {
                    Image(systemName: showsDanmaku ? "text.bubble.fill" : "text.bubble").font(.headline).frame(width: 22, height: 22)
                }
                .chromeButton()
                .accessibilityLabel(L10n.text("Danmaku"))
            }
            // Turns the picture even with Portrait Orientation Lock on, the way the system's own rotation can't.
            // Only on a phone-sized screen: iPhone Duo's inner display (regular both ways) ignores orientations.
            if PlayerOrientation.available, horizontalSizeClass == .compact || verticalSizeClass == .compact {
                let landscape = verticalSizeClass == .compact
                Button { PlayerOrientation.set(landscape: !landscape) } label: {
                    Image(systemName: landscape ? "rectangle.portrait.rotate" : "rectangle.landscape.rotate").font(.headline).frame(width: 22, height: 22)
                }
                .chromeButton()
                .accessibilityLabel(L10n.text(landscape ? "Rotate to Portrait" : "Rotate to Landscape"))
                .accessibilityIdentifier("player.rotate")
            }
        }
    }

    /// Whether the options have the smoothing and upscaling switches (iPhone and iPad on OS 26).
    private var pictureSwitches: Bool { VideoEnhancement.canUpscale || VideoEnhancement.canSmooth }

    /// The picture, sound and subtitle settings in one menu: what AVKit's ⋯ menu held, and the stream's quality.
    private var optionsMenu: some View {
        Menu {
            if session.qualities.count > 1 { Menu(L10n.text("Quality")) { QualityPicker(session: session) } }
            if pictureSwitches {
                Section(L10n.text("Picture")) {
                    if VideoEnhancement.canSmooth { Toggle(L10n.text("Smooth Motion (60 fps)"), isOn: $smoothsVideo) }
                    if VideoEnhancement.canUpscale { Toggle(L10n.text("Sharper Picture"), isOn: $upscalesVideo) }
                }
            }
            if let audio = tracks.audio, audio.options.count > 1 {
                Menu(L10n.text("Audio")) {
                    Picker(L10n.text("Audio"), selection: Binding(get: { tracks.selected(in: audio) }, set: { tracks.select($0, in: audio) })) {
                        ForEach(audio.options, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                }
            }
            if let legible = tracks.legible, !legible.options.isEmpty {
                Menu(L10n.text("Subtitles")) {
                    Picker(L10n.text("Subtitles"), selection: Binding(get: { tracks.selected(in: legible) }, set: { tracks.select($0, in: legible) })) {
                        if legible.group.allowsEmptySelection { Text(L10n.text("Off")).tag(AVMediaSelectionOption?.none) }
                        ForEach(legible.options, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                    }
                    .pickerStyle(.inline)
                }
            }
            if !session.isLive {
                Menu(L10n.text("Playback Speed")) {
                    Picker(L10n.text("Playback Speed"), selection: Binding(get: { speed }, set: { speed = $0; session.setSpeed($0) })) {
                        ForEach(Self.speeds, id: \.self) { Text(Self.speedLabel($0)).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
            Toggle(L10n.text("Fill Screen"), isOn: $fillsScreen)
        } label: {
            Image(systemName: "slider.horizontal.3").font(.headline).frame(width: 22, height: 22)
                .symbolVariant(pictureSwitches && (upscalesVideo || smoothsVideo) ? .fill : .none)
        }
        .chromeButton()
        // "Playback Options" is the catalog's episode menu beside it.
        .accessibilityLabel(L10n.text("Settings"))
        .accessibilityIdentifier("player.options")
    }

    private static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    private static func speedLabel(_ speed: Float) -> String {
        Double(speed).formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    // MARK: Middle and bottom

    private var centerRow: some View {
        HStack(spacing: 20) {
            if let previous = store.step(back: true, from: channel, session: session) {
                Button { previous.go() } label: { Image(systemName: "backward.end.fill") }
                    .buttonStyle(PlayerCircleStyle(size: 44))
                    .disabled(previous.busy)
                    .accessibilityLabel(L10n.text("Previous Episode"))
            }
            if seekable {
                Button { session.skip(-10); sought() } label: { Image(systemName: "gobackward.10") }
                    .buttonStyle(PlayerCircleStyle(size: 52))
                    .accessibilityLabel(L10n.text("Back 10 seconds"))
            }
            Button { session.togglePlayback() } label: { Image(systemName: session.paused ? "play.fill" : "pause.fill") }
                .buttonStyle(PlayerCircleStyle(size: 68))
                .accessibilityLabel(L10n.text(session.paused ? "Play" : "Pause"))
                .accessibilityIdentifier("player.playPause")
            if seekable {
                Button { session.skip(10); sought() } label: { Image(systemName: "goforward.10") }
                    .buttonStyle(PlayerCircleStyle(size: 52))
                    .accessibilityLabel(L10n.text("Forward 10 seconds"))
            }
            if let next = store.step(back: false, from: channel, session: session) {
                Button { next.go() } label: { Image(systemName: "forward.end.fill") }
                    .buttonStyle(PlayerCircleStyle(size: 44))
                    .disabled(next.busy)
                    .accessibilityLabel(L10n.text("Next Episode"))
            }
        }
        .simultaneousGesture(TapGesture().onEnded { poke() })
    }

    @ViewBuilder private var bottomRow: some View {
        if session.isLive {
            HStack {
                Text(L10n.text("LIVE")).font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.red, in: Capsule())
                Spacer(minLength: 0)
            }
        } else if session.hasTimeline {
            // Dragging holds the controls up itself (`hold`); a tap gesture here would compete with the scrubber's drag.
            SeekBar(clock: clock, moving: chromeVisible && !session.paused, hold: hold, sought: sought)
        }
    }

    /// The position moved by a button or the seek bar: the Lock Screen follows.
    private func sought() {
        poke()
        nowPlaying.update(title: channel.name, session: session)
    }

    private var pipPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "pip").font(.system(size: 48, weight: .light))
            Text(L10n.text("Playing in Picture in Picture")).font(.callout)
        }
        .foregroundStyle(.white.opacity(0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// The position and the length in a capsule over a scrubber the width of the screen, as in YouTube's player, and
/// scrubbing as in Telegram's: while dragged, only the bar, the time and a frame from that point (above the handle)
/// follow the finger, and the video seeks once, when the finger lifts. Seeking the playing video along with the finger
/// left it stuttering behind. A view of its own, so only it redraws as the position moves.
private struct SeekBar: View {
    let clock: PlayerClock
    /// Playing with the controls showing: the bar follows the player every frame.
    let moving: Bool
    let hold: (Bool) -> Void
    let sought: () -> Void
    /// Where a drag began: the position then and the finger's start. The handle moves by as much as the finger does
    /// (Telegram), rather than jumping under it; a touch away from the handle puts it there first.
    @State private var drag: (position: Double, location: CGPoint)?
    /// Slower scrubbing while the finger moves away from the bar: half, a quarter and a tenth of the speed (Telegram).
    @State private var fineness = 1.0
    @State private var width: CGFloat = 0

    var body: some View {
        // Every display frame while it plays, as AVKit's bar does; paused, held or hidden, only when the clock changes.
        let follows = moving && clock.scrubbing == nil
        TimelineView(.animation(paused: !follows)) { _ in
            bar(clock.scrubbing ?? (follows ? clock.currentPosition : clock.position))
        }
        .sensoryFeedback(.selection, trigger: fineness)
    }

    private func bar(_ position: Double) -> some View {
        let duration = clock.duration
        let value = min(max(0, position), duration)
        let x = duration > 0 ? width * value / duration : 0
        let held = drag != nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(Self.format(value) + " / " + Self.format(duration))
                if let speed = Self.fineLabel(fineness) { Text(speed).foregroundStyle(.white.opacity(0.75)) }
            }
            .font(.footnote.monospacedDigit().weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .glassSurface(.regular, in: Capsule())
            .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3)).frame(height: held ? 6 : 4)
                Capsule().fill(.white).frame(width: max(0, x), height: held ? 6 : 4)
                Circle().fill(.white)
                    .frame(width: held ? 24 : 14, height: held ? 24 : 14)
                    .shadow(color: .black.opacity(0.35), radius: 3)
                    .offset(x: x - (held ? 12 : 7))
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { changed($0, value: value, duration: duration) }
                .onEnded { _ in ended() })
            .animation(.spring(duration: 0.3, bounce: 0.3), value: held)
        }
        // The frame at the finger, above the time, centred on the handle and kept on screen.
        .overlay(alignment: .topLeading) {
            if held, let preview = clock.preview {
                let previewWidth: CGFloat = 160
                Image(decorative: preview, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: previewWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.8), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6)
                    .alignmentGuide(.top) { $0[.bottom] + 8 }
                    .offset(x: min(max(0, x - previewWidth / 2), max(0, width - previewWidth)))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.12), value: held && clock.preview != nil)
        .accessibilityElement()
        .accessibilityLabel(L10n.text("Playback Position"))
        .accessibilityValue(Self.format(value))
        .accessibilityIdentifier("player.seek")
        .accessibilityAdjustableAction { direction in
            clock.seek(to: min(max(0, value + (direction == .increment ? 10 : -10)), duration))
            sought()
        }
    }

    private func changed(_ gesture: DragGesture.Value, value: Double, duration: Double) {
        guard duration > 0, width > 0 else { return }
        if drag == nil {
            let handle = width * value / duration
            let start = abs(gesture.startLocation.x - handle) <= 30 ? value : duration * Double(min(max(0, gesture.startLocation.x / width), 1))
            drag = (start, gesture.startLocation)
            hold(true)
            clock.scrub(to: start)
        }
        guard let begin = drag else { return }
        let away = abs(gesture.location.y - begin.location.y)
        let wanted = away > 150 ? 0.1 : away > 100 ? 0.25 : away > 50 ? 0.5 : 1
        if wanted != fineness {
            // Carry on from here at the new speed, so the handle doesn't jump.
            fineness = wanted
            drag = (clock.scrubbing ?? begin.position, gesture.location)
            return
        }
        let moved = Double((gesture.location.x - begin.location.x) / width) * duration * fineness
        clock.scrub(to: min(max(0, begin.position + moved), duration))
    }

    private func ended() {
        guard drag != nil else { return }
        drag = nil
        fineness = 1
        hold(false)
        clock.endScrub()
        sought()
    }

    private static func fineLabel(_ fineness: Double) -> String? {
        switch fineness {
        case 0.5: L10n.text("Half-Speed Scrubbing")
        case 0.25: L10n.text("Quarter-Speed Scrubbing")
        case ..<0.25: L10n.text("Fine Scrubbing")
        default: nil
        }
    }

    static func format(_ seconds: Double) -> String {
        let total = Int(seconds.isFinite ? max(0, seconds) : 0)
        let hours = total / 3600, minutes = total / 60 % 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}

/// The top row's three parts: Back, the title and the buttons. All in one row while the title keeps `minimumTitle`;
/// otherwise Back and the buttons share the first row and the title has the next one to itself. On a screen too
/// narrow even for Back beside the buttons, the buttons take the first row alone and Back goes beside the title.
private struct PlayerTopBar: SwiftUI.Layout {
    var spacing: CGFloat = 12
    var rowSpacing: CGFloat = 10
    var minimumTitle: CGFloat = 160

    private enum Arrangement { case oneRow, titleBelow, buttonsAlone }

    private func arrangement(_ width: CGFloat, back: CGSize, buttons: CGSize) -> Arrangement {
        if back.width + spacing + minimumTitle + spacing + buttons.width <= width { return .oneRow }
        return back.width + spacing + buttons.width <= width ? .titleBelow : .buttonsAlone
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let back = subviews[0].sizeThatFits(.unspecified), buttons = subviews[2].sizeThatFits(.unspecified)
        let width = proposal.width ?? back.width + subviews[1].sizeThatFits(.unspecified).width + buttons.width + 2 * spacing
        func title(_ room: CGFloat) -> CGSize { subviews[1].sizeThatFits(ProposedViewSize(width: room, height: nil)) }
        switch arrangement(width, back: back, buttons: buttons) {
        case .oneRow:
            let title = title(width - back.width - buttons.width - 2 * spacing)
            return CGSize(width: width, height: max(back.height, buttons.height, title.height))
        case .titleBelow:
            return CGSize(width: width, height: max(back.height, buttons.height) + rowSpacing + title(width).height)
        case .buttonsAlone:
            return CGSize(width: width, height: buttons.height + rowSpacing + max(back.height, title(width - back.width - spacing).height))
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let back = subviews[0].sizeThatFits(.unspecified), buttons = subviews[2].sizeThatFits(.unspecified)
        /// Places a subview with its vertical centre at `middle`; the title gets `room` and truncates to it.
        func place(_ index: Int, x: CGFloat, middle: CGFloat, room: CGFloat? = nil) {
            let size = room.map { subviews[index].sizeThatFits(ProposedViewSize(width: $0, height: nil)) } ?? subviews[index].sizeThatFits(.unspecified)
            subviews[index].place(at: CGPoint(x: x, y: middle - size.height / 2), proposal: ProposedViewSize(width: size.width, height: size.height))
        }
        switch arrangement(bounds.width, back: back, buttons: buttons) {
        case .oneRow:
            place(0, x: bounds.minX, middle: bounds.midY)
            place(1, x: bounds.minX + back.width + spacing, middle: bounds.midY, room: bounds.width - back.width - buttons.width - 2 * spacing)
            place(2, x: bounds.maxX - buttons.width, middle: bounds.midY)
        case .titleBelow:
            let row = max(back.height, buttons.height)
            place(0, x: bounds.minX, middle: bounds.minY + row / 2)
            place(2, x: bounds.maxX - buttons.width, middle: bounds.minY + row / 2)
            let title = subviews[1].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            place(1, x: bounds.minX, middle: bounds.minY + row + rowSpacing + title.height / 2, room: bounds.width)
        case .buttonsAlone:
            place(2, x: bounds.maxX - buttons.width, middle: bounds.minY + buttons.height / 2)
            let room = bounds.width - back.width - spacing
            let row = max(back.height, subviews[1].sizeThatFits(ProposedViewSize(width: room, height: nil)).height)
            let middle = bounds.minY + buttons.height + rowSpacing + row / 2
            place(0, x: bounds.minX, middle: middle)
            place(1, x: bounds.minX + back.width + spacing, middle: middle, room: room)
        }
    }
}

/// A round glass button of the given size, for play and skip in the middle of the picture.
private struct PlayerCircleStyle: ButtonStyle {
    var size: CGFloat
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .glassSurface(.regular.interactive(), in: Circle())
            .contentShape(Circle())
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.38)
    }
}

/// The system's AirPlay button, which presents the route picker itself.
private struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        return view
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}

/// The picture in an AVPlayerLayer, which Picture in Picture takes over while it runs.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let fills: Bool
    let pip: PictureInPicture
    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        pip.attach(view.playerLayer)
        return view
    }
    func updateUIView(_ view: LayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
    }
}

/// Picture in Picture for the player layer: the button, and carrying on in a floating window when the app is left.
@MainActor @Observable final class PictureInPicture: NSObject, AVPictureInPictureControllerDelegate {
    let supported = AVPictureInPictureController.isPictureInPictureSupported()
    private(set) var possible = false
    private(set) var active = false
    @ObservationIgnored private var controller: AVPictureInPictureController?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    func attach(_ layer: AVPlayerLayer) {
        guard supported, controller == nil else { return }
        let controller = AVPictureInPictureController(contentSource: .init(playerLayer: layer))
        controller.delegate = self
        // Leaving the app while a video plays carries on in Picture in Picture, as AVKit's own player did.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        observation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor [weak self] in self?.possible = possible }
        }
        self.controller = controller
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive { controller.stopPictureInPicture() } else { controller.startPictureInPicture() }
    }

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.active = true }
    }
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.active = false }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        let detail = Diagnostics.describe(error)
        Task { @MainActor in Diagnostics.shared.record(.warning, "player", "Picture in Picture failed: \(detail)") }
    }
}

/// The playing item's position and duration, four times a second while it plays.
@MainActor @Observable final class PlayerClock {
    private(set) var position: Double = 0
    /// Zero until the item has a finite duration.
    private(set) var duration: Double = 0
    private(set) var item: AVPlayerItem?
    /// Where the seek bar is held, until the precise seek it ends with lands.
    private(set) var scrubbing: Double?
    @ObservationIgnored private weak var player: AVPlayer?
    @ObservationIgnored private var token: Any?

    func attach(_ player: AVPlayer) {
        detach()
        self.player = player
        // The observer also fires on seeks and rate changes, so a new item shows up here while paused too.
        token = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        tick(player.currentTime())
    }

    func detach() {
        if let token { player?.removeTimeObserver(token) }
        token = nil
    }

    /// The player's position now, read without waiting for the next tick.
    var currentPosition: Double {
        let seconds = player?.currentTime().seconds ?? 0
        return seconds.isFinite ? seconds : position
    }

    /// The frame the seek bar shows above its handle while dragged; nil until one is made, or where none can be.
    private(set) var preview: CGImage?
    @ObservationIgnored private var generator: AVAssetImageGenerator?
    @ObservationIgnored private var generatorItem: ObjectIdentifier?
    /// An item AVFoundation made no frame from (an HLS stream, say): no more tries for it.
    @ObservationIgnored private var previewless: ObjectIdentifier?
    @ObservationIgnored private var generating = false
    @ObservationIgnored private var nextPreview: Double?

    /// While dragging, only the bar, the time and the preview follow the finger; the playing video is left alone
    /// until the finger lifts (Telegram).
    func scrub(to seconds: Double) {
        scrubbing = seconds
        nextPreview = seconds
        makePreview()
    }

    /// Let go: one exact seek to where the finger stopped.
    func endScrub() {
        nextPreview = nil
        preview = nil
        if let target = scrubbing { seek(to: target) }
    }

    /// An exact seek; the bar stays at the target until it lands, rather than jumping back to the old position.
    func seek(to seconds: Double) {
        guard let player else { scrubbing = nil; return }
        scrubbing = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.scrubbing == seconds else { return }
                self.position = seconds
                self.scrubbing = nil
            }
        }
    }

    /// One frame at a time, then the latest place asked for (Telegram's MediaPlayerFramePreview does the same), from
    /// a generator of its own so the playing video isn't disturbed. Nearby keyframes are good enough, and quick.
    private func makePreview() {
        guard !generating, let seconds = nextPreview, let item = player?.currentItem else { return }
        let identity = ObjectIdentifier(item)
        guard previewless != identity else { nextPreview = nil; return }
        if generatorItem != identity {
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 320)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
            self.generator = generator
            generatorItem = identity
        }
        guard let generator else { return }
        nextPreview = nil
        generating = true
        generator.generateCGImageAsynchronously(for: CMTime(seconds: seconds, preferredTimescale: 600)) { [weak self] image, _, _ in
            nonisolated(unsafe) let frame = image
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.generating = false
                if let frame { if self.scrubbing != nil { self.preview = frame } }
                else if self.preview == nil { self.previewless = identity }
                self.makePreview()
            }
        }
    }

    private func tick(_ time: CMTime) {
        guard let player else { return }
        if item !== player.currentItem { item = player.currentItem }
        let seconds = time.seconds
        position = seconds.isFinite ? max(0, seconds) : 0
        let length = player.currentItem?.duration.seconds ?? 0
        let finite = length.isFinite ? max(0, length) : 0
        // Observation reports every assignment, even of the same value; the duration rarely changes.
        if finite != duration { duration = finite }
    }
}

/// The item's audio tracks and subtitles, for the options menu.
@MainActor @Observable final class MediaTracks {
    struct Group {
        let group: AVMediaSelectionGroup
        let options: [AVMediaSelectionOption]
    }
    private(set) var audio: Group?
    private(set) var legible: Group?
    /// Bumped by a selection, so the menus show the new choice.
    private var revision = 0
    @ObservationIgnored private weak var item: AVPlayerItem?

    func load(_ item: AVPlayerItem?) async {
        self.item = item; audio = nil; legible = nil
        guard let item else { return }
        let asset = item.asset
        let audible = try? await asset.loadMediaSelectionGroup(for: .audible)
        let subtitles = try? await asset.loadMediaSelectionGroup(for: .legible)
        guard !Task.isCancelled, self.item === item else { return }
        audio = audible.map { Group(group: $0, options: $0.options) }
        // Forced subtitles only translate foreign speech and come on by themselves; they aren't a choice.
        legible = subtitles.map { group in
            Group(group: group, options: group.options.filter { !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) })
        }
    }

    func selected(in group: Group) -> AVMediaSelectionOption? {
        _ = revision
        return item?.currentMediaSelection.selectedMediaOption(in: group.group)
    }

    func select(_ option: AVMediaSelectionOption?, in group: Group) {
        item?.select(option, in: group.group)
        revision += 1
    }
}

/// The video on the Lock Screen, in Control Center and on headphones, with play, pause, skip and scrub: AVKit's
/// own player published these by itself. Music holds Now Playing only while no video plays (MusicRemoteControl).
@MainActor final class VideoNowPlaying {
    private var targets: [(MPRemoteCommand, Any)] = []

    func start(_ session: PlaybackSession) {
        guard targets.isEmpty else { return }
        let commands = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor (PlaybackSession, MPRemoteCommandEvent) -> Void) {
            command.isEnabled = true
            let target = command.addTarget { [weak self, weak session] event in
                MainActor.assumeIsolated {
                    guard let session else { return .noActionableNowPlayingItem }
                    action(session, event)
                    self?.update(title: nil, session: session)
                    return .success
                }
            }
            targets.append((command, target))
        }
        on(commands.playCommand) { session, _ in if session.paused { session.togglePlayback() } }
        on(commands.pauseCommand) { session, _ in session.player.pause() }
        on(commands.togglePlayPauseCommand) { session, _ in session.togglePlayback() }
        commands.skipForwardCommand.preferredIntervals = [10]
        commands.skipBackwardCommand.preferredIntervals = [10]
        on(commands.skipForwardCommand) { session, _ in session.skip(10) }
        on(commands.skipBackwardCommand) { session, _ in session.skip(-10) }
        on(commands.changePlaybackPositionCommand) { session, event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return }
            session.player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600))
        }
    }

    private var title = ""

    /// `title` nil keeps the one shown.
    func update(title: String?, session: PlaybackSession) {
        guard !targets.isEmpty else { return }
        if let title { self.title = title }
        let player = session.player, seekable = session.hasTimeline && !session.isLive
        let commands = MPRemoteCommandCenter.shared()
        for command in [commands.skipForwardCommand, commands.skipBackwardCommand, commands.changePlaybackPositionCommand] {
            command.isEnabled = seekable
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: self.title,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: session.isLive,
            MPNowPlayingInfoPropertyPlaybackRate: session.paused ? 0.0 : Double(player.defaultRate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(player.defaultRate),
        ]
        let elapsed = player.currentTime().seconds
        if elapsed.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if seekable, let duration = player.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = session.paused ? .paused : .playing
    }

    func stop() {
        for (command, target) in targets { command.removeTarget(target) }
        targets = []
        // Music may already have taken Now Playing back as the player closed.
        let center = MPNowPlayingInfoCenter.default()
        if center.nowPlayingInfo?[MPNowPlayingInfoPropertyMediaType] as? UInt == MPNowPlayingInfoMediaType.video.rawValue {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
        }
    }
}
#endif
