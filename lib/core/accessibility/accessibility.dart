import 'package:flutter/material.dart';

/// Accessibility tokens and helpers shared across Jeeb screens.
///
/// Source-of-truth for AC T-mobile-036:
///   - Font scaling to 200% on all screens without overflow
///   - All buttons/tappable elements ≥ 48dp (Android) / 44pt (iOS)
///   - Semantic labels on all interactive elements
///   - Color contrast ≥ 4.5:1 body text, ≥ 3:1 large text
///
/// Detailed policy: `docs/design/07-accessibility-compliance.md`.
class A11y {
  A11y._();

  /// Minimum logical pixels every interactive element must occupy on either
  /// axis. 48 satisfies Android's 48dp guideline; iOS's 44pt is comfortably
  /// covered because Flutter logical pixels map 1:1 to iOS points.
  static const double minTapTargetSize = 48.0;

  /// Hard ceiling we apply to the system text scale factor. The AC requires
  /// scaling to 200% without overflow — anything beyond that is unsupported
  /// territory where even well-built layouts visibly degrade. Clamping to 2.0
  /// preserves the AC while protecting users who crank the OS slider beyond.
  static const double maxTextScaleFactor = 2.0;

  /// Floor on the text scaler. Users who disable scaling entirely (or some
  /// older Android variants reporting <1.0) still get readable type.
  static const double minTextScaleFactor = 1.0;

  /// Returns a copy of [data] with its text scaler clamped to
  /// `[minTextScaleFactor, maxTextScaleFactor]`. Drop in inside
  /// `MaterialApp.builder` to enforce the policy across every screen.
  static MediaQueryData clampTextScaler(MediaQueryData data) {
    return data.copyWith(
      textScaler: data.textScaler.clamp(
        minScaleFactor: minTextScaleFactor,
        maxScaleFactor: maxTextScaleFactor,
      ),
    );
  }
}

/// Builder for [MaterialApp.builder] that enforces [A11y.clampTextScaler] for
/// every route. Falls back to an empty widget if [child] is null (defensive —
/// the framework normally guarantees it).
Widget jeebA11yBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: A11y.clampTextScaler(MediaQuery.of(context)),
    child: child ?? const SizedBox.shrink(),
  );
}

/// Wraps [child] in a [ConstrainedBox] guaranteeing the
/// [A11y.minTapTargetSize] on both axes. Use on any custom interactive
/// surface that doesn't already inherit a ListTile / IconButton's enforced
/// minimum.
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: A11y.minTapTargetSize,
        minHeight: A11y.minTapTargetSize,
      ),
      child: child,
    );
  }
}
