// Shared dev-only fixtures for `RatingPromptScreen`.
//
// Both dev surfaces read this file: the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_03_entries.dart` and the JEEB PREVIEWS
// section at the bottom of
// `lib/features/deep_link_targets/rating_prompt_screen.dart`. One definition of
// "the designed states" so the designer-facing catalog and the engineer-facing
// canvas cannot drift apart.
//
// ## Why these fixtures are WINDOWS and not fake repositories
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. `RatingPromptScreen` has none. It is one of
// the frozen Type-A placeholders (`qa/t-mob-fix-001/placeholder-discipline.sh`):
// it resolves nothing out of GetIt, builds no cubit, holds no state, and renders
// an app bar plus one icon and two hardcoded English sentences. Its own dartdoc
// forbids adding behavior, loading indicators or dialogs. There is no empty /
// loading / error to seed and no repository for a fake to stand in for, so the
// usual preview question ("which state?") has to be asked differently: the only
// inputs this screen has are the WINDOW it is painted into — how wide, how tall,
// how much of the display the system chrome has claimed, how large the user has
// set their text — and the deep-link `deliveryId` it is handed.
//
// That second input is why [RatingPromptScreenWindow] carries a `deliveryId`.
// The screen REQUIRES the parameter and never renders it (the field is retained
// "so the import-graph stays green"), so the id is a designed state in exactly
// one sense: it is the one that shows the id going nowhere. Keeping it on the
// window means the catalog and the canvas hand the screen the same id in the
// same state, instead of each inventing one.
//
// Both surfaces are therefore network-free by construction rather than by the
// `CatalogNetworkGuard` that `jeebPreviewHost` and `_CatalogPreview` install:
// there is no seam here through which a Dio-backed repository could be reached
// even by accident.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';

/// One simulated device window to render `RatingPromptScreen` in.
///
/// The frame is pinned by the fixture rather than left to the canvas `size:`,
/// because the render tests in `test/previews/` pump onto a fixed 800 x 600
/// surface: a state that merely ASKED for a 320 x 568 canvas would be measured
/// at 800 x 600 under test and every state would silently collapse into the
/// same widget.
@immutable
class RatingPromptScreenWindow {
  const RatingPromptScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
    this.deliveryId = RatingPromptScreenFixtures.deliveryId,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  ///
  /// This screen renders the SAME app bar and the SAME two sentences in every
  /// state, so the caption is the only thing that distinguishes one rendering
  /// from another — in the canvas and in the render test's `expectedText`.
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

  /// The deep-link path parameter (`/orders/:id/rate`) this state hands the
  /// screen — which the screen accepts and never puts on screen.
  ///
  /// Every window but [RatingPromptScreenWindows.unusedDeepLinkId] uses the
  /// house id, so the odd one out is the state that makes the omission visible:
  /// two different ids, one identical rendering.
  final String deliveryId;
}

/// The delivery ids the states above are handed.
final class RatingPromptScreenFixtures {
  RatingPromptScreenFixtures._();

  /// The house order id, shared with the rest of the Screen Catalog.
  static const String deliveryId = 'ORD-4821';

  /// A deliberately unmistakable second id — long, dated and unique — so a
  /// reviewer can confirm it appears NOWHERE inside the screen it was handed to.
  static const String unusedDeliveryId = 'DLV-2026-08-02-000914';
}

/// The named windows this screen is reviewed in.
final class RatingPromptScreenWindows {
  RatingPromptScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const RatingPromptScreenWindow phone = RatingPromptScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class).
  static const RatingPromptScreenWindow compact = RatingPromptScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const RatingPromptScreenWindow phoneLargeText =
      RatingPromptScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. The empty-state page centres a `Column(mainAxisSize: min)` that
  /// nothing scrolls, inside a body the app bar has already taken 56 pt from,
  /// so this is the window that decides whether the composition fits or is
  /// clipped.
  static const RatingPromptScreenWindow compactLargeText =
      RatingPromptScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// A notched phone in portrait at the accessibility ceiling: 59 pt status
  /// bar, 34 pt home indicator.
  ///
  /// Unlike its sibling `KycStatusScreen`, this placeholder DOES pass an app
  /// bar, so the top inset is consumed for it — and the bottom inset still is
  /// not, because nothing occupies that slot.
  static const RatingPromptScreenWindow notchedLargeText =
      RatingPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );

  /// The same reference phone, handed a DIFFERENT deep-link delivery id.
  ///
  /// Renders identically to [phone] — that is the finding, not a copy-paste
  /// slip. The route this screen is registered on carries the id
  /// (`/orders/:id/rate`) and the screen names no delivery, no jeeber and no
  /// order reference anywhere on the surface.
  static const RatingPromptScreenWindow unusedDeepLinkId =
      RatingPromptScreenWindow(
    label: 'Phone · 390 × 844 · deep-link id '
        '${RatingPromptScreenFixtures.unusedDeliveryId} (never shown)',
    size: Size(390, 844),
    deliveryId: RatingPromptScreenFixtures.unusedDeliveryId,
  );

  /// Every window, in review order — the state list both dev surfaces render.
  static const List<RatingPromptScreenWindow> all = <RatingPromptScreenWindow>[
    phone,
    compact,
    phoneLargeText,
    compactLargeText,
    notchedLargeText,
    unusedDeepLinkId,
  ];
}

/// Hosts `RatingPromptScreen` inside one [RatingPromptScreenWindow].
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library,
/// and — the load-bearing one — `tool/preview_coverage.dart` only credits a
/// preview section that literally CONSTRUCTS the widget it is named after, so
/// the `RatingPromptScreen(...)` has to appear below the banner in the screen's
/// own file rather than in here.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog's device-sized state uses,
/// where the real device IS the frame.
class RatingPromptScreenPreviewHost extends StatelessWidget {
  const RatingPromptScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
  });

  /// The screen under review — `RatingPromptScreen(deliveryId: …)`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final RatingPromptScreenWindow? window;

  @override
  Widget build(BuildContext context) {
    final RatingPromptScreenWindow? window = this.window;
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
