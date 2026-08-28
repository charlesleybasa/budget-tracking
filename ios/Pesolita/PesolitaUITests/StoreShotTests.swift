import XCTest

/// Capture-only tests. They exist to produce App Store artwork, not to assert behaviour,
/// so they live apart from the real suite and are run explicitly by name.
final class StoreShotTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    /// Home in stack layout with five cards — the fullest the wallet looks.
    func testCaptureStackedWallet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet", "--showcase", "--layout=stack"]
        app.launch()

        XCTAssertTrue(app.buttons["log-spend-fab"].waitForExistence(timeout: 6))
        settle(1.2)
        capture("12-stacked-wallet")
    }

    /// Adds the widget to the Home Screen through Springboard, then photographs it there.
    /// Springboard's own UI is not ours and its labels move between releases, so every step
    /// is best-effort and the test reports what it managed rather than failing the build.
    func testCaptureWidgetOnHomeScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet", "--showcase"]
        app.launch()
        XCTAssertTrue(app.buttons["log-spend-fab"].waitForExistence(timeout: 6))
        settle(2.0)  // let the widget snapshot publish
        XCUIDevice.shared.press(.home)
        settle(1.5)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // Long-pressing the app icon offers "Add Widget" directly. This is a shorter path
        // than the widget gallery, whose result rows reject synthetic taps on iOS 26.
        let icon = springboard.icons["Pesolita"]
        if icon.waitForExistence(timeout: 5) {
            icon.press(forDuration: 1.4)
            settle(1.4)

            // Exact labels, read from Springboard's own tree. Two details cost several
            // attempts: the size button is "Medium-sized widget", not "Medium", and the
            // confirm button's label carries a leading space — " Add Widget" — so every
            // exact-match query for "Add Widget" silently found nothing.
            let tree = XCTAttachment(string: springboard.debugDescription)
            tree.name = "icon-menu-tree"
            tree.lifetime = .keepAlways
            add(tree)

            // Large, not medium: the medium size collapses the widget to icon-only
            // buttons, while the large one shows the card, the safe-to-spend figure and
            // labelled Spend / Top up — which is what the screenshot is meant to show.
            let large = springboard.buttons["Large widget"]
            if large.waitForExistence(timeout: 4), large.isHittable {
                large.tap()
            } else {
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.777, dy: 0.324)).tap()
            }
            settle(2.2)

            let confirm = springboard.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Add Widget'")
            ).firstMatch
            if confirm.waitForExistence(timeout: 5) {
                confirm.tap()
                settle(2.4)
            }

            if springboard.buttons["Done"].waitForExistence(timeout: 3) {
                springboard.buttons["Done"].tap()
                settle(1.8)
            }
        }

        capture("13-widget-home-screen")
        XCTAssertTrue(
            springboard.staticTexts["SAFE TODAY"].exists,
            "The widget is not on the Home Screen — the captured image would be unusable."
        )
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval) {
        let done = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }
}
