import Foundation

/// Feedback written in Settings, posted as an issue on the app's public GitHub repository by the
/// error-report server (Services/error-reports, /v1/feedback). The server holds the GitHub token, so
/// nobody needs a GitHub account. The issue is public: the message, the app and system versions, the
/// device model and the app's language. The install's random ID goes to the server only, which keeps
/// it with the issue number, so the developer can find the same install's error reports.
public enum Feedback {
    public enum Kind: String, CaseIterable, Sendable {
        case bug, idea, other
        public var title: String {
            switch self {
            case .bug: L10n.text("Problem")
            case .idea: L10n.text("Suggestion")
            case .other: L10n.text("Other")
            }
        }
    }

    public struct Issue: Decodable, Equatable, Sendable {
        public let number: Int
        public let url: URL
    }

    public enum Failure: LocalizedError, Equatable {
        /// The server's caps: a minute's, or the day's for this install or for everyone.
        case tooMany
        case failed
        public var errorDescription: String? {
            switch self {
            case .tooMany: L10n.text("You've sent a lot of feedback. Please try again later.")
            case .failed: L10n.text("Couldn't send feedback. Please try again later.")
            }
        }
    }

    /// Characters kept; the server cuts there too.
    public static let limit = 5000
    static let endpoint = URL(string: "https://yingxia-reports.getmegaportal.com/v1/feedback")!

    public static func send(_ message: String, kind: Kind, defaults: UserDefaults = .standard) async throws -> Issue {
        #if DEBUG
        // Debug builds and simulators only send with `-qaFeedback <url>` (e.g. a local `wrangler dev`).
        guard let address = defaults.string(forKey: "qaFeedback").flatMap(URL.init(string:)) else { throw Failure.failed }
        #else
        let address = endpoint
        #endif
        var request = URLRequest(url: address, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload(message, kind: kind, install: ErrorReports.shared.install))
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300:
            guard let issue = try? JSONDecoder().decode(Issue.self, from: data) else { throw Failure.failed }
            return issue
        case 429: throw Failure.tooMany
        default: throw Failure.failed
        }
    }

    struct Payload: Encodable {
        let install, platform, os, model, lang, app, build, kind, message: String
    }

    static func payload(_ message: String, kind: Kind, install: String) -> Payload {
        Payload(install: install, platform: ErrorReports.platform, os: ErrorReports.osVersion, model: ErrorReports.model,
                lang: L10n.resolvedLanguage(), app: ErrorReports.bundleValue("CFBundleShortVersionString"),
                build: ErrorReports.bundleValue("CFBundleVersion"), kind: kind.rawValue,
                message: String(message.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit)))
    }
}
