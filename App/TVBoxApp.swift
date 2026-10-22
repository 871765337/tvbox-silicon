import SwiftUI
import TVCore

@main struct TVBoxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @State private var store = Store.shared
    #else
    @State private var store = Store()
    #endif
    @State private var updates = Updates()
    #if os(iOS)
    /// An Apple TV's Douyin code, scanned with the Camera.
    @State private var douyinHandoff: DouyinHandoff.Link?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    init() {
        #if os(macOS)
        // Use thin overlay scrollers app-wide. With "Show scroll bars: Always" or a mouse attached,
        // AppKit otherwise draws wide legacy scrollers that crowd poster grids and the episode rail.
        // The app's own defaults domain takes precedence over the global setting.
        UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")
        #endif
        #if os(iOS)
        _ = MusicRemoteControl.shared
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(updates)
                #if !os(tvOS)
                // tvOS draws plain buttons and section links in the tint, so it keeps the neutral default.
                .tint(Brand.accent)
                #endif
                .task { Diagnostics.shared.record(.info, "app", "Application scene opened") }
                .task { await ErrorReports.shared.start() }
                .task {
                    #if DEBUG
                    if QALaunch.section != nil || QALaunch.page != nil { await QALaunch.start(store); return }
                    #endif
                    await store.restoreSubscription()
                }
                .task {
                    #if DEBUG
                    if QALaunch.section != nil, UserDefaults.standard.string(forKey: "qaReleaseFeed") == nil { return }
                    #endif
                    // Builds before 1.1 recorded no version, so earlier use shows as a saved subscription.
                    await updates.launched(returning: UserDefaults.standard.string(forKey: "subscriptionAddress") != nil)
                }
                #if os(tvOS) || os(macOS)
                .task { BilibiliCastController.shared.start(store) }
                .onChange(of: store.extrasUnlocked) { _, unlocked in if unlocked { BilibiliCastController.shared.start(store) } }
                #endif
                #if os(iOS)
                .onOpenURL { url in if let link = DouyinHandoff.Link(url) { douyinHandoff = link } }
                .sheet(item: $douyinHandoff) { DouyinHandoffView(link: $0) }
                #endif
                // A launch that ends while active, without passing through here, crashed or was ended.
                .onChange(of: scenePhase, initial: true) { _, phase in ErrorReports.shared.onScreen(phase == .active) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        Task { _ = await Diagnostics.shared.snapshot(); ErrorReports.shared.save() }
                    }
                    if phase == .active { Task { await ErrorReports.shared.sendIfDue() } }
                    #if os(tvOS) || os(macOS)
                    // Phones only see the TV while the app is open.
                    if phase == .background { BilibiliCastController.shared.stop() }
                    if phase == .active { BilibiliCastController.shared.start(store) }
                    #endif
                    #if !os(macOS)
                    if phase == .background { DownloadsLifecycle.enteredBackground() }
                    if phase == .active { DownloadsLifecycle.becameActive() }
                    #endif
                    // Apple TV and Mac sessions run for days; look again when the app comes back.
                    if phase == .active { Task { await updates.check() } }
                }
                #if os(tvOS)
                .preferredColorScheme(.dark)
                #endif
                #if os(macOS)
                .frame(minWidth: 920, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(after: .appInfo) {
                if !Distribution.isAppStore {
                    Button(L10n.text("Check for Updates…")) { Task { await updates.check(manual: true) } }
                        .disabled(updates.checking)
                }
            }
        }
        #endif
        #if os(macOS)
        // The music mini player, floating over other apps at the bottom right; also in the Window menu.
        Window(L10n.text("Mini Player"), id: MusicMacMiniPlayer.windowID) {
            MusicMacMiniPlayer().environment(store).tint(Brand.accent)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultWindowPlacement { content, context in
            let size = content.sizeThatFits(.unspecified)
            let screen = context.defaultDisplay.visibleRect
            return WindowPlacement(CGPoint(x: screen.maxX - size.width - 20, y: screen.maxY - size.height - 20), size: size)
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
        #endif
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The player's rotate button narrows this to landscape (see PlayerOrientation).
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { PlayerOrientation.mask }
    }
}
#endif
