import Firebase
import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  #if JEEB_DEV
  /// Dev-flavor-only channel that forwards a physical shake to Dart so the
  /// Jeeber Dev Tool can open on iOS, which has no second launcher icon and no
  /// URL scheme. Compiled ONLY into the Runner target's Debug-dev / Profile-dev
  /// / Release-dev configurations; the `Release` configuration a store build
  /// uses does not define JEEB_DEV, so none of this reaches the App Store.
  ///
  /// NOTE: the gate is `#if JEEB_DEV` alone, never `#if DEBUG` — the Runner
  /// target sets SWIFT_ACTIVE_COMPILATION_CONDITIONS to `JEEB_DEV` WITHOUT
  /// `DEBUG` (DEBUG=1 lives only in GCC_PREPROCESSOR_DEFINITIONS, which does
  /// not reach Swift), so `#if DEBUG && JEEB_DEV` would compile to nothing.
  private var devToolShakeChannel: FlutterMethodChannel?
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if JEEB_DEV
    // The isolated dev flavor intentionally ships without production Firebase
    // credentials. Firebase-backed features use their existing fallbacks until
    // a dedicated app.jeeb.jeebMobile.dev configuration is provisioned.
    //
    // UIKit otherwise treats a shake as "Undo Typing" and puts a system alert
    // on screen before our motion handler is useful. Dev flavor only.
    application.applicationSupportsShakeToEdit = false
    #else
    // Production remains fail-loud: configure the required bundled plist
    // before any plugin can touch Firebase.
    guard
      let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      mapsAPIKey.hasPrefix("AIza"),
      mapsAPIKey.count == 39,
      GMSServices.provideAPIKey(mapsAPIKey)
    else {
      fatalError("Required iOS Maps configuration is missing or invalid.")
    }
    FirebaseApp.configure()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if JEEB_DEV
    // `applicationRegistrar` is the sanctioned application-level messenger for
    // the implicit engine. Do NOT reach for `window?.rootViewController`: this
    // app is UIScene-based, so the window belongs to the scene, not to
    // FlutterAppDelegate.
    devToolShakeChannel = FlutterMethodChannel(
      name: "com.olivium.jeeb/devtool_shake",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    #endif
  }

  #if JEEB_DEV
  /// FlutterAppDelegate inherits UIResponder, so it is the terminal link of the
  /// responder chain and receives motion events nothing else handled. The
  /// pinned engine implements no motion callback at all, so a shake reaches
  /// here unswallowed.
  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    super.motionEnded(motion, with: event)
    guard motion == .motionShake else { return }
    // Fire-and-forget, with NO result callback on purpose. In Release-dev and
    // Profile-dev JEEB_DEV is defined but the Dart gate
    // (`kDebugMode && kDevToolRequested`) is false, so no handler is registered
    // and the reply is FlutterMethodNotImplemented. That is expected, not an
    // error: never force-unwrap or assert on it.
    devToolShakeChannel?.invokeMethod("open", arguments: nil)
  }
  #endif
}
