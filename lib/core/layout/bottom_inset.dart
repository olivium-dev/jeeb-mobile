import 'package:flutter/material.dart';

/// Edge-to-edge bottom-inset helpers for modal bottom sheets (and any other
/// bottom-pinned content that is NOT already wrapped in a [SafeArea]).
///
/// ## Why this exists
///
/// The app opts into edge-to-edge globally (`SystemUiMode.edgeToEdge` in
/// `lib/main.dart`), so Flutter draws under the transparent system navigation
/// bar. On Android 15 (and any device with a soft-button / gesture nav bar),
/// content pinned to the bottom of the screen will render *behind* the
/// navigation bar unless the screen reserves the bottom system inset.
///
/// A [Scaffold] body wrapped in the default [SafeArea] handles this for
/// regular screens. **Modal bottom sheets do not** — `showModalBottomSheet`
/// does not insert a bottom [SafeArea], so a sheet that pads only by
/// [MediaQueryData.viewInsets] (the keyboard) leaves its bottom CTA obscured by
/// the nav bar whenever the keyboard is closed.
///
/// The correct bottom padding for a sheet that is NOT inside a [SafeArea] is
/// the keyboard inset **plus** the system bar inset:
///
/// ```text
/// viewInsets.bottom   // keyboard height (0 when keyboard is closed)
/// + viewPadding.bottom // nav-bar height (stable; survives keyboard open/close)
/// ```
///
/// The nav-bar inset is read from `MediaQueryData.fromView(View.of(context))`
/// rather than `MediaQuery.of(context).viewPadding`. This is **load-bearing**:
/// `showModalBottomSheet` wraps its content in a route that *consumes* the
/// bottom padding, so inside a sheet builder `MediaQuery.of(context).viewPadding`
/// and `.padding` are both `EdgeInsets.zero` — reading them would reserve no
/// nav-bar space at all. `View.of(context)` exposes the raw, un-consumed
/// `FlutterView` insets (the physical nav-bar height), which survives the modal
/// route. The keyboard inset is read from the normal [MediaQuery] because
/// `viewInsets.bottom` IS propagated into the sheet correctly.
///
/// [FlutterView.viewPadding] is used (not `padding`) so the value is independent
/// of keyboard state — `padding.bottom` would collapse while the keyboard is
/// open and the keyboard inset already covers that case. This is correct for
/// BOTH gesture navigation (~24dp inset) and 3-button navigation (~48dp inset)
/// — no hardcoded padding involved.
extension BottomInsetX on BuildContext {
  /// Bottom padding that keeps content clear of both the on-screen keyboard
  /// and the system navigation bar, for content NOT already inside a
  /// [SafeArea]. Add this to the bottom of a sheet's outer padding.
  ///
  /// Works correctly inside `showModalBottomSheet` builders, where the modal
  /// route consumes [MediaQueryData.viewPadding] (see the extension docs).
  double get sheetBottomInset {
    final keyboard = MediaQuery.of(this).viewInsets.bottom;
    final view = View.of(this);
    // Raw nav-bar inset in logical pixels (physical insets ÷ devicePixelRatio).
    final navBar = view.viewPadding.bottom / view.devicePixelRatio;
    return keyboard + navBar;
  }

  /// Bottom padding for a scrollable [Scaffold] body (e.g. a `ListView`) so its
  /// LAST item scrolls clear of the system navigation bar / soft buttons in
  /// edge-to-edge mode.
  ///
  /// ## Why this exists (distinct from [sheetBottomInset])
  ///
  /// Two scrollable-body contexts both leak content under the soft buttons:
  ///
  /// 1. A screen pushed as a full route (e.g. Settings via `MaterialPageRoute`)
  ///    has NO `bottomNavigationBar`, so in edge-to-edge mode the `Scaffold`
  ///    body draws all the way down to the physical screen edge — the last
  ///    list row renders behind the soft buttons.
  /// 2. A tab body hosted above a `bottomNavigationBar` (e.g. the home request
  ///    list) is laid out above the bar, but its scroll extent must still
  ///    reserve enough bottom padding for the last card to scroll fully clear;
  ///    a fixed token (`Spacing.twoXLarge` = 32dp) is smaller than a 3-button
  ///    nav inset (~48dp), so the last card stays clipped against the bar.
  ///
  /// Unlike [sheetBottomInset], this reads [MediaQueryData.viewPadding] (NOT
  /// `View.of(context)`): a pushed [PageRoute] does NOT consume the bottom
  /// padding (only `showModalBottomSheet` does), so MediaQuery carries the true
  /// nav-bar inset here. Reading MediaQuery also makes this **double-pad safe**:
  /// if an ancestor already consumed the bottom inset via `SafeArea`, this
  /// returns `0` and no extra padding is added.
  ///
  /// No keyboard term: a scroll body's input fields scroll into view on focus,
  /// so only the stable nav-bar inset matters. Correct for BOTH gesture
  /// navigation (~24dp) and 3-button navigation (~48dp) — no hardcoded padding.
  double get scrollBodyBottomInset => MediaQuery.of(this).viewPadding.bottom;
}

/// Wraps a modal bottom sheet body so its content clears the keyboard and the
/// system navigation bar in edge-to-edge mode.
///
/// Use this as the outermost widget inside a `showModalBottomSheet` builder
/// when the sheet body is NOT already wrapped in a [SafeArea]. It applies
/// [BottomInsetX.sheetBottomInset] as bottom padding (keyboard + nav bar) and
/// leaves the left/right/top untouched so the sheet's own content padding is
/// preserved.
///
/// ```dart
/// showModalBottomSheet<void>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => BottomSheetSafeArea(child: MySheetBody()),
/// );
/// ```
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
