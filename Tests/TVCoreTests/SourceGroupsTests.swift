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
