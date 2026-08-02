// Shared dev-only fixtures for `ProhibitedItemReportScreen`.
//
// EXTRACTED from the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_09_entries.dart`, which now imports this
// file instead of spelling its two designed states inline. The preview section
// at the bottom of
// `lib/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart`
// imports the same file, so the designer's on-device browser and the engineer's
// canvas cannot drift into showing two different "designed states".
//
// ## Why these fixtures are STRINGS and WINDOWS, not a fake repository
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. This one has none. `ProhibitedItemReport-
// Screen` builds no cubit, resolves nothing out of GetIt, holds one
// `TextEditingController`, and its only action is a synchronous
// `Navigator.of(context).pop(true)`. There is no request in flight, so there is
// no loading state; nothing can fail, so there is no error state. Both surfaces
// are therefore network-free by construction rather than by the guard
// `jeebPreviewHost` / the catalog host installs: there is no seam here through
// which a Dio-backed repository could be reached even by mistake.
//
// What DOES vary, and what the states below are:
//
//  1. **The description text.** It is the screen's only input and its only
//     gate — `Report Item` is enabled iff `_descriptionController.text
//     .isNotEmpty`. Empty / typed / very long / Arabic / whitespace-only are
//     five genuinely different renderings.
//  2. **The window.** The body is a non-scrolling `Column` with a `Spacer()`
//     between the "Attach Photo" and "Report Item" buttons, so the viewport is
//     what decides whether the form fits at all. Height, system-chrome insets,
//     the software keyboard, and the user's text scale are all real, reviewable
//     states — see `ProhibitedItemReportScreenWindows`.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'package:flutter/material.dart';

/// One simulated device window to render `ProhibitedItemReportScreen` in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and every state would silently collapse
/// into the same widget.
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
  ///
  /// Load-bearing for this screen: `Scaffold` drops the TOP padding for a body
  /// that sits under an `appBar`, but it does not drop the bottom one, and the
  /// body here is a bare `Padding` with no `SafeArea`. Whatever the home
  /// indicator claims, the destructive `Report Item` CTA is drawn into.
  final EdgeInsets insets;

  /// Height of the software keyboard (`MediaQuery.viewInsets.bottom`).
  ///
  /// The description field is the screen's whole purpose, so the keyboard is up
  /// for most of the time this screen is on display. `Scaffold` defaults to
  /// `resizeToAvoidBottomInset: true`, so this subtracts directly from the
  /// height the non-scrolling `Column` has to lay out in.
  final double keyboard;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
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
  /// costing lines.
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
  /// portrait keyboard on a 320 pt-wide display.
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
  ///
  /// The screen renders five hardcoded English strings and nothing else, so
  /// four of the six states below share every pixel of chrome. Without a
  /// caption there is no string that identifies WHICH state a card is showing,
  /// and a render test could only assert that something drew.
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
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of an import back into the feature library, and — the
/// load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `ProhibitedItemReportScreen(...)` has to appear below the banner in the
/// screen's own file rather than in here.
///
/// Pass `state: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog entry uses, where the device
/// IS the frame.
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
            // read the same way in the Arabic renderings of the matrix.
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
            // ZEROES `padding` for everything below it. Restoring it here is
            // what makes the notched window mean anything at all.
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
    // frames here are taller than that; an `Align` + `SizedBox` would pass the
    // host's constraints down and an 844 pt frame would be silently clamped to
    // 600 pt — the exact measurement the "does the form still fit" states
    // depend on not being faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}
