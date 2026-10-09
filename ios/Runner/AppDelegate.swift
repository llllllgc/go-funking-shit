import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LalemaPrivacyScreen") else { return }
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
}
