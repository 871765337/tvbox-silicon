import SwiftUI
import TVCore

/// Bilibili Live: the busiest rooms of each area as cards, like Bilibili's own live home.
struct BilibiliLiveView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rooms: [BilibiliLive.Room] = []
    @State private var area: String?
    @State private var loading = false
    @State private var error: String?
    private var areas: [String] {
        var seen = Set<String>()
        return rooms.map(\.area).filter { seen.insert($0).inserted }
    }
    private var shown: [BilibiliLive.Room] {
        let selected = area ?? areas.first
        return rooms.filter { $0.area == selected }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if !areas.isEmpty {
                    ChipRow {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(areas, id: \.self) { value in
                                    Chip(title: value, selected: (area ?? areas.first) == value) { area = value }
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                } else if loading { ChipSkeletonRow() }
                if let error {
                    ErrorStateCard(title: L10n.text("Unable to Load Channels"), message: L10n.text("Try again, or choose another source to keep watching."),
                                   details: error, retry: { Task { await load() } }, goBack: { dismiss() }, busy: loading)
                        .padding(.vertical, 24)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Layout.tileMin), spacing: Layout.cardSpacing)], spacing: Layout.gridRowSpacing) {
                    ForEach(shown) { room in LiveRoomCard(room: room) }
                }
                if loading && rooms.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60) }
            }.pageContainer()
        }
        .screenBackdrop()
        .screenTitle(LiveSource.bilibili.name)
        #if !os(tvOS)
        .toolbar { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.disabled(loading).accessibilityLabel(L10n.text("Refresh")) }
        #endif
        .task {
            #if DEBUG
            // `-qaLiveArea <area>` opens that area, for screenshots.
            if area == nil { area = UserDefaults.standard.string(forKey: "qaLiveArea") }
            #endif
            if rooms.isEmpty { await load() }
        }
    }

    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do { rooms = try await BilibiliLive.rooms() }
        catch is CancellationError {}
        catch { self.error = error.localizedDescription }
    }
}

/// A live room: its 16:9 cover with a live badge and the audience, then the title and the streamer.
struct LiveRoomCard: View {
    @Environment(Store.self) private var store
    let room: BilibiliLive.Room

    var body: some View {
        let favorite = store.isFavorite(room.channel)
        Button { store.playing = room.channel } label: {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear.aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { PosterImage(url: room.cover, headers: [:]) }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 5) {
                            Image(systemName: "dot.radiowaves.left.and.right").font(.caption2.weight(.bold))
                            Text(L10n.text("LIVE")).font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Brand.rose, in: Capsule()).padding(8)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if room.online > 0 {
                            Label(room.online.formatted(.number.notation(.compactName)), systemImage: "person.2.fill")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.white).labelStyle(.titleAndIcon)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .glassEffect(.regular.tint(.black.opacity(0.45)), in: Capsule()).padding(8)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if favorite {
                            Image(systemName: "heart.fill").font(.caption).foregroundStyle(Brand.rose)
                                .padding(6).glassEffect(.regular.tint(.black.opacity(0.45)), in: Circle()).padding(8)
                        }
                    }
                Text(room.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(1).truncationMode(.tail)
                Text(room.host).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            // Cards in a row share its height; a one-line title leaves the space below, not between.
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .cardButton()
        .contextMenu {
            Button(favorite ? L10n.text("Remove %@ from favorites", room.host) : L10n.text("Add %@ to favorites", room.host),
                   systemImage: favorite ? "heart.slash" : "heart") { store.toggleFavorite(room.channel) }
        }
        .accessibilityLabel("\(room.host), \(room.title)")
    }
}
