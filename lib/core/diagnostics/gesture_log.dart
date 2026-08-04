import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../dev_flags.dart';
import 'diag.dart';
import 'diag_redaction.dart';

class GestureLog {
  GestureLog._();

  static final GestureLog instance = GestureLog._();

  static const bool _defaultEnabled =
      bool.fromEnvironment('JEEB_GESTURE_LOG_DEFAULT', defaultValue: false);

  final ValueNotifier<bool> enabledListenable =
      ValueNotifier<bool>(_defaultEnabled);

  bool get enabled => kDevAffordancesAllowed && enabledListenable.value;

  set enabled(bool value) => enabledListenable.value = value;
}

const double _kMoveThresholdPx = 40;

const int _kLongPressMs = 400;

const int _kAncestorBudget = 40;

const int _kDescendantBudget = 40;

const int _kMaxTextChars = 40;

const int _kSecretWordLen = 12;

const String _kTap = 'tap';
const String _kLongPress = 'long-press';
const String _kSwipe = 'swipe';
const String _kTextInput = 'text-input';

class GestureLogListener extends StatefulWidget {
  const GestureLogListener({required this.child, super.key});

  final Widget child;

  @override
  State<GestureLogListener> createState() => _GestureLogListenerState();
}

class _GestureLogListenerState extends State<GestureLogListener> {
  final Map<int, _GestureTrack> _tracks = <int, _GestureTrack>{};

  SemanticsHandle? _semanticsHandle;

  @override
  void initState() {
    super.initState();
    GestureLog.instance.enabledListenable.addListener(_syncSemantics);
    _syncSemantics();
  }

  @override
  void dispose() {
    GestureLog.instance.enabledListenable.removeListener(_syncSemantics);
    _releaseSemantics();
    super.dispose();
  }

  void _syncSemantics() {
    if (GestureLog.instance.enabled) {
      _acquireSemantics();
    } else {
      _releaseSemantics();
    }
  }

  void _acquireSemantics() {
    if (_semanticsHandle != null) return;
    try {
      _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    } catch (_) {
      _semanticsHandle = null; // fail-soft: a dev tool must never crash the app.
    }
  }

  void _releaseSemantics() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
  }

  @override
  Widget build(BuildContext context) {
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
      idInner: hit?.idInner,
    );
  }

  _HitInfo? _inspect(Offset globalPosition) {
    final anchor = context.findRenderObject();
    if (anchor is! RenderBox || !anchor.hasSize) return null;
    final result = BoxHitTestResult();
    anchor.hitTest(result, position: anchor.globalToLocal(globalPosition));
    final hit = _deepestElement(result);
    if (hit == null) return null;
    return (_AncestorProbe()..scan(hit)).toInfo();
  }

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

  Element? _elementOf(RenderObject renderObject) {
    final creator = renderObject.debugCreator;
    if (creator is DebugCreator) return creator.element;
    return _searchElement(renderObject);
  }

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

class _HitInfo {
  _HitInfo({
    this.id,
    this.idInner,
    this.text,
    this.target,
    this.key,
    this.isTextInput = false,
  });

  final String? id;

  final String? idInner;

  final String? text;

  final String? target;

  final String? key;

  final bool isTextInput;
}

String _classify(double moved, Duration elapsed, _HitInfo? hit) {
  if (moved > _kMoveThresholdPx) return _kSwipe;
  if (hit?.isTextInput ?? false) return _kTextInput;
  if (elapsed.inMilliseconds >= _kLongPressMs) return _kLongPress;
  return _kTap;
}

class _AncestorProbe {
  String? _idExposedNode;

  String? _idExposedWidget;

  String? _idInner;

  String? label;
  String? target;
  String? key;
  Element? anchor;
  bool isTextInput = false;
  int _seen = 0;

  String? get id => _idExposedNode ?? _idExposedWidget ?? _idInner;

  String? get idInner {
    final resolved = id;
    return (_idInner != null && _idInner != resolved) ? _idInner : null;
  }

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
    return _seen < _kAncestorBudget;
  }

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

  void _captureSemantics(Element element, Widget widget) {
    if (widget is Semantics) {
      final widgetId = _nonEmpty(widget.properties.identifier);
      if (widgetId != null) {
        _idInner ??= widgetId; // innermost annotation (first seen climbing up)
        _idExposedWidget = widgetId; // outermost annotation (last write wins)
      }
      label ??= _nonEmpty(widget.properties.label);
    }

    final node = element.renderObject?.debugSemantics;
    if (node != null) {
      final data = node.getSemanticsData();
      final nodeId = _nonEmpty(data.identifier);
      if (nodeId != null && !node.isMergedIntoParent) {
        _idExposedNode ??= nodeId;
      }
      label ??= _nonEmpty(data.label);
    }
  }

  _HitInfo toInfo() => _HitInfo(
        id: id,
        idInner: idInner,
        text: isTextInput ? null : _redactText(label),
        target: target,
        key: key,
        isTextInput: isTextInput,
      );
}

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
