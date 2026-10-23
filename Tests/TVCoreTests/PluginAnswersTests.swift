import Foundation
import Testing
@testable import TVCore

@Test func emptyAnswersAreReportedOnlyAfterRecentContent() throws {
    let suite = "plugin-answers." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let answers = PluginAnswers(defaults: defaults)
    let now = Date(timeIntervalSince1970: 1_000_000)
    let content: [String: JSONValue] = ["class": .array([.object(["type_id": .string("1"), "type_name": .string("电影")])])]
    let videos: [String: JSONValue] = ["list": .array([.object(["vod_id": .string("v")])])]
    // A source that never had content stays quiet.
    #expect(answers.record(source: "wogg", params: [:], answer: [:], now: now) == nil)
    #expect(answers.record(source: "wogg", params: [:], answer: content, now: now) == nil)
    #expect(answers.record(source: "wogg", params: ["t": "1", "pg": "1"], answer: videos, now: now) == nil)
    #expect(answers.record(source: "wogg", params: [:], answer: [:], now: now.addingTimeInterval(3600)) == 3600)
    #expect(answers.record(source: "wogg", params: ["t": "1", "pg": "1"], answer: [:], now: now.addingTimeInterval(7200)) == 7200)
    // Only the source that had content, only recently, and only pages that can't be empty.
    #expect(answers.record(source: "other", params: [:], answer: [:], now: now) == nil)
    #expect(answers.record(source: "wogg", params: [:], answer: [:], now: now.addingTimeInterval(PluginAnswers.window + 1)) == nil)
    #expect(answers.record(source: "wogg", params: ["t": "1", "pg": "3"], answer: [:], now: now) == nil)
    #expect(answers.record(source: "wogg", params: ["wd": "x"], answer: [:], now: now) == nil)
    #expect(answers.record(source: "wogg", params: ["ids": "v"], answer: [:], now: now) == nil)
}

@Test func conversionFailuresNameTheClassAndRuntime() {
    let rejected: [String: JSONValue] = [
        "error": .string("java.lang.VerifyError: Bad type on operand stack\nException Details:\n  Location:\n    com/github/catvod/spider/Ddys.a()V @1: ireturn"),
        "errorCode": .string("class_conversion"), "brokenClass": .string("com.github.catvod.spider.Ddys"), "host": .string("host-v15"),
        "trace": .string("java.lang.VerifyError: Bad type on operand stack\n\tat java.base/java.lang.Class.forName0(Native Method)")]
    #expect(PluginFailure.message(rejected, language: "en") == "This plugin couldn't be prepared on this device (com.github.catvod.spider.Ddys could not be converted).")
    let lines = PluginFailure.diagnostic(source: "ddys", rejected, archive: String(repeating: "ab", count: 32)).split(separator: "\n")
    // The first line groups the report; the class is part of it, the host and archive are not.
    #expect(lines[0] == "source=ddys code=class_conversion java.lang.VerifyError: Bad type on operand stack brokenClass=com.github.catvod.spider.Ddys")
    #expect(lines[1] == "host=host-v15 archive=abababababab")
    #expect(lines[2] == "java.lang.VerifyError: Bad type on operand stack")
    #expect(ErrorReports.groupKey("jar.request", PluginFailure.diagnostic(source: "ddys", rejected, archive: "cd")) == ErrorReports.groupKey("jar.request", PluginFailure.diagnostic(source: "ddys", rejected)))
}
