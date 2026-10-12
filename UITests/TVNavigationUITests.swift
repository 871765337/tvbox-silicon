#if os(tvOS)
import XCTest

/// Apple TV navigation with the Siri Remote against Scripts/qa-server.py (Scripts/test-tv-ui.sh).
final class TVNavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Back on a video page whose details are still loading returns to the source. With nothing
    /// focusable on the page, tvOS used to hand the press to the system, which left the app.
    func testBackWhileDetailsLoadReturnsToTheSource() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-qaSection", "sites", "-qaPage", "open-detail:qa-stall:1", "-qaIsolatedData", "1",
                               "-qaSubscription", "http://127.0.0.1:8776/stall-config.json",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let remote = XCUIRemote.shared
        let open = app.buttons["qa.open-detail"]
        XCTAssertTrue(open.waitForExistence(timeout: 60), "The QA page did not appear")
        // Focus starts in the tab sidebar on the left; move right into the page until Select opens the video.
        let loading = app.staticTexts["Loading video details…"]
        for _ in 0..<4 where !loading.exists {
            remote.press(.right); sleep(1)
            remote.press(.select)
            _ = loading.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(loading.exists, "The video page did not open")
        sleep(3)
        remote.press(.menu)
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground, "Back left the app")
        XCTAssertFalse(loading.exists, "Back did not leave the loading video page")
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Back did not return to the previous page")
    }
}
#endif
