// Shared dev-only fixtures for `RatingPromptScreen`.

import 'package:flutter/material.dart';

/// One simulated device window to render `RatingPromptScreen` in.
/// The frame is pinned by the fixture rather than left to the canvas `size:`,
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
  /// This screen renders the SAME app bar and the SAME two sentences in every
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;

  /// The deep-link path parameter (`/orders/:id/rate`) this state hands the
  /// screen — which the screen accepts and never puts on screen.
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
  static const RatingPromptScreenWindow compactLargeText =
      RatingPromptScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// A notched phone in portrait at the accessibility ceiling: 59 pt status
  /// bar, 34 pt home indicator.
  static const RatingPromptScreenWindow notchedLargeText =
      RatingPromptScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );

  /// The same reference phone, handed a DIFFERENT deep-link delivery id.
  /// Renders identically to [phone] — that is the finding, not a copy-paste
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
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library,
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
