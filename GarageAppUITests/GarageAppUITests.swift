//
//  Created by Doğa Erdemir on 12.07.2026.
//

import XCTest

final class GarageAppUITests: XCTestCase {
    func testTabBarContainsFiveSections() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertEqual(app.tabBars.buttons.count, 5)
    }

    func testOnboardingReachesFirstVehicleAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Araç geçmişiniz tek yerde"].waitForExistence(timeout: 5))
        app.buttons["Devam"].tap()
        XCTAssertTrue(app.staticTexts["Önemli tarihleri kaçırmayın"].waitForExistence(timeout: 2))
        app.buttons["Devam"].tap()
        XCTAssertTrue(app.buttons["İlk Aracımı Ekle"].waitForExistence(timeout: 2))
    }

    func testCreateVehicleAndMaintenanceRecordFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingOnboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["Devam"].waitForExistence(timeout: 5))
        app.buttons["Devam"].tap()
        app.buttons["Devam"].tap()
        app.buttons["İlk Aracımı Ekle"].tap()

        let nickname = app.textFields["Araç adı"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 3))
        nickname.tap(); nickname.typeText("Test Aracı")
        let make = app.buttons["Marka"]
        XCTAssertTrue(make.waitForExistence(timeout: 3))
        make.tap()
        app.buttons["Toyota"].tap()
        let model = app.buttons["Model"]
        model.tap()
        app.buttons["Corolla"].tap()
        app.buttons["Yıl"].tap()
        app.buttons[String(Calendar.current.component(.year, from: .now))].tap()
        app.navigationBars["Araç Ekle"].buttons["Kaydet"].tap()

        XCTAssertTrue(app.buttons["Bakım"].waitForExistence(timeout: 5))
        app.buttons["Bakım"].tap()
        let title = app.textFields["Başlık"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap(); title.typeText("Periyodik Bakım")
        app.navigationBars["Bakım Ekle"].buttons["Kaydet"].tap()

        XCTAssertTrue(app.buttons["Periyodik Bakım"].waitForExistence(timeout: 5))
    }
}
