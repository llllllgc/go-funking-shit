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

  func testRecordPersistsAndBackupRestoresThroughSystemFiles() throws {
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
    let originalRecordLabel = persistedRecords.firstMatch.label
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Persisted synthetic record in normal history UI"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["备份、导出与恢复"].tap()
    let saveBackup = app.buttons["保存 JSON 备份"]
    XCTAssertTrue(saveBackup.waitForExistence(timeout: 10), app.debugDescription)
    saveBackup.tap()
    let nativeSave = app.buttons["保存"]
    XCTAssertTrue(nativeSave.waitForExistence(timeout: 15), app.debugDescription)
    let savedName = try XCTUnwrap(app.textFields["DOCPicker.filenameTextField"].value as? String)
    XCTAssertTrue(savedName.hasPrefix("lalema-backup-"))
    nativeSave.tap()
    XCTAssertTrue(text("备份已保存，共 1 条记录。").waitForExistence(timeout: 15), app.debugDescription)

    let clear = app.buttons["清空全部记录…"]
    reveal(clear)
    clear.tap()
    let confirmation = app.textFields.firstMatch
    XCTAssertTrue(confirmation.waitForExistence(timeout: 10), app.debugDescription)
    confirmation.tap()
    confirmation.typeText("清空")
    app.buttons["确认清空"].tap()
    XCTAssertTrue(text("本机记录已清空。导出的文件和系统备份仍由你保管。").waitForExistence(timeout: 10), app.debugDescription)

    let pick = app.buttons["选择 JSON 备份"]
    reveal(pick, upward: false)
    pick.tap()
    let savedFile = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", savedName + ".json,")).firstMatch
    XCTAssertTrue(savedFile.waitForExistence(timeout: 15), app.debugDescription)
    savedFile.tap()
    let importBackup = app.buttons["确认导入 1 条"]
    XCTAssertTrue(importBackup.waitForExistence(timeout: 15), app.debugDescription)
    reveal(importBackup)
    XCTAssertTrue(importBackup.isEnabled)
    importBackup.tap()
    XCTAssertTrue(text("已新增 1 条，跳过 0 条重复记录，保留 0 条本机冲突记录。").waitForExistence(timeout: 10), app.debugDescription)

    // Cancellation releases the native picker, so the same backup can be opened again.
    reveal(pick, upward: false)
    pick.tap()
    let cancel = app.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 15), app.debugDescription)
    cancel.tap()
    XCTAssertTrue(text("已取消选择，记录未更改。").waitForExistence(timeout: 10), app.debugDescription)
    pick.tap()
    XCTAssertTrue(savedFile.waitForExistence(timeout: 15), app.debugDescription)
    savedFile.tap()
    let duplicate = app.buttons["没有需要新增的记录"]
    XCTAssertTrue(duplicate.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertFalse(duplicate.isEnabled, "Opening the original backup again must not duplicate the record.")
    let preview = XCTAttachment(screenshot: app.screenshot())
    preview.name = "Original backup remains readable and duplicate import is disabled"
    preview.lifetime = .keepAlways
    add(preview)

    app.buttons["返回"].tap()
    XCTAssertTrue(persistedRecords.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertEqual(persistedRecords.count, 1)
    XCTAssertEqual(persistedRecords.firstMatch.label, originalRecordLabel)
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["历史"].waitForExistence(timeout: 30), app.debugDescription)
    app.buttons["历史"].tap()
    XCTAssertTrue(persistedRecords.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertEqual(persistedRecords.count, 1)
    XCTAssertEqual(persistedRecords.firstMatch.label, originalRecordLabel)
  }

  private func text(_ label: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  private func reveal(_ element: XCUIElement, upward: Bool = true) {
    for _ in 0..<6 {
      if element.exists && element.isHittable {
        // Flutter scroll animation is not part of XCTest's native idle tracking.
        // Wait for the actual target frame to settle before tapping its location.
        var previousFrame = CGRect.null
        var lastChange = Date()
        let stable = NSPredicate { _, _ in
          guard element.exists && element.isHittable && element.isEnabled else { return false }
          let frame = element.frame
          if frame != previousFrame {
            previousFrame = frame
            lastChange = Date()
          }
          return Date().timeIntervalSince(lastChange) >= 0.5
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: stable, object: nil)], timeout: 5), .completed, app.debugDescription)
        return
      }
      if upward { app.swipeUp() } else { app.swipeDown() }
    }
    XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
  }
}
