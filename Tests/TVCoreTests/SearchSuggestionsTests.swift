import Foundation
import Testing
@testable import TVCore

/// Answers as iQiyi's suggestion service and 360kan's chart do, and records what was asked.
private final class SuggestionProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let host = request.url?.host() ?? ""
        let status = host == "suggest.video.iqiyi.com" || host == "api.web.360kan.com" ? 200 : 404
        let body = host == "suggest.video.iqiyi.com"
            ? #"{"code":0,"data":[{"name":"西游记"},{"name":" 西游记续集 "},{"name":"西游记"},{"name":""},{"aid":1}]}"#
            : #"{"errno":0,"data":[{"title":"开心锤锤"},{"title":"庆余年"}]}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SuggestionProtocol.self]
    return URLSession(configuration: configuration)
}

@Suite(.serialized) struct SearchSuggestionsTests {
    @Test func suggestionsAreTrimmedTitlesWithoutRepeats() async {
        SuggestionProtocol.requests = []
        let titles = await SearchSuggestions.titles(for: "  西游 ", session: session())
        #expect(titles == ["西游记", "西游记续集"])
        let asked = SuggestionProtocol.requests.first.flatMap { URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems }
        #expect(asked == [URLQueryItem(name: "if", value: "mobile"), URLQueryItem(name: "key", value: "西游")])
    }

    @Test func nothingTypedAsksNothing() async {
        SuggestionProtocol.requests = []
        #expect(await SearchSuggestions.titles(for: "  ", session: session()).isEmpty)
        #expect(SuggestionProtocol.requests.isEmpty)
    }

    @Test func trendingReadsTheChartsTitles() async {
        SuggestionProtocol.requests = []
        #expect(await SearchSuggestions.trending(session: session()) == ["开心锤锤", "庆余年"])
        #expect(SuggestionProtocol.requests.first?.value(forHTTPHeaderField: "Referer") == "https://www.360kan.com/rank/general")
    }

    @Test func anyOtherAnswerIsNoSuggestions() {
        #expect(SearchSuggestions.titles(in: Data("<html>".utf8), key: "name").isEmpty)
        #expect(SearchSuggestions.titles(in: Data(#"{"data":{"name":"x"}}"#.utf8), key: "name").isEmpty)
        let many = #"{"data":["# + (1...20).map { #"{"name":"t\#($0)"}"# }.joined(separator: ",") + "]}"
        #expect(SearchSuggestions.titles(in: Data(many.utf8), key: "name").count == SearchSuggestions.limit)
    }
}
