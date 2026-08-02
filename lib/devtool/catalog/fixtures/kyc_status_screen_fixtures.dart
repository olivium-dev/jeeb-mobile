// Shared dev-only fixtures for `KycStatusScreen`.
//
// Both dev surfaces read this file: the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_03_entries.dart` and the JEEB PREVIEWS
// section at the bottom of
// `lib/features/deep_link_targets/kyc_status_screen.dart`. One definition of
// "the designed states" so the designer-facing catalog and the engineer-facing
// canvas cannot drift apart.
//
// ## Why these fixtures are WINDOWS and not fake repositories
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. `KycStatusScreen` has none. It is the
// restored placeholder from T-MOB-FIX-001: it takes nothing but a `key`,
// resolves nothing out of GetIt, builds no cubit, holds no state, and renders
// one icon and two hardcoded English strings. Its own dartdoc says "Do NOT add
// behavior here". There is no empty / loading / error to seed and no repository
// for a fake to stand in for, so the usual preview question ("which state?")
// has to be asked differently: the only inputs this screen has are the ones the
// WINDOW supplies — how wide, how tall, how much of the display the system
// chrome has claimed, and how large the user has set their text.
//
// That also makes both surfaces network-free by construction rather than by the
// `CatalogNetworkGuard` that `jeebPreviewHost` and `_CatalogPreview` install:
// there is no seam here through which a Dio-backed repository could be reached
// even by accident.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';

/// One simulated device window to render `KycStatusScreen` in.
///
/// The frame is pinned by the fixture rather than left to the canvas `size:`,
/// because the render tests in `test/previews/` pump onto a fixed 800 x 600
/// surface: a state that merely ASKED for a 320 x 568 canvas would be measured
/// at 800 x 600 under test and every state would silently collapse into the
/// same widget.
@immutable
class KycStatusScreenWindow {
  const KycStatusScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  ///
  /// This screen renders the SAME two sentences in every state, so the caption
  /// is the only thing that distinguishes one rendering from another — in the
  /// canvas and in the render test's `expectedText`.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  ///
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES
  /// padding for everything below it, so a window that wants insets has to
  /// restore them itself.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class KycStatusScreenWindows {
  KycStatusScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const KycStatusScreenWindow phone = KycStatusScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class).
  static const KycStatusScreenWindow compact = KycStatusScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const KycStatusScreenWindow phoneLargeText = KycStatusScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. `OmdsEmptyStatePage` centres a `Column(mainAxisSize: min)` that
  /// nothing scrolls, so this is the window that decides whether the composition
  /// fits or is clipped.
  static const KycStatusScreenWindow compactLargeText = KycStatusScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// A notched phone in portrait at the accessibility ceiling: 59 pt status
  /// bar, 34 pt home indicator.
  ///
  /// The screen passes `appBar: null`, so nothing consumes the top inset, and
  /// `Scaffold` does not `SafeArea` its body. At 100% the centred column is far
  /// too short to reach either edge and the omission costs nothing; 200% is
  /// where the column is tall enough for it to matter.
  static const KycStatusScreenWindow notchedLargeText = KycStatusScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );

  /// Every window, in review order — the state list both dev surfaces render.
  static const List<KycStatusScreenWindow> all = <KycStatusScreenWindow>[
    phone,
    compact,
    phoneLargeText,
    compactLargeText,
    notchedLargeText,
  ];
}

/// Hosts `KycStatusScreen` inside one [KycStatusScreenWindow].
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library,
/// and — the load-bearing one — `tool/preview_coverage.dart` only credits a
/// preview section that literally CONSTRUCTS the widget it is named after, so
/// the `const KycStatusScreen()` has to appear below the banner in the screen's
/// own file rather than in here.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog's device-sized state uses,
/// where the real device IS the frame.
class KycStatusScreenPreviewHost extends StatelessWidget {
  const KycStatusScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
  });

  /// The screen under review — `const KycStatusScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final KycStatusScreenWindow? window;

  @override
  Widget build(BuildContext context) {
    final KycStatusScreenWindow? window = this.window;
    if (window == null) return screen;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            window.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: screen),
          ),
        ),
      ],
    );

    // Unbound on both axes. The render tests pump onto 800 x 600 and every
    // frame here is taller than that; an `Align` + `SizedBox` would pass the
    // host's constraints down and the frame would be silently clamped to 600 pt,
    // which is exactly the measurement the clipping tests depend on not being
    // faked.
    //
    // The `Material` is for the Screen Catalog rather than the canvas: the
    // catalog mounts a state inside a bare `Stack` with no `Scaffold`
    // (`catalog_screen.dart` · `_CatalogPreview`), and the caption `Text` above
    // needs a `Material` ancestor to pick up a text style. Inside
    // `jeebPreviewHost`'s `Scaffold` it is a no-op.
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: framed,
        ),
      ),
    );
  }
}
