import Foundation
import Testing
@testable import TVCore

private let origin = URL(string: "https://one.example/a.json")!
private func source(_ key: String) -> Site {
    Site(key: key, name: key, type: 1, api: "https://api.example/" + key, raw: ["key": .string(key)])
}

@Test @MainActor func hiddenSourcesPersistAndStayQualifiedBySubscription() throws {
    let suite = "hidden." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let site = source("a")
    let hidden = HiddenSources(defaults: defaults)
    #expect(!hidden.contains(site, origin: origin))
    hidden.toggle(site, origin: origin)
    #expect(hidden.contains(site, origin: origin))
    #expect(HiddenSources(defaults: defaults).contains(site, origin: origin))
    #expect(!hidden.contains(site, origin: URL(string: "https://other.example/a.json")!))
    hidden.toggle(site, origin: origin)
    #expect(!hidden.contains(site, origin: origin))
    hidden.insert(site, origin: origin)
    hidden.insert(site, origin: origin)
    #expect(hidden.contains(site, origin: origin))
}
