import 'package:flutter/widgets.dart';

typedef ForegroundListener = void Function(bool isForeground);

abstract interface class AppLifecycleGate {
  bool get isForeground;
  void addForegroundListener(ForegroundListener listener);
  void removeForegroundListener(ForegroundListener listener);

  static AppLifecycleGate get instance => _ambient;
  static final _AmbientAppLifecycleGate _ambient = _AmbientAppLifecycleGate();

  static void install(AppLifecycleGate source) => _ambient.attach(source);

  @visibleForTesting
  static void debugReset() => _ambient.detach();

  @visibleForTesting
  static int get debugListenerCount => _ambient.listenerCount;
}

class AlwaysForegroundAppLifecycleGate implements AppLifecycleGate {
  const AlwaysForegroundAppLifecycleGate();

  @override
  bool get isForeground => true;

  @override
  void addForegroundListener(ForegroundListener listener) {}

  @override
  void removeForegroundListener(ForegroundListener listener) {}
}

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

class WidgetsBindingAppLifecycleGate
    with WidgetsBindingObserver
    implements AppLifecycleGate {
  WidgetsBindingAppLifecycleGate() {
    final binding = WidgetsBinding.instance;
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

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listeners.clear();
  }
}

class _AmbientAppLifecycleGate implements AppLifecycleGate {
  AppLifecycleGate _source = const AlwaysForegroundAppLifecycleGate();
  final List<ForegroundListener> _listeners = <ForegroundListener>[];
  bool _lastKnown = true;

  int get listenerCount => _listeners.length;

  void attach(AppLifecycleGate source) {
    if (identical(source, _source)) return;
    final AppLifecycleGate previous = _source;
    previous.removeForegroundListener(_onSourceChanged);
    _source = source;
    source.addForegroundListener(_onSourceChanged);
    // Dropping the listener is not enough: a `WidgetsBindingAppLifecycleGate`
    // registers itself as a binding observer in its constructor, so an
    // un-disposed predecessor keeps receiving every lifecycle transition for
    // the life of the process. `configureDependencies` installs a fresh gate on
    // each run, and the Dev Tool's `Apply & Restart` runs it again per restart —
    // so without this the observer list grows once per restart.
    if (previous is WidgetsBindingAppLifecycleGate) {
      previous.dispose();
    }
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
