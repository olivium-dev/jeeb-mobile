import CoreMotion
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
  private let shakeCatcher = DevToolShakeCatcherView(frame: .zero)
  private let shakeDetector = DevToolShakeDetector()
  /// True between `keyboardWillShow` and `keyboardDidHide`. While set, the
  /// catcher must not take first responder — doing so resigns whatever text
  /// field owns it and dismisses the keyboard under the user.
  private var keyboardIsUp = false
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Every flavor is fail-loud: the protected native config must be bundled
    // and Firebase must be configured before any Flutter plugin can touch it.
    guard
      let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      mapsAPIKey.hasPrefix("AIza"),
      mapsAPIKey.count == 39,
      GMSServices.provideAPIKey(mapsAPIKey)
    else {
      fatalError("Required iOS Maps configuration is missing or invalid.")
    }
    FirebaseApp.configure()

    #if JEEB_DEV
    // UIKit otherwise treats a shake as "Undo Typing" and puts a system alert
    // on screen before our motion handler is useful. Dev flavor only.
    application.applicationSupportsShakeToEdit = false
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
    // iOS delivers motion events to the FIRST RESPONDER and only then walks the
    // responder chain. A Flutter app has no first responder unless a text field
    // is focused, so a shake is dropped before it can ever reach this delegate.
    // `DevToolShakeCatcherView` exists solely to be that first responder; it
    // handles nothing and lets every motion event travel up to `motionEnded`
    // below. Observing the scene notification avoids depending on which window
    // setup hook `FlutterSceneDelegate` happens to expose.
    // Re-assert on EVERY event that can cost the catcher first-responder
    // status. Scene activation alone is not enough: focusing a Flutter text
    // field hands first responder to `FlutterTextInputView`, and when that
    // resigns nobody restores ours — so the shake dies permanently the first
    // time the user types anything (Super Login is the path that exposed it).
    // `keyboardDidHide` is the safe moment to take it back; taking it while the
    // keyboard is up would dismiss it under the user.
    // PRIMARY detection path. UIKit's own shake recognizer has a fixed, quite
    // high threshold with no API to soften it, and it only delivers through the
    // responder chain — the exact mechanism that proved fragile here. CoreMotion
    // reads the accelerometer directly: tunable, and independent of who holds
    // first responder. The UIKit path below is kept as a redundant fallback;
    // if both fire for one physical shake the Dart side debounces on
    // `kDevToolShakeDebounce`.
    shakeDetector.onShake = { [weak self] in
      self?.devToolShakeChannel?.invokeMethod("open", arguments: nil)
    }
    shakeDetector.start()
    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardWillShowNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.keyboardIsUp = true }
    NotificationCenter.default.addObserver(
      forName: UIResponder.keyboardDidHideNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.keyboardIsUp = false
      self?.reassertShakeCatcher()
    }
    for name in [
      UIScene.didActivateNotification,
      UIApplication.didBecomeActiveNotification,
      UIWindow.didBecomeKeyNotification,
    ] {
      NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reassertShakeCatcher()
      }
    }
    // Accelerometer updates are not free; run them only while the app is
    // actually in front of the user.
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.shakeDetector.start() }
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in self?.shakeDetector.stop() }
    #endif
  }

  #if JEEB_DEV
  /// Backstop only — do NOT rely on this as the delivery path.
  ///
  /// It was originally the sole handler, on the theory that FlutterAppDelegate
  /// inherits UIResponder and is therefore "the terminal link of the responder
  /// chain". Measured on an iPhone 12 mini / iOS 26.4.1, that is false for this
  /// app, twice over: UIKit delivers motion events to the FIRST RESPONDER and a
  /// Flutter app has none unless a text field is focused, so nothing was
  /// delivered at all; and once `DevToolShakeCatcherView` supplied a first
  /// responder, `super.motionEnded` still never reached this method — the chain
  /// does not arrive here in this UIScene-based app. This fired 0 times across
  /// every shake in that session while the catcher fired every time.
  ///
  /// Kept because it costs nothing and would cover a non-scene configuration.
  /// A double delivery is safe: the Dart side debounces on
  /// `kDevToolShakeDebounce`.
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

  /// Adds the shake catcher to the scene's window and makes it first responder.
  /// Idempotent: re-running on every scene activation re-takes first responder
  /// after a Flutter text field has released it.
  /// Re-acquires first-responder status for the catcher if it has lost it.
  ///
  /// Cheap and idempotent, so it is safe to call from several notifications.
  /// Deliberately does NOTHING while the keyboard owns first responder — the
  /// caller set is chosen so this only runs at moments when stealing it back is
  /// invisible to the user.
  private func reassertShakeCatcher() {
    // Never take first responder away from a live text field. `didBecomeActive`
    // and `didBecomeKey` fire on returning from Control Center or a system
    // interruption WHILE a field is still focused, and `becomeFirstResponder()`
    // would unconditionally resign it — dismissing the keyboard mid-typing.
    // CoreMotion is the primary detector and needs none of this, so when in
    // doubt the correct move is to skip.
    guard !keyboardIsUp else { return }
    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
    else { return }
    attachShakeCatcher(to: windowScene)
  }

  private func attachShakeCatcher(to windowScene: UIWindowScene) {
    guard let window = windowScene.windows.first(where: { $0.isKeyWindow })
      ?? windowScene.windows.first
    else {
      return
    }
    if shakeCatcher.isFirstResponder, shakeCatcher.superview === window {
      return
    }
    if shakeCatcher.superview !== window {
      shakeCatcher.frame = .zero
      shakeCatcher.backgroundColor = .clear
      window.addSubview(shakeCatcher)
    }
    shakeCatcher.onShake = { [weak self] in
      self?.devToolShakeChannel?.invokeMethod("open", arguments: nil)
    }
    shakeCatcher.becomeFirstResponder()
  }
  #endif
}

#if JEEB_DEV
/// Accelerometer-based shake detection with a threshold we control.
///
/// UIKit's built-in recognizer requires a deliberately hard shake and exposes
/// no sensitivity knob, so this reads `CMMotionManager` directly. A single jolt
/// is ignored on purpose: firing needs [requiredCrossings] separate rising
/// edges above [thresholdG] inside [crossingWindow], which is what distinguishes
/// shaking the device from setting it down, a pothole, or a footstep — this app
/// rides in a courier's pocket, so a single-spike trigger would open the Dev
/// Tool on its own.
///
/// Raw accelerometer access needs no usage-description key or user permission
/// (unlike CMMotionActivity/pedometer), so this adds no privacy prompt.
final class DevToolShakeDetector {
  /// Total acceleration, in g, that counts as a spike. At rest the magnitude is
  /// ~1.0 (gravity alone). Lower = more sensitive.
  private let thresholdG: Double = 1.6

  /// Rising edges required before a shake is reported.
  private let requiredCrossings = 2

  /// How long those crossings may be spread over.
  private let crossingWindow: TimeInterval = 1.0

  /// Minimum gap between two reported shakes. Independent of, and shorter than,
  /// the Dart-side debounce — this one only stops one continuous shake from
  /// reporting many times.
  private let cooldown: TimeInterval = 1.0

  private let motion = CMMotionManager()
  private var crossingTimestamps: [Date] = []
  private var above = false
  private var lastFired = Date.distantPast

  var onShake: (() -> Void)?

  func start() {
    guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else {
      return
    }
    motion.accelerometerUpdateInterval = 1.0 / 50.0
    motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
      guard let self, let a = data?.acceleration else { return }
      self.consume(magnitude: (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot())
    }
  }

  func stop() {
    motion.stopAccelerometerUpdates()
    crossingTimestamps.removeAll()
    above = false
  }

  /// Edge-triggered so one spike counts once, however many samples it spans.
  private func consume(magnitude: Double) {
    let now = Date()
    if magnitude > thresholdG {
      if !above {
        above = true
        crossingTimestamps.append(now)
      }
    } else {
      above = false
    }
    crossingTimestamps.removeAll { now.timeIntervalSince($0) > crossingWindow }
    guard crossingTimestamps.count >= requiredCrossings else { return }
    guard now.timeIntervalSince(lastFired) > cooldown else { return }
    lastFired = now
    crossingTimestamps.removeAll()
    onShake?()
  }
}

/// Zero-size, non-drawing view whose ONLY purpose is to occupy first-responder
/// status so UIKit has somewhere to deliver motion events. It deliberately
/// implements no motion callback: every event travels up the responder chain to
/// `AppDelegate.motionEnded`, which owns the Dev Tool wiring.
final class DevToolShakeCatcherView: UIView {
  override var canBecomeFirstResponder: Bool { true }

  /// Invoked by the owner when a shake reaches this view directly.
  var onShake: (() -> Void)?

  /// NOTE: UIKit sends `motionCancelled` — never `motionEnded` — when the
  /// shaking continues for roughly a second or more. Only a single sharp flick
  /// produces `motionEnded`, so a user who "shakes hard, repeatedly" will see
  /// nothing happen. Measured on an iPhone 12 mini / iOS 26.4.1.
  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake { onShake?() }
    super.motionEnded(motion, with: event)
  }
}
#endif
