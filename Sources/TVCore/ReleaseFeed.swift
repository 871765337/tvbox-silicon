import Foundation

/// Release announcements published with the website (`website/public/releases.json`).
/// The apps bundle a copy too, so "What's New" works offline right after an update.
public struct ReleaseFeed: Codable, Sendable, Equatable {
    public static let address = URL(string: "https://yingxia.getmegaportal.com/releases.json")!
    public var releases: [Release]
    public init(releases: [Release]) { self.releases = releases }

    public struct Release: Codable, Sendable, Equatable, Identifiable {
        public var version: String
        /// ISO date, e.g. "2026-10-09".
        public var date: String?
        /// Where to get this release, keyed by `ReleaseFeed.platform`, plus `ReleaseFeed.intelMacKey` for the Intel
        /// Mac package. A platform without a link did not get this release, so its users are not told about it.
        public var links: [String: URL]
        public var features: [Feature]
        public var id: String { version }
        public init(version: String, date: String? = nil, links: [String: URL], features: [Feature]) {
            self.version = version; self.date = date; self.links = links; self.features = features
        }
        /// Intel Macs get their own package; the `macos` link is the Apple silicon one.
        public func link(for platform: String = ReleaseFeed.platform, intelMac: Bool = ReleaseFeed.isIntelMac) -> URL? {
            links[platform == "macos" && intelMac ? ReleaseFeed.intelMacKey : platform]
        }
        /// The features that apply to `platform`.
        public func features(for platform: String = ReleaseFeed.platform) -> [Feature] {
            features.filter { $0.platforms?.contains(platform) ?? true }
        }
    }

    public struct Feature: Codable, Sendable, Hashable {
        /// SF Symbol name.
        public var symbol: String
        public var title: LocalizedText
        public var detail: LocalizedText
        /// Limits the feature to some platforms; nil means every platform.
        public var platforms: [String]?
        public init(symbol: String, title: LocalizedText, detail: LocalizedText, platforms: [String]? = nil) {
            self.symbol = symbol; self.title = title; self.detail = detail; self.platforms = platforms
        }
    }

    public static var platform: String {
        #if os(macOS)
        "macos"
        #elseif os(tvOS)
        "tvos"
        #else
        "ios"
        #endif
    }

    /// The key of the Intel Mac package in `Release.links` (from 1.7.3 on).
    public static let intelMacKey = "macos-x86_64"

    public static var isIntelMac: Bool {
        #if os(macOS) && arch(x86_64)
        true
        #else
        false
        #endif
    }

    /// Releases for `platform` newer than `version`, newest first.
    public func updates(after version: String, platform: String = ReleaseFeed.platform, intelMac: Bool = ReleaseFeed.isIntelMac) -> [Release] {
        let current = AppVersion(version)
        return newestFirst.filter { AppVersion($0.version) > current && $0.link(for: platform, intelMac: intelMac) != nil }
    }

    /// The releases someone skipped over when updating from `previous` to `current`, newest first.
    /// Without a previous version only the current release counts.
    public func whatsNew(since previous: String?, current: String, platform: String = ReleaseFeed.platform) -> [Release] {
        let now = AppVersion(current)
        return newestFirst.filter { release in
            let version = AppVersion(release.version)
            let skipped = previous.map { version > AppVersion($0) && version <= now } ?? (version == now)
            return skipped && !release.features(for: platform).isEmpty
        }
    }

    /// Entries from `newer` replace same-version entries here; the rest are kept.
    public func merged(with newer: ReleaseFeed) -> ReleaseFeed {
        let replaced = Set(newer.releases.map { AppVersion($0.version) })
        return ReleaseFeed(releases: newer.releases + releases.filter { !replaced.contains(AppVersion($0.version)) })
    }

    private var newestFirst: [Release] { releases.sorted { AppVersion($0.version) > AppVersion($1.version) } }

    public static func fetch(_ url: URL = address, session: URLSession = .shared) async throws -> ReleaseFeed {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw TVError.http(http.statusCode) }
        return try JSONDecoder().decode(ReleaseFeed.self, from: data)
    }
}

/// Text in several languages, keyed by the app's localization names ("en", "zh-Hans", ...).
/// A plain string in the feed counts as English.
public struct LocalizedText: Codable, Sendable, Hashable, ExpressibleByStringLiteral {
    public var values: [String: String]
    public init(_ values: [String: String]) { self.values = values }
    public init(stringLiteral value: String) { values = ["en": value] }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) { values = ["en": text] }
        else { values = try container.decode([String: String].self) }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
    /// The text in the app's current language, else English.
    public func text(language: String? = nil) -> String {
        values[L10n.resolvedLanguage(language)] ?? values["en"] ?? values.values.first ?? ""
    }
}

/// A dotted version number; missing parts count as zero, so 1.1 == 1.1.0.
public struct AppVersion: Comparable, Hashable, Sendable {
    public let parts: [Int]
    public init(_ text: String) {
        var parts = text.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        while parts.count > 1, parts.last == 0 { parts.removeLast() }
        self.parts = parts
    }
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}
