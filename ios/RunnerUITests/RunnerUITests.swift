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
      let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      screenshot.lifetime = .keepAlways
      add(screenshot)
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Failure accessibility hierarchy (synthetic data only)"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      let systemHierarchy = XCTAttachment(string: XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
      systemHierarchy.name = "System accessibility hierarchy (disposable simulator only)"
      systemHierarchy.lifetime = .keepAlways
      add(systemHierarchy)
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

  func testFirstNotificationApprovalPersists() throws {
    let settings = app.buttons["设置与隐私"]
    XCTAssertTrue(settings.waitForExistence(timeout: 30), app.debugDescription)
    settings.tap()
    let reminder = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "每日提醒")).firstMatch
    reveal(reminder)
    XCTAssertEqual(reminder.value as? String, "0")
    reminder.tap()
    let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let permission = system.alerts.firstMatch
    XCTAssertTrue(permission.waitForExistence(timeout: 15), system.debugDescription)
    XCTAssertTrue(permission.label.contains("Notifications"), system.debugDescription)
    permission.buttons["Allow"].tap()
    let scheduled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND label CONTAINS %@", "1", "已安排"), object: reminder)
    XCTAssertEqual(XCTWaiter.wait(for: [scheduled], timeout: 15), .completed, app.debugDescription)
    app.terminate()
    app.launch()
    XCTAssertTrue(settings.waitForExistence(timeout: 30), app.debugDescription)
    settings.tap()
    XCTAssertTrue(reminder.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(reminder.value as? String, "1")
    XCTAssertTrue(reminder.label.contains("已安排"))
    reveal(reminder)
    reminder.tap()
    let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: reminder)
    XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 10), .completed, app.debugDescription)
  }

  func testReminderPermissionRecoveryAndDelivery() throws {
    let settings = app.buttons["设置与隐私"]
    XCTAssertTrue(settings.waitForExistence(timeout: 30), app.debugDescription)
    settings.tap()
    let reminder = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "每日提醒")).firstMatch
    reveal(reminder)
    XCTAssertEqual(reminder.value as? String, "0")
    reminder.tap()
    let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let permission = system.alerts.firstMatch
    XCTAssertTrue(permission.waitForExistence(timeout: 15), system.debugDescription)
    XCTAssertTrue(permission.label.contains("Notifications"), system.debugDescription)
    permission.buttons["Don’t Allow"].tap()
    let systemSettings = app.buttons["打开系统通知设置"]
    XCTAssertTrue(systemSettings.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(reminder.value as? String, "0", "Denying permission must not turn reminders on.")
    reveal(systemSettings)
    systemSettings.tap()
    let preferences = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    XCTAssertTrue(preferences.wait(for: .runningForeground, timeout: 15), preferences.debugDescription)
    let allow = preferences.switches["ALLOW_NOTIFICATIONS_ID"]
    if !allow.waitForExistence(timeout: 5) {
      // The iOS 26.4 simulator can open Settings home for the documented URL.
      // Follow the same visible route available to a user; do not alter permission storage.
      if !preferences.buttons["NOTIFICATIONS"].exists {
        XCTAssertTrue(preferences.navigationBars["Settings"].exists, preferences.debugDescription)
        let apps = preferences.buttons["com.apple.settings.apps"]
        for _ in 0..<4 {
          if apps.exists && apps.isHittable { break }
          preferences.swipeUp()
        }
        XCTAssertTrue(apps.exists && apps.isHittable, preferences.debugDescription)
        apps.tap()
        let appEntry = preferences.buttons["com.lalema.lalema"]
        XCTAssertTrue(appEntry.waitForExistence(timeout: 10), preferences.debugDescription)
        appEntry.tap()
      }
      let notifications = preferences.buttons["NOTIFICATIONS"]
      XCTAssertTrue(notifications.waitForExistence(timeout: 10), preferences.debugDescription)
      notifications.tap()
      print("NOTIFICATION_SETTINGS_PATH=manual-apps")
    } else {
      print("NOTIFICATION_SETTINGS_PATH=direct")
    }
    XCTAssertTrue(allow.waitForExistence(timeout: 10), preferences.debugDescription)
    XCTAssertEqual(allow.value as? String, "0")
    // Settings exposes a labelled row and an inner physical switch.
    allow.switches.firstMatch.tap()
    let permissionEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: allow)
    XCTAssertEqual(XCTWaiter.wait(for: [permissionEnabled], timeout: 5), .completed, preferences.debugDescription)
    app.activate()
    let sendTest = app.buttons["发送测试提醒"]
    XCTAssertTrue(sendTest.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(reminder.value as? String, "0", "System permission alone must not enable daily reminders.")
    reveal(reminder, upward: false)
    reminder.tap()
    let scheduled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND label CONTAINS %@", "1", "已安排"), object: reminder)
    XCTAssertEqual(XCTWaiter.wait(for: [scheduled], timeout: 15), .completed, app.debugDescription)
    reveal(sendTest)
    sendTest.tap()
    XCUIDevice.shared.press(.home)
    let background = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.app.state == .runningBackground || self.app.state == .runningBackgroundSuspended
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 5), .completed, "App state after Home: \(app.state.rawValue)")
    let notification = system.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "测试提醒")).firstMatch
    XCTAssertTrue(notification.waitForExistence(timeout: 15), system.debugDescription)
    let genericBody = system.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "有空时，记下今天的情况。按自己的节奏来。")).firstMatch
    XCTAssertTrue(genericBody.exists, system.debugDescription)
    let delivered = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    delivered.name = "Real test notification delivered while app is in background"
    delivered.lifetime = .keepAlways
    add(delivered)
    notification.tap()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), system.debugDescription)
    XCTAssertTrue(reminder.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(reminder.value as? String, "1")
    reveal(reminder, upward: false)
    reminder.tap()
    let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ AND label CONTAINS %@", "0", "已关闭"), object: reminder)
    XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 15), .completed, app.debugDescription)
    app.terminate()
    app.launch()
    XCTAssertTrue(settings.waitForExistence(timeout: 30), app.debugDescription)
    settings.tap()
    XCTAssertTrue(reminder.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertEqual(reminder.value as? String, "0", "Disabling reminders must survive restart.")
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
