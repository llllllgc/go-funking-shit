import XCTest

/// Run only through tool/test_ios_ui.sh, which creates a fresh simulator.
/// Uses the ordinary app entry point and real storage; all records are synthetic.
final class RunnerUITests: XCTestCase {
  private let app = XCUIApplication(bundleIdentifier: "com.lalema.lalema")

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    app.launch()
  }

  override func tearDownWithError() throws {
    if let run = testRun, run.failureCount > 0 {
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.lifetime = .keepAlways
      add(screenshot)
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Failure accessibility hierarchy (synthetic data only)"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    app.terminate()
  }

  func testNormalRecordPersistsAcrossRestart() throws {
    let record = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "记录一次")).firstMatch
    XCTAssertTrue(record.waitForExistence(timeout: 30), app.debugDescription)
    XCTAssertFalse(app.buttons["修改"].exists, "This test requires a fresh simulator with no existing records.")
    record.tap()
    let type = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "光滑柔软")).firstMatch
    XCTAssertTrue(type.waitForExistence(timeout: 10), app.debugDescription)
    for _ in 0..<5 where !type.isHittable { app.swipeUp() }
    XCTAssertTrue(type.isHittable, app.debugDescription)
    type.tap()
    XCTAssertTrue(app.buttons["修改"].waitForExistence(timeout: 15), app.debugDescription)
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["修改"].waitForExistence(timeout: 30), app.debugDescription)
    app.buttons["历史"].tap()
    XCTAssertTrue(app.buttons["备份、导出与恢复"].waitForExistence(timeout: 10), app.debugDescription)
    let persistedRecords = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "光滑柔软", "修改")
    )
    XCTAssertTrue(persistedRecords.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertEqual(persistedRecords.count, 1, "One tap must persist exactly one record across restart.")
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Persisted synthetic record in normal history UI"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
