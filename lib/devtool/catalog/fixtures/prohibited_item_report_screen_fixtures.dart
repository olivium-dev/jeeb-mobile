// Shared dev-only fixtures for `ProhibitedItemReportScreen`.

import 'package:flutter/material.dart';

/// One simulated device window to render `ProhibitedItemReportScreen` in.
/// The frame has to be pinned by the fixture rather than left to the canvas
@immutable
class ProhibitedItemReportScreenWindow {
  const ProhibitedItemReportScreenWindow({
    required this.name,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.keyboard = 0,
    this.textScale,
  });

  /// Short geometry label, folded into each case's caption.
  final String name;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  /// Load-bearing for this screen: `Scaffold` drops the TOP padding for a body
  final EdgeInsets insets;

  /// Height of the software keyboard (`MediaQuery.viewInsets.bottom`).
  /// The description field is the screen's whole purpose, so the keyboard is up
  final double keyboard;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class ProhibitedItemReportScreenWindows {
  ProhibitedItemReportScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed
  /// and no keyboard up.
  static const ProhibitedItemReportScreenWindow phone =
      ProhibitedItemReportScreenWindow(
    name: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class), which is also the width at which the warning copy first starts
  static const ProhibitedItemReportScreenWindow compact =
      ProhibitedItemReportScreenWindow(
    name: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  static const ProhibitedItemReportScreenWindow notched =
      ProhibitedItemReportScreenWindow(
    name: 'Notched 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The compact phone with its software keyboard up — i.e. the screen as it
  /// looks while the jeeber is actually typing the report. 216 pt is the iOS
  static const ProhibitedItemReportScreenWindow compactKeyboard =
      ProhibitedItemReportScreenWindow(
    name: 'Compact 320 × 568 · keyboard 216',
    size: Size(320, 568),
    keyboard: 216,
  );
}

/// One designed state: a description to seed the field with, and the window to
/// review it in.
@immutable
class ProhibitedItemReportScreenCase {
  const ProhibitedItemReportScreenCase({
    required this.caption,
    required this.window,
    this.description,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  final String caption;

  /// The window this state is reviewed in.
  final ProhibitedItemReportScreenWindow window;

  /// Seeds `ProhibitedItemReportScreen.initialDescription`; `null` is the cold
  /// state the router would produce.
  final String? description;
}

/// The designed states, shared by the Screen Catalog entry and the preview
/// section.
final class ProhibitedItemReportScreenPreviewFixtures {
  ProhibitedItemReportScreenPreviewFixtures._();

  /// The request under report. Note that the screen never renders it and never
  /// sends it anywhere — see the preview section's prose.
  static const String requestId = 'REQ-7742';

  /// The catalog's "Filled — Ready to Report" text: one plausible line.
  static const String filledDescription =
      'Client asked me to carry an unsealed bottle of liquor.';

  /// The layout ceiling: more than the field's four visible lines.
  static const String longestDescription =
      'The client asked me to carry two sealed one-litre bottles of arak and a '
      'five-kilo camping gas cylinder from the shop under their building in '
      'Hamra up to a flat in Achrafieh, and would not let me photograph the box '
      'before I loaded it onto the scooter — I only worked out what was inside '
      'when the bag started leaking at the second set of lights.';

  /// A jeeber typing in Arabic into a form whose every label is hardcoded
  /// English.
  static const String arabicDescription =
      'طلب مني الزبون نقل قنينتين من الكحول وأسطوانة غاز صغيرة من الحمرا إلى '
      'الأشرفية، ورفض أن أصور الصندوق قبل تحميله على الدراجة.';

  /// Three spaces: not a report, but `String.isNotEmpty` says otherwise.
  static const String whitespaceDescription = '   ';

  /// Catalog state 1 — the cold form, nothing typed, `Report Item` disabled.
  static const ProhibitedItemReportScreenCase empty =
      ProhibitedItemReportScreenCase(
    caption: 'Empty · nothing typed · Report disabled',
    window: ProhibitedItemReportScreenWindows.phone,
  );

  /// Catalog state 2 — one plausible line typed, `Report Item` armed.
  static const ProhibitedItemReportScreenCase filled =
      ProhibitedItemReportScreenCase(
    caption: 'Filled · one line typed · Report armed',
    window: ProhibitedItemReportScreenWindows.phone,
    description: filledDescription,
  );

  /// The longest plausible content, on the reference phone.
  static const ProhibitedItemReportScreenCase longest =
      ProhibitedItemReportScreenCase(
    caption: 'Longest · a paragraph in a four-line box',
    window: ProhibitedItemReportScreenWindows.phone,
    description: longestDescription,
  );

  /// The same paragraph on the narrowest phone the app supports.
  static const ProhibitedItemReportScreenCase longestCompact =
      ProhibitedItemReportScreenCase(
    caption: 'Longest · narrowest phone',
    window: ProhibitedItemReportScreenWindows.compact,
    description: longestDescription,
  );

  /// Arabic content inside untranslated English chrome.
  static const ProhibitedItemReportScreenCase arabic =
      ProhibitedItemReportScreenCase(
    caption: 'Arabic report · English chrome',
    window: ProhibitedItemReportScreenWindows.phone,
    description: arabicDescription,
  );

  /// Whitespace only — the CTA gate's blind spot.
  static const ProhibitedItemReportScreenCase whitespaceOnly =
      ProhibitedItemReportScreenCase(
    caption: 'Whitespace only · Report armed anyway',
    window: ProhibitedItemReportScreenWindows.phone,
    description: whitespaceDescription,
  );

  /// The notched phone: what the home indicator claims from the bottom CTA.
  static const ProhibitedItemReportScreenCase notched =
      ProhibitedItemReportScreenCase(
    caption: 'Home indicator · CTA drawn into it',
    window: ProhibitedItemReportScreenWindows.notched,
    description: filledDescription,
  );

  /// The state the jeeber is actually in while writing the report: small phone,
  /// keyboard up.
  static const ProhibitedItemReportScreenCase keyboardOpen =
      ProhibitedItemReportScreenCase(
    caption: 'Typing · compact phone, keyboard up',
    window: ProhibitedItemReportScreenWindows.compactKeyboard,
    description: filledDescription,
  );
}

/// Hosts `ProhibitedItemReportScreen` in one
/// [ProhibitedItemReportScreenCase]'s window, captioned and outlined.
/// The screen is passed IN rather than constructed here, for two reasons. It
class ProhibitedItemReportScreenPreviewHost extends StatelessWidget {
  const ProhibitedItemReportScreenPreviewHost({
    required this.screen,
    super.key,
    this.state,
  });

  /// The screen under review.
  final Widget screen;

  /// The designed state being rendered, or `null` to use the real display.
  final ProhibitedItemReportScreenCase? state;

  @override
  Widget build(BuildContext context) {
    final ProhibitedItemReportScreenCase? state = this.state;
    if (state == null) return screen;

    final ProhibitedItemReportScreenWindow window = state.window;
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = EdgeInsets.only(bottom: window.keyboard);

    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text(
            '${state.caption} · ${window.name}',
            // Forced LTR: a diagnostic caption, not shipped copy, and it must
            textDirection: TextDirection.ltr,
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
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: viewInsets,
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

    // Unbind both axes. The render tests pump onto 800 x 600 and the phone
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}
