import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.applicationSupportsShakeToEdit = false // Disable shake to undo
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    // System overlays (e.g. the AirPods HUD) also query the application mask.
    // Keep it in sync with SystemChrome's mask on the Flutter view controller,
    // rather than falling back to the broader orientations in Info.plist.
    // With the scene lifecycle, the app window belongs to SceneDelegate; the
    // queried window may instead be a temporary system window or even nil.
    let scene = window?.windowScene
      ?? (application.connectedScenes.first(where: {
        $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
      }) as? UIWindowScene)
    let sceneWindow = (scene?.delegate as? FlutterSceneDelegate)?.window
    (scene?.delegate as? SceneDelegate)?.recordOrientation("app orientation query")
    let controller = (sceneWindow?.rootViewController
      ?? window?.rootViewController
      ?? self.window?.rootViewController) as? FlutterViewController

    return controller?.supportedInterfaceOrientations
      ?? (UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrientationDiagnostics") {
      SceneDelegate.registerOrientationDiagnostics(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PipPlugin") {
      PipPlugin.register(with: registrar)
    }
  }
}
