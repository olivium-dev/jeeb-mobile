import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class A11y {
  A11y._();

  static const double minTapTargetSize = UIConstants.buttonHeight;

  static const double maxTextScaleFactor = 2.0;

  static MediaQueryData clampTextScaler(MediaQueryData data) {
    return data.copyWith(
      textScaler: _MaxTextScaler(
        delegate: data.textScaler,
        maxScaleFactor: maxTextScaleFactor,
      ),
    );
  }
}

class _MaxTextScaler extends TextScaler {
  const _MaxTextScaler({required this.delegate, required this.maxScaleFactor});

  final TextScaler delegate;
  final double maxScaleFactor;

  @override
  double scale(double fontSize) {
    final scaled = delegate.scale(fontSize);
    final maximum = maxScaleFactor * fontSize;
    return scaled > maximum ? maximum : scaled;
  }

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) {
    return other is _MaxTextScaler &&
        other.delegate == delegate &&
        other.maxScaleFactor == maxScaleFactor;
  }

  @override
  int get hashCode => Object.hash(delegate, maxScaleFactor);
}

Widget jeebA11yBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: A11y.clampTextScaler(MediaQuery.of(context)),
    child: child ?? const SizedBox.shrink(),
  );
}

class MinTapTarget extends StatelessWidget {
  const MinTapTarget({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: A11y.minTapTargetSize,
        minHeight: A11y.minTapTargetSize,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: IgnorePointer(child: child),
        ),
      ),
    );
  }
}
