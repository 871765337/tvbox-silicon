import SwiftUI
import TVCore

/// Messages the website publishes for the people using the app (`website/public/messages.json`), each
/// shown once in an alert. Unlike release notes they also reach App Store and TestFlight builds.
@MainActor @Observable final class Announcements {
    /// The first message this device hasn't shown; it waits while something else is on screen.
    var current: MessageFeed.Message? { pending.first }
    private var pending: [MessageFeed.Message] = []
    private var feed: MessageFeed
    private var checking = false
    private var lastChecked: Date?
    private let build: MessageFeed.Build
    private let defaults: UserDefaults
    private let address: URL
    private static let interval: TimeInterval = 15 * 60

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        var version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        var number = Int(bundle.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
        var address = MessageFeed.address
        #if DEBUG
        // QA: `-qaMessageFeed <url>` reads another feed (a file:// path works on simulators); `-qaVersion 1.7.7`
        // and `-qaBuild 27` pretend to be another build.
        if let value = defaults.string(forKey: "qaMessageFeed"), let url = URL(string: value) { address = url }
        if let value = defaults.string(forKey: "qaVersion") { version = value }
        if defaults.object(forKey: "qaBuild") != nil { number = defaults.integer(forKey: "qaBuild") }
        #endif
        build = MessageFeed.Build(appStore: Distribution.isAppStore, version: version, number: number)
        self.address = address
        feed = defaults.data(forKey: Keys.feed).flatMap { try? JSONDecoder().decode(MessageFeed.self, from: $0) } ?? MessageFeed(messages: [])
        lastChecked = defaults.object(forKey: Keys.checked) as? Date
        refresh()
    }

    /// Asks whether the feed changed at most every quarter hour; an unchanged feed costs a 304 without a body.
    /// Between checks the saved copy decides (a message may have started).
    func check() async {
        guard !checking else { return }
        if let lastChecked, Date().timeIntervalSince(lastChecked) < Self.interval { refresh(); return }
        checking = true
        defer { checking = false }
        do {
            // The validator only counts with the saved copy it names.
            let known = defaults.data(forKey: Keys.feed) == nil ? nil
                : defaults.data(forKey: Keys.validator).flatMap { try? JSONDecoder().decode(MessageFeed.Validator.self, from: $0) }
            if case .changed(let fetched, let validator) = try await MessageFeed.fetch(address, ifChangedFrom: known) {
                feed = fetched
                defaults.set(try? JSONEncoder().encode(fetched), forKey: Keys.feed)
                defaults.set(try? JSONEncoder().encode(validator), forKey: Keys.validator)
            }
            lastChecked = Date()
            defaults.set(lastChecked, forKey: Keys.checked)
        } catch {
            Diagnostics.shared.record(.warning, "messages", "Message feed check failed: \(error.localizedDescription)")
        }
        refresh()
    }

    /// Records the message on screen as shown. The next one follows after a moment: an alert presented
    /// while the last one is still closing doesn't appear.
    func dismiss() {
        guard let message = current else { return }
        defaults.set(Array((seen + [message.id]).suffix(200)), forKey: Keys.seen)
        pending = []
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            refresh()
        }
    }

    private var seen: [String] { defaults.stringArray(forKey: Keys.seen) ?? [] }

    private func refresh() {
        let next = feed.pending(for: build, seen: Set(seen))
        if next != pending { pending = next }
    }

    private enum Keys {
        static let feed = "messages.feed"
        static let validator = "messages.validator"
        static let checked = "messages.lastChecked"
        static let seen = "messages.seen"
    }
}

extension View {
    /// Shows the next message in an alert, once nothing else is on screen.
    func announcementPresentation(_ announcements: Announcements, blocked: Bool) -> some View {
        modifier(AnnouncementAlert(announcements: announcements, blocked: blocked))
    }
}

private struct AnnouncementAlert: ViewModifier {
    let announcements: Announcements
    let blocked: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        let message = announcements.current
        content.alert(message?.title.text() ?? "", isPresented: Binding(get: { !blocked && message != nil }, set: { if !$0 { announcements.dismiss() } }),
                      presenting: message) { message in
            #if !os(tvOS)
            // Apple TV can't open web pages.
            if let link = message.link {
                Button(message.linkTitle?.text() ?? L10n.text("Learn More")) { openURL(link) }
            }
            #endif
            Button(L10n.text("OK"), role: .cancel) {}
        } message: { message in
            Text(message.body.text())
        }
    }
}
