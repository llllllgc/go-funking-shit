import Flutter
import UserNotifications
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testDisabledByDefaultAndPreferencesRoundTrip() throws {
    let name = "lalema.reminder.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let original = try ReminderConfiguration.load(defaults)
    XCTAssertFalse(original.enabled)
    XCTAssertEqual(original.hour, 20)
    let changed = try ReminderConfiguration(enabled: true, hour: 8, minute: 15)
    changed.save(defaults)
    let loaded = try ReminderConfiguration.load(UserDefaults(suiteName: name)!)
    XCTAssertTrue(loaded.enabled)
    XCTAssertEqual(loaded.hour, 8)
    XCTAssertEqual(loaded.minute, 15)
    XCTAssertThrowsError(try ReminderConfiguration(hour: 24))
    defaults.set(["enabled": true, "hour": -1, "minute": 0], forKey: "lalema.reminder")
    XCTAssertThrowsError(try ReminderConfiguration.load(defaults))
  }

  func testDailyTriggerFollowsLocalClockInsteadOfFixedDateOrZone() throws {
    let trigger = try ReminderConfiguration(enabled: true, hour: 20, minute: 15).trigger
    XCTAssertTrue(trigger.repeats)
    XCTAssertEqual(trigger.dateComponents.hour, 20)
    XCTAssertEqual(trigger.dateComponents.minute, 15)
    XCTAssertNil(trigger.dateComponents.year)
    XCTAssertNil(trigger.dateComponents.day)
    XCTAssertNil(trigger.dateComponents.timeZone)
    XCTAssertNotNil(trigger.nextTriggerDate())
  }

  func testNativeReadAndDisableDoNotRequireNotificationPermission() throws {
    let name = "lalema.reminder.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let service = ReminderService(defaults: defaults, identifierPrefix: name)
    let read = expectation(description: "Read native notification settings")
    service.handle(FlutterMethodCall(methodName: "getState", arguments: nil)) { result in
      let state = result as? [String: Any]
      XCTAssertEqual(state?["enabled"] as? Bool, false)
      XCTAssertEqual(state?["scheduled"] as? Bool, false)
      XCTAssertNotNil(state?["permission"])
      read.fulfill()
    }
    wait(for: [read], timeout: 10)
    let disable = expectation(description: "Persist disabled state and cancel owned requests")
    service.handle(FlutterMethodCall(methodName: "configure", arguments: ["enabled": false, "hour": 9, "minute": 30])) { result in
      let state = result as? [String: Any]
      XCTAssertEqual(state?["enabled"] as? Bool, false)
      XCTAssertEqual(state?["scheduled"] as? Bool, false)
      XCTAssertEqual(state?["hour"] as? Int, 9)
      XCTAssertEqual(state?["minute"] as? Int, 30)
      disable.fulfill()
    }
    wait(for: [disable], timeout: 10)
    XCTAssertFalse(try ReminderConfiguration.load(defaults).enabled)
  }
}
