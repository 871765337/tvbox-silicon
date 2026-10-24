import SwiftUI
import TVCore

/// Watched titles, newest first: resume where you left off, or select titles to remove.
struct PlaybackHistoryView: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var managing = false
    @State private var selected = Set<String>()
    @State private var confirmsDelete = false
    @State private var deletionIDs = Set<String>()
    /// Shows titles hidden from Continue Watching. Leaving it off never changes the home row.
    @State private var includeHidden = false
    private var history: PlaybackHistory { store.playbackHistory }
    private var entries: [PlaybackHistoryEntry] {
        history.entries.filter { includeHidden || !history.isHidden($0.id) }
            .filter { query.isEmpty || $0.context.videoName.localizedCaseInsensitiveContains(query) || $0.context.sourceName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if history.entries.isEmpty {
                EmptyPage(symbol: AppSection.history.icon, title: L10n.text("No Playback History Yet"),
                          message: L10n.text("Videos you watch appear here, ready to pick up where you left off."),
                          action: L10n.text("Browse Sources"), actionSymbol: AppSection.sites.icon, perform: { store.section = .sites })
            } else {
                content.catalogSearchable(text: $query, prompt: L10n.text("Search history"))
            }
        }
        .screenBackdrop()
        .tabTitle(L10n.text("Playback History"))
        #if !os(tvOS)
        .toolbar {
            Button { includeHidden.toggle() } label: {
                Label(L10n.text("Show Hidden"), systemImage: includeHidden ? "eye.fill" : "eye")
            }
            .accessibilityAddTraits(includeHidden ? .isSelected : [])
            .accessibilityIdentifier("history.showHidden")
        }
        #endif
        .onChange(of: history.entries.isEmpty) { _, empty in if empty { managing = false; selected.removeAll() } }
        // Leaving the page gives up a title still being prepared.
        .onDisappear { if store.playing == nil { store.cancelResume() } }
        .confirmationDialog(L10n.text("Remove selected history and its cached content?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(L10n.text("Remove from history"), role: .destructive) {
                history.remove(deletionIDs); selected.subtract(deletionIDs); deletionIDs.removeAll()
            }
            .accessibilityIdentifier("history.confirmDelete")
        } message: {
            Text(L10n.text("Removing a title also clears its cached content and skip times."))
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.headerSpacing) {
                if let error = history.persistenceError {
                    StatusNotice(text: L10n.text("Unable to save playback history: %@", error))
                }
                header
                LazyVGrid(columns: Layout.posterColumns, spacing: Layout.gridRowSpacing) {
                    ForEach(entries) { entry in
                        HistoryCard(entry: entry, selection: managing ? selected.contains(entry.id) : nil, details: true, dimmed: includeHidden && history.isHidden(entry.id)) { tap(entry) }
                    }
                }
                .tvFocusSection()
            }
            .pageContainer()
        }
    }

    /// Count and actions on one line, or actions under the count when a phone is too narrow;
    /// managing swaps them for selection actions.
    private var header: some View {
        let title = SectionHeader(title: L10n.text("%lld titles", entries.count))
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                title
                Spacer(minLength: 12)
                actions
            }
            VStack(alignment: .leading, spacing: 12) {
                title
                HStack(spacing: 10) { actions }
            }
        }
        .tvFocusSection()
    }

    @ViewBuilder private var actions: some View {
            if managing {
                Button(L10n.text("Select all")) { selected = Set(entries.map(\.id)) }
                    .controlButton().accessibilityIdentifier("history.selectAll")
                Button { deletionIDs = selected; confirmsDelete = true } label: {
                    Label(L10n.text("Delete selected (%lld)", selected.count), systemImage: "trash").lineLimit(1).fixedSize()
                }
                .controlButton().disabled(selected.isEmpty).accessibilityIdentifier("history.deleteSelected")
                Button(L10n.text("Done")) { managing = false; selected.removeAll() }
                    .controlButton(prominent: true).accessibilityIdentifier("history.manage")
            } else {
                #if os(tvOS)
                Button { includeHidden.toggle() } label: {
                    Label(L10n.text("Show Hidden"), systemImage: includeHidden ? "eye.fill" : "eye")
                }
                .controlButton().accessibilityIdentifier("history.showHidden")
                #endif
                Button { managing = true } label: {
                    Label(L10n.text("Manage history"), systemImage: "checklist").lineLimit(1).fixedSize()
                }
                .controlButton().accessibilityIdentifier("history.manage")
                Button { deletionIDs = Set(history.entries.map(\.id)); confirmsDelete = true } label: {
                    Label(L10n.text("Clear history"), systemImage: "trash").lineLimit(1).fixedSize()
                }
                .controlButton()
            }
    }

    private func tap(_ entry: PlaybackHistoryEntry) {
        if managing {
            if selected.contains(entry.id) { selected.remove(entry.id) } else { selected.insert(entry.id) }
        } else {
            store.resume(entry)
        }
    }
}

enum HistoryMetrics {
    /// Continue Watching card width on Watch Now; the History page lets the grid size its cards.
    #if os(tvOS)
    static let card: CGFloat = 240
    #elseif os(macOS)
    static let card: CGFloat = 150
    #else
    static let card: CGFloat = 120
    #endif
}

enum HistoryFormat {
    static func status(_ entry: PlaybackHistoryEntry) -> String {
        entry.completed ? L10n.text("Finished · Watch again") : L10n.text("Continue from %@", EpisodeSkipSettings.formatTime(entry.position))
    }
}

/// A watched title as a poster card, with progress along the poster's foot. Continue Watching shows
/// the episode; the History page (`details`) adds the source and where playback resumes.
struct HistoryCard: View {
    @Environment(Store.self) private var store
    @Environment(\.stripDrag) private var drag
    let entry: PlaybackHistoryEntry
    /// Whether the card is selected while managing history; nil outside managing.
    var selection: Bool? = nil
    var details = false
    /// A title hidden from Continue Watching, shown faded on the history page.
    var dimmed = false
    /// Replaces resuming, for managing.
    var action: (() -> Void)? = nil
    @State private var hovering = false
    /// Touch and the remote have no hover, so the empty heart stays available there.
    private var heartRevealed: Bool {
        #if os(macOS)
        hovering
        #else
        true
        #endif
    }
    var body: some View {
        // The heart is a sibling of the poster button, so a click does not resume or change the selection.
        ZStack(alignment: .topLeading) {
            posterButton
            FavoriteHeartButton(item: entry.favoriteItem(), name: entry.context.videoName, onArtwork: true, revealed: heartRevealed)
                .fixedSize()
                .padding(8)
                .allowsHitTesting(drag?.active != true)
        }
        .overlay(alignment: .topTrailing) {
            if selection == nil, hovering {
                HStack(spacing: 6) { historyHide; historyRemove }
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.15), value: hovering)
    }

    /// Hides this title from Continue Watching, or shows it there again. Not a delete.
    private var historyHide: some View {
        let hidden = store.playbackHistory.isHidden(entry.id)
        return Button {
            guard drag?.active != true else { return }
            store.playbackHistory.toggleHidden(entry.id)
        } label: {
            Image(systemName: hidden ? "eye" : "eye.slash")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.black.opacity(0.55), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(hidden ? "Show in Continue Watching" : "Hide from Continue Watching"))
        .allowsHitTesting(drag?.active != true)
    }

    /// Red remove control. A pointer shows it; the context menu stays for touch and the remote.
    private var historyRemove: some View {
        Button {
            guard drag?.active != true else { return }
            store.playbackHistory.remove(entry.id)
        } label: {
            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.black.opacity(0.8))
                .frame(width: 22, height: 22)
                .background(Brand.rose, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("Remove from history"))
        .allowsHitTesting(drag?.active != true)
    }

    private var posterButton: some View {
        Button {
            guard drag?.active != true else { return }
            if let action { action() } else { store.resume(entry) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear.aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { PosterImage(url: entry.context.poster, headers: entry.context.posterHeaders ?? [:]) }
                    .overlay(alignment: .bottom) {
                        if entry.duration > 0 {
                            // White on the artwork, as in the TV app: the accent is near-black in light mode.
                            GeometryReader { proxy in
                                Capsule().fill(.white.opacity(0.25))
                                    .overlay(alignment: .leading) { Capsule().fill(.white).frame(width: proxy.size.width * entry.progress) }
                            }
                            .frame(height: 5).padding(10)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let selection {
                            Image(systemName: selection ? "checkmark.circle.fill" : "circle")
                                .font(.title2).symbolRenderingMode(.palette)
                                .foregroundStyle(selection ? Brand.onAccent : .white, selection ? Brand.accent : .black.opacity(0.35))
                                .contentTransition(.symbolEffect(.replace))
                                .padding(8)
                        }
                    }
                    .overlay {
                        // Preparing this title; choosing another card switches to that one.
                        if store.resumingHistoryID == entry.id {
                            ZStack {
                                Color.black.opacity(0.5)
                                ProgressView().controlSize(.large).tint(.white)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(selection == false ? 0.6 : 1)
                Text(entry.context.videoName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                if details {
                    Text("\(entry.context.episodeName) · \(SourceLabel(entry.context.sourceName).text)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(HistoryFormat.status(entry)).font(.caption).monospacedDigit().foregroundStyle(.tertiary).lineLimit(1)
                } else {
                    // The bar on the poster already says how far; the line names the episode.
                    Text(entry.context.episodeName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(width: details ? nil : HistoryMetrics.card)
            .frame(maxWidth: details ? .infinity : nil, alignment: .leading)
        }
        .cardButton()
        .opacity(dimmed ? 0.45 : 1)
        .accessibilityAddTraits(selection == true ? [.isSelected] : [])
        .accessibilityIdentifier((selection != nil ? "history.select." : "history.resume.") + entry.context.videoID)
        .contextMenu {
            FavoriteMenuButton(item: entry.favoriteItem(), name: entry.context.videoName)
            Button(L10n.text(store.playbackHistory.isHidden(entry.id) ? "Show in Continue Watching" : "Hide from Continue Watching"), systemImage: store.playbackHistory.isHidden(entry.id) ? "eye" : "eye.slash") {
                store.playbackHistory.toggleHidden(entry.id)
            }
            Button(L10n.text("Remove from history"), systemImage: "trash", role: .destructive) { store.playbackHistory.remove(entry.id) }
        }
    }
}
