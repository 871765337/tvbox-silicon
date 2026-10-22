import SwiftUI
import TVCore

struct HomeView: View {
    @Environment(Store.self) private var store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    #if os(tvOS)
    @FocusState private var primaryFocused: Bool
    #endif

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if !store.playbackHistory.entries.isEmpty { continueWatching }
                    if let config = store.subscription {
                        if store.orderedSites(config).contains(where: { store.pinnedSources.contains($0, origin: config.origin) }) {
                            pinnedSources(config)
                        }
                        RecommendationsView(config: config)
                        if !store.favorites.isEmpty { favorites }
                        if !config.lives.isEmpty { playlists(config).id("live") }
                    } else {
                        welcome
                    }
                }
                .pageContainer()
            }
            #if DEBUG
            .task { if let target = QALaunch.scrollTarget { try? await Task.sleep(for: .seconds(8)); reader.scrollTo(target, anchor: .bottom) } }
            #endif
        }
        .screenBackdrop()
        #if os(tvOS)
        // The tab sidebar already names this page; a second heading just repeats it.
        .toolbar(.hidden, for: .navigationBar)
        #else
        .screenTitle(L10n.text("Watch Now"))
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Welcome

    /// First run: one clear action, a way to bring your own URL, and artwork so the empty
    /// screen reads as an invitation rather than a missing page.
    private var welcome: some View {
        HStack(alignment: .center, spacing: welcomeInset > 0 ? 40 : Layout.gutter) {
            welcomeCopy.frame(maxWidth: .infinity, alignment: .leading)
            if showsPosterWall {
                PosterWall().frame(maxWidth: .infinity).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, welcomeInset)
        .containerRelativeFrame(.vertical, alignment: .center) { height, _ in height * 0.82 }
        #if os(tvOS)
        // Moving right out of the sidebar lands on the primary action, not the secondary one.
        .defaultFocus($primaryFocused, true, priority: .userInitiated)
        #endif
    }

    /// The welcome's title size. On an iPad or iPhone Duo's inner display (regular width) a phone's 34 pt title and
    /// the page's 16 pt margin left the copy small and pressed against the edge of a large, empty screen.
    private var heroTitle: CGFloat {
        #if os(iOS)
        sizeClass == .regular ? 52 : Layout.heroTitle
        #else
        Layout.heroTitle
        #endif
    }

    private var welcomeInset: CGFloat {
        #if os(iOS)
        sizeClass == .regular ? 48 : 0
        #else
        0
        #endif
    }

    private var welcomeCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                AppMark(size: heroTitle * 1.4)
                Text(L10n.text("Yingxia")).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
            Text(L10n.text("Your cinema,\non every screen."))
                .font(.system(size: heroTitle, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
            Text(L10n.text("Connect your subscription to watch on Mac, iPhone, iPad, and Apple TV."))
                .font(.title3).foregroundStyle(.secondary)
                .frame(maxWidth: heroTitle * 10, alignment: .leading)
                .padding(.bottom, 40)
            Group {
                #if os(tvOS)
                HStack(spacing: 16) { welcomeButtons }
                #else
                // Side by side when both fit on one line each, else stacked: on an iPad in portrait the copy
                // column is about 430 pt and "Sign In to Cloud Drive" wrapped onto two lines.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { welcomeButtons }
                    VStack(alignment: .leading, spacing: 12) { welcomeButtons }
                }
                #endif
            }
            .controlSize(.large)
            if store.importing {
                LoadingCard { .server(URL(string: store.subscriptionAddress)?.host(), title: L10n.text("Importing…")) }
                    .frame(maxWidth: heroTitle * 9)
                    .padding(.top, 24)
            }
        }
    }

    @ViewBuilder private var welcomeButtons: some View {
        // There is no default subscription. A cloud drive works without one (Cloud Files), and a
        // subscription address is added in Settings.
        RouteLink { CloudDriveView() } label: {
            Label(L10n.text("Sign In to Cloud Drive"), systemImage: "externaldrive.fill.badge.person.crop").lineLimit(1)
        }
        .controlButton(prominent: true).tint(Brand.accent)
        #if os(tvOS)
        .focused($primaryFocused)
        #endif
        Button { store.section = .settings } label: {
            Label(L10n.text("Add Subscription"), systemImage: "plus.circle.fill").lineLimit(1)
        }
        .controlButton().disabled(store.importing)
    }

    private var showsPosterWall: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

    // MARK: Sections

    private func pinnedSources(_ config: Subscription) -> some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            SectionHeader(title: L10n.text("Pinned Sources")) { store.section = .sites }
            LazyVGrid(columns: Layout.cardColumns, spacing: Layout.cardSpacing) {
                ForEach(store.orderedSites(config).filter { store.pinnedSources.contains($0, origin: config.origin) }) { site in
                    RouteLink { SiteView(site: site, origin: config.origin, jarURL: config.spiderURL) } label: { SiteCard(site: site) }
                        .tileButton().contextMenu { PinSourceButton(site: site, origin: config.origin) }
                        .accessibilityIdentifier("home.pinned." + site.key)
                }
            }
        }.accessibilityIdentifier("home.pinnedSources")
    }

    private var continueWatching: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            SectionHeader(title: L10n.text("Continue Watching")) { store.section = .history }
            ChipRow {
                HStack(spacing: Layout.cardSpacing) {
                    ForEach(store.playbackHistory.entries.prefix(12)) { HistoryCard(entry: $0).accessibilityIdentifier("history.resume." + $0.context.videoID) }
                }.padding(.vertical, 6)
            }
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            SectionHeader(title: L10n.text("Favorites")) { store.section = .favorites }
            ChipRow {
                HStack(spacing: Layout.cardSpacing) {
                    ForEach(store.favorites.prefix(12)) { ChannelCard(channel: $0).frame(width: Layout.cardMin) }
                }.padding(.vertical, 6)
            }
        }
    }

    private func playlists(_ config: Subscription) -> some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            SectionHeader(title: L10n.text("Live TV")) { store.section = .live }
            // Every platform, then one row of playlists.
            LiveSourceGrid(sources: config.lives.filter(\.isBuiltIn) + config.lives.filter { !$0.isBuiltIn }.prefix(3), titled: false)
        }
    }

}

/// The app icon artwork, masked like a home-screen icon.
struct AppMark: View {
    var size: CGFloat
    var body: some View {
        Image("YingxiaLogo").resizable().interpolation(.high).scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: Color(red: 0.1, green: 0.55, blue: 1).opacity(0.35), radius: size * 0.22, y: size * 0.06)
    }
}

/// Decorative poster tiles: staggered columns in the icon's blues, fading into the canvas.
private struct PosterWall: View {
    private static let hues: [Color] = [Brand.cyan, Brand.indigo, Brand.teal, Brand.cyan.opacity(0.6)]
    private static let symbols = ["film", "sparkles.tv", "theatermasks", "music.note.tv", "popcorn", "star"]
    var body: some View {
        GeometryReader { proxy in
            let spacing = proxy.size.width * 0.045
            let width = (proxy.size.width - spacing * 2) / 3
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<3, id: \.self) { column in
                    VStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { row in tile(column * 4 + row, width: width) }
                    }
                    .offset(y: column == 1 ? -width * 0.55 : column == 2 ? -width * 0.15 : 0)
                }
            }
            .rotationEffect(.degrees(-6))
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .background { EllipticalGradient(colors: [Brand.cyan.opacity(0.3), .clear], endRadiusFraction: 0.5) }
            // An ellipse that reaches clear at the frame's edges, so no tile meets a hard clip.
            .mask { EllipticalGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.75), location: 0.45), .init(color: .clear, location: 1)], endRadiusFraction: 0.5) }
        }
    }

    private func tile(_ index: Int, width: CGFloat) -> some View {
        let hue = Self.hues[index % Self.hues.count]
        let lit = index % 3 != 1
        return RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
            .fill(LinearGradient(colors: lit ? [hue.opacity(0.7), hue.opacity(0.28)] : [PosterSurface.raised, PosterSurface.base],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: Self.symbols[index % Self.symbols.count])
                    .font(.system(size: width * 0.26, weight: .semibold))
                    .foregroundStyle(.white.opacity(lit ? 0.55 : 0.18))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: width * 0.04) {
                    Capsule().frame(width: width * 0.55, height: width * 0.05)
                    Capsule().frame(width: width * 0.32, height: width * 0.05)
                }
                .foregroundStyle(.white.opacity(lit ? 0.35 : 0.12))
                .padding(width * 0.09)
            }
            .frame(width: width, height: width * 1.45)
    }
}

/// Neutral tile fills that track the canvas on every platform.
private enum PosterSurface {
    static let base = Color(light: Color(red: 0.88, green: 0.905, blue: 0.94), dark: Color(red: 0.065, green: 0.09, blue: 0.165))
    static let raised = Color(light: Color(red: 0.83, green: 0.86, blue: 0.91), dark: Color(red: 0.11, green: 0.15, blue: 0.25))
}
