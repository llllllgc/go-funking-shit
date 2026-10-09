import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?
  private(set) var coverEpoch = 0
  #if DEBUG
  var debugCoverVisible: Bool { privacyCover != nil }
  #endif

  override func sceneWillResignActive(_ scene: UIScene) {
    showPrivacyCover()
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    showPrivacyCover()
    super.sceneDidEnterBackground(scene)
  }

  private func showPrivacyCover() {
    coverEpoch += 1
    guard privacyCover == nil, let window = window else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(red: 247.0/255, green: 244.0/255, blue: 234.0/255, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.isAccessibilityElement = true
    cover.accessibilityLabel = "内容已隐藏"
    cover.accessibilityViewIsModal = true
    window.addSubview(cover)
    privacyCover = cover
  }

  func revealAfterSafeFrame(epoch: Int) {
    guard epoch == coverEpoch, window?.windowScene?.activationState == .foregroundActive else { return }
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
