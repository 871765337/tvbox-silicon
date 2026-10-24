import Foundation
import Testing
@testable import TVCore

@Test func feedbackSendsTheTrimmedMessageWithTheAppsDetails() throws {
    let payload = Feedback.payload("  \n Freezes halfway \n", kind: .bug, install: "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0")
    let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: String])
    #expect(json["message"] == "Freezes halfway")
    #expect(json["kind"] == "bug")
    #expect(json["install"] == "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0")
    // The fields the server checks before it posts anything (Services/error-reports, /v1/feedback).
    #expect(["macos", "ios", "tvos"].contains(json["platform"] ?? ""))
    #expect(Set(json.keys) == ["install", "platform", "os", "model", "lang", "app", "build", "kind", "message"])
    #expect(Feedback.payload(String(repeating: "x", count: 9000), kind: .idea, install: "").message.count == Feedback.limit)
}

@Test func feedbackKindsMatchTheServersLabels() {
    #expect(Feedback.Kind.allCases.map(\.rawValue) == ["bug", "idea", "other"])
}

@Test func feedbackContextListsSubscriptionsAndRecentPlays() throws {
    let origin = try #require(URL(string: "https://example.com/tv.json"))
    let played = PlaybackHistoryContext(origin: origin, sourceKey: "lz", sourceName: "量子资源", videoID: "42",
                                        videoName: "庆余年", episodeID: "2", episodeName: "第2集", episodeFlag: "lzm3u8")
    let entry = PlaybackHistoryEntry(context: played, position: 754, duration: 3723, updatedAt: Date(timeIntervalSince1970: 1_792_843_200))
    let text = Feedback.context(subscriptions: [SubscriptionEntry(address: "https://example.com/tv.json", name: "Home"),
                                                SubscriptionEntry(address: "https://a.example/sub?token=abc&page=1", enabled: false)],
                                errors: ["https://example.com/tv.json": "Timed out"], history: [entry], timeZone: .gmt)
    #expect(text == """
    Subscriptions:
    - Home: https://example.com/tv.json
      - failed: Timed out
    - https://a.example/sub?token=***&page=1 (off)

    Recently played:
    - 庆余年 · 第2集, 量子资源 (lz), 12:34 / 1:02:03, 2026-10-24 12:00:00Z
    """)
    #expect(Feedback.context(subscriptions: [], history: []) == "Subscriptions:\n- none\n\nRecently played:\n- nothing")
}

@Test func feedbackMasksSignInsInAddresses() {
    #expect(Feedback.shareable("http://me:secret@host.example/a.json") == "http://***@host.example/a.json")
    #expect(Feedback.shareable("https://h.example/s?Key=1&sign=2&name=x") == "https://h.example/s?Key=***&sign=***&name=x")
    #expect(Feedback.shareable("file:///Users/someone/Documents/tv.json") == "file: tv.json")
    #expect(Feedback.shareable("not a url") == "not a url")
}

@Test func feedbackSendsTheMessageThenWhatIsLeftOfTheDetails() {
    #expect(Feedback.combined(" It stutters \n", context: "Subscriptions:\n- none\n") == "It stutters\n\nSubscriptions:\n- none")
    #expect(Feedback.combined("It stutters", context: " \n") == "It stutters")
}
