import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private static var orientationEvents: [String] = []

  // iOS 27 queries the scene delegate instead of the deprecated app callback.
  // Export the Objective-C selector explicitly so this also builds with the
  // iOS 26 SDK used by CI; all parameter and return types predate iOS 27.
  @objc(supportedInterfaceOrientationsForWindowScene:)
  func supportedSceneOrientations(_ windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
    let mask = (window?.rootViewController as? FlutterViewController)?
      .supportedInterfaceOrientations
      ?? (UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown)
    recordOrientation("scene orientation query -> \(mask.rawValue)")
    return mask
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    recordOrientation("will resign active")
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    recordOrientation("did enter background")
    super.sceneDidEnterBackground(scene)
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    recordOrientation("will enter foreground")
    super.sceneWillEnterForeground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    recordOrientation("did become active")
    // Observe the unlock animation without issuing extra rotation requests.
    for delay in [0.5, 1.5, 3.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak scene] in
        guard scene?.activationState == .foregroundActive else { return }
        self?.recordOrientation("active +\(delay)s")
      }
    }
  }

  func recordOrientation(_ event: String) {
    let scene = window?.windowScene
    let mask = window?.rootViewController?.supportedInterfaceOrientations.rawValue ?? 0
    let entry = "\(Date().timeIntervalSince1970) \(event) "
      + "state=\(scene?.activationState.rawValue ?? -99) "
      + "interface=\(scene?.interfaceOrientation.rawValue ?? 0) "
      + "device=\(UIDevice.current.orientation.rawValue) mask=\(mask) "
      + "window=\(String(describing: window?.bounds.size))"
    Self.orientationEvents.append(entry)
    if Self.orientationEvents.count > 120 {
      Self.orientationEvents.removeFirst(Self.orientationEvents.count - 120)
    }
  }

  static func registerOrientationDiagnostics(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.example.piliplus/orientation",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getDiagnostics" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(([
        "PiliPlus orientation diagnostics v2; iOS \(UIDevice.current.systemVersion)",
        "interface: 1=portrait 2=upsideDown 3=landscapeLeft 4=landscapeRight",
        "mask: 2=portrait 4=upsideDown 8=landscapeLeft 16=landscapeRight",
      ] + orientationEvents).joined(separator: "\n"))
    }
  }

  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(
    for windowScene: UIWindowScene
  ) -> UIWindowScene.WindowingControlStyle {
    return .minimal
  }
}
