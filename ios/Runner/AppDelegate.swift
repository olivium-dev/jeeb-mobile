import Firebase
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Sprint 1 Stream B: initialise Firebase before any plugin touches it.
    // Reads GoogleService-Info.plist (never committed; see the .template).
    //
    // Startup-crash guard: a bare `FirebaseApp.configure()` raises an uncaught
    // ObjC exception ("could not find a valid GoogleService-Info.plist") and
    // terminates the process before Flutter ever boots — exactly the
    // simulator/dev startup crash this fixes. We therefore configure ONLY when
    // a valid plist is actually bundled. This mirrors the Dart bootstrap, which
    // is explicitly built to tolerate a missing Firebase config on dev/QA
    // (Bootstrap._defaultCrashReporterFactory falls back to NoopCrashReporter).
    // CI/prod inject the real plist (see GoogleService-Info.plist.template), so
    // configuration runs normally there; only local/simulator boots skip it.
    if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let options = FirebaseOptions(contentsOfFile: plistPath) {
      FirebaseApp.configure(options: options)
    } else {
      NSLog(
        "[AppDelegate] GoogleService-Info.plist not bundled — skipping "
          + "FirebaseApp.configure(). Firebase-backed features (Crashlytics, "
          + "Messaging) are disabled for this run; the Dart layer degrades to "
          + "NoopCrashReporter. Add the real plist for full Firebase support."
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
