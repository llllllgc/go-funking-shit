import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let reminders = ReminderService()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LalemaPrivacyScreen") else { return }
    let reminderChannel = FlutterMethodChannel(name: "lalema/reminders", binaryMessenger: registrar.messenger())
    reminderChannel.setMethodCallHandler { [weak self] call, result in
      self?.reminders.handle(call, result: result)
    }
    let channel = FlutterMethodChannel(name: "lalema/privacy_screen", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "protect":
        // iOS uses a scene cover; no claim that foreground screenshots are blocked.
        result(nil)
      case "foregroundEpoch":
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive }
        result((scene?.delegate as? SceneDelegate)?.coverEpoch)
      case "frameReady":
        if let epoch = call.arguments as? Int {
          for scene in UIApplication.shared.connectedScenes {
            (scene.delegate as? SceneDelegate)?.revealAfterSafeFrame(epoch: epoch)
          }
        }
        result(nil)
      #if DEBUG
      case "debugStatus":
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive }
        let delegate = scene?.delegate as? SceneDelegate
        result(["covered": delegate?.debugCoverVisible ?? true, "epoch": delegate?.coverEpoch ?? -1])
      #endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if [ReminderService.dailyID, ReminderService.testID].contains(notification.request.identifier) {
      completionHandler([.banner, .list, .sound])
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if [ReminderService.dailyID, ReminderService.testID].contains(response.notification.request.identifier) {
      // Opening the app follows its normal privacy gate; never write a record
      // or navigate around authentication from a notification response.
      completionHandler()
    } else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
  }

}
