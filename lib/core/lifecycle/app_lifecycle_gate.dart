import 'package:flutter/widgets.dart';

/// Called when the app crosses the foreground/background boundary.
/// [isForeground] is the NEW value. Invoked synchronously; never for a
/// no-op transition.
typedef ForegroundListener = void Function(bool isForeground);

/// The app-wide "is the app in the foreground?" signal.
///
/// This is the ONE place allowed to interpret [AppLifecycleState] for polling.
/// Cubits, repositories and screens consume the boolean.
///
/// ## Foreground definition (FROZEN)
/// Foreground == [AppLifecycleState.resumed]. `inactive`, `hidden`, `paused`
/// and `detached` are ALL background.
///
/// ## Unknown state fails OPEN (FROZEN)
/// Under `flutter_test`, `WidgetsBinding.instance.lifecycleState` is `null`
/// until a lifecycle message is driven. An unknown state is treated as
/// FOREGROUND so a bare widget test behaves exactly as it does today. In
/// production the binding populates the state during
/// `WidgetsFlutterBinding.ensureInitialized()` (`lib/main.dart:20`), which
/// runs before `configureDependencies()` (`lib/app/bootstrap.dart:105`), so
/// the unknown window is closed before the real gate is installed.
///
/// ## Ambient resolution
/// [instance] ALWAYS returns the same process-wide object. [install] swaps the
/// *source* behind it and re-broadcasts, so a poller constructed BEFORE the
/// install is still gated afterwards. There is no order-of-installation hazard.
abstract interface class AppLifecycleGate {
  bool get isForeground;
  void addForegroundListener(ForegroundListener listener);
  void removeForegroundListener(ForegroundListener listener);

  /// The stable process-wide gate. Until [install] is called it forwards to
  /// [AlwaysForegroundAppLifecycleGate] — R8: no root install required.
  static AppLifecycleGate get instance => _ambient;
  static final _AmbientAppLifecycleGate _ambient = _AmbientAppLifecycleGate();

  /// Point the ambient gate at a real source. Idempotent for the same source.
  static void install(AppLifecycleGate source) => _ambient.attach(source);

  /// Test-only: drop back to the inert always-foreground source so one test
  /// file cannot leak a paused gate into the next. Call from `tearDown`.
  @visibleForTesting
  static void debugReset() => _ambient.detach();

  /// Test-only leak probe: how many listeners the ambient gate holds.
  /// A correctly-disposed poller contributes 0.
  @visibleForTesting
  static int get debugListenerCount => _ambient.listenerCount;
}

/// The inert source: always foreground, never notifies. `const`.
class AlwaysForegroundAppLifecycleGate implements AppLifecycleGate {
  const AlwaysForegroundAppLifecycleGate();

  @override
  bool get isForeground => true;

  @override
  void addForegroundListener(ForegroundListener listener) {}

  @override
  void removeForegroundListener(ForegroundListener listener) {}
}

/// Test double whose foreground flag is driven by hand.
class ManualAppLifecycleGate implements AppLifecycleGate {
  ManualAppLifecycleGate({bool isForeground = true})
    : _isForeground = isForeground;

  final List<ForegroundListener> _listeners = <ForegroundListener>[];
  bool _isForeground;

  @override
  bool get isForeground => _isForeground;

  void setForeground(bool value) {
    if (_isForeground == value) return;
    _isForeground = value;
    for (final listener in List<ForegroundListener>.of(_listeners)) {
      listener(value);
    }
  }

  @override
  void addForegroundListener(ForegroundListener listener) =>
      _listeners.add(listener);

  @override
  void removeForegroundListener(ForegroundListener listener) =>
      _listeners.remove(listener);
}

/// The production source: the app's SINGLE polling-related
/// [WidgetsBindingObserver]. Before FM-3 there were 8 observer sites and 8
/// real `didChangeAppLifecycleState` overrides (verified count, see §6),
/// each re-deriving "am I foreground?" with its own definition.
class WidgetsBindingAppLifecycleGate
    with WidgetsBindingObserver
    implements AppLifecycleGate {
  WidgetsBindingAppLifecycleGate() {
    final binding = WidgetsBinding.instance;
    // Unknown fails OPEN — see the class doc above.
    _isForeground =
        (binding.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  final List<ForegroundListener> _listeners = <ForegroundListener>[];
  late bool _isForeground;

  @override
  bool get isForeground => _isForeground;

  @override
  void addForegroundListener(ForegroundListener listener) =>
      _listeners.add(listener);

  @override
  void removeForegroundListener(ForegroundListener listener) =>
      _listeners.remove(listener);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isForeground) return;
    _isForeground = foreground;
    for (final listener in List<ForegroundListener>.of(_listeners)) {
      listener(foreground);
    }
  }

  /// Detach from the binding. Required so this file's `addObserver` and
  /// `removeObserver` counts are equal (guardrail T1 / checklist 11).
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listeners.clear();
  }
}

/// Stable forwarding gate. Never replaced, so listeners registered before an
/// [AppLifecycleGate.install] keep working after it.
class _AmbientAppLifecycleGate implements AppLifecycleGate {
  AppLifecycleGate _source = const AlwaysForegroundAppLifecycleGate();
  final List<ForegroundListener> _listeners = <ForegroundListener>[];
  bool _lastKnown = true;

  int get listenerCount => _listeners.length;

  void attach(AppLifecycleGate source) {
    if (identical(source, _source)) return;
    _source.removeForegroundListener(_onSourceChanged);
    _source = source;
    source.addForegroundListener(_onSourceChanged);
    _onSourceChanged(source.isForeground);
  }

  void detach() {
    _source.removeForegroundListener(_onSourceChanged);
    _source = const AlwaysForegroundAppLifecycleGate();
    _onSourceChanged(true);
  }

  void _onSourceChanged(bool isForeground) {
    if (isForeground == _lastKnown) return;
    _lastKnown = isForeground;
    for (final listener in List<ForegroundListener>.of(_listeners)) {
      listener(isForeground);
    }
  }

  @override
  bool get isForeground => _source.isForeground;

  @override
  void addForegroundListener(ForegroundListener listener) =>
      _listeners.add(listener);

  @override
  void removeForegroundListener(ForegroundListener listener) =>
      _listeners.remove(listener);
}
