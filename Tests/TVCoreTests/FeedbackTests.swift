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
