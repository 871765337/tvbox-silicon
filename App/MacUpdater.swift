#if os(macOS)
import AppKit
import Sparkle
import TVCore

/// Installs Mac updates in place with Sparkle and relaunches. The release feed (`Updates`) still decides
/// what to announce and shows the sheet; this downloads, checks and swaps the app. Sparkle reads an appcast
/// made at release time from the notarized DMGs (Scripts/make-appcast.sh) and only installs an update
/// signed with the EdDSA key in Info.plist and by the same Developer ID as this app.
///
/// With automatic installs on (the default), Sparkle downloads new versions in the background and puts them
/// in place when the app quits; the sheet's button then just relaunches.
@MainActor @Observable final class MacUpdater: NSObject {
    enum Phase: Equatable {
        case idle
        case checking
        /// Bytes so far and in all; `expected` is 0 until the server says.
        case downloading(received: UInt64, expected: UInt64)
        case preparing
        /// Downloaded and checked: it goes in when the app quits, or now with `install()`.
        case ready
        case installing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Downloads updates in the background and installs them on quit.
    var automaticallyInstalls: Bool {
        didSet { if updater.automaticallyDownloadsUpdates != automaticallyInstalls { updater.automaticallyDownloadsUpdates = automaticallyInstalls } }
    }
    var canCancel: Bool { cancellation != nil }

    @ObservationIgnored private var updater: SPUUpdater!
    @ObservationIgnored private let feed: URL
    /// Someone pressed Install: say yes to each of Sparkle's questions until the app relaunches.
    @ObservationIgnored private var installRequested = false
    @ObservationIgnored private var cancellation: (() -> Void)?
    /// Installs an update Sparkle downloaded on its own, without asking again.
    @ObservationIgnored private var installNow: (() -> Void)?
    /// Closes the release sheet: macOS doesn't quit an app while a sheet is open, so the relaunch waits for it.
    @ObservationIgnored var closeSheet: (() -> Void)?
    @ObservationIgnored private var terminationRetries = 0

    /// Nil in App Store builds, which the App Store updates, and in debug builds, whose update would replace
    /// the build in DerivedData (QA: `-qaAppcast <url>`).
    static func make(defaults: UserDefaults = .standard) -> MacUpdater? {
        guard !Distribution.isAppStore else { return nil }
        #if DEBUG
        guard let value = defaults.string(forKey: "qaAppcast"), let url = URL(string: value) else { return nil }
        let updater = MacUpdater(feed: url)
        // `-qaInstallUpdate 1` presses Install and Relaunch a few seconds after launch.
        if defaults.bool(forKey: "qaInstallUpdate") { Task { try? await Task.sleep(for: .seconds(4)); updater.install() } }
        return updater
        #else
        return MacUpdater(feed: ReleaseFeed.appcastAddress)
        #endif
    }

    private init(feed: URL) {
        self.feed = feed
        automaticallyInstalls = true
        super.init()
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
        do { try updater.start() } catch {
            Diagnostics.shared.record(.warning, "updates", "Updater didn't start: \(error.localizedDescription)")
        }
        automaticallyInstalls = updater.automaticallyDownloadsUpdates
    }

    /// Downloads the newest version if needed, installs it and relaunches.
    func install() {
        switch phase {
        case .checking, .downloading, .preparing, .installing: return
        case .idle, .ready, .failed: break
        }
        installRequested = true
        if let installNow {
            phase = .installing
            installNow()
            return
        }
        // A background download that is still running can't be shown or restarted; it installs as soon as it lands.
        guard updater.canCheckForUpdates else { phase = .preparing; return }
        phase = .checking
        updater.checkForUpdates()
    }

    func cancel() {
        let cancellation = cancellation
        self.cancellation = nil
        installRequested = false
        phase = .idle
        cancellation?()
    }

    /// Forgets a failure once its message has been seen.
    func clearFailure() { if case .failed = phase { phase = installNow == nil ? .idle : .ready } }

    private func fail(_ message: String, _ error: (any Error)? = nil) {
        installRequested = false
        cancellation = nil
        phase = .failed(message)
        Diagnostics.shared.record(.warning, "updates", "Update install failed: \(error.map(Self.detail) ?? message)")
    }

    /// The error with its code and causes: Sparkle's own messages are general ("An error occurred in retrieving
    /// update information"), the reason is underneath.
    private static func detail(_ error: any Error) -> String {
        var parts: [String] = []
        var next: NSError? = error as NSError
        while let error = next, parts.count < 4 {
            parts.append("\(error.domain) \(error.code): \(error.localizedDescription)")
            next = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return parts.joined(separator: " <- ")
    }
}

extension MacUpdater: SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // Info.plist turns automatic checks on, so Sparkle shouldn't ask; if it does, the answer is yes.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
        phase = .checking
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if installRequested { reply(.install); return }
        // A scheduled check with automatic installs off: the release sheet already tells people. A download
        // made earlier stays and goes in on quit.
        if state.stage != .notDownloaded { phase = .ready }
        reply(.dismiss)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        // The release feed announced a version this appcast doesn't have (yet), e.g. one built before Sparkle.
        if installRequested { fail(L10n.text("This update can't be installed from within Yingxia yet. Download it instead."), error) }
        else { phase = .idle }
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        if installRequested { fail(L10n.text("The update couldn't be installed: %@", error.localizedDescription), error) }
        else {
            Diagnostics.shared.record(.warning, "updates", "Background update failed: \(Self.detail(error))")
            if phase != .ready { phase = .idle }
        }
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
        phase = .downloading(received: 0, expected: 0)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        phase = .downloading(received: 0, expected: expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        if case .downloading(let received, let expected) = phase { phase = .downloading(received: received + length, expected: expected) }
    }

    func showDownloadDidStartExtractingUpdate() {
        cancellation = nil
        phase = .preparing
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if installRequested {
            phase = .installing
            reply(.install)
        } else {
            // Installs on quit; Install later resumes it through checkForUpdates.
            phase = .ready
            reply(.dismiss)
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        phase = .installing
        // The app refused to quit, as it does while a sheet is open (the release sheet, where Install was pressed):
        // close the sheets and ask again. Should something else keep it open, the update still goes in on quit.
        guard !applicationTerminated, terminationRetries < 3 else { return }
        terminationRetries += 1
        closeSheet?()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            retryTerminatingApplication()
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {}

    func dismissUpdateInstallation() {
        cancellation = nil
        switch phase {
        case .checking, .downloading, .preparing, .installing:
            installRequested = false
            phase = .idle
        case .idle, .ready, .failed: break
        }
    }
}

extension MacUpdater: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? { feed.absoluteString }

    /// A background download finished. Keep the handler so Install relaunches right away instead of
    /// waiting for the next quit.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        installNow = immediateInstallHandler
        cancellation = nil
        if installRequested {
            phase = .installing
            Task { immediateInstallHandler() }
        } else {
            phase = .ready
        }
        Diagnostics.shared.record(.info, "updates", "Update \(item.displayVersionString) downloaded; installs on quit")
        return true
    }

    /// A check or download that ended without telling the user driver, such as the background download Install was
    /// waiting for (Sparkle doesn't start a second session while one runs).
    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        guard installRequested else { return }
        fail(L10n.text("The update couldn't be installed: %@", error.localizedDescription), error)
    }
}
#endif
