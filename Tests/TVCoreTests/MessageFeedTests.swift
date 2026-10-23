import Foundation
import Testing
@testable import TVCore

private let phone = MessageFeed.Build(platform: "ios", appStore: false, version: "1.7.9", number: 28)
private let testFlight = MessageFeed.Build(platform: "ios", appStore: true, version: "1.7.7", number: 27)
private let now = MessageFeed.Message.date("2026-10-24T12:00:00Z")!

private func message(_ id: String = "m", platforms: [String]? = nil, channels: [String]? = nil, minVersion: String? = nil,
                     maxVersion: String? = nil, minBuild: Int? = nil, maxBuild: Int? = nil, start: String? = nil,
                     end: String? = nil) -> MessageFeed.Message {
    .init(id: id, title: "Title", body: "Body", platforms: platforms, channels: channels, minVersion: minVersion,
          maxVersion: maxVersion, minBuild: minBuild, maxBuild: maxBuild, start: start, end: end)
}

@Test func messagesWithoutLimitsReachEveryBuild() {
    #expect(message().applies(to: phone, at: now))
    #expect(message().applies(to: testFlight, at: now))
}

@Test func messagesFollowPlatformAndChannel() {
    #expect(!message(platforms: ["tvos", "macos"]).applies(to: phone, at: now))
    #expect(message(platforms: ["ios"]).applies(to: phone, at: now))
    #expect(message(channels: ["appstore"]).applies(to: testFlight, at: now))
    #expect(!message(channels: ["appstore"]).applies(to: phone, at: now))
    #expect(message(channels: ["direct"]).applies(to: phone, at: now))
}

@Test func messagesFollowVersionAndBuildBounds() {
    #expect(message(minVersion: "1.7.9").applies(to: phone, at: now))
    #expect(!message(minVersion: "1.7.10").applies(to: phone, at: now))
    #expect(message(maxVersion: "1.7.9").applies(to: phone, at: now))
    #expect(!message(maxVersion: "1.7.8").applies(to: phone, at: now))
    // TestFlight builds share a version; the build number picks the broken one.
    #expect(message(maxBuild: 27).applies(to: testFlight, at: now))
    #expect(!message(maxBuild: 27).applies(to: phone, at: now))
    #expect(!message(minBuild: 28).applies(to: testFlight, at: now))
}

@Test func messagesShowBetweenStartAndEnd() {
    #expect(message(start: "2026-10-24").applies(to: phone, at: now))
    #expect(!message(start: "2026-10-25").applies(to: phone, at: now))
    // Noon UTC is 20:00 in Singapore; the end itself is past.
    #expect(message(end: "2026-10-24T20:01:00+08:00").applies(to: phone, at: now))
    #expect(!message(end: "2026-10-24T20:00:00+08:00").applies(to: phone, at: now))
    #expect(!message(start: "soon").applies(to: phone, at: now))
}

@Test func pendingSkipsShownMessagesAndKeepsFeedOrder() {
    let feed = MessageFeed(messages: [message("b"), message("a"), message("c", platforms: ["tvos"]), message("d")])
    #expect(feed.pending(for: phone, seen: ["a"], at: now).map(\.id) == ["b", "d"])
}

@Test func messagesDecodeFromTheFeedFormat() throws {
    let json = #"{"messages":[{"id":"x","title":{"en":"Hi","zh-Hans":"你好"},"body":"Plain","link":"https://example.com","maxBuild":27}]}"#
    let feed = try JSONDecoder().decode(MessageFeed.self, from: Data(json.utf8))
    #expect(feed.messages[0].title.text(language: "zh-Hans") == "你好")
    #expect(feed.messages[0].body.text(language: "ja") == "Plain")
    #expect(feed.messages[0].link?.host == "example.com")
    #expect(feed.messages[0].maxBuild == 27)
}

/// The published file: a mistake there would hide every message, so check what a test can.
@Test func websiteMessagesAreValid() throws {
    let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../website/public/messages.json")
    let feed = try JSONDecoder().decode(MessageFeed.self, from: Data(contentsOf: url))
    #expect(Set(feed.messages.map(\.id)).count == feed.messages.count, "message IDs must be unique")
    for message in feed.messages {
        #expect(!message.title.text(language: "en").isEmpty && !message.body.text(language: "en").isEmpty, "\(message.id): empty text")
        #expect(Set(message.platforms ?? []).isSubset(of: ["macos", "ios", "tvos"]), "\(message.id): unknown platform")
        #expect(Set(message.channels ?? []).isSubset(of: ["direct", "appstore"]), "\(message.id): unknown channel")
        for time in [message.start, message.end].compactMap({ $0 }) {
            #expect(MessageFeed.Message.date(time) != nil, "\(message.id): \(time) is not an ISO 8601 date")
        }
    }
}

/// Serves the feed with an ETag and answers 304 when it is sent back, as the website does.
private final class MessageServer: URLProtocol, @unchecked Sendable {
    static let etag = #"W/"v2""#
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let unchanged = request.value(forHTTPHeaderField: "If-None-Match") == Self.etag
        let response = HTTPURLResponse(url: request.url!, statusCode: unchanged ? 304 : 200, httpVersion: "HTTP/1.1", headerFields: ["ETag": Self.etag])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !unchanged { client?.urlProtocol(self, didLoad: Data(#"{"messages":[{"id":"x","title":"T","body":"B"}]}"#.utf8)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func fetchSendsTheValidatorBackAndSkipsAnUnchangedFeed() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MessageServer.self]
    let session = URLSession(configuration: config)
    let url = URL(string: "https://messages.test/messages.json")!
    let first = try await MessageFeed.fetch(url, session: session)
    guard case .changed(let feed, let validator) = first else { Issue.record("expected the feed, got \(first)"); return }
    #expect(feed.messages.map(\.id) == ["x"])
    #expect(validator.etag == MessageServer.etag)
    #expect(try await MessageFeed.fetch(url, ifChangedFrom: validator, session: session) == .unchanged)
    #expect(try await MessageFeed.fetch(url, ifChangedFrom: .init(etag: #"W/"v1""#), session: session) != .unchanged)
}
