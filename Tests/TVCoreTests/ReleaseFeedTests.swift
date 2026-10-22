import Foundation
import Testing
@testable import TVCore

private func release(_ version: String, platforms: [String] = ["macos", "ios", "tvos"], features: [ReleaseFeed.Feature] = [
    .init(symbol: "sparkles", title: "New", detail: "Something new")
]) -> ReleaseFeed.Release {
    .init(version: version, links: Dictionary(uniqueKeysWithValues: platforms.map { ($0, URL(string: "https://example.com/\($0)")!) }), features: features)
}

@Test func versionsCompareNumerically() {
    #expect(AppVersion("1.0.1") > AppVersion("1.0"))
    #expect(AppVersion("1.10") > AppVersion("1.9.9"))
    #expect(AppVersion("1.1") == AppVersion("1.1.0"))
    #expect(AppVersion("2.0b3") > AppVersion("1.9"))
    #expect(!(AppVersion("1.0") < AppVersion("1.0.0")))
}

@Test func updatesListNewerReleasesForThisPlatformNewestFirst() {
    let feed = ReleaseFeed(releases: [release("1.0.1"), release("1.2", platforms: ["macos"]), release("1.1"), release("1.0")])
    #expect(feed.updates(after: "1.0.1", platform: "macos").map(\.version) == ["1.2", "1.1"])
    #expect(feed.updates(after: "1.0.1", platform: "tvos").map(\.version) == ["1.1"])
    #expect(feed.updates(after: "1.2", platform: "macos").isEmpty)
}

@Test func intelMacsUseTheirOwnPackageAndSkipReleasesWithoutOne() {
    let feed = ReleaseFeed(releases: [release("1.7.2"), release("1.7.3", platforms: ["macos", ReleaseFeed.intelMacKey])])
    #expect(feed.updates(after: "1.7.1", platform: "macos", intelMac: true).map(\.version) == ["1.7.3"])
    #expect(feed.updates(after: "1.7.1", platform: "macos", intelMac: false).map(\.version) == ["1.7.3", "1.7.2"])
    #expect(feed.releases[1].link(for: "macos", intelMac: true)?.absoluteString == "https://example.com/macos-x86_64")
    #expect(feed.releases[1].link(for: "macos", intelMac: false)?.absoluteString == "https://example.com/macos")
    #expect(feed.releases[1].link(for: "ios", intelMac: true) == nil)
}

@Test func whatsNewCoversSkippedReleasesWithFeatures() {
    let macOnly = ReleaseFeed.Feature(symbol: "macwindow", title: "Mac", detail: "Mac only", platforms: ["macos"])
    let feed = ReleaseFeed(releases: [release("1.0"), release("1.1"), release("1.2", features: [macOnly]), release("1.3"), release("1.4")])
    #expect(feed.whatsNew(since: "1.0", current: "1.3", platform: "macos").map(\.version) == ["1.3", "1.2", "1.1"])
    #expect(feed.whatsNew(since: "1.0", current: "1.3", platform: "ios").map(\.version) == ["1.3", "1.1"])
    #expect(feed.whatsNew(since: nil, current: "1.3", platform: "ios").map(\.version) == ["1.3"])
    #expect(feed.whatsNew(since: "1.3", current: "1.3", platform: "ios").isEmpty)
    #expect(feed.release("1.2").features(for: "tvos").isEmpty)
}

@Test func fetchedEntriesReplaceBundledOnes() {
    let bundled = ReleaseFeed(releases: [release("1.0"), release("1.1", features: [])])
    let fetched = ReleaseFeed(releases: [release("1.1.0"), release("1.2")])
    let merged = bundled.merged(with: fetched)
    #expect(merged.releases.map(\.version).sorted() == ["1.0", "1.1.0", "1.2"])
    #expect(merged.release("1.1").features.count == 1)
}

@Test func localizedTextFallsBackToEnglish() throws {
    let text = try JSONDecoder().decode(LocalizedText.self, from: Data(#"{"en": "New", "zh-Hans": "新"}"#.utf8))
    #expect(text.text(language: "zh-CN") == "新")
    #expect(text.text(language: "ja") == "New")
    #expect(try JSONDecoder().decode(LocalizedText.self, from: Data(#""Plain""#.utf8)).text(language: "ja") == "Plain")
}

/// Sparkle reads one appcast per Mac package; Scripts/make-appcast.sh writes them where the website publishes them.
@Test func eachMacPackageHasItsOwnPublishedAppcast() throws {
    let site = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../website/public")
    for intel in [false, true] {
        let address = ReleaseFeed.appcastAddress(intelMac: intel)
        #expect(address.lastPathComponent == (intel ? "macos-x86_64.xml" : "macos-arm64.xml"))
        let appcast = try String(contentsOf: site.appending(path: String(address.path.dropFirst())), encoding: .utf8)
        #expect(appcast.contains("<channel>"))
    }
}

/// The feed the website publishes and the apps bundle.
@Test func publishedFeedIsValidAndTranslated() throws {
    let file = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../website/public/releases.json")
    let feed = try JSONDecoder().decode(ReleaseFeed.self, from: Data(contentsOf: file))
    #expect(!feed.releases.isEmpty)
    #expect(Set(feed.releases.map { AppVersion($0.version) }).count == feed.releases.count)
    for entry in feed.releases {
        #expect(!entry.links.isEmpty, "\(entry.version) has no links")
        #expect(Set(entry.links.keys).isSubset(of: ["macos", ReleaseFeed.intelMacKey, "ios", "tvos"]), "\(entry.version) has an unknown platform")
        for feature in entry.features {
            for language in L10n.supportedLanguages {
                #expect(!(feature.title.values[language] ?? "").isEmpty, "\(entry.version) \(feature.symbol): no \(language) title")
                #expect(!(feature.detail.values[language] ?? "").isEmpty, "\(entry.version) \(feature.symbol): no \(language) detail")
            }
        }
    }
}

private extension ReleaseFeed {
    func release(_ version: String) -> Release { releases.first { AppVersion($0.version) == AppVersion(version) }! }
}
