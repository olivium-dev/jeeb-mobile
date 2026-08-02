/// Widget previews for [ClientHomeTierBadge] — run with
/// `flutter widget-preview start`.
///
/// The badge takes no repository, no cubit and no async input: everything it
/// draws is a function of one enum ([ClientRequestTier]), the ambient
/// [JeebTierColors] theme extension, and the [AppLocalizations] of the host. So
/// these previews are network-free because there is nothing to fetch, not
/// merely because [jeebPreviewHost] guards the wire — and "empty / loading /
/// error" do not exist. Its states are the four enum values plus the pressure
/// its three shipping hosts put on it.
///
/// **Why every state is a header row rather than a bare chip.** The badge is the
/// trailing child of a title row in all three call sites — `_ActiveOrderHeader`
/// here in `active_request_card.dart`, `_PendingHeader` in
/// `pending_request_card.dart` and `_PendingCardHeader` in
/// `pending_requests_tab.dart`. Reviewed on its own it is one word on an empty
/// page and every state looks fine; reviewed in the row it competes with an
/// ellipsizing title for a fixed width, which is where a tier badge can actually
/// go wrong. Those rows are reproduced below rather than imported, because the
/// production ones are private and because importing the whole card would make
/// this a preview of the card. If either header changes its geometry, these
/// previews are wrong and say nothing — the same trade
/// `jeeb_verified_badge_preview.dart` makes.
///
/// Three things the matrix surfaces, all in the widget rather than in the
/// previews — see the notes on the individual states:
///
///  * [ClientRequestTier.unknown] resolves to the empty string, so the
///    "neutral chip" the domain enum promises for a tier the backend adds
///    mid-deploy is in fact NOTHING: a zero-width [Text] and a stray 8pt gap;
///  * the tier inks are three fixed hexes registered identically in
///    `AppTheme.light()` and `AppTheme.dark()`, painted as 11pt text straight
///    onto `surface` — on the light scheme's white none of the three clears
///    WCAG AA (Flash 4.23:1, Express 2.37:1, Standard 3.68:1), and the AR RTL
///    dark rendering reuses those same hexes on a near-black surface, where the
///    ranking inverts (Express 7.81:1, Standard 5.03:1, Flash still 4.38:1);
///  * the badge is nothing but a [Text], so the two production header shapes
///    align it differently — centred against the title here, top-aligned in
///    both pending headers.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/widgets/active_request_card.dart';
import '../harness/jeeb_preview.dart';

/// The width the in-progress header row really gets: a 390pt phone, the card's
/// `Spacing.medium` gutters on both sides, the `Sizes.threeXLarge` avatar and
/// its `Spacing.twoXSmall` gap. `390 - 16 - 16 - 40 - 4 = 314`.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose. The
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface — a row left to fill its host would squeeze the badge on the phone
/// and not squeeze it under test, so the state that breaks would only break in
/// one of the two places it is looked at.
const double _activeHeaderWidth = 314;

/// The width the pending header row gets: same phone, same gutters, no avatar.
/// `390 - 16 - 16 = 358`.
const double _pendingHeaderWidth = 358;

/// Canvas box for a header row. Tall enough that the 200% rendering (a 22pt
/// title at 44pt) still has air around it.
const Size _headerBox = Size(390, 120);

/// Canvas box for the four-value strip, which wraps at 200%.
const Size _stripBox = Size(390, 260);

/// Puts [child] at the width its production row really has, centred in the
/// canvas.
Widget _hosted(Widget child, {double width = _activeHeaderWidth}) => Center(
      child: SizedBox(width: width, child: child),
    );

/// Reproduces `_ActiveOrderHeader` from `active_request_card.dart`: a
/// [Flexible] ellipsizing title, `Spacing.xSmall`, the badge, spread apart and
/// vertically centred.
class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({required this.title, required this.tier});

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

/// Reproduces `_PendingCardHeader` from `pending_requests_tab.dart` (and its
/// twin `_PendingHeader` in `pending_request_card.dart`): an [Expanded] title
/// and `CrossAxisAlignment.start`.
///
/// The only difference from [_ActiveHeader] that matters is the cross-axis
/// alignment, and it is the badge that pays for it — see
/// [clientHomeTierBadgeExpressPending].
class _PendingHeader extends StatelessWidget {
  const _PendingHeader({required this.title, required this.tier});

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

/// One cell of the comparison strip: the badge over the enum value that
/// produced it.
///
/// The enum name is preview scaffolding, not widget output. It exists because
/// the `unknown` swatch renders nothing at all — without a caption underneath,
/// that cell is indistinguishable from a rendering bug.
class _TierSwatch extends StatelessWidget {
  const _TierSwatch(this.tier);

  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: Sizes.large,
            child: Center(child: ClientHomeTierBadge(tier: tier)),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            tier.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      );
}

/// The state that ships on an in-progress card: Flash, in the header row the
/// card really gives it.
///
/// This is the one a designer signs off, and the rendering to compare across the
/// matrix rather than to admire in EN light:
///
///  * **AR RTL dark** — the row mirrors correctly (a [Row] is order-based and
///    `Spacing.xSmall` is a symmetric [SizedBox], so there is no
///    `EdgeInsets.only` to get wrong) and the label is localized ("سريع", not
///    "Flash"). What does not change is the ink: `JeebTierColors.standard()` is
///    registered with the SAME three hexes in `AppTheme.light()` and
///    `AppTheme.dark()`, so the `#E53935` that reads at 4.23:1 on white is asked
///    to read on the near-black dark surface too, where it manages 4.38:1.
///    Flash is the one tier that misses the 4.5:1 WCAG AA asks of 11pt text at
///    BOTH ends of the theme — the price of a single fixed hex serving two
///    schemes.
///  * **EN 200% text** — the badge does scale with the text scaler (it is a
///    [Text], and nothing overrides `textScaler`), which is the right behaviour
///    and worth confirming against the fixed-size seal in
///    `jeeb_verified_badge_preview.dart`. Both texts double, but the
///    `Spacing.xSmall` between them does not: even this short name has to
///    ellipsize at 200%, and 8 unscaled points are then all that separate it
///    from the tier label.
@JeebPreview(name: 'Flash · in-progress header', size: _headerBox)
Widget clientHomeTierBadgeFlash() => _hosted(
      const _ActiveHeader(title: 'Kamal Hajj', tier: ClientRequestTier.flash),
    );

/// The state that ships on a pending card: Express, in the OTHER production
/// header — `Expanded` title, `CrossAxisAlignment.start`.
///
/// Visually this should be the same badge in the same place, and it is not. The
/// in-progress header centres its children, so the badge sits against the
/// optical middle of the title; the two pending headers top-align them, so the
/// same 11pt label rides up against the title's ascender. One widget, two
/// vertical positions relative to the line it labels — pinned in the render test
/// because it is a few pixels, and a few pixels is exactly what nobody catches
/// by scrolling the canvas.
///
/// Express is also the worst of the three inks in the scheme users actually
/// ship on: `#FB8C00` on white is 2.37:1, barely half of AA. Flip to the AR RTL
/// dark rendering and the same hex is 7.81:1 — the best of the three. One token
/// serving two surfaces cannot be tuned for either.
@JeebPreview(name: 'Express · pending header', size: _headerBox)
Widget clientHomeTierBadgeExpressPending() => _hosted(
      const _PendingHeader(
        title: 'ORD-23470',
        tier: ClientRequestTier.express,
      ),
      width: _pendingHeaderWidth,
    );

/// Standard, the default tier and the quietest of the three.
///
/// `#1E88E5` on white is 3.68:1 — above the 3:1 asked of a graphical object,
/// below the 4.5:1 asked of the small text this actually is. Worth looking at
/// beside [clientHomeTierBadgeFlash]: the tiers are told apart ONLY by hue, at
/// 11pt, with no fill, no border and no icon, so a red/green-blind reader (and
/// anyone on a sun-washed screen) is distinguishing Flash from Standard by two
/// mid-tone colours of near-identical lightness.
@JeebPreview(name: 'Standard · in-progress header', size: _headerBox)
Widget clientHomeTierBadgeStandard() => _hosted(
      const _ActiveHeader(
        title: 'Pharmacy run',
        tier: ClientRequestTier.standard,
      ),
    );

/// The state that breaks, and the reason this widget has a fallback branch at
/// all: a tier the backend introduced mid-deploy.
///
/// `ClientRequestTier.parse` maps every unrecognised string to `unknown`, and
/// the enum's own doc comment says that "falls back to a neutral chip so the
/// screen never crashes". It does not crash — but there is no chip. `_labelFor`
/// returns `''`, so the badge is a zero-width [Text] carrying a carefully chosen
/// `colorScheme.tertiary` that inks nothing, and the `Spacing.xSmall` gap before
/// it becomes a stray 8pt of trailing air. The order silently loses its tier
/// rather than showing an unstyled one.
///
/// Nothing in the canvas can distinguish this from a correct render, which is
/// why the render test measures the badge box instead of looking at it.
@JeebPreview(name: 'Unknown tier · nothing renders', size: _headerBox)
Widget clientHomeTierBadgeUnknown() => _hosted(
      const _ActiveHeader(
        title: 'ORD-88213',
        tier: ClientRequestTier.unknown,
      ),
    );

/// Longest plausible content: a title that cannot fit, pressing on the badge.
///
/// The good news, and the failure this preview was written to look for: the
/// badge is never pushed off the trailing edge. [Flexible] hands the title only
/// the leftovers, so the label and its 8pt gap are always reserved and the title
/// ellipsizes instead. Compare the EN 200% rendering, where the title is reduced
/// to about two words and an ellipsis while the tier survives intact — the
/// priority is right, and it is worth having a preview that proves it rather
/// than assuming it.
///
/// The bad news is legibility, not layout: at the width left over the ellipsized
/// title and the badge sit 8 unscaled points apart, and the badge's
/// `letterSpacing: 0.5` is applied to the Arabic label too, where letter
/// spacing pulls apart a cursive script that is meant to join.
@JeebPreview(name: 'Long title · badge holds its place', size: _headerBox)
Widget clientHomeTierBadgeLongTitle() => _hosted(
      const _ActiveHeader(
        title: 'Pharmacy run — Ashrafieh to Hamra, ring the second bell',
        tier: ClientRequestTier.flash,
      ),
    );

/// All four enum values side by side, which is the only way to see the palette
/// as a palette.
///
/// Two things only show up here. First, `unknown` is a hole: three labels and a
/// gap. Second, the **AR RTL dark** rendering paints the same three
/// light-scheme hexes on a near-black surface — nothing re-tunes them — where
/// Flash and Standard sit at 0.20 and 0.23 relative luminance. The strip that
/// reads as three distinct tiers in EN light reads as one tone family there,
/// and in both schemes hue is the ONLY channel carrying the distinction: no
/// fill, no border, no icon, 11pt.
///
/// A [Wrap] rather than a [Row] so the 200% rendering reflows instead of
/// reporting a fixture overflow that says nothing about the badge.
@JeebPreview(name: 'All four tiers · strip', size: _stripBox)
Widget clientHomeTierBadgeStrip() => _hosted(
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: Spacing.large,
            runSpacing: Spacing.small,
            alignment: WrapAlignment.center,
            children: <Widget>[
              _TierSwatch(ClientRequestTier.flash),
              _TierSwatch(ClientRequestTier.express),
              _TierSwatch(ClientRequestTier.standard),
              _TierSwatch(ClientRequestTier.unknown),
            ],
          ),
          SizedBox(height: Spacing.small),
          Text(
            'Every ClientRequestTier value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      width: _pendingHeaderWidth,
    );
