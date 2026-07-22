import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show BuildContext, FocusManager, FocusNode;

import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import '../secret_redactor.dart';

/// USER-INTERACTION capture — architecture contract Module 4.
///
/// [ObsInteractionObserver] is a process-global singleton that watches two
/// ALREADY-PUBLISHED, app-wide streams instead of wrapping the widget tree:
///
///  * every pointer event, via a PASSIVE global route on
///    [GestureBinding.pointerRouter] (`addGlobalRoute` — the exact mechanism
///    Flutter itself documents for app-wide pointer observation without
///    participating in, or altering, gesture-arena resolution);
///  * every focus change, via [FocusManager.instance]'s [ChangeNotifier]
///    listener API.
///
/// Both are purely observational: nothing here ever consumes, cancels, or
/// short-circuits an event, so installing/uninstalling this observer can
/// NEVER change what the rest of the app sees or how it behaves — it only
/// watches. This is why the contract mandates NO widget-tree wrapping for
/// this module (contrast the top-level task description's illustrative
/// `Listener`/`GestureDetector`-wrapper sketch, which a global route
/// supersedes with an equivalent, strictly-additive alternative).
///
/// ## Target resolution — the always-published semantics tree
///
/// `main.dart` holds a [SemanticsHandle] for the process lifetime (see its
/// top-of-file doc), so the semantics tree is always populated, in every
/// build mode — not just when an accessibility service is active. This
/// observer exploits that to resolve a tap's target `identifier`/`label`
/// (and a focused field's "is this a text field / is it obscured" flags)
/// by walking [SemanticsNode]s and accumulating [SemanticsNode.transform]
/// from the root down — the identical technique the framework's own
/// (built-in, first-party) `SemanticsDebugger` overlay uses to paint node
/// outlines at their true screen position. See [_bestMatch].
///
/// ## Redaction — hard rules, not toggles
///
///  * A target's semantics `label` is ALWAYS passed through
///    [SecretRedactor.redactLabel] before it reaches an event field.
///  * Keystrokes and raw text-field contents are NEVER captured. A
///    `text_submit` event's `valuePreview` is either the literal
///    [SecretRedactor.redacted] token (sensitive/obscured fields) or a
///    LENGTH-only summary such as `'12 chars'` (see [_resolveValuePreview])
///    — the live [SemanticsNode.value] string is read only transiently, to
///    take its `.length`, and is never stored, logged, or forwarded.
///
/// ## Gating
///
/// Every public/callback entry point opens with [_shouldCapture]: a hard
/// no-op unless the tool is compiled in ([kObsCompiledIn]) AND runtime
/// recording is enabled ([ObservabilityConfig.enabled]) AND the interaction
/// signal itself is toggled on. [install] additionally short-circuits on
/// [kObsCompiledIn] so even a direct, mistaken call in a production build
/// touches neither [GestureBinding] nor [FocusManager].
final class ObsInteractionObserver {
  ObsInteractionObserver._();

  /// The app-global singleton. Wiring point W4
  /// (`lib/app/bootstrap.dart` → `Bootstrap.minimal()`) calls [install] once,
  /// guarded by `if (kObsCompiledIn) { if (ObservabilityConfig.instance
  /// .captureInteractions) ObsInteractionObserver.instance.install(); }`.
  static final ObsInteractionObserver instance = ObsInteractionObserver._();

  /// Max travel (logical px) from the down point before a gesture is a
  /// [_Gesture.drag] rather than a tap-family gesture. Reuses Flutter's own
  /// touch-slop constant — the same threshold its `GestureDetector` family
  /// (e.g. `TapGestureRecognizer`) uses to distinguish a tap from a drag.
  static const double _dragSlop = kTouchSlop;

  /// Min held duration (down → up) for an otherwise-still gesture to count
  /// as a long press. Reuses Flutter's own [kLongPressTimeout].
  static const Duration _longPressDuration = kLongPressTimeout;

  /// Max gap between one tap's touch-down and the next tap's touch-down for
  /// the pair to be a [_Gesture.doubleTap]. Reuses [kDoubleTapTimeout].
  static const Duration _doubleTapGap = kDoubleTapTimeout;

  /// Max distance (logical px) between two taps' down points for them to
  /// still count as the same double-tap. Reuses [kDoubleTapSlop].
  static const double _doubleTapDistance = kDoubleTapSlop;

  /// Field-name keywords (lower-cased substring match) that mark a text
  /// field as sensitive even when the widget didn't set `obscureText`
  /// (e.g. a plainly-visible OTP field). This is a LOCAL heuristic over
  /// human-readable semantics *labels*; it is intentionally separate from
  /// [SecretRedactor.isSensitiveKey], which matches exact *map keys*
  /// (`'otp_code'`), not prose (`'Enter your OTP code'`).
  static const List<String> _sensitiveFieldKeywords = <String>[
    'password',
    'passcode',
    'otp',
    'pin',
    'cvv',
    'secret',
  ];

  bool _installed = false;
  final Map<int, _PendingPointer> _pendingPointers = <int, _PendingPointer>{};
  _CompletedTap? _lastTap;
  FocusNode? _lastFocusNode;
  _ActiveTextField? _activeTextField;

  /// True once [install] has armed the pointer route + focus listener.
  @visibleForTesting
  bool get isInstalled => _installed;

  /// Arms a passive global pointer route and a global focus listener.
  /// Additive only: no widget wrapping, no change to hit-testing, gesture
  /// arenas, or focus behaviour — this observer only WATCHES events already
  /// flowing through the bindings. Idempotent; hard no-op when
  /// [kObsCompiledIn] is false, so a mistaken call in a production build
  /// touches neither [GestureBinding] nor [FocusManager].
  void install() {
    if (_installed || !kObsCompiledIn) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    FocusManager.instance.addListener(_onFocusChange);
    _installed = true;
  }

  /// Reverses [install]. Not called in production; exposed for tests and
  /// any future dev-UI "pause capture" affordance.
  void uninstall() {
    if (!_installed) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    FocusManager.instance.removeListener(_onFocusChange);
    _installed = false;
    _resetState();
  }

  /// Test-only: clears in-flight gesture/focus tracking state without
  /// touching [isInstalled]. Call from a test `tearDown`.
  @visibleForTesting
  void resetForTest() => _resetState();

  void _resetState() {
    _pendingPointers.clear();
    _lastTap = null;
    _lastFocusNode = null;
    _activeTextField = null;
  }

  static bool _shouldCapture() =>
      Observability.instance.recording &&
      Observability.instance.config.signalEnabled(ObsEventType.interaction);

  // ── Pointer: tap / double_tap / long_press / drag ───────────────────────

  /// Routed for EVERY pointer event in the app (see [install]). Total: a
  /// capture mistake here can never break input handling.
  void _onPointerEvent(PointerEvent event) {
    try {
      if (event is PointerDownEvent) {
        _onPointerDown(event);
      } else if (event is PointerMoveEvent) {
        _onPointerMove(event);
      } else if (event is PointerUpEvent) {
        _onPointerUp(event);
      } else if (event is PointerCancelEvent) {
        _pendingPointers.remove(event.pointer);
      }
    } catch (_) {
      // Fail-soft by contract — a capture mistake can never break input.
    }
  }

  /// Resolves the (best-effort) target ONCE, at touch-down — cheaper than
  /// re-resolving on every move/up, and "where the user first touched" is
  /// the more useful target signal for a drag/scroll anyway.
  void _onPointerDown(PointerDownEvent event) {
    if (!_shouldCapture()) return;
    final target = _describeTarget(_hitTestSemantics(event.position));
    _pendingPointers[event.pointer] = _PendingPointer(
      downTime: event.timeStamp,
      downPosition: event.position,
      targetId: target.id,
      targetLabel: target.label,
    );
  }

  /// Cheap running-max travel update; a no-op when the pointer wasn't
  /// tracked at down-time (recording was off, or an untracked pointer id).
  void _onPointerMove(PointerMoveEvent event) {
    _pendingPointers[event.pointer]?.trackTravel(event.position);
  }

  /// Finalizes + emits ONE interaction event per completed pointer gesture.
  /// The map entry is ALWAYS removed (even when not currently capturing) so
  /// toggling recording off mid-gesture can never leak pending state.
  void _onPointerUp(PointerUpEvent event) {
    final pending = _pendingPointers.remove(event.pointer);
    if (pending == null || !_shouldCapture()) return;
    pending.trackTravel(event.position);
    Observability.instance.recordInteraction(
      gesture: _classify(pending, event.timeStamp),
      targetId: pending.targetId,
      targetLabel: pending.targetLabel,
      screen: Observability.instance.currentScreen,
      dx: pending.downPosition.dx.round(),
      dy: pending.downPosition.dy.round(),
    );
  }

  /// Classifies one completed down→up cycle from its accumulated timing and
  /// travel. A drag or a long press always breaks a pending double-tap
  /// chain; only a fresh, still, quick tap can pair with the next one.
  String _classify(_PendingPointer pending, Duration upTime) {
    if (pending.maxTravel > _dragSlop) {
      _lastTap = null;
      return _Gesture.drag;
    }
    if (upTime - pending.downTime >= _longPressDuration) {
      _lastTap = null;
      return _Gesture.longPress;
    }
    if (_isDoubleTap(pending)) {
      _lastTap = null;
      return _Gesture.doubleTap;
    }
    _lastTap = _CompletedTap(pending.downTime, pending.downPosition);
    return _Gesture.tap;
  }

  bool _isDoubleTap(_PendingPointer pending) {
    final last = _lastTap;
    if (last == null) return false;
    final gap = pending.downTime - last.time;
    final distance = (pending.downPosition - last.position).distance;
    return gap >= Duration.zero &&
        gap <= _doubleTapGap &&
        distance <= _doubleTapDistance;
  }

  // ── Focus: text_focus / text_submit ─────────────────────────────────────

  /// [FocusManager] listener signature is a bare [VoidCallback]; the changed
  /// node is read back via [FocusManager.primaryFocus].
  void _onFocusChange() {
    if (!_shouldCapture()) return;
    try {
      _handleFocusChange();
    } catch (_) {
      // Fail-soft by contract.
    }
  }

  void _handleFocusChange() {
    final newFocus = FocusManager.instance.primaryFocus;
    if (identical(newFocus, _lastFocusNode)) return;
    _lastFocusNode = newFocus;
    _submitPreviousIfLeaving(newFocus);
    _focusNewTextFieldIfAny(newFocus);
  }

  /// Emits `text_submit` for the previously-active field the moment focus
  /// moves away from it (including to null) — the closest cheaply-available
  /// global proxy for "editing finished" without owning each field's
  /// `onSubmitted`/`onEditingComplete` callback (which would require
  /// widget-tree wrapping, ruled out by this module's design).
  void _submitPreviousIfLeaving(FocusNode? newFocus) {
    final previous = _activeTextField;
    if (previous == null || identical(newFocus, previous.node)) return;
    _activeTextField = null;
    Observability.instance.recordInteraction(
      gesture: _Gesture.textSubmit,
      targetId: previous.targetId,
      targetLabel: previous.targetLabel,
      screen: Observability.instance.currentScreen,
      valuePreview: _resolveValuePreview(previous),
    );
  }

  void _focusNewTextFieldIfAny(FocusNode? newFocus) {
    if (newFocus == null) return;
    final field = _resolveTextField(newFocus);
    if (field == null) return;
    _activeTextField = field;
    Observability.instance.recordInteraction(
      gesture: _Gesture.textFocus,
      targetId: field.targetId,
      targetLabel: field.targetLabel,
      screen: Observability.instance.currentScreen,
    );
  }

  /// Resolves [node] to its semantics info via a probe point (the render
  /// object's global center) fed through the SAME semantics hit-test used
  /// for pointer taps. Returns null for a non-text-field focus target (a
  /// button, a checkbox, a scope, …) — this module only reports on
  /// EDITABLE fields, never generic focus traversal.
  _ActiveTextField? _resolveTextField(FocusNode node) {
    final probePoint = _globalCenterOf(node.context);
    if (probePoint == null) return null;
    final semanticsNode = _hitTestSemantics(probePoint);
    if (semanticsNode == null || !semanticsNode.flagsCollection.isTextField) {
      return null;
    }
    final target = _describeTarget(semanticsNode);
    return _ActiveTextField(
      node: node,
      probePoint: probePoint,
      targetId: target.id,
      targetLabel: target.label,
      sensitive: _isFieldSensitive(semanticsNode),
    );
  }

  /// True for an obscured field (`TextField(obscureText: true)` — covers
  /// passwords/PINs/OTP entry rendered as dots) or one whose semantics
  /// label/identifier reads as sensitive per [_sensitiveFieldKeywords].
  static bool _isFieldSensitive(SemanticsNode node) =>
      node.flagsCollection.isObscured ||
      _looksSensitive(node.label) ||
      _looksSensitive(node.identifier);

  /// Never returns raw field text — only [SecretRedactor.redacted]
  /// (sensitive/obscured fields) or a LENGTH-only summary. [SemanticsNode
  /// .value] (the field's live text, mirrored into semantics for screen
  /// readers) is read ONLY to take its `.length`; the string itself is
  /// discarded immediately and never stored, logged, or forwarded.
  String? _resolveValuePreview(_ActiveTextField field) {
    if (field.sensitive) return SecretRedactor.redacted;
    final node = _hitTestSemantics(field.probePoint);
    if (node == null || !node.flagsCollection.isTextField) return null;
    final length = node.value.length;
    return '$length chars';
  }

  static bool _looksSensitive(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return _sensitiveFieldKeywords.any(lower.contains);
  }

  // ── Shared: semantics-tree target resolution ────────────────────────────

  /// The render object's global-coordinate center point — a cheap, always
  /// public (non-debug-gated) way to turn a [FocusNode] into a probe point
  /// for [_hitTestSemantics], via [RenderBox.localToGlobal].
  static Offset? _globalCenterOf(BuildContext? context) {
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  /// Extracts a target's `identifier`/redacted `label`, treating empty
  /// strings (Flutter's "unset" convention for these fields) as absent.
  static ({String? id, String? label}) _describeTarget(SemanticsNode? node) {
    if (node == null) return (id: null, label: null);
    final id = node.identifier;
    final label = node.label;
    return (
      id: id.isEmpty ? null : id,
      label: label.isEmpty ? null : SecretRedactor.redactLabel(label),
    );
  }

  /// Best-effort semantics-tree lookup for [globalPosition]. Total: any
  /// framework surprise (a detached tree, a mid-frame mutation, no
  /// semantics client attached) degrades to `null` rather than throwing
  /// into a pointer/focus hot path.
  static SemanticsNode? _hitTestSemantics(Offset globalPosition) {
    try {
      return _bestMatch(globalPosition);
    } catch (_) {
      return null;
    }
  }

  /// The smallest-area [SemanticsNode] (across every attached [RenderView]
  /// — normally exactly one, in Jeeb's single-window app) whose global rect
  /// contains [point]. Smallest-area, rather than paint/z-order, is a
  /// deliberately simple "most specific" heuristic: it needs no assumption
  /// about sibling paint order and degrades gracefully when nodes overlap.
  ///
  /// [point] arrives in LOGICAL pixels (both [PointerEvent.position] and
  /// [RenderBox.localToGlobal] are logical-pixel APIs), but a [RenderView]'s
  /// semantics geometry is rooted in PHYSICAL pixels — its `child`'s
  /// [SemanticsNode.transform] IS [ViewConfiguration.toMatrix], the
  /// `devicePixelRatio` scale — because the native accessibility trees this
  /// feeds (TalkBack/VoiceOver) are physical-pixel-based. Each view's own
  /// [RenderView.configuration] converts [point] into that view's physical
  /// space before walking its tree, so this is correct even across views
  /// with different device pixel ratios.
  static SemanticsNode? _bestMatch(Offset point) {
    _Match? best;
    for (final view in RendererBinding.instance.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;
      final physicalPoint = point * view.configuration.devicePixelRatio;
      best = _visit(root, Matrix4.identity(), physicalPoint, best);
    }
    return best?.node;
  }

  /// Accumulates [SemanticsNode.transform] from parent to child (each
  /// node's transform maps ITS coordinate system into its PARENT's, per the
  /// framework doc) — the identical technique the built-in
  /// `SemanticsDebugger` overlay uses when painting node outlines, here
  /// applied to matrices instead of a [Canvas] so it can run outside a
  /// paint callback.
  static _Match? _visit(
    SemanticsNode node,
    Matrix4 ancestorTransform,
    Offset point,
    _Match? best,
  ) {
    final transform = node.transform == null
        ? ancestorTransform
        : ancestorTransform.multiplied(node.transform!);
    final rect = MatrixUtils.transformRect(transform, node.rect);
    var next = best;
    if (rect.contains(point)) {
      final area = rect.width * rect.height;
      if (next == null || area < next.area) next = _Match(node, area);
    }
    node.visitChildren((child) {
      next = _visit(child, transform, point, next);
      return true;
    });
    return next;
  }
}

/// One pointer's in-flight down→up gesture state, keyed by
/// [PointerEvent.pointer] so concurrent touches classify independently.
class _PendingPointer {
  _PendingPointer({
    required this.downTime,
    required this.downPosition,
    required this.targetId,
    required this.targetLabel,
  });

  final Duration downTime;
  final Offset downPosition;
  final String? targetId;
  final String? targetLabel;

  /// Running max distance from [downPosition] seen across move/up events.
  double maxTravel = 0;

  void trackTravel(Offset current) {
    final distance = (current - downPosition).distance;
    if (distance > maxTravel) maxTravel = distance;
  }
}

/// A completed tap's down time/position, kept only long enough to decide
/// whether the NEXT tap pairs with it into a `double_tap`.
class _CompletedTap {
  const _CompletedTap(this.time, this.position);

  final Duration time;
  final Offset position;
}

/// The currently-focused text field's resolved (redacted) identity, cached
/// at focus-GAIN time so focus-LOSS can emit `text_submit` even if the
/// field's widget is mid-teardown by then.
class _ActiveTextField {
  const _ActiveTextField({
    required this.node,
    required this.probePoint,
    required this.targetId,
    required this.targetLabel,
    required this.sensitive,
  });

  final FocusNode node;
  final Offset probePoint;
  final String? targetId;
  final String? targetLabel;
  final bool sensitive;
}

/// A hit-test candidate: the node and its global-rect area (smaller wins).
class _Match {
  const _Match(this.node, this.area);

  final SemanticsNode node;
  final double area;
}

/// The [ObsInteractionEvent.gesture] vocabulary this observer emits —
/// mirrors the doc comment on `ObsInteractionEvent.gesture` verbatim.
abstract final class _Gesture {
  static const String tap = 'tap';
  static const String doubleTap = 'double_tap';
  static const String longPress = 'long_press';
  static const String drag = 'drag';
  static const String textFocus = 'text_focus';
  static const String textSubmit = 'text_submit';
}
