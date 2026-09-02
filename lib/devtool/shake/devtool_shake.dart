// Shake-to-open for the Jeeber Dev Tool (iOS entry point).
//
// iOS has no second launcher icon and no URL scheme, so — unlike Android,
// which reaches `/devtool` through a flavor-specific launcher Activity — a
// physical shake is the only Dev Tool entry point on that platform. The
// gesture is delivered natively by `ios/Runner/AppDelegate.swift`
// (`motionEnded(_:with:)`, inside `#if JEEB_DEV`) over [kDevToolShakeChannel]
// and handled here.
//
// TWO INDEPENDENT COMPILE-OUT GATES protect a store build:
//   1. Dart  — everything in this file is only reachable through the
//              `kDevToolEnabled` const ternary in `app/app.dart`, so a
//              release/profile AOT snapshot tree-shakes the wiring AND the
//              `../devtool_shell.dart` import below out entirely.
//   2. Native — `#if JEEB_DEV` is defined on exactly three Runner
//              configurations (Debug-dev / Profile-dev / Release-dev), never
//              on the `Release` configuration a store build uses.
// Neither gate depends on the other. `tool/inspect_unsigned_ios_release.sh`
// scans both binaries for `devtool_shake` and fails the build on a hit.
library;

import 'package:flutter/material.dart';

import '../../app/app_restarter.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';

import '../../core/dev_flags.dart';
import '../devtool_shell.dart';

/// Native → Dart channel carrying the shake gesture. Matches the
/// `com.olivium.jeeb/<snake_name>` convention used by the dev-seam and power
/// channels. The `devtool_shake` suffix is deliberately distinctive so the
/// release binary scanners can grep for it.
const String kDevToolShakeChannelName = 'com.olivium.jeeb/devtool_shake';

/// Android launcher → Dart channel used to reopen an existing single-task
/// Dev Tool activity. It stays independent of the optional shake channel so
/// an internal build can disable physical shake without disabling its icon.
const String kDevToolLauncherChannelName = 'com.olivium.jeeb/devtool_launcher';

/// The only method the native side sends.
const String kDevToolShakeOpenMethod = 'open';

/// The channel instance shared by the host and its tests.
const MethodChannel kDevToolShakeChannel = MethodChannel(
  kDevToolShakeChannelName,
);

/// Channel shared by both Android Dev Tool launcher activities.
const MethodChannel kDevToolLauncherChannel = MethodChannel(
  kDevToolLauncherChannelName,
);

/// Identifies the mounted Dev Tool layer (used by tests and by the no-op
/// "already open" check).
const Key kDevToolShakeLayerKey = ValueKey<String>('jeeb-devtool-shake-layer');

/// Identifies the layer's close affordance — dismiss WITHOUT restarting.
const Key kDevToolShakeCloseKey = ValueKey<String>('jeeb-devtool-shake-close');

/// Identifies the layer's apply affordance — dismiss AND restart the app.
const Key kDevToolShakeApplyKey = ValueKey<String>('jeeb-devtool-shake-apply');

/// A single physical shake can deliver `motionEnded` more than once, and the
/// OS does not deduplicate it. Repeats inside this window are dropped.
const Duration kDevToolShakeDebounce = Duration(seconds: 1);

DateTime _systemClock() => DateTime.now();

/// Which host instance currently owns the method-call handler, keyed by
/// channel name.
///
/// A handler is registered against the binary messenger by channel NAME, not
/// by `MethodChannel` instance, so every host competes for a single slot —
/// giving each host its own channel object would not separate them. Flutter
/// runs the incoming element's `initState` BEFORE the outgoing element's
/// `dispose` (`Element.updateChild` deactivates then inflates; `dispose` is
/// deferred to `finalizeTree`), so on a same-frame host swap an unconditional
/// `setMethodCallHandler(null)` in the old host's `dispose` would wipe the NEW
/// host's handler and leave shake dead for the rest of the process. That swap
/// is reachable in a dev build today: `app/app.dart` rebuilds the subtree from
/// `ClarityMask` to `ClarityWidget` when Clarity consent is accepted, and any
/// structural hot reload above the host does the same. Clearing only when this
/// instance is still the recorded owner makes the teardown safe.
final Map<String, _DevToolShakeHostState> _nativeHandlerOwners =
    <String, _DevToolShakeHostState>{};

/// Default content of the Dev Tool layer.
///
/// The reference to [DevToolShell] sits behind the same compile-time const as
/// everything else here, so the shell (and its `Super Login` string literals)
/// never enter a release snapshot. When the gate is off this is an empty box
/// rather than a shell, because [DevToolShell] hard-asserts the gate.
///
/// [registerDevToolSuperLoginDependencies] must run before the shell is built:
/// unlike [DevToolApp], this path never goes through `Bootstrap.minimal`, and
/// product DI does not register `SuperLoginService` — without this call, Dev
/// Tool → Super Login throws in GetIt. The call is idempotent, so repeating it
/// on a rebuild is free, and it stays inside the gated branch so the gate-off
/// branch keeps its zero-side-effect `SizedBox`.
Widget defaultDevToolShakeLayer(BuildContext context) {
  if (!kDevToolEnabled) return const SizedBox.shrink();
  registerDevToolSuperLoginDependencies();
  return const DevToolShell();
}

/// Pure trigger policy for the shake gesture: debounce plus the "already
/// open" no-op. Kept free of Flutter state on purpose so it is directly
/// testable without the compile-time gate being on.
class DevToolShakeGate {
  DevToolShakeGate({this.window = kDevToolShakeDebounce});

  /// Repeat deliveries closer together than this are dropped.
  final Duration window;

  DateTime? _lastAccepted;

  /// Whether this delivery should open the Dev Tool.
  ///
  /// Returns `false` when the tool is already on top (no-op) and when the
  /// previous accepted trigger is less than [window] old (debounce). An
  /// [alreadyOpen] rejection deliberately does NOT extend the window: the
  /// window measures accepted opens, not delivered shakes.
  bool shouldOpen({required bool alreadyOpen, required DateTime now}) {
    if (alreadyOpen) return false;
    final DateTime? last = _lastAccepted;
    if (last != null && now.difference(last) < window) return false;
    _lastAccepted = now;
    return true;
  }
}

/// Wraps the routed product UI and mounts the Dev Tool on top of it when the
/// native side reports a shake or the Android launcher supplies `/devtool`.
///
/// This is a builder-chain wrap rather than a `Navigator.push`: an imperative
/// push onto go_router's Navigator produces a pageless route anchored to the
/// topmost page, and `app.dart`'s push-banner tap and empty-stack recovery
/// both call `GoRouter.go` without user intent — either would silently tear
/// the Dev Tool down mid-use. Wrapping also keeps the tool inside
/// `ClarityMask`, so session recording never captures it.
class DevToolShakeHost extends StatefulWidget {
  const DevToolShakeHost({
    required this.child,
    super.key,
    this.initiallyOpen = false,
    this.shakeEnabled = true,
    this.channel = kDevToolShakeChannel,
    this.launcherChannel = kDevToolLauncherChannel,
    this.layerBuilder = defaultDevToolShakeLayer,
    this.clock = _systemClock,
    this.debounce = kDevToolShakeDebounce,
  });

  /// The routed product UI this host sits above.
  final Widget child;

  /// Whether the Dev Tool layer is visible on the host's first frame.
  final bool initiallyOpen;

  /// Whether this host owns the optional native shake channel.
  final bool shakeEnabled;

  /// Channel the native shake arrives on.
  final MethodChannel channel;

  /// Channel an existing Android launcher activity uses to reopen the tool.
  final MethodChannel launcherChannel;

  /// Builds the content of the Dev Tool layer.
  final WidgetBuilder layerBuilder;

  /// Wall clock, injectable so the debounce window is testable.
  final DateTime Function() clock;

  /// Repeat-shake suppression window.
  final Duration debounce;

  @override
  State<DevToolShakeHost> createState() => _DevToolShakeHostState();
}

class _DevToolShakeHostState extends State<DevToolShakeHost> {
  late final DevToolShakeGate _gate = DevToolShakeGate(window: widget.debounce);
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
    _claimNativeHandlers();
  }

  void _claimNativeHandlers() {
    _claimNativeHandler(widget.launcherChannel);
    if (widget.shakeEnabled &&
        widget.channel.name != widget.launcherChannel.name) {
      _claimNativeHandler(widget.channel);
    }
  }

  void _claimNativeHandler(MethodChannel channel) {
    // Registered synchronously, not in a post-frame callback: a shake can
    // arrive at any time and the handler is cheap. Claiming ownership here —
    // before any outgoing host's deferred `dispose` runs — is what lets that
    // teardown know it is no longer the owner. See [_nativeHandlerOwners].
    _nativeHandlerOwners[channel.name] = this;
    channel.setMethodCallHandler(_onNativeCall);
  }

  void _releaseNativeHandler(MethodChannel channel) {
    final String name = channel.name;
    if (!identical(_nativeHandlerOwners[name], this)) return;
    _nativeHandlerOwners.remove(name);
    channel.setMethodCallHandler(null);
  }

  void _releaseNativeHandlers(DevToolShakeHost host) {
    _releaseNativeHandler(host.launcherChannel);
    if (host.channel.name != host.launcherChannel.name) {
      _releaseNativeHandler(host.channel);
    }
  }

  @override
  void didUpdateWidget(covariant DevToolShakeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeEnabled == widget.shakeEnabled &&
        oldWidget.channel.name == widget.channel.name &&
        oldWidget.launcherChannel.name == widget.launcherChannel.name) {
      return;
    }
    _releaseNativeHandlers(oldWidget);
    _claimNativeHandlers();
  }

  @override
  void dispose() {
    // Tear down ONLY the handler this instance still owns: a host that was
    // already superseded in the same frame must leave its successor's handler
    // alone. See [_nativeHandlerOwners].
    _releaseNativeHandlers(widget);
    super.dispose();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != kDevToolShakeOpenMethod) return;
    if (!mounted) return;
    if (!_gate.shouldOpen(alreadyOpen: _open, now: widget.clock())) return;
    setState(() => _open = true);
  }

  /// Dismiss and leave the app exactly as it was.
  ///
  /// This is the cheap, reversible exit, and it is the one mapped to `X`
  /// because the Dev Tool opens on a physical gesture that fires by accident.
  /// An accidental open must cost nothing — restarting on `X` would turn a
  /// stray shake in a pocket into a cold start and lost screen state.
  void _close() {
    if (!_open) return;
    setState(() => _open = false);
  }

  /// Dismiss AND restart, so settings edited in the Dev Tool take effect.
  ///
  /// Startup-scoped settings are inert without this: `configureDependencies`
  /// registers `Dio` as a LAZY singleton over `DevBaseUrl.read(prefs)`, so once
  /// resolved the base URL is fixed for the life of the process — which is why
  /// `dev_settings_page` says "Restart the app to apply". A no-op when no
  /// [AppRestarter] is above us (widget tests, and any build with the Dev Tool
  /// compiled out).
  void _apply() {
    if (!_open) return;
    setState(() => _open = false);
    AppRestarter.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    // The Stack is mounted unconditionally so `widget.child` keeps a stable
    // slot in the element tree — moving it between "direct child" and
    // "Stack.children[0]" would deactivate the whole routed subtree and lose
    // its state every time the Dev Tool opens or closes.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_open)
          _DevToolShakeLayer(
            key: kDevToolShakeLayerKey,
            onClose: _close,
            onApply: _apply,
            layerBuilder: widget.layerBuilder,
          ),
      ],
    );
  }
}

/// The opaque Dev Tool layer.
///
/// It carries its own [Navigator] because the host sits ABOVE go_router's
/// Navigator in the tree — without one, `DevToolShell`'s section pushes would
/// find no Navigator ancestor. The nested Navigator also keeps every Dev Tool
/// push inside the layer instead of on the product route stack.
class _DevToolShakeLayer extends StatefulWidget {
  const _DevToolShakeLayer({
    required this.onClose,
    required this.onApply,
    required this.layerBuilder,
    super.key,
  });

  final VoidCallback onClose;
  final VoidCallback onApply;
  final WidgetBuilder layerBuilder;

  @override
  State<_DevToolShakeLayer> createState() => _DevToolShakeLayerState();
}

class _DevToolShakeLayerState extends State<_DevToolShakeLayer> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// The layer's own hero controller.
  ///
  /// `MaterialApp` publishes a single [HeroControllerScope] ABOVE its
  /// `builder` (material/app.dart:1163), and the host is mounted inside that
  /// `builder` — so without this scope the layer's [Navigator] would adopt the
  /// SAME controller as the app's routed Navigator and trip
  /// "A HeroController can not be shared by multiple Navigators" on every
  /// open. Owning one keeps hero transitions working inside the Dev Tool
  /// instead of disabling them with `HeroControllerScope.none`.
  final HeroController _hero = MaterialApp.createMaterialHeroController();

  @override
  void dispose() {
    _hero.dispose();
    super.dispose();
  }

  /// Closes the layer outright, from any depth of the Dev Tool's own stack.
  ///
  /// It deliberately does NOT pop one level first. `X` is labelled "close" and
  /// exists so an accidental shake costs one tap; making it Back meant a user
  /// three pages deep tapped it three times and, each time, stayed inside the
  /// tool they were trying to leave. Navigating BACK within the Dev Tool is
  /// already served by each page's own `AppBar` leading button, which the
  /// nested `Navigator` supplies whenever it can pop.
  void _handleClose() => widget.onClose();

  /// Unlike [_handleClose] this does NOT unwind the Dev Tool's own stack first:
  /// the whole tree is about to be rebuilt, so popping back to the shell would
  /// only add a frame of animation before it disappears.
  void _handleApply() => widget.onApply();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          children: [
            HeroControllerScope(
              controller: _hero,
              child: Navigator(
                key: _navigator,
                onGenerateRoute: (settings) =>
                    MaterialPageRoute<void>(builder: widget.layerBuilder),
              ),
            ),
            Positioned(
              right: Spacing.medium,
              bottom: Spacing.xLarge,
              // NO `tooltip:` ON EITHER CONTROL. `FloatingActionButton` wraps
              // its child in a `Tooltip` iff `tooltip != null`
              // (material/floating_action_button.dart:822-824), and
              // `RawTooltipState.build` asserts `debugCheckHasOverlay`
              // (widgets/raw_tooltip.dart:865). These buttons are SIBLINGS of
              // the layer's Navigator, and the host sits above the app's
              // Navigator — the app's only `Overlay` — so there is no `Overlay`
              // ancestor and the assert would replace the only exit affordances
              // with an `ErrorWidget` on a device that has no hardware back
              // button. `semanticLabel` and the visible label carry the
              // accessible names instead.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Deliberately the LABELLED, wider control, and deliberately
                  // NOT the one at the thumb's resting position: restarting is
                  // the expensive, irreversible-feeling action and must be
                  // chosen on purpose, never hit while reaching for "get me out
                  // of here".
                  FloatingActionButton.extended(
                    key: kDevToolShakeApplyKey,
                    heroTag: null,
                    onPressed: _handleApply,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Apply & Restart'),
                  ),
                  const SizedBox(height: Spacing.small),
                  // `X` keeps its universal meaning — dismiss, change nothing —
                  // and keeps the position the muscle memory already knows.
                  // This is the exit for an accidental shake.
                  FloatingActionButton.small(
                    key: kDevToolShakeCloseKey,
                    heroTag: null,
                    onPressed: _handleClose,
                    child: const Icon(
                      Icons.close,
                      semanticLabel: 'Close Dev Tool without restarting',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
