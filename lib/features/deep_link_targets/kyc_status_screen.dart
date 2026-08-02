import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/kyc_status_screen_fixtures.dart';
import '../../core/previews/jeeb_preview.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  static const _featureId = 'kyc-status';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'KYC Status coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'KYC Status coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/deep_link_targets/kyc_status_screen_preview_test.dart
// ===========================================================================
//
// [KycStatusScreen] has NO data axis. It takes nothing but a `key`, resolves
// nothing out of GetIt, builds no cubit, holds no state, and renders one icon
// plus two fixed strings — its own dartdoc says "Do NOT add behavior here".
// There is no empty / loading / error to seed and no repository to fake, so the
// only inputs it has are the ones the WINDOW supplies: how wide, how tall, how
// much of the display the system chrome has already claimed, and how large the
// user has set their text. Those are the five states below.
//
// The windows and the host live in
// `lib/devtool/catalog/fixtures/kyc_status_screen_fixtures.dart` and are shared
// with the Screen Catalog entry for this screen
// (`lib/devtool/catalog/entries/batch_03_entries.dart`), so the designer's
// on-device browser and this canvas render the same designed states. The frame
// is pinned INSIDE the fixture — a `MediaQuery` override plus a `SizedBox` —
// rather than left to the canvas [Size], because the render tests pump onto a
// fixed 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas
// would be measured at 800 x 600 and all five states would silently become the
// same widget. Windows that exist FOR a text scale pin one; the rest inherit,
// so `matrix: true` can still render its own 200% card.
//
// Note that this screen owns its own `Scaffold` — `OmdsEmptyStatePage` returns
// one — and [jeebPreviewHost] wraps every child in one as well, so the canvas
// shows two nested Scaffolds. The inner one is the real surface; the outer
// contributes a background and a `SafeArea`, which is why each window has to
// RESTORE `MediaQuery.padding` or the notched state would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **The copy is hardcoded English, not localized.** "KYC Status coming
//    soon", "This screen is not yet available." and the `Semantics.label` are
//    string literals, not ARB lookups, so the AR RTL card of
//    `Phone 390 × 844` renders English inside a right-to-left layout. Every
//    other placeholder screen of this family goes through `AppLocalizations`.
//  * **Nothing scrolls, and the composition is clipped at the accessibility
//    ceiling.** `OmdsEmptyStatePage` is `Center(child: OmdsEmptyState(...))` and
//    `OmdsEmptyState` is a bare `Column(mainAxisSize: min)` — no `ListView`, no
//    `SingleChildScrollView`. The icon is a fixed 100 pt that does NOT shrink
//    with the text scale, so at 200% on a 320 x 568 display the column is taller
//    than the window and the content is cut off with no way to reach it.
//  * **The `Semantics(container: true)` wrapper double-announces.** It sets a
//    label ("KYC Status coming soon. This screen is not yet available.") over a
//    subtree that already publishes both sentences as text, and does not set
//    `explicitChildNodes`, so a screen reader hears the sentence pair twice.
//  * The good news, recorded because it is cheap to lose: at 100% text nothing
//    clips in any window, in either locale, and the centred column stays clear
//    of the notch and the home indicator by a wide margin.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _kycStatusScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _kycStatusScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _kycStatusScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
///
/// The `const KycStatusScreen()` is constructed HERE rather than inside the
/// fixture host on purpose: `tool/preview_coverage.dart` credits a section only
/// when it literally builds the widget its previews are named after, and it
/// keeps the fixture library free of a circular import back into this one.
Widget _kycStatusScreenHosted(KycStatusScreenWindow window) =>
    KycStatusScreenPreviewHost(
      window: window,
      screen: const KycStatusScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text.
///
/// Everything fits with room to spare — the centred column occupies roughly a
/// quarter of the display. Read the four states below against this one.
///
/// Matrixed because the AR card is the finding: the two sentences and the
/// `Semantics` label are hardcoded English literals rather than ARB lookups, so
/// the right-to-left rendering shows English copy. If this preview ever renders
/// Arabic, someone localized the screen and this note is stale.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone 390 × 844',
  size: _kycStatusScreenPhoneCanvas,
  matrix: true,
)
Widget kycStatusScreenPhone() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.phone);

/// The smallest display the app supports, at default text size.
///
/// Still clean: the fixed 100 pt icon plus both sentences fit inside 568 pt with
/// margin left over. This is the last window in which the missing scroll view
/// costs nothing.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact 320 × 568',
  size: _kycStatusScreenCompactCanvas,
)
Widget kycStatusScreenCompact() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.compact);

/// The accessibility ceiling on an ordinary phone: 200% text on 390 × 844.
///
/// Both sentences wrap several times around an icon that did not grow, so the
/// column roughly doubles — measured 524 pt of the 796 pt the padded window
/// offers. It holds. Width is what saves it, not height: the same content in a
/// 320 pt-wide window wraps far more and is the state below.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone · 200% text',
  size: _kycStatusScreenPhoneCanvas,
)
Widget kycStatusScreenPhoneLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.phoneLargeText);

/// The worst case the app supports: the smallest display AND the largest text.
///
/// This is the state that breaks. `OmdsEmptyState` is an unscrollable
/// `Column(mainAxisSize: min)` inside a `Center`, and the icon is a fixed 100 pt
/// that ignores the text scale, so the column asks for more height than the
/// window has and the ends of it are simply cut off. There is no scroll
/// affordance and no way for the user to reach what was clipped.
///
/// Measured under `flutter test`: 668 pt of content in the 520 pt the padded
/// window offers — "RenderFlex overflowed by 148 pixels on the bottom", in EN
/// and AR alike. Treat 148 with care, since the test font is wider than Inter
/// and wraps English more often than a device would; what is NOT a font
/// artifact is that nothing in this screen can absorb a shortfall of any size,
/// which is what the render test pins.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact · 200% text',
  size: _kycStatusScreenCompactCanvas,
)
Widget kycStatusScreenCompactLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.compactLargeText);

/// A notched phone at the accessibility ceiling: 59 pt status bar, 34 pt home
/// indicator, 200% text.
///
/// The screen passes `appBar: null`, so nothing consumes the top inset, and
/// `Scaffold` does not `SafeArea` its body. The content is centred rather than
/// anchored, so on an 852 pt display the column still clears both — this window
/// exists to keep that true. It is the combination in which a taller
/// composition would start hiding text under the status bar.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Notched · 200% text',
  size: _kycStatusScreenNotchedCanvas,
)
Widget kycStatusScreenNotchedLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.notchedLargeText);
