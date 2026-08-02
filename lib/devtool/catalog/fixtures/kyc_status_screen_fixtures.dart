// Shared dev-only fixtures for `KycStatusScreen`.

import 'package:flutter/material.dart';

/// One simulated device window to render `KycStatusScreen` in.
/// The frame is pinned by the fixture rather than left to the canvas `size:`,
@immutable
class KycStatusScreenWindow {
  const KycStatusScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  /// This screen renders the SAME two sentences in every state, so the caption
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
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
  static const KycStatusScreenWindow compactLargeText = KycStatusScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// A notched phone in portrait at the accessibility ceiling: 59 pt status
  /// bar, 34 pt home indicator.
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
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library,
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
