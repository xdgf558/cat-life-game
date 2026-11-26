import XCTest

final class CatLifeUITests: XCTestCase {
    @MainActor
    func testLaunchAndNavigateBetweenHomeAndWorkshop() {
        let app = XCUIApplication()
        app.launch()

        // Dismiss any queued photo reveal modal if an existing save triggered one
        let keepPhoto = app.buttons["photoKeepButton"]
        for _ in 0..<4 where keepPhoto.waitForExistence(timeout: 1.2) {
            keepPhoto.tap()
        }

        let catButton = app.descendants(matching: .any)["homeCatButton"]
        XCTAssertTrue(catButton.waitForExistence(timeout: 8))
        catButton.tap()
        attachScreenshot(named: "01-Home")

        let diaryButton = app.buttons["homeDiaryButton"]
        if diaryButton.waitForExistence(timeout: 1.5) {
            diaryButton.tap()
            sleep(1)
            attachScreenshot(named: "02-Diary")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        let shopButton = app.buttons["homeShopButton"]
        if shopButton.waitForExistence(timeout: 1.5) {
            shopButton.tap()
            sleep(1)
            attachScreenshot(named: "03-Shop")
            app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1).tap()
        }

        let workshopButton = app.buttons["homeWorkshopButton"]
        XCTAssertTrue(workshopButton.waitForExistence(timeout: 5))
        workshopButton.tap()

        let toybox = app.buttons["generator_cloth"]
        XCTAssertTrue(toybox.waitForExistence(timeout: 5))
        toybox.tap()
        sleep(1)
        attachScreenshot(named: "04-Workshop")

        let homeButton = app.buttons["workshopHomeButton"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 5))
        homeButton.tap()
        XCTAssertTrue(catButton.waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
