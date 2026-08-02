/// Widget previews for [DeliveryEtaBadge] — run with
/// `flutter widget-preview start`.
///
/// The badge takes one `int` and nothing else — no cubit, no repository, no
/// async input — so these previews are network-free because there is nothing to
/// fetch, not merely because [jeebPreviewHost] guards the wire. "Empty /
/// loading / error" do not exist for it either: the screen decides whether the
/// badge exists at all (`DeliverySnapshot.isEtaVisible` gates it to
/// `active` + `inTransit` + a non-null ETA), so by the time this widget builds
/// there is always a number. Its states are the two branches of
/// `minutes <= 1`, the values that branch has to survive, and the width its one
/// host leaves it.
///
/// **Why every state is a header row rather than a bare pill.** The badge has
/// exactly one call site — the `Row` in `_Body` of `delivery_status_screen.dart`
/// — where it is the *non-flexible* trailing child beside an `Expanded`
/// "Delivery #id" caption. That is the whole story of this widget's layout: a
/// non-flexible child is laid out first, against unbounded width, so the badge
/// always takes what it wants and the caption always pays. Reviewed on its own
/// the badge is a pill on an empty page and every state looks fine; reviewed in
/// the row you can see what it costs the caption. The row is reproduced here
/// rather than imported because the production one is private to `_Body` — the
/// same trade `client_home_tier_badge_preview.dart` makes, with the same
/// caveat: if `_Body` changes its geometry these previews are wrong and say
/// nothing.
///
/// Three things the matrix surfaces, all in the widget rather than in the
/// previews — see the notes on the individual states:
///
///  * the `Icon` is pinned at `size: 16` and Flutter's default
///    `applyTextScaling` is `false` (nothing in `AppTheme` registers an
///    `iconTheme`), so at the 200% ceiling the label doubles to 22pt and the
///    value to 28pt while the timer glyph stays exactly 16 — the one element of
///    the pill that opts out of the accessibility contract the rest of it
///    honours;
///  * the pill is `colorScheme.primaryContainer`, and that role is not the same
///    colour family in the two schemes. `AppTheme.light()` overrides it to the
///    brand ORANGE container (`#FFDBD1`, hue 13°); `AppTheme.dark()` derives it
///    from the NAVY seed (`#3C4279`, hue 234°). So the AR RTL dark rendering
///    shows a *blue* pill where EN light shows an orange one. Contrast is
///    comfortable at both ends (13.3:1 and 7.2:1) — it is the hue that jumps,
///    and only a side-by-side rendering shows it;
///  * neither `Text` sets `maxLines` or `overflow`, which is survivable only
///    because of the unbounded-width lay-out above: the badge cannot ellipsize,
///    so pressure is exported to the caption instead of absorbed. Within the
///    200% ceiling and the app's bundled Inter it never actually overflows —
///    see [deliveryEtaBadgeNarrowCeiling] for how far that goes and what the
///    caption looks like by then.
library;

import 'package:flutter/material.dart';

import '../../features/delivery_status/presentation/widgets/delivery_eta_badge.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The width the status header row really gets on a 390pt phone: `_Body`'s
/// `SingleChildScrollView` padding is `Spacing.large` (20) on both sides.
/// `390 - 20 - 20 = 350`.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose. The
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface — a row left to fill its host would squeeze the badge on the phone
/// and not squeeze it under test, so the state that breaks would only break in
/// one of the two places it is looked at.
const double _rowWidth = 350;

/// The same row on the narrowest phone the app still lays out for (320pt):
/// `320 - 20 - 20 = 280`.
const double _narrowRowWidth = 280;

/// Canvas box for the header row. Tall enough for the 200% rendering, where the
/// caption wraps beside a 64pt pill instead of ellipsizing.
const Size _rowBox = Size(390, 220);

/// Puts [child] at the width its production row really has, centred in the
/// canvas.
Widget _hosted(Widget child, {double width = _rowWidth}) => Center(
      child: SizedBox(width: width, child: child),
    );

/// Reproduces the status header row from `_Body` in
/// `delivery_status_screen.dart`: an [Expanded] "Delivery #id" caption in
/// `bodySmall` / `onSurfaceVariant`, spread apart from the badge and vertically
/// centred.
///
/// The caption is not decoration here. It is the only thing in the app that
/// competes with the badge for width, and — like the badge — it carries no
/// `maxLines` and no `overflow`, so when the badge grows the caption *wraps*
/// rather than ellipsizing.
class _StatusHeaderRow extends StatelessWidget {
  const _StatusHeaderRow({required this.deliveryId, required this.minutes});

  final String deliveryId;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            l10n.deliveryStatusIdSubtitle(deliveryId),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DeliveryEtaBadge(minutes: minutes),
      ],
    );
  }
}

/// The state that ships: a courier a few minutes out, in the row the screen
/// really gives it.
///
/// Seven is the ETA `test/delivery_status_screen_test.dart` drives the
/// in-transit case with (the in-repo gateway fixture emits eight), so this is
/// the ordinary reading — and the one to compare the rest of the matrix
/// against rather than to admire in EN light:
///
///  * **AR RTL dark** — the row mirrors and so does the pill, unaided: both are
///    order-based [Row]s, the badge's padding is `EdgeInsets.symmetric` and its
///    inner gaps are symmetric [SizedBox]es, so there is no `EdgeInsets.only`
///    to get wrong. The timer glyph moves to the right edge of the pill and the
///    pill to the left edge of the row, and the label is localized ("الوصول",
///    not "ETA"). What changes and arguably should not is the fill: the same
///    `primaryContainer` role is brand orange in light and navy-blue in dark —
///    one pill, two identities.
///  * **EN 200% text** — both strings scale (neither `Text` overrides
///    `textScaler`) and the pill grows from 44 to 64pt tall with them, which is
///    right. The `Icon` does not: `size: 16` with `applyTextScaling` unset
///    leaves a 16pt glyph beside a 28pt value.
@JeebPreview(name: 'In transit · 7 min', size: _rowBox)
Widget deliveryEtaBadgeTypical() => _hosted(
      const _StatusHeaderRow(deliveryId: 'd-1', minutes: 7),
    );

/// The other branch, and the reason this widget takes `minutes` rather than a
/// pre-formatted string: at one minute the number is replaced by words.
///
/// "Arriving now" is also the widest thing the badge can say — it swells the
/// pill from 123pt to 175pt on a 350pt row, half the header, and at 200% to
/// 284pt of 350. Its Arabic twin measures almost exactly the same (the AR label
/// "الوصول" is wider than "ETA" while "يصل الآن" is narrower than "Arriving
/// now", and the two differences cancel), so unusually for this app the RTL
/// rendering is under the same pressure rather than less.
@JeebPreview(name: 'Arriving now · 1 min', size: _rowBox)
Widget deliveryEtaBadgeArriving() => _hosted(
      const _StatusHeaderRow(deliveryId: 'd-2', minutes: 1),
    );

/// The off-by-one guard: two minutes is the first value that is NOT "arriving".
///
/// `minutes <= 1` is the whole of the branch — written once, easy to widen by
/// accident. Beside [deliveryEtaBadgeArriving] this pins the threshold
/// visually: if this ever renders "Arriving now" the comparison was loosened to
/// `<= 2` and every courier silently gained a minute of grace.
@JeebPreview(name: 'Threshold · 2 min', size: _rowBox)
Widget deliveryEtaBadgeThreshold() => _hosted(
      const _StatusHeaderRow(deliveryId: 'd-3', minutes: 2),
    );

/// Longest plausible numeric content: the ceiling of the ETA a courier was
/// allowed to promise.
///
/// `OfferEtaBand.defaultBand()` offers 5..120 minutes in 5-minute steps, so 120
/// is the largest ETA that can enter the system through the offer composer —
/// three digits, and the widest the *number* ever legitimately gets. It is
/// still narrower than [deliveryEtaBadgeArriving]: a third digit costs the pill
/// ~16pt, a twelve-character phrase costs it ~52pt. Worth knowing which state
/// is really the layout ceiling before tuning anything for the other.
@JeebPreview(name: 'Ceiling · 120 min', size: _rowBox)
Widget deliveryEtaBadgeCeiling() => _hosted(
      const _StatusHeaderRow(deliveryId: 'd-4', minutes: 120),
    );

/// The bad-data state, and the second reason the `<= 1` branch exists.
///
/// `DeliverySnapshot.etaMinutes` is an unvalidated `int?`. The gateway contract
/// says the production binding "will sit on a realtime-communication-service
/// websocket", and nothing between that wire and this widget clamps the value —
/// so a backend that computes *remaining* time against a promise the courier
/// has already blown sends a negative int, and this widget renders whatever it
/// is handed.
///
/// It degrades correctly: `minutes <= 1` catches every non-positive value, so
/// the pill says "Arriving now" and never "-6 min". This state earns a preview
/// precisely because that is invisible in the canvas — the bug and the
/// non-bug look identical — which is why the render test asserts the raw number
/// is ABSENT instead of looking at the pill.
@JeebPreview(name: 'Past due · negative ETA', size: _rowBox)
Widget deliveryEtaBadgePastDue() => _hosted(
      const _StatusHeaderRow(deliveryId: 'PAST-DUE-9', minutes: -6),
    );

/// The worst case a real device can produce: the ceiling ETA, on the narrowest
/// phone the app lays out for, at the 200% text ceiling.
///
/// This is the state the "no `maxLines`, no `overflow`" note in the library doc
/// is about, and the answer is better than expected in one way and worse in
/// another. Nothing overflows: at 200% the pill is 213pt of the 280pt row, so
/// the `Expanded` caption still has 67pt and Flutter never paints the
/// yellow-and-black. But 67pt is not a caption — "Delivery #NARROW-320" wraps
/// into SIX stacked fragments and drags the header from 44pt to 192pt tall,
/// taller than the stage indicator below it. The badge exports every point of
/// pressure to its sibling and absorbs none, because it has no ellipsis to give.
///
/// Worth comparing against [deliveryEtaBadgeCeiling], which is the same pill on
/// a 350pt row: 70pt more width is the difference between a two-line caption
/// and a six-line one.
@JeebPreview(name: 'Narrow phone · 120 min', size: _rowBox)
Widget deliveryEtaBadgeNarrowCeiling() => _hosted(
      const _StatusHeaderRow(deliveryId: 'NARROW-320', minutes: 120),
      width: _narrowRowWidth,
    );
