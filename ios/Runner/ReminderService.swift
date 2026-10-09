import Flutter
import UIKit
import UserNotifications

struct ReminderConfiguration {
  var enabled = false
  var hour = 20
  var minute = 0

  init(enabled: Bool = false, hour: Int = 20, minute: Int = 0) throws {
    guard (0...23).contains(hour), (0...59).contains(minute) else {
      throw NSError(domain: "ReminderConfiguration", code: 1)
    }
    self.enabled = enabled
    self.hour = hour
    self.minute = minute
  }

  static func load(_ defaults: UserDefaults) throws -> ReminderConfiguration {
    guard let value = defaults.object(forKey: "lalema.reminder") else { return try ReminderConfiguration() }
    guard let map = value as? [String: Any], let enabled = map["enabled"] as? Bool,
          let hour = map["hour"] as? Int, let minute = map["minute"] as? Int else {
      throw NSError(domain: "ReminderConfiguration", code: 2)
    }
    return try ReminderConfiguration(enabled: enabled, hour: hour, minute: minute)
  }

  func save(_ defaults: UserDefaults) {
    defaults.set(["enabled": enabled, "hour": hour, "minute": minute], forKey: "lalema.reminder")
  }

  var trigger: UNCalendarNotificationTrigger {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    // No fixed date or time zone: the system matches the device's local clock.
    return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
  }
}

final class ReminderService {
  static let dailyID = "lalema.daily-reminder"
  static let testID = "lalema.test-reminder"
  private let center = UNUserNotificationCenter.current()
  private let defaults: UserDefaults
  private let dailyIdentifier: String
  private let testIdentifier: String

  init(defaults: UserDefaults = .standard, identifierPrefix: String = "lalema") {
    self.defaults = defaults
    self.dailyIdentifier = identifierPrefix + ".daily-reminder"
    self.testIdentifier = identifierPrefix + ".test-reminder"
  }
  private var busy = false

  private func permission(_ settings: UNNotificationSettings) -> String {
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return settings.alertSetting == .disabled ? "denied" : "allowed"
    case .notDetermined: return "notDetermined"
    default: return "denied"
    }
  }

  private func content(test: Bool = false) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = test ? "测试提醒" : "记录提醒"
    content.body = "有空时，记下今天的情况。按自己的节奏来。"
    content.sound = .default
    return content
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !busy else {
      result(FlutterError(code: "REMINDER_BUSY", message: "Reminder update pending", details: nil))
      return
    }
    busy = true
    let finish: FlutterResult = { value in
      DispatchQueue.main.async { self.busy = false; result(value) }
    }
    let failure = FlutterError(code: "REMINDER_UNAVAILABLE", message: "Unable to update reminders", details: nil)
    do {
      switch call.method {
      case "getState":
        snapshot(try ReminderConfiguration.load(defaults), result: finish)
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
          DispatchQueue.main.async {
            guard error == nil, let config = try? ReminderConfiguration.load(self.defaults) else { finish(failure); return }
            self.snapshot(config, result: finish)
          }
        }
      case "configure":
        guard let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool,
              let hour = args["hour"] as? Int, let minute = args["minute"] as? Int else { finish(failure); return }
        let config = try ReminderConfiguration(enabled: enabled, hour: hour, minute: minute)
        center.getNotificationSettings { settings in
          DispatchQueue.main.async {
            guard !enabled || self.permission(settings) == "allowed" else { finish(failure); return }
            config.save(self.defaults)
            if !enabled {
              self.center.removePendingNotificationRequests(withIdentifiers: [self.dailyIdentifier, self.testIdentifier])
              self.center.removeDeliveredNotifications(withIdentifiers: [self.dailyIdentifier, self.testIdentifier])
            }
            self.snapshot(config, result: finish)
          }
        }
      case "test":
        center.getNotificationSettings { settings in
          guard self.permission(settings) == "allowed" else { finish(failure); return }
          let request = UNNotificationRequest(identifier: self.testIdentifier, content: self.content(test: true),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
          self.center.add(request) { error in finish(error == nil ? nil : failure) }
        }
      case "openSettings":
        let settingsURL: String
        if #available(iOS 16.0, *) { settingsURL = UIApplication.openNotificationSettingsURLString }
        else { settingsURL = UIApplication.openSettingsURLString }
        guard let url = URL(string: settingsURL) else { finish(failure); return }
        UIApplication.shared.open(url) { opened in finish(opened ? nil : failure) }
      default: finish(FlutterMethodNotImplemented)
      }
    } catch { finish(failure) }
  }

  private func snapshot(_ config: ReminderConfiguration, result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      let permission = self.permission(settings)
      let report: (Error?) -> Void = { error in
        guard error == nil else {
          result(FlutterError(code: "REMINDER_UNAVAILABLE", message: "Unable to schedule reminder", details: nil))
          return
        }
        self.center.getPendingNotificationRequests { requests in
          let next = (requests.first { $0.identifier == self.dailyIdentifier }?.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
          let scheduled = config.enabled && permission == "allowed" && next != nil
          result(["enabled": config.enabled, "hour": config.hour, "minute": config.minute,
                  "permission": permission, "scheduled": scheduled,
                  "nextAt": scheduled ? Int64(next!.timeIntervalSince1970 * 1000) as Any : NSNull()])
        }
      }
      if config.enabled && permission == "allowed" {
        self.center.add(UNNotificationRequest(identifier: self.dailyIdentifier, content: self.content(), trigger: config.trigger), withCompletionHandler: report)
      } else {
        self.center.removePendingNotificationRequests(withIdentifiers: [self.dailyIdentifier])
        report(nil)
      }
    }
  }
}
