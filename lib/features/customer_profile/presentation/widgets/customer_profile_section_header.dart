import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';

/// Section header ("Account" / "Support"): navy, title-medium, guttered.
class CustomerProfileSectionHeader extends StatelessWidget {
  const CustomerProfileSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        Spacing.xSmall,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
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
// Render tests: test/previews/customer_profile/customer_profile_section_header_preview_test.dart
// ===========================================================================

// Widget previews for [CustomerProfileSectionHeader] — run with
// `flutter widget-preview start`.
//
// The header is a [Padding] around a single [Text]. It has one input, a
// `String title`, no cubit and no repository, so every preview below is
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// Its two shipping callers are in `customer_profile_rows.dart`, and both hand
// it an ARB string — `customerProfileSectionAccount` and
// `customerProfileSectionSupport`. The previews resolve those keys through
// [AppLocalizations] instead of restating the English, so the **AR RTL dark**
// rendering shows the real Arabic copy (`الحساب` / `الدعم`) that
// `test/customer_profile_screen_test.dart` already asserts, rather than
// English text in an Arabic frame.
//
// What is worth looking at, and why each state below exists:
//
// * **Ink colour.** The title is painted with `colorScheme.secondaryContainer`
//   — a *container* role, i.e. a fill meant to sit BEHIND ink. `app_theme.dart`
//   says so in its own words ("Anything that wants to PAINT ... must use
//   `tertiary`, never a `*Container` role"). It survives in light only because
//   the light scheme hard-codes that role to the brand navy: navy on white is
//   17.13:1. The dark scheme is `ColorScheme.fromSeed(_jeebNavy, dark)`, where
//   the role resolves to a dark container tone on a surface of nearly the same
//   tone — **1.98:1**, under the 4.5:1 WCAG AA floor for body text and under
//   even the 3:1 large-text floor. Every `AR RTL dark` rendering here is that
//   defect, and the preview test pins the numbers. `JeebVerifiedBadge` inks
//   with the same role and its preview test already pins the same gap.
//
// * **Mirroring.** The padding is [EdgeInsetsDirectional], so it mirrors — but
//   it is also symmetric (24 start / 24 end), so the mirroring is invisible in
//   the padding and shows up only as the paragraph flipping to right-aligned.
//   That is asserted from the glyph boxes in the preview test, because the
//   `Text`'s own render box spans the full width in both directions.
//
// * **Overflow.** The [Text] sets no `maxLines` and no `overflow`, so a title
//   too long for its line wraps instead of ellipsizing or painting an overflow
//   stripe. Good degradation, but nothing enforces it — see
//   [customerProfileSectionHeaderLongestTitleCompact].

/// The canvas box for one section header: phone width, one line of title plus
/// its 20/8 padding. Roomy enough that the `EN 200% text` rendering (which
/// scales the line but not the padding) still fits without a stripe of its own.
const Size _customerProfileSectionHeaderHeaderBox = Size(390, 96);

/// Taller box: the states whose title wraps, and the multi-widget boundary.
const Size _customerProfileSectionHeaderTallBox = Size(390, 220);

/// The Account → Support boundary needs room for two rows plus the header.
const Size _customerProfileSectionHeaderBoundaryBox = Size(390, 260);

/// The narrowest device the app still supports.
///
/// Applied as a real [SizedBox] rather than by shrinking the canvas box,
/// because a preview's `size` only constrains the canvas — the render test
/// pumps at the default 800pt test surface, where a canvas-only width would
/// silently stop being the state under review.
const double _customerProfileSectionHeaderCompactPhoneWidth = 320;

/// Hosts [header] the way `CustomerProfileRows` really does — a [Column] with
/// `crossAxisAlignment.stretch`.
///
/// Not decoration. [jeebPreviewHost]'s [Scaffold] passes its body LOOSE
/// constraints, so a header dropped straight into it shrink-wraps: the title
/// paragraph sizes to its own glyphs and every alignment question answers
/// itself. Stretched, the paragraph gets the full width and has to choose an
/// edge — which is the only place the [EdgeInsetsDirectional] mirroring is
/// observable at all.
Widget _customerProfileSectionHeaderStretched(Widget header) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[header],
    );

/// The header, with its title resolved from the real ARB at build time.
Widget _customerProfileSectionHeaderHosted(
  String Function(AppLocalizations) title,
) =>
    _customerProfileSectionHeaderStretched(
      Builder(
        builder: (BuildContext context) => CustomerProfileSectionHeader(
          title: title(AppLocalizations.of(context)),
        ),
      ),
    );

/// The first of the two strings this widget ships with.
///
/// The `Account` header opens the profile's navigation list, so it is the
/// rendering a reviewer signs off. Read the **AR RTL dark** variant of this one
/// first: the Arabic is correct and the paragraph mirrors, and the title is
/// still barely legible, because the ink role resolves to a container tone at
/// 1.98:1 against the dark surface (see the section doc).
@JeebPreview(
  group: 'customer_profile',
  name: 'Account (production)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderAccount() =>
    _customerProfileSectionHeaderHosted(
      (AppLocalizations l10n) => l10n.customerProfileSectionAccount,
    );

/// The second shipping string, and the only other real caller.
///
/// Worth its own preview rather than being assumed identical to `Account`:
/// Arabic `الدعم` is shorter than `الحساب` and sits on a different baseline mix
/// of ascenders, which is exactly the kind of difference a single-state preview
/// hides.
@JeebPreview(
  group: 'customer_profile',
  name: 'Support (production)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderSupport() =>
    _customerProfileSectionHeaderHosted(
      (AppLocalizations l10n) => l10n.customerProfileSectionSupport,
    );

/// The header in the only place it actually appears: the Account → Support
/// boundary of `CustomerProfileRows`, reproduced row for row.
///
/// A section header cannot be reviewed alone, because its whole job is spatial.
/// Two contracts only become visible here:
///
/// * **Gutter.** The header indents to `Spacing.xLarge` (24), the same gutter
///   the row's 32dp icon disc starts at — so it aligns with the row's *disc*,
///   40pt to the leading side of the row's *label*. That is the design §1/§4
///   alignment, and it is a decision, not an accident; the preview test pins it
///   so a future tweak to either padding shows up as a failure.
/// * **Rhythm.** The padding is asymmetric on purpose — 20 above, 8 below — so
///   the header binds to the section *beneath* it rather than floating between
///   two groups. At 200% text that asymmetry does not scale with the type, so
///   the visual grouping weakens exactly where the rows get taller.
@JeebPreview(
  group: 'customer_profile',
  name: 'Account → Support boundary',
  size: _customerProfileSectionHeaderBoundaryBox,
)
Widget customerProfileSectionHeaderBoundary() => Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The last row of the Account section.
            CustomerProfileRow(
              icon: Icons.location_on_outlined,
              label: l10n.savedAddressesTitle,
              semanticsId: 'customer_profile_addresses_row',
              onTap: () {},
            ),
            CustomerProfileSectionHeader(
              title: l10n.customerProfileSectionSupport,
            ),
            // The first row of the Support section.
            CustomerProfileRow(
              icon: Icons.call_outlined,
              label: l10n.customerProfileContactUs,
              semanticsId: 'customer_profile_contact_row',
              onTap: () {},
            ),
          ],
        );
      },
    );

/// The layout ceiling, built from real copy rather than an invented string.
///
/// `jeeberRequestDetailSectionDescription` ("What the client says" /
/// "ما يقوله العميل") is the LONGEST section title in the app's 1534-key ARB, so
/// it is the worst case a future third section on this screen could plausibly
/// hand the header. It is shown on a 320pt host — the narrowest supported
/// device — which leaves the title `320 - 48 = 272`pt.
///
/// In the canvas (real Inter) it still fits on one line at 1.0, which is the
/// point: the EN light rendering looks fine long after the other two have
/// stopped. The **EN 200% text** rendering is the state to read — the title
/// wraps to several lines while the 20/8 padding stays frozen, and it wraps
/// rather than ellipsizing only because the [Text] sets no `maxLines` and no
/// `overflow`. Nothing in the widget enforces that; add either and this state
/// starts clipping instead. (The render test asserts only that the line count
/// GROWS with text scale — `flutter_test` substitutes its own metrics for
/// Inter, so the exact wrap point there is a property of the test font.)
@JeebPreview(
  group: 'customer_profile',
  name: 'Longest ARB title, 320pt device',
  size: _customerProfileSectionHeaderTallBox,
)
Widget customerProfileSectionHeaderLongestTitleCompact() => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _customerProfileSectionHeaderCompactPhoneWidth,
        child: _customerProfileSectionHeaderHosted(
          (AppLocalizations l10n) => l10n.jeeberRequestDetailSectionDescription,
        ),
      ),
    );

/// The degenerate input: a title that is present but empty.
///
/// `title` is `required`, which only means "supplied" — nothing asserts it is
/// non-empty, and nothing in the widget short-circuits on it. The result is a
/// header that paints no pixels while still consuming its 20 + line + 8 band,
/// i.e. an unexplained gap between two rows that reads as a layout bug rather
/// than as missing copy.
///
/// Not reachable from today's two callers (both pass ARB constants), and worth
/// a picture precisely because the next caller — a server-named section, a key
/// that fell out of the ARB during a merge — would reach it silently.
@JeebPreview(
  group: 'customer_profile',
  name: 'Empty title (invisible, still spaced)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderEmptyTitle() =>
    _customerProfileSectionHeaderStretched(
      const CustomerProfileSectionHeader(title: ''),
    );
