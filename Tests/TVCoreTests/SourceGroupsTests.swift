import Foundation
import Testing
@testable import TVCore

private func source(_ key: String, hide: Bool = false) -> Site {
    var raw: [String: JSONValue] = ["key": .string(key), "searchable": .number(1)]
    if hide { raw["hide"] = .number(1) }
    return Site(key: key, name: key, type: 1, api: "https://api.example/" + key, raw: raw)
}

@Test func browsableSourcesSkipJsonHidesAndUserHides() {
    let sites = [source("a"), source("b", hide: true), source("c")]
    let listed = SourceLists.browsable(sites, jarURL: nil) { $0.key == "c" }
    #expect(listed.map(\.key) == ["a"])
}

@Test func searchEligibilitySkipsUserHidesAndCacheDropsThem() {
    let sites = [source("a"), source("b"), source("c", hide: true)]
    let eligible = SearchModel.eligible(sites, jarURL: nil) { $0.key == "b" }
    #expect(eligible.map(\.key) == ["a", "c"])
    let results = sites.map { SearchSourceResult(site: $0, page: nil, error: nil) }
    #expect(SearchModel.visible(results) { $0.key == "b" }.map(\.site.key) == ["a", "c"])
}

private func entry(_ address: String, name: String, enabled: Bool) -> SubscriptionEntry {
    SubscriptionEntry(address: address, name: name, enabled: enabled)
}

private func document(_ origin: String, keys: [String]) throws -> Subscription {
    let sites = keys.map { #"{"key":"\#($0)","name":"\#($0)","type":1,"api":"https://api.example/\#($0)"}"# }.joined(separator: ",")
    return try Subscription.parse(Data(#"{"sites":[\#(sites)]}"#.utf8), origin: URL(string: origin)!)
}

@Test func groupsPutPinsAndBuiltInsAboveSubscriptions() throws {
    let first = try document("https://one.example/a.json", keys: ["show", "secret"])
    let second = try document("https://two.example/b.json", keys: ["other"])
    let entries = [
        entry("https://one.example/a.json", name: "One", enabled: true),
        entry("https://off.example/c.json", name: "Off", enabled: false),
        entry("https://two.example/b.json", name: "Two", enabled: true),
    ]
    var show = first.sites[0]
    show.provenance = SourceProvenance(origin: first.origin, spider: nil)
    var secret = first.sites[1]
    secret.provenance = SourceProvenance(origin: first.origin, spider: nil)
    let documents = [
        "https://one.example/a.json": Subscription(origin: first.origin, importedAt: first.importedAt, sites: [show, secret], lives: [], raw: first.raw),
        "https://two.example/b.json": second,
    ]
    let hidden = SourceGroups.make(entries: entries, documents: documents, builtIns: [], builtInOrigin: first.origin, pinOrder: [secret], userHidden: { $0.key == "other" }, includeHidden: false, jarURL: nil)
    #expect(hidden.map(\.id) == ["pinned", "https://one.example/a.json"])
    #expect(hidden[0].sites.map(\.key) == ["secret"])
    #expect(hidden[1].sites.map(\.key) == ["show"])
    let shown = SourceGroups.make(entries: entries, documents: documents, builtIns: [], builtInOrigin: first.origin, pinOrder: [secret], userHidden: { $0.key == "other" }, includeHidden: true, jarURL: nil)
    #expect(shown.map(\.id) == ["pinned", "https://one.example/a.json", "https://two.example/b.json"])
}

@Test func draggingAVisibleSubscriptionLeavesTheHiddenSlot() {
    let entries = [
        entry("jia", name: "Jia", enabled: true),
        entry("yi", name: "Yi", enabled: false),
        entry("bing", name: "Bing", enabled: true),
    ]
    let moved = SubscriptionOrder.applying(displayed: ["bing", "jia"], to: entries)
    #expect(moved.map(\.address) == ["bing", "yi", "jia"])
    #expect(moved.map(\.name) == ["Bing", "Yi", "Jia"])
}
