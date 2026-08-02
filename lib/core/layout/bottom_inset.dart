import 'package:flutter/material.dart';

/// Edge-to-edge bottom-inset helpers for modals. Must use View.of() not MediaQuery
/// (modal routes consume viewPadding).
extension BottomInsetX on BuildContext {
  /// Keyboard + nav-bar inset for sheets. Use View.of() not MediaQuery.
  double get sheetBottomInset {
    final keyboard = MediaQuery.of(this).viewInsets.bottom;
    final view = View.of(this);
    // Logical pixels.
    final navBar = view.viewPadding.bottom / view.devicePixelRatio;
    return keyboard + navBar;
  }

  /// Nav-bar inset for scrollable bodies. Uses MediaQuery (not View.of()).
  double get scrollBodyBottomInset => MediaQuery.of(this).viewPadding.bottom;
}

/// Wraps a modal sheet body to clear keyboard and nav-bar in edge-to-edge mode.
/// Applies [BottomInsetX.sheetBottomInset] as bottom padding.
class BottomSheetSafeArea extends StatelessWidget {
  const BottomSheetSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.sheetBottomInset),
      child: child,
    );
  }
}
