import XCTest

@MainActor
final class PesolitaUITests: XCTestCase {
    func testCoreMoneyJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-wallet"]
        app.launch()

        capture("01-onboarding-intro")

        app.buttons["Let's make your first card"].tap()
        let name = app.textFields["Your name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Rli")
        app.buttons["onboarding-name-continue"].tap()

        let debit = app.buttons["kind-ATM / Debit"]
        XCTAssertTrue(debit.waitForExistence(timeout: 3))
        debit.tap()
        settleTransition()
        capture("02-template-picker")
        app.buttons["Use this template"].tap()

        let balance = app.textFields["onboarding-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 3))
        balance.tap()
        balance.typeText("1000")
        XCTAssertEqual(balance.value as? String, "1,000", "Typed amounts should group thousands")
        capture("03-funding")
        app.buttons["create-card"].tap()

        let logSpend = app.buttons["log-spend-fab"]
        XCTAssertTrue(logSpend.waitForExistence(timeout: 4))
        settleTransition()
        capture("04-home")
        logSpend.tap()
        XCTAssertTrue(app.staticTexts["Log a spend"].waitForExistence(timeout: 3))
        settleTransition()
        capture("05-spend-sheet")
        app.buttons["1"].tap()
        app.buttons["0"].tap()
        app.buttons["0"].tap()
        app.buttons["submit-transaction"].tap()

        XCTAssertTrue(app.staticTexts["Logged it."].waitForExistence(timeout: 4))
        capture("06-logged-success")
        app.buttons["close-success"].tap()
        XCTAssertTrue(app.staticTexts["Recent activity"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["−₱100.00"].exists)
        capture("07-home-with-activity")
    }

    func testCompletedAppSurfacesAreReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet"]
        app.launch()

        XCTAssertTrue(app.buttons["wallet-card-card_everyday"].waitForExistence(timeout: 4))

        app.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Insights"].waitForExistence(timeout: 3))

        app.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["Find a transaction"].waitForExistence(timeout: 3))

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["--demo-wallet", "--route=detail"]
        app.launch()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Top up"].exists)

        app.terminate()
        app.launchArguments = ["--demo-wallet", "--route=transfer"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Move money"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Pick where from and where to"].exists)

        app.terminate()
        app.launchArguments = ["--demo-wallet", "--route=editor"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Redesign card"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["card-editor-preview"].exists)
    }

    func testBackupAndRestorePickersOpen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet", "--tab=settings"]
        app.launch()

        let backup = app.buttons["backup-wallet"]
        scrollUntilHittable(backup, in: app)
        backup.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))
        // The iOS 26 Files exporter has no exposed Cancel control. Relaunching keeps
        // this regression test focused on presentation rather than Files-app chrome.
        app.terminate()
        app.launch()

        let restore = app.buttons["restore-wallet"]
        scrollUntilHittable(restore, in: app)
        restore.tap()
        XCTAssertTrue(
            app.buttons["Open"].waitForExistence(timeout: 5)
                || app.buttons["Cancel"].exists
                || app.navigationBars["Browse"].exists
                || app.navigationBars["Recents"].exists
                || app.staticTexts["Browse"].exists
                || app.staticTexts["Recents"].exists
        )
        app.terminate()
    }

    /// Amounts are typed on a custom keypad, so grouping has to be applied to the draft
    /// string as it grows — a formatter that only runs on the saved value would leave the
    /// user staring at "15000" while entering it.
    func testKeypadAmountsGroupThousands() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet"]
        app.launch()

        let spend = app.buttons["log-spend-fab"]
        XCTAssertTrue(spend.waitForExistence(timeout: 4))
        spend.tap()
        XCTAssertTrue(app.staticTexts["Log a spend"].waitForExistence(timeout: 3))

        for key in ["1", "5", "0", "0", "0"] { app.buttons[key].tap() }
        XCTAssertTrue(app.staticTexts["15,000"].waitForExistence(timeout: 3))
        capture("11-grouped-amount")

        app.buttons["."].tap()
        app.buttons["5"].tap()
        XCTAssertTrue(app.staticTexts["15,000.5"].exists, "A half-typed decimal must survive grouping")
    }

    func testTransactionCardChangingMatchesWebFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-wallet", "--route=detail"]
        app.launch()

        let topUp = app.buttons["Top up"]
        XCTAssertTrue(topUp.waitForExistence(timeout: 4))
        topUp.tap()

        let sourcePicker = app.buttons["money-card-picker-source"]
        XCTAssertTrue(sourcePicker.waitForExistence(timeout: 3))
        sourcePicker.tap()
        XCTAssertTrue(app.staticTexts["Top up into"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["money-card-option-card_everyday"].exists)
        XCTAssertTrue(app.buttons["money-card-option-card_cash"].exists)
        capture("08-top-up-card-picker")
        app.buttons["money-card-option-card_cash"].tap()

        app.buttons["Spend"].tap()
        sourcePicker.tap()
        XCTAssertTrue(app.staticTexts["Spend out of"].waitForExistence(timeout: 3))
        app.buttons["money-card-option-card_everyday"].tap()

        app.buttons["Move"].tap()
        XCTAssertTrue(app.buttons["money-card-picker-destination"].waitForExistence(timeout: 3))
        app.buttons["money-card-picker-destination"].tap()
        XCTAssertTrue(app.staticTexts["Move it into"].waitForExistence(timeout: 3))
        let otherSide = app.buttons["money-card-option-card_everyday"]
        XCTAssertTrue(otherSide.exists)
        XCTAssertFalse(otherSide.isEnabled)
        XCTAssertEqual(otherSide.value as? String, "Already the other side of this move")
        capture("09-move-destination-card-picker")

        app.terminate()
        app.launchArguments = ["--demo-wallet", "--route=transfer"]
        app.launch()
        let transferSource = app.buttons["money-card-picker-source"]
        XCTAssertTrue(transferSource.waitForExistence(timeout: 4))
        transferSource.tap()
        XCTAssertTrue(app.staticTexts["Move money from"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["money-card-option-card_wallet"].isEnabled)
        capture("10-full-move-card-picker")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settleTransition() {
        let settled = expectation(description: "The interface transition settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
