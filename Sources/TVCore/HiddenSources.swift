import Foundation
import Observation

/// Subscription-qualified hides. The same key scheme as `PinnedSources`.
@MainActor @Observable public final class HiddenSources {
    private var keys: [String]
    private let defaults: UserDefaults
    private static let storageKey = "hiddenSources.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keys = defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    private func key(_ site: Site, origin: URL) -> String {
        EpisodeSkipSettings.scope(origin: site.origin(or: origin), source: site.sourceKey, video: "")
    }

    public func contains(_ site: Site, origin: URL) -> Bool { keys.contains(key(site, origin: origin)) }

    public func toggle(_ site: Site, origin: URL) {
        let key = key(site, origin: origin)
        if keys.contains(key) { keys.removeAll { $0 == key } } else { keys.append(key) }
        defaults.set(keys, forKey: Self.storageKey)
    }

    public func insert(_ site: Site, origin: URL) {
        let key = key(site, origin: origin)
        guard !keys.contains(key) else { return }
        keys.append(key)
        defaults.set(keys, forKey: Self.storageKey)
    }
}
