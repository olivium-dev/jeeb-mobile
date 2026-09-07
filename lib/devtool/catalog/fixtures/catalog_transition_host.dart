import 'package:flutter/widgets.dart';

/// Dev-only driver: each step invokes the real mounted control/cubit action.
/// Missing controls fail loudly; never capture a normal page under a failure label.
class CatalogTransitionHost extends StatefulWidget {
  const CatalogTransitionHost({
    super.key,
    required this.child,
    required this.steps,
  });

  final Widget child;
  final List<bool Function(Element root)> steps;

  static Element? find<T extends Widget>(
    Element root, [
    bool Function(T widget)? matches,
  ]) {
    Element? result;
    void visit(Element element) {
      if (result != null) return;
      final widget = element.widget;
      if (widget is T && (matches == null || matches(widget))) {
        result = element;
      } else {
        element.visitChildElements(visit);
      }
    }

    root.visitChildElements(visit);
    return result;
  }

  @override
  State<CatalogTransitionHost> createState() => _CatalogTransitionHostState();
}

class _CatalogTransitionHostState extends State<CatalogTransitionHost> {
  int _step = 0;
  int _attempts = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant CatalogTransitionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child || oldWidget.steps != widget.steps) {
      _generation++;
      _step = 0;
      _attempts = 0;
      _schedule();
    }
  }

  void _schedule() {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || _step == widget.steps.length) {
        return;
      }
      if (widget.steps[_step](context as Element)) {
        _step++;
        _attempts = 0;
      } else if (++_attempts >= 40) {
        throw StateError('Catalog transition step $_step never became ready');
      }
      if (_step < widget.steps.length) {
        _schedule();
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
