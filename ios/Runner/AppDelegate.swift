import Firebase
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if JEEB_DEV
    // The isolated dev flavor intentionally ships without production Firebase
    // credentials. Firebase-backed features use their existing fallbacks until
    // a dedicated app.jeeb.jeebMobile.dev configuration is provisioned.
    #else
    // Production remains fail-loud: configure the required bundled plist
    // before any plugin can touch Firebase.
    FirebaseApp.configure()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
