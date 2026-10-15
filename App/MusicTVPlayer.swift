import SwiftUI
import TVCore

#if os(tvOS)
/// Now Playing at the top of a music page, as a small pill like the filter chips beside it: the
/// remote reaches it in a move from the results, and it opens the full-screen player.
struct MusicNowPlayingButton: View {
    @Environment(Store.self) private var store
    var body: some View {
        let music = store.music
        if let track = music.track {
            Button { music.presentsPlayer = true } label: {
                HStack(spacing: 14) {
                    PosterImage(url: track.artwork, symbol: "music.note")
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    // Bars in the label's own colour, so they stay visible on the focused white plate.
                    Image(systemName: "waveform").symbolEffect(.variableColor.iterative, isActive: music.phase == .playing)
                    Text([track.title, track.artistLine].joined(separator: " · ")).lineLimit(1)
                }
            }
            .glassPill()
            .accessibilityLabel(Text(L10n.text("Now Playing") + ", " + track.title))
            .padding(.bottom, 16)
        }
    }
}

/// The sidebar's Now Playing page: the cover large, the song, where it is, the transport, and the
/// full-screen player with its lyrics a click away. Play/Pause on the remote works here too.
struct MusicTVNowPlayingPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        let music = store.music
        if let track = music.track {
            HStack(alignment: .center, spacing: 90) {
                MusicArtwork(url: track.artwork, size: 560)
                    .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Label(L10n.text("Now Playing"), systemImage: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: music.phase == .playing)
                        .font(.system(size: 26, weight: .semibold)).foregroundStyle(.secondary)
                    Text(track.title).font(.system(size: 58, weight: .bold)).lineLimit(2).padding(.top, 14)
                    Text([track.artistLine, track.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — "))
                        .font(.system(size: 30)).foregroundStyle(.secondary).lineLimit(1).padding(.top, 6)
                    progress(music).padding(.top, 40)
                    HStack(spacing: 24) {
                        Button { music.previous() } label: { Image(systemName: "backward.fill") }
                            .controlButton().accessibilityLabel(L10n.text("Previous"))
                        Button { music.toggle() } label: { Image(systemName: music.isPlaying ? "pause.fill" : "play.fill").frame(width: 34) }
                            .controlButton().accessibilityLabel(L10n.text(music.isPlaying ? "Pause" : "Play"))
                        Button { music.next() } label: { Image(systemName: "forward.fill") }
                            .controlButton().disabled(!music.canAdvance).accessibilityLabel(L10n.text("Next"))
                        Button { music.presentsPlayer = true } label: { Label(L10n.text("Open Player"), systemImage: "arrow.up.left.and.arrow.down.right") }
                            .controlButton(prominent: true)
                    }
                    .padding(.top, 36)
                    .focusSection()
                }
                .frame(maxWidth: 820, alignment: .leading)
            }
            .padding(80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { backdrop(track.artwork) }
            .onPlayPauseCommand { music.toggle() }
        }
    }

    private func progress(_ music: MusicPlaybackSession) -> some View {
        let total = max(music.duration ?? 0, 1), position = min(music.seekingTo ?? music.position, total)
        return VStack(spacing: 10) {
            ProgressView(value: position, total: total).tint(.white)
            HStack {
                Text(MusicTime.text(position))
                Spacer()
                Text(music.duration.map { "-" + MusicTime.text($0 - position) } ?? "--:--")
            }
            .font(.system(size: 22, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    /// The cover blurred small and drawn once, then scaled to the screen.
    private func backdrop(_ artwork: URL?) -> some View {
        GeometryReader { proxy in
            ZStack {
                TVStyle.background
                if let artwork {
                    PosterImage(url: artwork, symbol: "music.note")
                        .frame(width: 48, height: 48)
                        .blur(radius: 7, opaque: true)
                        .drawingGroup()
                        .scaleEffect(max(proxy.size.width, proxy.size.height) / 48 * 1.25)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(0.55)
                }
                Color.black.opacity(0.35)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif
