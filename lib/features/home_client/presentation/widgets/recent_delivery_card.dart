import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/recent_delivery_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// One-tap "order again" card for the most recent completed delivery.
///
/// Composed entirely from OMDS primitives — [OmdsPrimaryButton] for the
/// reorder CTA, and tokenized layout containers (`Spacing`, `Sizes`,
/// `OmdsBorderRadius`, `colorScheme.*`) elsewhere. No raw `TextButton`,
/// no hardcoded colors, no magic dimensions.
class RecentDeliveryCard extends StatelessWidget {
  const RecentDeliveryCard({
    super.key,
    required this.summary,
    required this.onReorder,
  });

  final RecentDeliverySummary summary;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: _RecentDeliveryRow(summary: summary, onReorder: onReorder),
    );
  }
}

class _RecentDeliveryRow extends StatelessWidget {
  const _RecentDeliveryRow({required this.summary, required this.onReorder});

  final RecentDeliverySummary summary;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        const _RecentDeliveryIcon(),
        const SizedBox(width: Spacing.small),
        Expanded(child: _RecentDeliveryText(summary: summary)),
        const SizedBox(width: Spacing.small),
        OmdsPrimaryButton(
          key: Key('recent-delivery-reorder-${summary.id}'),
          variant: OmdsButtonVariant.text,
          text: l10n.homeReorderAction,
          onTap: onReorder,
        ),
      ],
    );
  }
}

class _RecentDeliveryIcon extends StatelessWidget {
  const _RecentDeliveryIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Icon(
        Icons.replay_outlined,
        color: scheme.onPrimaryContainer,
        size: Sizes.large,
      ),
    );
  }
}

class _RecentDeliveryText extends StatelessWidget {
  const _RecentDeliveryText({required this.summary});

  final RecentDeliverySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecentDeliveryTitle(text: summary.title),
        const SizedBox(height: Spacing.twoXSmall),
        _RecentDeliverySubtitle(text: summary.destinationLabel),
      ],
    );
  }
}

class _RecentDeliveryTitle extends StatelessWidget {
  const _RecentDeliveryTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RecentDeliverySubtitle extends StatelessWidget {
  const _RecentDeliverySubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
// Render tests: test/previews/home_client/recent_delivery_card_preview_test.dart
// ===========================================================================
//
// [RecentDeliveryCard] is a pure view over one [RecentDeliverySummary]: no
// cubit, no repository, no image. Every fixture below is a plain value object
// and `onReorder` is a no-op, so these previews are network-free by
// construction, not merely by the guard in [jeebPreviewHost].
//
// The happy-path fixture reuses `test/client_home_cubit_test.dart` (`_recent`:
// "Mini-market run" / "Hamra, Beirut"), and the degraded fixture reuses what
// `DioClientHomeRepository._parseRecentDelivery` actually emits for a row with
// no `title` and no `dropoff.address` — a `Delivery #XXXXXX` reference title
// and an **empty** destination string.
//
// ## Read this canvas for one thing: the text column is tiny, and localized
//
// The row is `icon(24) + 12 + Expanded(text) + 12 + button`, inside 16 pt card
// padding. The button is NOT flexible — `OmdsPrimaryButton` has a null `width`,
// so in a [Row] it lays out at its intrinsic label width first and `Expanded`
// divides what is left. The label is localized, so the *text column width
// depends on the locale*. Measured at real device widths, not guessed:
//
// | width           | button (EN / AR) | text column EN | text column AR |
// |-----------------|-----------------:|---------------:|---------------:|
// | 390 pt (iPhone) |   144.8 / 186.0  |     165.2 pt   |   **124.0 pt** |
// | 360 pt (S22)    |   144.8 / 186.0  |     135.2 pt   |    **94.0 pt** |
// | 320 pt (SE)     |   144.8 / 186.0  |      95.2 pt   |    **54.0 pt** |
//
// Against that: "Mini-market run" wants **211.5 pt** and "Hamra, Beirut" wants
// **161.2 pt**. So the *shortest realistic fixture in the repo already
// ellipsizes on every phone*, and in Arabic — where "إعادة الطلب" is 41 pt
// wider than "Re-order" — both lines are clipped on every phone, down to about
// three characters on a 320 pt device.
//
// At 200% text the button grows but the column does not: EN leaves 53.2 pt,
// and **AR leaves 0.0 pt and still overflows the card by 30 px** — the title
// and destination disappear entirely and the canvas shows the stripe. That
// rendering is in the matrix for every preview below; it is the same card in
// each, so read it once on `Typical` and then look at content.
//
// None of this is visible under `test/`: widget tests pump into an 800×600
// viewport where the text column is 575 pt and everything fits. That gap is the
// whole reason these `size:` boxes are real phone widths. The preview render
// tests inherit the same 800 pt viewport and stay green; the clipping is a
// canvas finding, not a test failure.

/// A phone-width box. The card lays out at **80 pt** tall at 390 pt (108 pt at
/// 200% text), so 120 frames all three renderings of the matrix.
const Size _recentDeliveryCardCardBox = Size(390, 120);

/// The same card on a 320 pt phone — the small-device end of the range.
const Size _recentDeliveryCardSmallPhoneBox = Size(320, 120);

/// `completedAt` is fixed so nothing here depends on the clock.
///
/// It is also never rendered: the card shows title + destination only, so this
/// value cannot be seen in any preview below.
final DateTime _recentDeliveryCardCompletedAt = DateTime.utc(2026, 5, 16, 10, 30);

Widget _recentDeliveryCardHosted({
  required String id,
  required String title,
  required String destinationLabel,
}) =>
    RecentDeliveryCard(
      summary: RecentDeliverySummary(
        id: id,
        title: title,
        destinationLabel: destinationLabel,
        completedAt: _recentDeliveryCardCompletedAt,
      ),
      onReorder: () {},
    );

/// The happy path, straight from `test/client_home_cubit_test.dart`.
///
/// This is the reference rendering the others are read against — and the first
/// surprise: a 15-character title on the widest supported phone is *already*
/// truncated. "Mini-market run" wants 211.5 pt and gets 165.2 pt in English,
/// 124.0 pt in Arabic. Nothing about this fixture is long; the column is short.
@JeebPreview(
  group: 'home_client',
  name: 'Typical',
  size: _recentDeliveryCardCardBox,
)
Widget recentDeliveryCardTypical() => _recentDeliveryCardHosted(
      id: 'rd-2f1c',
      title: 'Mini-market run',
      destinationLabel: 'Hamra, Beirut',
    );

/// Real Beirut content: an Arabic title and an Arabic destination.
///
/// The AR RTL rendering of every other preview mirrors the *chrome* while
/// showing English content, which is not what a Lebanese client sees — titles
/// and addresses come back from the gateway in whatever the client typed. This
/// is the state where the mirrored layout and the mirrored content are read
/// together, and where the ellipsis has to land on the **left**.
///
/// It is also the tightest realistic pairing: the Arabic CTA leaves 124.0 pt,
/// and "طلبية سوبرماركت" wants 210.0 pt.
@JeebPreview(
  group: 'home_client',
  name: 'Arabic content',
  size: _recentDeliveryCardCardBox,
)
Widget recentDeliveryCardArabicContent() => _recentDeliveryCardHosted(
      id: 'rd-9b30',
      title: 'طلبية سوبرماركت',
      destinationLabel: 'الحمرا، بيروت',
    );

/// Degraded payload: exactly what the Dio parser produces for a completed row
/// that carries neither a `title`/`description` nor a `dropoff.address`.
///
/// Two fallbacks fire at once, and only one of them is real. The title degrades
/// to a friendly reference (`Delivery #CC42E6`) — deliberate, and the reason
/// `friendlyReference` exists. The destination degrades to `''`, which
/// [RecentDeliveryCard] renders as a `Text('')`: a **0 × 16 pt blank line**
/// under the title, plus its 4 pt gap, still occupying the same space a real
/// address would. The card does not shrink and does not say "destination
/// unknown" — it just shows a gap. Put this next to `Typical` in the canvas:
/// same height, one line of information missing with nothing marking it.
@JeebPreview(
  group: 'home_client',
  name: 'Degraded payload',
  size: _recentDeliveryCardCardBox,
)
Widget recentDeliveryCardDegradedPayload() => _recentDeliveryCardHosted(
      id: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
      title: 'Delivery #CC42E6',
      destinationLabel: '',
    );

/// Content ceiling: the longest plausible title next to the longest plausible
/// address.
///
/// Both lines are `maxLines: 1` + ellipsis, so the card can only clip — it
/// never wraps and never grows. In 165.2 pt of English column that is
/// "Pharmacy pickup for…"; in 124.0 pt of Arabic column it is roughly the first
/// two words. Because the card is the *"order again"* affordance, a client
/// re-ordering from a truncated title is tapping a button whose subject they
/// cannot fully read.
@JeebPreview(
  group: 'home_client',
  name: 'Long title + long destination',
  size: _recentDeliveryCardCardBox,
)
Widget recentDeliveryCardLongContent() => _recentDeliveryCardHosted(
      id: 'rd-7d41',
      title: 'Pharmacy pickup for Mrs. Haddad on Rue Sursock and the bakery '
          'next door',
      destinationLabel:
          'Rue Sursock, near the Sursock Museum, Ashrafieh, Beirut',
    );

/// The same card on a 320 pt phone — a small Android or an SE-class device.
///
/// The fixed-width CTA does not shrink with the viewport, so every pixel lost
/// comes out of the text: 95.2 pt of column in English, **54.0 pt in Arabic**.
/// At that width the Arabic rendering of a normal title shows about three
/// characters before the ellipsis, which is the state to weigh when deciding
/// whether this row should become two lines (text above, CTA below) rather than
/// one.
@JeebPreview(
  group: 'home_client',
  name: 'Small phone (320 pt)',
  size: _recentDeliveryCardSmallPhoneBox,
)
Widget recentDeliveryCardSmallPhone() => _recentDeliveryCardHosted(
      id: 'rd-4e88',
      title: 'Bakery order',
      destinationLabel: 'Mar Mikhael, Beirut',
    );
