import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../dev_flags.dart';
import 'diag.dart';
import 'diag_redaction.dart';

/// GESTURE-LOG hook — records taps/gestures the Flutter engine receives,
/// INCLUDING adb/Maestro-injected taps that `getevent` (kernel `/dev/input`)
/// cannot see, onto the `[jeeb-diag]` logcat stream a host recorder tails.
///
/// Injected taps reach Android's InputDispatcher → the Flutter engine, so a
/// root [Listener] sees them exactly like a real finger. From the hit position
/// we read the INTERNAL semantics tree (reliable even when the device's
/// EXPORTED a11y tree is broken) to attach Maestro-ready selectors — the
/// `SemanticsProperties.identifier` (`id`) and the visible `text` — so a logged
/// gesture can be replayed as a `tapOn: { id: … }` / `tapOn: { text: … }` step.
///
/// Master-gated on [kDevAffordancesAllowed]: in a production release binary that
/// flag is a compile-time `false`, so [enabled] folds to `false`, the root
/// [GestureLogListener] is never wired (see `app.dart`), and the whole hook is
/// tree-shaken out. Default OFF at runtime; a test build can start it ON with
/// `--dart-define=JEEB_GESTURE_LOG_DEFAULT=true`. Flip live from the Dev Tool.
class GestureLog {
  GestureLog._();

  /// The process-wide instance (the hook is stateless beyond its on/off flag).
  static final GestureLog instance = GestureLog._();

  /// Build-time default for [enabled]. A normal Dev-Tool build starts OFF; a
  /// dedicated automated-test build starts ON via the dart-define.
  static const bool _defaultEnabled =
      bool.fromEnvironment('JEEB_GESTURE_LOG_DEFAULT', defaultValue: false);

  /// Live on/off, listenable so the Dev Tool switch rebuilds when it flips and
  /// the state survives navigation. Read on every pointer-up via [enabled].
  final ValueNotifier<bool> enabledListenable =
      ValueNotifier<bool>(_defaultEnabled);

  /// True only when logging is toggled on AND dev affordances are compiled in.
  /// The [kDevAffordancesAllowed] conjunct is a const `false` in production, so
  /// this getter (and every caller behind it) is tree-shaken from the release.
  bool get enabled => kDevAffordancesAllowed && enabledListenable.value;

  set enabled(bool value) => enabledListenable.value = value;
}

// ── Gesture classification thresholds ──────────────────────────────────────
/// Displacement (logical px) above which a press is reclassified as a swipe.
const double _kMoveThresholdPx = 40;

/// Press duration (ms) at/above which a stationary press is a long-press.
const int _kLongPressMs = 400;

/// Max ancestors walked up from the hit element when gathering identity.
const int _kAncestorBudget = 40;

/// Max descendants scanned for a fallback `Text` caption.
const int _kDescendantBudget = 40;

/// Max characters kept from a visible-text selector before truncation.
const int _kMaxTextChars = 40;

/// A single "word" of at least this length in a caption is treated as a secret
/// (e.g. an accidentally-rendered JWT/API key) and fingerprinted via redaction.
const int _kSecretWordLen = 12;

const String _kTap = 'tap';
const String _kLongPress = 'long-press';
const String _kSwipe = 'swipe';
const String _kTextInput = 'text-input';

/// Root, translucent, pass-through [Listener] that records one gesture per
/// pointer on pointer-UP. Wrapped around the app child in `app.dart`'s builder
/// ONLY when [kDevAffordancesAllowed] — additive and non-consuming, so with the
/// hook disabled or not compiled the app behaves byte-identically.
class GestureLogListener extends StatefulWidget {
  const GestureLogListener({required this.child, super.key});

  final Widget child;

  @override
  State<GestureLogListener> createState() => _GestureLogListenerState();
}

class _GestureLogListenerState extends State<GestureLogListener> {
  /// In-flight presses keyed by pointer id, so concurrent touches (multi-touch)
  /// stay distinct and a scroll never leaks per-move events — we emit on UP.
  final Map<int, _GestureTrack> _tracks = <int, _GestureTrack>{};

  @override
  Widget build(BuildContext context) {
    // translucent => never absorbs; children still receive their own events.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }

  void _onDown(PointerDownEvent event) {
    if (!GestureLog.instance.enabled) return;
    _tracks[event.pointer] = _GestureTrack(event.position, event.timeStamp);
  }

  void _onMove(PointerMoveEvent event) =>
      _tracks[event.pointer]?.observe(event.position);

  void _onCancel(PointerCancelEvent event) => _tracks.remove(event.pointer);

  void _onUp(PointerUpEvent event) {
    final track = _tracks.remove(event.pointer);
    if (track == null || !GestureLog.instance.enabled) return;
    _emit(track, event);
  }

  /// Coalesced emit: exactly one diag line per completed gesture. Fail-soft —
  /// any inspection error degrades to a coordinate-only record, never a throw.
  void _emit(_GestureTrack track, PointerUpEvent up) {
    _HitInfo? hit;
    try {
      hit = _inspect(up.position);
    } catch (_) {
      hit = null;
    }
    final moved = math.max(
      track.maxDistance,
      (up.position - track.downPosition).distance,
    );
    final kind = _classify(moved, up.timeStamp - track.downTime, hit);
    final dpr = _devicePixelRatio();
    Diag.gesture(
      type: kind,
      x: (up.position.dx * dpr).round(),
      y: (up.position.dy * dpr).round(),
      screen: Diag.currentScreen,
      id: hit?.id,
      text: hit?.text,
      target: hit?.target,
      key: hit?.key,
    );
  }

  /// Hit-tests the app subtree at [globalPosition] and derives widget identity.
  /// Uses this widget's own [RenderBox] as the anchor, so it is view-agnostic
  /// and works for adb/Maestro-injected pointers just like real ones.
  _HitInfo? _inspect(Offset globalPosition) {
    final anchor = context.findRenderObject();
    if (anchor is! RenderBox || !anchor.hasSize) return null;
    final result = BoxHitTestResult();
    anchor.hitTest(result, position: anchor.globalToLocal(globalPosition));
    final hit = _deepestElement(result);
    if (hit == null) return null;
    return (_AncestorProbe()..scan(hit)).toInfo();
  }

  /// The deepest (front-most) element in the hit path, mapping each hit render
  /// object back to its owning [Element].
  Element? _deepestElement(BoxHitTestResult result) {
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderObject) {
        final element = _elementOf(target);
        if (element != null) return element;
      }
    }
    return null;
  }

  /// Maps a [RenderObject] to its [Element]. Debug builds carry a [DebugCreator]
  /// (O(1)); profile Dev-Tool builds fall back to a bounded subtree search.
  Element? _elementOf(RenderObject renderObject) {
    final creator = renderObject.debugCreator;
    if (creator is DebugCreator) return creator.element;
    return _searchElement(renderObject);
  }

  /// Finds the [Element] owning [target] by walking this widget's own subtree
  /// (bounded to the app content below the listener). Only runs on pointer-up.
  Element? _searchElement(RenderObject target) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (identical(element.renderObject, target)) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  double _devicePixelRatio() {
    final query = MediaQuery.maybeOf(context);
    if (query != null) return query.devicePixelRatio;
    return View.of(context).devicePixelRatio;
  }
}

/// Per-pointer press state: where/when it went down and how far it has drifted.
class _GestureTrack {
  _GestureTrack(this.downPosition, this.downTime);

  final Offset downPosition;
  final Duration downTime;
  double maxDistance = 0;

  void observe(Offset position) {
    final distance = (position - downPosition).distance;
    if (distance > maxDistance) maxDistance = distance;
  }
}

/// Derived widget identity at the tap point. All fields are best-effort and
/// null when unknown — never fabricated.
class _HitInfo {
  _HitInfo({this.id, this.text, this.target, this.key, this.isTextInput = false});

  /// `SemanticsProperties.identifier` — the value Flutter maps to the Android
  /// view resource-id, i.e. Maestro's `tapOn: { id: … }`. Never redacted.
  final String? id;

  /// Nearest visible text (semantics label or a short `Text` descendant),
  /// already redacted. Null for text inputs — a field's content never logs.
  final String? text;

  /// Widget runtimeType (debugging aid, e.g. `ElevatedButton`).
  final String? target;

  /// Nearest `ValueKey`/`GlobalObjectKey` string (debugging aid).
  final String? key;

  final bool isTextInput;
}

/// Classifies a completed gesture. Motion wins first (a swipe is a swipe even
/// on a field); then a press landing on a text input; then duration.
String _classify(double moved, Duration elapsed, _HitInfo? hit) {
  if (moved > _kMoveThresholdPx) return _kSwipe;
  if (hit?.isTextInput ?? false) return _kTextInput;
  if (elapsed.inMilliseconds >= _kLongPressMs) return _kLongPress;
  return _kTap;
}

/// Walks up from the hit element gathering identity (runtimeType, key, semantics
/// identifier + label, editable-ness), then falls back to a descendant `Text`
/// for the visible-text selector. Bounded and allocation-light.
class _AncestorProbe {
  String? id;
  String? label;
  String? target;
  String? key;
  Element? anchor;
  bool isTextInput = false;
  int _seen = 0;

  void scan(Element hit) {
    _consider(hit);
    hit.visitAncestorElements(_consider);
    label ??= _firstText(anchor ?? hit);
  }

  bool _consider(Element element) {
    final widget = element.widget;
    _captureTarget(element, widget);
    _captureKey(widget);
    _captureSemantics(element, widget);
    if (widget is EditableText) isTextInput = true;
    _seen++;
    return _seen < _kAncestorBudget && !_complete;
  }

  bool get _complete =>
      target != null && key != null && id != null && label != null;

  void _captureTarget(Element element, Widget widget) {
    if (target != null) return;
    final name = widget.runtimeType.toString();
    if (!_isMeaningfulType(name)) return;
    target = name;
    anchor = element;
  }

  void _captureKey(Widget widget) {
    if (key != null) return;
    final widgetKey = widget.key;
    if (widgetKey is ValueKey) {
      key = widgetKey.value?.toString();
    } else if (widgetKey is GlobalObjectKey) {
      key = widgetKey.value.toString();
    }
  }

  /// Reads the semantics identifier + label at this node: first from a
  /// [Semantics] WIDGET's properties (available in every build mode), then from
  /// the merged [SemanticsNode] via `debugSemantics` when present (debug builds
  /// — the most accurate read of the internal tree). Fail-soft.
  void _captureSemantics(Element element, Widget widget) {
    if (widget is Semantics) {
      id ??= _nonEmpty(widget.properties.identifier);
      label ??= _nonEmpty(widget.properties.label);
    }
    if (id != null && label != null) return;
    final node = element.renderObject?.debugSemantics;
    if (node == null) return;
    final data = node.getSemanticsData();
    id ??= _nonEmpty(data.identifier);
    label ??= _nonEmpty(data.label);
  }

  _HitInfo toInfo() => _HitInfo(
        id: id,
        // A field's visible text may be its typed value — never log it. id +
        // coordinates still let Maestro target the field.
        text: isTextInput ? null : _redactText(label),
        target: target,
        key: key,
        isTextInput: isTextInput,
      );
}

/// Widget runtimeTypes that carry no identity value — skipped so `target` names
/// the real interactive/content widget, not a framework wrapper.
const Set<String> _kNoiseTypes = <String>{
  'Listener', 'RawGestureDetector', 'GestureDetector', 'Semantics',
  'MergeSemantics', 'MouseRegion', 'IgnorePointer', 'AbsorbPointer',
  'Focus', 'FocusScope', 'Actions', 'Shortcuts', 'RepaintBoundary',
  'Padding', 'Center', 'Align', 'SizedBox', 'ColoredBox', 'DecoratedBox',
  'ConstrainedBox', 'Container', 'Expanded', 'Flexible', 'Positioned',
  'KeyedSubtree', 'Builder', 'Directionality', 'DefaultTextStyle',
  'PhysicalModel', 'PhysicalShape', 'ClipRRect', 'ClipRect', 'Transform',
};

bool _isMeaningfulType(String name) =>
    !name.startsWith('_') && !_kNoiseTypes.contains(name);

/// First non-empty `Text` caption under [root], bounded by [_kDescendantBudget].
String? _firstText(Element root) {
  String? found;
  var budget = _kDescendantBudget;
  void visit(Element element) {
    if (found != null || budget-- <= 0) return;
    final widget = element.widget;
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.isNotEmpty) {
        found = data;
        return;
      }
    }
    element.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found;
}

/// Collapses whitespace, truncates, and fingerprints any secret-length word via
/// [DiagRedaction] so a label that accidentally holds a token cannot leak.
String? _redactText(String? raw) {
  if (raw == null) return null;
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return null;
  final capped = collapsed.length > _kMaxTextChars
      ? '${collapsed.substring(0, _kMaxTextChars)}…'
      : collapsed;
  return capped
      .split(' ')
      .map((word) =>
          word.length >= _kSecretWordLen ? DiagRedaction.redactToken(word) : word)
      .join(' ');
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;
