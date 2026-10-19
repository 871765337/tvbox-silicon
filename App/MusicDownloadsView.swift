import SwiftUI
import TVCore

#if !os(tvOS)
/// Songs saved for listening without a connection, and those still on their way. Apple TV keeps
/// nothing lasting on disk, so downloads are for iPhone, iPad and Mac.
struct MusicDownloadsView: View {
    @Environment(Store.self) private var store
    @State private var confirmsDeleteAll = false
    private var library: MusicDownloadLibrary { .shared }

    var body: some View {
        // Most recently saved first.
        let saved = library.completed.sorted { ($0.finished ?? $0.created) > ($1.finished ?? $1.created) }
        let tracks = saved.map(\.track)
        let pending = library.pending
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MusicLayout.rowSpacing) {
                header(tracks).padding(.bottom, 20)
                if library.items.isEmpty {
                    ContentUnavailableView(L10n.text("No Downloaded Songs"), systemImage: "arrow.down.circle",
                                           description: Text(L10n.text("Download a song, album or playlist from its menu to listen without a connection.")))
                        .frame(maxWidth: .infinity).padding(.vertical, 60)
                }
                if !pending.isEmpty {
                    // Its own stack: a song that finishes moves to the list below under the same ID,
                    // and in one lazy stack its old row stayed on screen in place of the new one.
                    VStack(alignment: .leading, spacing: MusicLayout.rowSpacing) {
                        SectionHeader(title: L10n.text("Downloading")).padding(.bottom, 8)
                        ForEach(pending) { MusicPendingRow(item: $0) }
                    }
                }
                if !saved.isEmpty {
                    if !pending.isEmpty { SectionHeader(title: L10n.text("Downloaded")).padding(.top, 24).padding(.bottom, 8) }
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        MusicTrackRow(track: track) { store.music.play(MusicQueue(tracks: tracks, start: index, source: Self.title)) }
                    }
                }
            }
            .pageContainer()
        }
        .screenBackdrop()
        .screenTitle(Self.title)
        #if os(macOS)
        .toolbar(removing: .title)
        #endif
        .musicPlayerInset()
        .toolbar {
            if !library.items.isEmpty {
                Button { confirmsDeleteAll = true } label: { Image(systemName: "trash") }
                    .help(L10n.text("Delete Downloads")).accessibilityLabel(L10n.text("Delete Downloads"))
            }
        }
        .confirmationDialog(L10n.text("Delete all downloaded songs?"), isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
            Button(L10n.text("Delete Downloads"), role: .destructive) { library.remove(library.items.map(\.id)) }
        }
        #if DEBUG
        // `-qaPlayDownloaded 1` plays the newest saved song as soon as there is one.
        .task(id: tracks.first?.id) {
            if UserDefaults.standard.bool(forKey: "qaPlayDownloaded"), store.music.track == nil, !tracks.isEmpty {
                store.music.play(MusicQueue(tracks: tracks, start: 0, source: Self.title))
            }
        }
        #endif
    }

    static var title: String { L10n.text("Downloaded Songs") }

    private func header(_ tracks: [MusicTrack]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            #if os(macOS)
            Text(Self.title).font(.largeTitle.weight(.bold))
            #endif
            Text([L10n.text("%lld songs", tracks.count), DownloadFormat.size(library.size)].joined(separator: " · "))
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button { store.music.play(MusicQueue(tracks: tracks, start: 0, source: Self.title)) } label: {
                    Label(L10n.text("Play"), systemImage: "play.fill")
                }
                .controlButton(prominent: true)
                Button { store.music.play(MusicQueue.shuffled(tracks, source: Self.title)) } label: {
                    Label(L10n.text("Shuffle"), systemImage: "shuffle")
                }
                .controlButton()
            }
            .fixedSize()
            .disabled(tracks.isEmpty)
        }
    }
}

/// A song on its way: how far it got, or why it stopped, with Retry and Cancel.
private struct MusicPendingRow: View {
    let item: MusicDownload

    var body: some View {
        HStack(spacing: MusicLayout.gap) {
            MusicArtwork(url: item.track.artwork, size: MusicLayout.art)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.track.title).font(.headline).lineLimit(1)
                Text(status).font(.subheadline).monospacedDigit().lineLimit(2)
                    .foregroundStyle(item.status == .failed ? AnyShapeStyle(Brand.rose) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 8)
            if item.status == .failed {
                Button { MusicDownloadLibrary.shared.retry(item.id) } label: {
                    Image(systemName: "arrow.clockwise").font(.body.weight(.semibold)).frame(width: 30, height: 30).contentShape(.rect)
                }
                .buttonStyle(.borderless).help(L10n.text("Retry")).accessibilityLabel(L10n.text("Retry"))
            } else {
                DownloadState(status: item.status, fraction: item.fraction)
            }
            Button { MusicDownloadLibrary.shared.remove([item.id]) } label: {
                Image(systemName: "xmark").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 30, height: 30).contentShape(.rect)
            }
            .buttonStyle(.borderless).help(L10n.text("Cancel Download")).accessibilityLabel(L10n.text("Cancel Download"))
        }
        .padding(.vertical, 6)
    }

    private var status: String {
        switch item.status {
        case .queued, .paused: L10n.text("Waiting")
        case .downloading:
            if let expected = item.expected, expected > 0 {
                L10n.text("%@ of %@", DownloadFormat.size(item.received), DownloadFormat.size(expected))
            } else {
                L10n.text("Downloading")
            }
        case .finishing: L10n.text("Finishing…")
        case .failed: item.failure ?? L10n.text("Download failed")
        case .completed: L10n.text("Downloaded")
        }
    }
}

/// The way to saved songs, at the top of the Music page and on the Downloads page.
struct MusicDownloadsLink: View {
    /// On the Downloads page it sits among cards, so it is one too.
    var card = false

    var body: some View {
        let library = MusicDownloadLibrary.shared
        RouteLink { MusicDownloadsView() } label: {
            HStack(spacing: MusicLayout.gap) {
                #if os(iOS)
                SectionGlyph(section: .downloads, size: MusicLayout.art)
                #else
                Image(systemName: AppSection.downloads.icon)
                    .font(.system(size: MusicLayout.art * 0.46, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: MusicLayout.art, height: MusicLayout.art)
                    .background(Brand.cyan.gradient, in: RoundedRectangle(cornerRadius: MusicLayout.art * 0.3, style: .continuous))
                    .accessibilityHidden(true)
                #endif
                VStack(alignment: .leading, spacing: 3) {
                    Text(MusicDownloadsView.title).font(.headline).lineLimit(1).foregroundStyle(.primary)
                    Text(details(library)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, card ? 12 : 6)
            .padding(.horizontal, card ? 14 : 0)
            .background { if card { Color.clear.contentPanel(cornerRadius: 18) } }
            .contentShape(Rectangle())
        }
        .glassRow()
    }

    private func details(_ library: MusicDownloadLibrary) -> String {
        var parts = [L10n.text("%lld songs", library.completed.count)]
        // Failed songs wait for Retry on the page; only those on their way count here.
        let running = library.pending.filter { $0.status != .failed }.count
        if running > 0 { parts.append(L10n.text("%lld downloading", running)) }
        if library.size > 0 { parts.append(DownloadFormat.size(library.size)) }
        return parts.joined(separator: " · ")
    }
}

/// Download, or Remove Download once every song is saved or on its way, for songs' menus.
struct MusicDownloadMenuItems: View {
    let tracks: [MusicTrack]

    var body: some View {
        let library = MusicDownloadLibrary.shared
        let saved = tracks.compactMap { library.item(for: $0) }
        if !tracks.isEmpty, saved.count == tracks.count {
            Button(role: .destructive) { library.remove(saved.map(\.id)) } label: {
                Label(L10n.text(saved.allSatisfy { $0.status == .completed } ? "Remove Download" : "Cancel Download"), systemImage: "trash")
            }
        } else {
            Button { library.download(tracks) } label: { Label(L10n.text("Download"), systemImage: "arrow.down.circle") }
        }
    }
}

/// Downloads an album's or playlist's songs; a check once they are all saved.
struct MusicDownloadButton: View {
    let tracks: [MusicTrack]
    /// The Mac header's buttons have a fixed size.
    var side: CGFloat?

    var body: some View {
        let library = MusicDownloadLibrary.shared
        let items = tracks.compactMap { library.item(for: $0) }
        let queued = !tracks.isEmpty && items.count == tracks.count && !items.contains { $0.status == .failed }
        let done = queued && items.allSatisfy { $0.status == .completed }
        let label = L10n.text(done ? "Downloaded" : queued ? "Downloading" : "Download")
        Button { library.download(tracks) } label: {
            Image(systemName: done ? "checkmark.circle" : queued ? "arrow.down.circle.dotted" : "arrow.down.circle")
                .frame(width: side, height: side)
        }
        .disabled(tracks.isEmpty || queued)
        .help(label).accessibilityLabel(label)
    }
}
#endif
