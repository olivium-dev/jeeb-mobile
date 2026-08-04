import 'package:flutter/material.dart';

/// The modal dim behind a Midnight bottom sheet or dialog.
///
/// Pass-1 sheets barriered on `onSecondaryContainer` at `opacityHigh`, which
/// under Midnight is `#B9C0F0` (`inkSoft`) at 87% — a pale periwinkle veil that
/// *lightens* the field instead of dimming it. The scheme's `scrim` is the only
/// sanctioned black in the app (`Colors.*` is banned by the token gate), and
/// [barrierAlpha] is the 0.55 the app already uses for its other overlay dims
/// (`handoff_tiles`) and the value Flutter's own `black54` barrier lands on.
///
/// Every `showModalBottomSheet`/`showDialog` in the app should barrier on
/// [barrier] so the dim is one decision, not one per sheet.
abstract final class JeebScrim {
  /// Alpha for [barrier]. Sibling lanes adopting this must not re-pick it.
  static const double barrierAlpha = 0.55;

  /// Barrier colour for a modal presented over the Midnight field.
  static Color barrier(BuildContext context) =>
      Theme.of(context).colorScheme.scrim.withValues(alpha: barrierAlpha);
}
