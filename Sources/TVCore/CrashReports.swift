import Foundation
#if canImport(MetricKit) && !os(tvOS)
import MetricKit
#endif

/// Crashes and hangs on iPhone, iPad and Mac, from MetricKit, which hands them over on a later launch.
/// (tvOS has no MetricKit; ErrorReports notices an exit while on screen there instead.) Each becomes one
/// error for ErrorReports: what happened, then the crashed thread's frames as binary+offset, which
/// `atos` turns into code lines with that release's dSYM (build/release-*/<version>/dSYMs).
public final class CrashReports: NSObject, @unchecked Sendable {
    public static let shared = CrashReports()
    private var started = false

    func start() {
        #if canImport(MetricKit) && !os(tvOS)
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
        #endif
    }

    /// One (category, message) per crash or hang in a MetricKit diagnostic payload's JSON.
    static func summaries(_ json: Data, executable: String = Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "") -> [(category: String, message: String)] {
        guard let payload = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return [] }
        var found: [(String, String)] = []
        for crash in payload["crashDiagnostics"] as? [[String: Any]] ?? [] {
            let meta = crash["diagnosticMetaData"] as? [String: Any] ?? [:]
            let frames = Self.frames(crash["callStackTree"])
            let reason = meta["exceptionReason"] as? [String: Any]
            let kind = (reason?["exceptionName"] as? String) ?? Self.exception((meta["exceptionType"] as? NSNumber)?.intValue)
            var lines = ["crash \(kind) \(Self.signal((meta["signal"] as? NSNumber)?.intValue)) in \(Self.place(frames, executable: executable))"]
            if let message = reason?["composedMessage"] as? String { lines.append("reason: " + message) }
            if let termination = meta["terminationReason"] as? String { lines.append("termination: " + termination) }
            lines.append(Self.origin(meta))
            lines.append(contentsOf: frames.prefix(16))
            found.append(("crash", lines.joined(separator: "\n")))
        }
        for hang in payload["hangDiagnostics"] as? [[String: Any]] ?? [] {
            let meta = hang["diagnosticMetaData"] as? [String: Any] ?? [:]
            let frames = Self.frames(hang["callStackTree"])
            var lines = ["hang in \(Self.place(frames, executable: executable))"]
            lines.append("duration \(meta["hangDuration"] as? String ?? "-") " + Self.origin(meta))
            lines.append(contentsOf: frames.prefix(16))
            found.append(("hang", lines.joined(separator: "\n")))
        }
        return found
    }

    /// The version that crashed: payloads arrive on a later launch, maybe after an update.
    private static func origin(_ meta: [String: Any]) -> String {
        "app=\(meta["appVersion"] as? String ?? "-") (\(meta["appBuildVersion"] as? String ?? "-")) \(meta["platformArchitecture"] as? String ?? "")"
    }

    /// The first frame in the app's own binary: where a crash is usually fixed. It names the group.
    private static func place(_ frames: [String], executable: String) -> String {
        frames.first { !executable.isEmpty && $0.hasPrefix(executable + "+") } ?? frames.first ?? "-"
    }

    /// The attributed thread's frames, innermost first, as "binary+0xoffset".
    private static func frames(_ tree: Any?) -> [String] {
        let stacks = (tree as? [String: Any])?["callStacks"] as? [[String: Any]] ?? []
        let stack = stacks.first { $0["threadAttributed"] as? Bool == true } ?? stacks.first
        var frame = (stack?["callStackRootFrames"] as? [[String: Any]])?.first
        var result: [String] = []
        while let current = frame, result.count < 64 {
            let offset = (current["offsetIntoBinaryTextSegment"] as? NSNumber)?.uint64Value ?? 0
            result.append("\(current["binaryName"] as? String ?? "?")+0x\(String(offset, radix: 16))")
            frame = (current["subFrames"] as? [[String: Any]])?.first
        }
        return result
    }

    private static func exception(_ type: Int?) -> String {
        switch type {
        case 1: "EXC_BAD_ACCESS"
        case 2: "EXC_BAD_INSTRUCTION"
        case 3: "EXC_ARITHMETIC"
        case 5: "EXC_SOFTWARE"
        case 6: "EXC_BREAKPOINT"
        case 10: "EXC_CRASH"
        case 11: "EXC_RESOURCE"
        case 12: "EXC_GUARD"
        case let type?: "exception \(type)"
        case nil: "exception"
        }
    }

    private static func signal(_ number: Int?) -> String {
        switch number {
        case 4: "SIGILL"
        case 5: "SIGTRAP"
        case 6: "SIGABRT"
        case 9: "SIGKILL"
        case 10: "SIGBUS"
        case 11: "SIGSEGV"
        case let number?: "signal \(number)"
        case nil: ""
        }
    }
}

#if canImport(MetricKit) && !os(tvOS)
extension CrashReports: MXMetricManagerSubscriber {
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for summary in Self.summaries(payload.jsonRepresentation()) {
                Diagnostics.shared.record(.error, summary.category, summary.message)
            }
        }
    }
}
#endif
