import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show BuildContext, FocusManager, FocusNode;

import '../model/obs_event.dart';
import '../observability.dart';
import '../observability_config.dart';
import '../secret_redactor.dart';

final class ObsInteractionObserver {
  ObsInteractionObserver._();

  static final ObsInteractionObserver instance = ObsInteractionObserver._();

  static const double _dragSlop = kTouchSlop;

  static const Duration _longPressDuration = kLongPressTimeout;

  static const Duration _doubleTapGap = kDoubleTapTimeout;

  static const double _doubleTapDistance = kDoubleTapSlop;

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

  @visibleForTesting
  bool get isInstalled => _installed;

  void install() {
    if (_installed || !kObsCompiledIn) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    FocusManager.instance.addListener(_onFocusChange);
    _installed = true;
  }

  void uninstall() {
    if (!_installed) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    FocusManager.instance.removeListener(_onFocusChange);
    _installed = false;
    _resetState();
  }

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
    }
  }

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

  void _onPointerMove(PointerMoveEvent event) {
    _pendingPointers[event.pointer]?.trackTravel(event.position);
  }

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


  void _onFocusChange() {
    if (!_shouldCapture()) return;
    try {
      _handleFocusChange();
    } catch (_) {
    }
  }

  void _handleFocusChange() {
    final newFocus = FocusManager.instance.primaryFocus;
    if (identical(newFocus, _lastFocusNode)) return;
    _lastFocusNode = newFocus;
    _submitPreviousIfLeaving(newFocus);
    _focusNewTextFieldIfAny(newFocus);
  }

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

  static bool _isFieldSensitive(SemanticsNode node) =>
      node.flagsCollection.isObscured ||
      _looksSensitive(node.label) ||
      _looksSensitive(node.identifier);

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


  static Offset? _globalCenterOf(BuildContext? context) {
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  static ({String? id, String? label}) _describeTarget(SemanticsNode? node) {
    if (node == null) return (id: null, label: null);
    final id = node.identifier;
    final label = node.label;
    return (
      id: id.isEmpty ? null : id,
      label: label.isEmpty ? null : SecretRedactor.redactLabel(label),
    );
  }

  static SemanticsNode? _hitTestSemantics(Offset globalPosition) {
    try {
      return _bestMatch(globalPosition);
    } catch (_) {
      return null;
    }
  }

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

  double maxTravel = 0;

  void trackTravel(Offset current) {
    final distance = (current - downPosition).distance;
    if (distance > maxTravel) maxTravel = distance;
  }
}

class _CompletedTap {
  const _CompletedTap(this.time, this.position);

  final Duration time;
  final Offset position;
}

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

class _Match {
  const _Match(this.node, this.area);

  final SemanticsNode node;
  final double area;
}

abstract final class _Gesture {
  static const String tap = 'tap';
  static const String doubleTap = 'double_tap';
  static const String longPress = 'long_press';
  static const String drag = 'drag';
  static const String textFocus = 'text_focus';
  static const String textSubmit = 'text_submit';
}
