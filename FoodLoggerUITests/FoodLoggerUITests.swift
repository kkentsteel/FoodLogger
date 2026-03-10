import XCTest

final class FoodLoggerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
