import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';
import 'customer_register_pill.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class CustomerProfileRows extends StatelessWidget {
  const CustomerProfileRows({
    super.key,
    required this.showRegister,
    required this.onRegisterDelivery,
    required this.onPassword,
    required this.onNotifications,
    required this.onLanguage,
    required this.onAddresses,
    required this.onContact,
    required this.onRateApp,
    required this.onLogout,
  });

  final bool showRegister;
  final VoidCallback onRegisterDelivery;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;
  final VoidCallback onLanguage;
  final VoidCallback onAddresses;
  final VoidCallback onContact;
  final VoidCallback onRateApp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionAccount),
        if (showRegister)
          CustomerProfileRow(
            icon: Icons.delivery_dining_outlined,
            label: l10n.customerProfileRegisterAsDelivery,
            semanticsId: 'customer_profile_register_delivery_row',
            onTap: onRegisterDelivery,
            trailing: CustomerRegisterPill(onTap: onRegisterDelivery),
          ),
        CustomerProfileRow(
          icon: Icons.lock_outline,
          label: l10n.customerProfilePasswordSecurity,
          semanticsId: 'customer_profile_password_row',
          onTap: onPassword,
        ),
        CustomerProfileRow(
          icon: Icons.notifications_none,
          label: l10n.customerProfileNotification,
          semanticsId: 'customer_profile_notifications_row',
          onTap: onNotifications,
        ),
        CustomerProfileRow(
          icon: Icons.language_outlined,
          label: l10n.settingsLanguage,
          semanticsId: 'customer_profile_language_row',
          onTap: onLanguage,
        ),
        CustomerProfileRow(
          icon: Icons.location_on_outlined,
          label: l10n.savedAddressesTitle,
          semanticsId: 'customer_profile_addresses_row',
          onTap: onAddresses,
        ),
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionSupport),
        CustomerProfileRow(
          icon: Icons.call_outlined,
          label: l10n.customerProfileContactUs,
          semanticsId: 'customer_profile_contact_row',
          onTap: onContact,
        ),
        CustomerProfileRow(
          icon: Icons.star_outline,
          label: l10n.customerProfileRateApp,
          semanticsId: 'customer_profile_rate_app_row',
          onTap: onRateApp,
        ),
        CustomerProfileRow(
          icon: Icons.logout_outlined,
          label: l10n.appBarSignOut,
          semanticsId: 'customer_profile_logout_row',
          onTap: onLogout,
        ),
      ],
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
// Render tests: test/previews/customer_profile/customer_profile_rows_preview_test.dart
// ===========================================================================

// Widget previews for [CustomerProfileRows] — run with
// `flutter widget-preview start`.
//
// The widget takes no state: one `bool` ([CustomerProfileRows.showRegister])
// and eight `VoidCallback`s the screen owns. There is no cubit and no
// repository to stub, so every state below is network-free by construction
// rather than by the guard in `jeebPreviewHost` — the callbacks are no-ops and
// the eight labels all resolve from the ambient [AppLocalizations].
//
// That leaves exactly three axes worth reviewing, and the interesting states
// are the combinations:
//
//  * **`showRegister`** — JM-035 AC2 / design §8.2: the "Register as a
//    delivery" row disappears once the account is already a Jeeber. It is the
//    only row that carries a trailing *button* instead of a chevron, so it is
//    also the only row whose layout can fail.
//  * **width** — every preview pins its own width with a [SizedBox] instead of
//    relying on the canvas [Size]. The canvas honours `size`, but the render
//    tests in `test/previews/` pump onto a fixed 800 × 600 surface, so a 320 pt
//    state that only asked for a 320 pt canvas would be laid out at 800 pt
//    under test and silently become the same widget as the default one.
//  * **text scale** — same reason. `@JeebPreview` always adds an EN 200%
//    rendering to the canvas, but a widget test pumps at 1×, so the states that
//    only exist at 200% pin their own [TextScaler] and are therefore identical
//    in all three canvas renderings.
//
// Each preview is wrapped in a [SingleChildScrollView] because the live parent
// (`CustomerProfileScreen._Body`) is a [ListView]: the column is 552 pt tall at
// 1× and ~600 pt at 200%, and growing past the viewport is normal here, not a
// defect. Horizontal overflow inside a row is a defect, and stays visible.
//
// Three things these previews surface, all in the widgets rather than in the
// previews — measured in the preview render harness, whose test font is
// monospaced, so treat the pixel figures as the shape of the problem rather
// than as device-exact:
//
//  * **The register row loses its label before it loses its button.**
//    `CustomerProfileRow` gives the label an [Expanded] with
//    `TextOverflow.ellipsis` and no `maxLines` (so it truncates at one line
//    instead of wrapping), while [CustomerRegisterPill] is intrinsically sized
//    and never yields. At 390 pt / 200% the label is squeezed from 157 pt to
//    45 pt; at 320 pt / 200% it reaches **zero width** and the row overflows on
//    the trailing edge — leaving a naked "Register" button whose row label has
//    vanished. See [customerProfileRowsNarrowPhone] and
//    [customerProfileRowsLargeText].
//  * **The pill's height is frozen at 40 pt** (`height: Sizes.threeXLarge`)
//    while its text scales, so at 200% the CTA fills the button edge to edge
//    with no internal padding.
//  * **Dark mode loses the section headers and the icon glyphs.**
//    `CustomerProfileSectionHeader` paints its title in
//    `colorScheme.secondaryContainer` and `CustomerProfileIconDisc` paints a
//    `onSecondary` glyph on a `secondaryContainer` disc. Both pairings are
//    written for the light scheme (navy on white, white on navy — 17:1). The
//    dark scheme is `ColorScheme.fromSeed`, where both roles are dark: the
//    headers land at **1.98:1** on the dark surface and the glyph at **1.40:1**
//    on its disc. Every AR RTL dark rendering below shows it.
//
// RTL itself is clean: the row padding is [EdgeInsetsDirectional], and the
// chevron comes from `DirectionalIcons.disclosureIos`, so the AR renderings
// mirror properly and the Arabic labels are shorter than the English ones —
// the 200% overflow is an English-only failure.

/// A typical phone — the width the profile rows are designed against.
const double _customerProfileRowsPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen and the
/// small Android estate). The register row's label is what pays for it.
const double _customerProfileRowsNarrowPhoneWidth = 320;

/// Canvas boxes. Tall enough to show the whole column without scrolling at the
/// scale each state pins.
const Size _customerProfileRowsPhoneBox =
    Size(_customerProfileRowsPhoneWidth, 600);
const Size _customerProfileRowsJeeberBox =
    Size(_customerProfileRowsPhoneWidth, 540);
const Size _customerProfileRowsNarrowBox =
    Size(_customerProfileRowsNarrowPhoneWidth, 600);
const Size _customerProfileRowsLargeTextBox =
    Size(_customerProfileRowsPhoneWidth, 640);
const Size _customerProfileRowsNarrowLargeTextBox =
    Size(_customerProfileRowsNarrowPhoneWidth, 600);

/// One set of rows, wired the way `CustomerProfileScreen._Body` wires it.
///
/// The eight callbacks are deliberately inert: navigation belongs to the
/// screen, and a preview that could `goNamed` would need a router in context to
/// render at all.
///
/// [width] and [textScale] are pinned into the tree rather than left to the
/// canvas so the canvas and the render tests lay the widget out identically.
Widget _customerProfileRowsHosted({
  required bool showRegister,
  double width = _customerProfileRowsPhoneWidth,
  double? textScale,
}) {
  final Widget rows = CustomerProfileRows(
    showRegister: showRegister,
    onRegisterDelivery: () {},
    onPassword: () {},
    onNotifications: () {},
    onLanguage: () {},
    onAddresses: () {},
    onContact: () {},
    onRateApp: () {},
    onLogout: () {},
  );

  final Widget sized = Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      // Mirrors the live ListView parent: vertical growth scrolls, it does not
      // overflow. Anything that DOES overflow here is horizontal, and real.
      child: SingleChildScrollView(child: rows),
    ),
  );

  if (textScale == null) return sized;
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: sized,
    ),
  );
}

/// The default surface: a customer who is not yet a Jeeber.
///
/// Eight rows under two section headers, and the only state in which the
/// "Register as a delivery" row exists — so it is both the tallest (552 pt) and
/// the only one that can break horizontally. Everything is legible at 1×; open
/// the AR RTL dark rendering to see the "Account"/"Support" headers and the
/// glyphs inside the navy discs drop to ~2:1 and ~1.4:1.
@JeebPreview(
  group: 'customer_profile',
  name: 'Client · 390',
  size: _customerProfileRowsPhoneBox,
)
Widget customerProfileRowsClient() =>
    _customerProfileRowsHosted(showRegister: true);

/// JM-035 AC2 / design §8.2, made visible: once the account is already a
/// Jeeber, the register row must disappear **entirely** — not grey out, not
/// read "already registered".
///
/// Worth its own preview because the failure mode is silent: the row is behind
/// a bare `if (showRegister)`, so a regression either leaves a Jeeber a dead
/// "Register" button or removes 56 pt of the Account section from everyone. The
/// column drops from 552 pt to 496 pt and from 8 rows to 7; the
/// `customer_profile_register_delivery_row` semantics node must be gone with
/// it, since Maestro keys on the identifier rather than on the text.
@JeebPreview(
  group: 'customer_profile',
  name: 'Jeeber · register hidden',
  size: _customerProfileRowsJeeberBox,
)
Widget customerProfileRowsJeeber() =>
    _customerProfileRowsHosted(showRegister: false);

/// Layout ceiling, part 1: the same client rows on a 320 pt phone.
///
/// The row spends a fixed 24 pt of padding per side, a 32 pt icon disc and an
/// 8 pt gap before the label gets anything, and the register row then hands the
/// rest to an intrinsically-sized pill. At 1× that already truncates
/// "Register as a delivery" from 157 pt to 87 pt — the label is capped at one
/// line (ellipsis without `maxLines`), so it clips rather than wrapping.
///
/// **This is the preview whose EN 200% rendering is the one to open.** At 320 pt
/// and 200% the label is allotted zero width and the row overflows on the
/// trailing edge: the user is left with a "Register" button and no statement of
/// what they are registering for. It is pinned in the render test as a known
/// defect; the sibling [customerProfileRowsJeeberNarrowLargeText] shows the
/// same width and scale staying clean once the pill is gone, which is what
/// identifies the pill as the cause.
@JeebPreview(
  group: 'customer_profile',
  name: 'Narrow 320',
  size: _customerProfileRowsNarrowBox,
)
Widget customerProfileRowsNarrowPhone() => _customerProfileRowsHosted(
      showRegister: true,
      width: _customerProfileRowsNarrowPhoneWidth,
    );

/// Layout ceiling, part 2: phone width at the 200% accessibility ceiling, with
/// the scale pinned so a widget test reproduces it.
///
/// Nothing overflows at 390 pt, which is exactly why this state is easy to miss:
/// the row still measures 56 pt tall, but the label has collapsed from 157 pt to
/// 45 pt while the pill grew from 113 pt to 225 pt. The row's chrome (a fixed
/// 40 pt-high button carrying 40 pt-tall text) is unchanged; only the sentence
/// that says what the row does is gone.
///
/// The seven chevron rows survive the same scale intact — an [Expanded] label
/// against a 16 pt chevron has room to shrink — so the register row is the only
/// one whose meaning depends on text scale.
@JeebPreview(
  group: 'customer_profile',
  name: '200% text · 390',
  size: _customerProfileRowsLargeTextBox,
)
Widget customerProfileRowsLargeText() =>
    _customerProfileRowsHosted(showRegister: true, textScale: 2.0);

/// The control for [customerProfileRowsNarrowPhone]: worst width AND worst text
/// scale, but for a Jeeber.
///
/// Same 320 pt, same 200%, one row fewer — and it renders clean, with every
/// remaining label ellipsized instead of overflowing. That contrast is the
/// finding: the trailing pill, not the width, the scale, or `CustomerProfileRow`
/// itself, is what breaks the layout.
@JeebPreview(
  group: 'customer_profile',
  name: 'Jeeber narrow · 200% text',
  size: _customerProfileRowsNarrowLargeTextBox,
)
Widget customerProfileRowsJeeberNarrowLargeText() => _customerProfileRowsHosted(
      showRegister: false,
      width: _customerProfileRowsNarrowPhoneWidth,
      textScale: 2.0,
    );
