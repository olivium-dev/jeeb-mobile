import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/recent_delivery_summary.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

/// A phone-width box. The card lays out at **80 pt** tall at 390 pt (108 pt at
/// 200% text), so 120 frames all three renderings of the matrix.
const Size _recentDeliveryCardCardBox = Size(390, 120);

/// The same card on a 320 pt phone — the small-device end of the range.
const Size _recentDeliveryCardSmallPhoneBox = Size(320, 120);

/// `completedAt` is fixed so nothing here depends on the clock.
/// It is also never rendered: the card shows title + destination only, so this
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
/// This is the reference rendering the others are read against — and the first
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
/// The AR RTL rendering of every other preview mirrors the *chrome* while
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
/// The fixed-width CTA does not shrink with the viewport, so every pixel lost
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
