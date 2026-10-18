import Foundation
import Testing
@testable import TVCore

@Test func errorReportsKeepOnlyHostsAndDropPersonalPaths() {
    let scrubbed = ErrorReports.scrub("failed https://user:pw@cdn.example.com:8443/token/abc/movie.m3u8 and rtmp://live.example.org/app/key "
        + "at /Users/alice/Library/x.json, /var/mobile/Containers/Data/Application/0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0/tmp, "
        + "nas 192.168.1.20:5000, proxy 127.0.0.1")
    #expect(scrubbed == "failed https://cdn.example.com:8443 and rtmp://live.example.org at ~/Library/x.json, ~/tmp, nas <lan>:5000, proxy 127.0.0.1")
    #expect(ErrorReports.scrub(String(repeating: "x", count: 3000)).count == 1000)
}

@Test func errorReportsGroupOneBugAcrossVaryingDetails() {
    let a = ErrorReports.groupKey("cloud.stream", "chunk=12 status=503 bytes=0")
    let b = ErrorReports.groupKey("cloud.stream", "chunk=40 status=503 bytes=1024\nstack line")
    #expect(a == b)
    #expect(a != ErrorReports.groupKey("player", "chunk=12 status=503 bytes=0"))
    #expect(ErrorReports.groupKey("x", "id 9f86d081884c7d65 done") == ErrorReports.groupKey("x", "id 0a1b2c3d4e5f6a7b done"))
}

@Test func errorReportsCollectOnlyErrorsAfterStartAndForgetWhenOff() async throws {
    let suite = "error-reports-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    defer { try? FileManager.default.removeItem(at: directory) }
    let reports = ErrorReports(defaults: defaults, directory: directory)
    let entry = { (level: LogLevel, message: String) in LogEntry(id: UUID(), date: Date(), level: level, category: "jar.timeout", message: message) }

    reports.collect([entry(.error, "before start")])
    await reports.start()  // no `qaErrorReports`, so a debug build never sends
    reports.collect([entry(.error, "timeout seconds=30"), entry(.error, "timeout seconds=45"), entry(.warning, "slow")])
    reports.save()
    let saved = try JSONDecoder().decode([String: ErrorReports.Group].self, from: Data(contentsOf: directory.appendingPathComponent("error-reports.json")))
    #expect(saved.count == 1)
    #expect(saved.values.first?.count == 2)
    #expect(saved.values.first?.message == "timeout seconds=45")

    defaults.set(false, forKey: ErrorReports.key)
    await reports.sendIfDue()
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("error-reports.json").path))
}

@Test func errorReportsKeepCodesApartAndVaryingNumbersTogether() {
    let key = { ErrorReports.groupKey("player", $0) }
    #expect(key("failed error=NSURLErrorDomain -1001: timed out") != key("failed error=NSURLErrorDomain -1009: offline"))
    #expect(key("chunk=3 status=403 bytes=0") != key("chunk=3 status=500 bytes=0"))
    #expect(key("source=a complete duration=1.25 seconds bytes=88123") == key("source=a complete duration=12.5 seconds bytes=7"))
    #expect(key("interrupted at=1834s log=-12938 CoreMediaErrorDomain") == key("interrupted at=7s log=-12938 CoreMediaErrorDomain"))
    #expect(key("rooms page=2 at 1760000000") == key("rooms page=9 at 1760500000"))
    #expect(key("crash EXC_BAD_ACCESS SIGSEGV in Yingxia+0x1a2b3c") != key("crash EXC_BAD_ACCESS SIGSEGV in Yingxia+0x1a2b40"))
}

@Test func crashReportsSummarizeTheCrashedThread() throws {
    let json = """
    {"crashDiagnostics": [{"callStackTree": {"callStackPerThread": true, "callStacks": [
        {"threadAttributed": false, "callStackRootFrames": [{"binaryName": "libsystem_kernel.dylib", "offsetIntoBinaryTextSegment": 4096}]},
        {"threadAttributed": true, "callStackRootFrames": [{"binaryName": "libswiftCore.dylib", "offsetIntoBinaryTextSegment": 255,
            "subFrames": [{"binaryName": "Yingxia", "offsetIntoBinaryTextSegment": 1715004,
                "subFrames": [{"binaryName": "SwiftUI", "offsetIntoBinaryTextSegment": 16}]}]}]}]},
      "diagnosticMetaData": {"appVersion": "1.6.5", "appBuildVersion": "16", "exceptionType": 6, "signal": 5,
        "platformArchitecture": "arm64e", "terminationReason": "Namespace SIGNAL, Code 5"}}],
     "hangDiagnostics": [{"callStackTree": {"callStacks": [{"threadAttributed": true, "callStackRootFrames": [
        {"binaryName": "libsystem_kernel.dylib", "offsetIntoBinaryTextSegment": 1, "subFrames": [{"binaryName": "Yingxia", "offsetIntoBinaryTextSegment": 32}]}]}]},
      "diagnosticMetaData": {"hangDuration": "3.5 sec", "appVersion": "1.6.5", "appBuildVersion": "16"}}]}
    """
    let found = CrashReports.summaries(Data(json.utf8), executable: "Yingxia")
    try #require(found.count == 2)
    #expect(found[0].category == "crash")
    #expect(found[0].message == """
        crash EXC_BREAKPOINT SIGTRAP in Yingxia+0x1a2b3c
        termination: Namespace SIGNAL, Code 5
        app=1.6.5 (16) arm64e
        libswiftCore.dylib+0xff
        Yingxia+0x1a2b3c
        SwiftUI+0x10
        """)
    #expect(found[1].category == "hang")
    #expect(found[1].message.hasPrefix("hang in Yingxia+0x20\nduration 3.5 sec app=1.6.5 (16) "))
    #expect(CrashReports.summaries(Data("{}".utf8)).isEmpty)
}

/// The server's `normalize` (Services/error-reports/src/index.ts) gives these same lines: it groups
/// reports from every install by them.
@Test func errorReportsGroupLikeTheServer() {
    let expected = [
        "source=a complete duration=1.25 seconds bytes=88123": "source=a complete duration=# seconds bytes=#",
        "interrupted at=1834s log=-12938 CoreMediaErrorDomain": "interrupted at=#s log=-12938 CoreMediaErrorDomain",
        "rooms page=2 at 1760000000": "rooms page=# at #",
        "id 0a1b2c3d4e5f6a7b done 0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0": "id <id> done <id>",
        "hang in X\nmore": "hang in X",
        "timeout seconds=60 stage=startup": "timeout seconds=# stage=startup",
        "Quit unexpectedly while on screen (low on memory, during playback)\nmemory: footprint=812MB available=40MB":
            "Quit unexpectedly while on screen (low on memory, during playback)",
    ]
    for (message, line) in expected { #expect(ErrorReports.groupKey("c", message) == "c\n" + line) }
}

@Test func quitReportsSayWhyALaunchEndedOnScreen() throws {
    let playback = QuitContext.Playback(live: false, format: "m3u8", source: "csp_Test", since: 1_000, danmaku: true, sharper: false)
    let squeezed = QuitContext(launch: "a", started: 0, saved: 3_040, footprint: 812, available: 300, pressure: 3_020, pressureLevel: "critical", playback: playback)
    let report = try #require(QuitContext.report(squeezed, bootTime: 0))
    #expect(report == """
        Quit unexpectedly while on screen (low on memory, during playback)
        memory: footprint=812MB available=300MB pressure=critical 20s before the last sample
        playing: vod format=m3u8 source=csp_Test for=34min danmaku=on sharper=off
        launched 50min before the last sample (taken every 30s on screen)
        """)

    // Little memory left counts too; pressure long before the end does not.
    var nearlyOut = squeezed; nearlyOut.pressure = nil; nearlyOut.available = 40
    #expect(QuitContext.report(nearlyOut, bootTime: 0)?.hasPrefix("Quit unexpectedly while on screen (low on memory, during playback)\n") == true)
    var browsing = squeezed; browsing.pressure = 2_000; browsing.playback = nil
    #expect(QuitContext.report(browsing, bootTime: 0)?.hasPrefix("Quit unexpectedly while on screen (not low on memory, browsing)\n") == true)

    // The device started up after the last sample: a restart, not a crash.
    #expect(QuitContext.report(squeezed, bootTime: 3_041) == nil)
    #expect(QuitContext.report(nil, bootTime: 3_041) == QuitContext.unknown)

    // One group per cause, whatever the numbers.
    var other = squeezed; other.footprint = 1_500; other.pressure = 9_990; other.saved = 9_999
    #expect(ErrorReports.groupKey("app", report) == ErrorReports.groupKey("app", QuitContext.report(other, bootTime: 0)!))
    #expect(ErrorReports.groupKey("app", report) != ErrorReports.groupKey("app", QuitContext.report(browsing, bootTime: 0)!))
}

@Test func quitContextReadsThisDevice() {
    let now = Int(Date().timeIntervalSince1970)
    #expect(ErrorReports.bootTime > 0 && ErrorReports.bootTime < now)
    #expect((ErrorReports.memory().footprint ?? 0) > 0)
}
