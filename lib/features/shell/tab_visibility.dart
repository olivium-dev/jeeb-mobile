import 'package:flutter/widgets.dart';

class TabVisibility extends InheritedWidget {
  const TabVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  final bool isVisible;

  static TabVisibility? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabVisibility>();
  }

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      oldWidget.isVisible != isVisible;
}
