import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_filter_sheet.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import 'client_request_filter.dart';

/// How many requests a staged [ClientRequestFilter] would show. The screen owns
/// the data, so the live apply-CTA count is resolved through this.
typedef ClientRequestFilterCount = int Function(ClientRequestFilter filter);

/// The requests filter: a bucket row over the offer-status guide. Every
/// selection is STAGED — only the apply CTA pops with a value.
class OfferStatusInfoSheet extends StatefulWidget {
  const OfferStatusInfoSheet({
    super.key,
    this.filter = const ClientRequestFilter(),
    this.countFor,
  });

  /// The committed filter this sheet opens on.
  final ClientRequestFilter filter;

  /// Resolves the apply CTA's live count; null renders it as zero.
  final ClientRequestFilterCount? countFor;

  static Future<ClientRequestFilter?> show(
    BuildContext context, {
    ClientRequestFilter filter = const ClientRequestFilter(),
    ClientRequestFilterCount? countFor,
  }) {
    return showModalBottomSheet<ClientRequestFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (_) => OfferStatusInfoSheet(filter: filter, countFor: countFor),
    );
  }

  @override
  State<OfferStatusInfoSheet> createState() => _OfferStatusInfoSheetState();
}

class _OfferStatusInfoSheetState extends State<OfferStatusInfoSheet> {
  late ClientRequestFilter _draft = widget.filter;

  void _stageBucket(ClientHomeTab bucket) {
    setState(() {
      _draft = ClientRequestFilter(
        bucket: bucket,
        offerStatus: _draft.offerStatus,
      );
    });
  }

  /// Re-tapping the staged status unsets it, so the row is its own way back.
  void _stageStatus(ClientOfferStatus status) {
    setState(() {
      _draft = ClientRequestFilter(
        bucket: _draft.bucket,
        offerStatus: _draft.offerStatus == status ? null : status,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double maxHeight = (MediaQuery.sizeOf(context).height * 0.78)
        .clamp(420.0, 640.0)
        .toDouble();
    final int count = widget.countFor?.call(_draft) ?? 0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: JeebFilterSheetScaffold(
        identifier: 'offer_status_info_sheet',
        title: l10n.homeFilterSheetTitle,
        subtitle: l10n.homeFilterSheetSubtitle,
        clearLabel: l10n.filterSheetClearCta,
        applyLabel: l10n.filterSheetApplyCta(count),
        clearEnabled: _draft.isActive,
        clearIdentifier: 'orders_filter_clear',
        applyIdentifier: 'orders_filter_apply',
        onClear: () => setState(() => _draft = const ClientRequestFilter()),
        onApply: () => Navigator.of(context).pop(_draft),
        children: <Widget>[
          JeebFilterSheetGroupLabel(text: l10n.homeFilterShowGroup),
          _BucketRow(selected: _draft.bucket, onSelected: _stageBucket),
          const SizedBox(height: Spacing.medium),
          JeebFilterSheetGroupLabel(text: l10n.offerStatusGroupActive),
          _StatusRow(
            status: ClientOfferStatus.pending,
            icon: Icons.schedule_outlined,
            title: l10n.offerStatusPendingTitle,
            description: l10n.offerStatusPendingDescription,
            tone: _StatusTone.warning,
            selected: _draft.offerStatus == ClientOfferStatus.pending,
            onTap: _stageStatus,
          ),
          _StatusRow(
            status: ClientOfferStatus.submitted,
            icon: Icons.send_outlined,
            title: l10n.offerStatusSubmittedTitle,
            description: l10n.offerStatusSubmittedDescription,
            tone: _StatusTone.info,
            selected: _draft.offerStatus == ClientOfferStatus.submitted,
            onTap: _stageStatus,
          ),
          _StatusRow(
            status: ClientOfferStatus.edited,
            icon: Icons.edit_outlined,
            title: l10n.offerStatusEditedTitle,
            description: l10n.offerStatusEditedDescription,
            tone: _StatusTone.accent,
            selected: _draft.offerStatus == ClientOfferStatus.edited,
            onTap: _stageStatus,
          ),
          const SizedBox(height: Spacing.medium),
          JeebFilterSheetGroupLabel(text: l10n.offerStatusGroupClosed),
          _StatusRow(
            status: ClientOfferStatus.accepted,
            icon: Icons.check_circle_outline,
            title: l10n.offerStatusAcceptedTitle,
            description: l10n.offerStatusAcceptedDescription,
            tone: _StatusTone.success,
            selected: _draft.offerStatus == ClientOfferStatus.accepted,
            onTap: _stageStatus,
          ),
          _StatusRow(
            status: ClientOfferStatus.withdrawn,
            icon: Icons.undo_outlined,
            title: l10n.offerStatusWithdrawnTitle,
            description: l10n.offerStatusWithdrawnDescription,
            tone: _StatusTone.neutral,
            selected: _draft.offerStatus == ClientOfferStatus.withdrawn,
            onTap: _stageStatus,
          ),
          _StatusRow(
            status: ClientOfferStatus.expired,
            icon: Icons.timer_off_outlined,
            title: l10n.offerStatusExpiredTitle,
            description: l10n.offerStatusExpiredDescription,
            tone: _StatusTone.warning,
            selected: _draft.offerStatus == ClientOfferStatus.expired,
            onTap: _stageStatus,
          ),
          _StatusRow(
            status: ClientOfferStatus.superseded,
            icon: Icons.cancel_outlined,
            title: l10n.offerStatusNotSelectedTitle,
            description: l10n.offerStatusNotSelectedDescription,
            tone: _StatusTone.neutral,
            selected: _draft.offerStatus == ClientOfferStatus.superseded,
            onTap: _stageStatus,
          ),
        ],
      ),
    );
  }
}

/// All / Awaiting offers / Has replies — the merged list's three slices.
class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.selected, required this.onSelected});

  static const List<ClientHomeTab> buckets = <ClientHomeTab>[
    ClientHomeTab.all,
    ClientHomeTab.pendingRequests,
    ClientHomeTab.replies,
  ];

  final ClientHomeTab selected;
  final ValueChanged<ClientHomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: Spacing.xSmall,
        runSpacing: Spacing.xSmall,
        children: <Widget>[
          for (final ClientHomeTab bucket in buckets)
            JeebSelectChip(
              key: Key('client-home-bucket-${bucket.name}'),
              role: JeebChipRole.filter,
              label: clientBucketLabel(l10n, bucket),
              selected: selected == bucket,
              identifier: 'orders_filter_bucket_${bucket.name}',
              onTap: () => onSelected(bucket),
            ),
        ],
      ),
    );
  }
}

/// The bucket's human-readable name, shared with the screen's applied pill.
String clientBucketLabel(AppLocalizations l10n, ClientHomeTab bucket) {
  return switch (bucket) {
    ClientHomeTab.all => l10n.homeFilterBucketAll,
    ClientHomeTab.pendingRequests => l10n.homeFilterBucketAwaiting,
    ClientHomeTab.replies => l10n.homeFilterBucketReplies,
    ClientHomeTab.inProgress => l10n.homeTabInProgress,
  };
}

enum _StatusTone { success, warning, info, accent, neutral }

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final ClientOfferStatus status;
  final IconData icon;
  final String title;
  final String description;
  final _StatusTone tone;
  final bool selected;
  final ValueChanged<ClientOfferStatus> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = context.jeebRoles;
    final (background, foreground) = switch (tone) {
      _StatusTone.success => (roles.successContainer, roles.onSuccessContainer),
      _StatusTone.warning => (roles.warningContainer, roles.onWarningContainer),
      _StatusTone.info => (roles.infoContainer, roles.onInfoContainer),
      _StatusTone.accent => (roles.accentContainer, roles.onAccentContainer),
      _StatusTone.neutral => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Semantics(
      identifier: 'offer_status_filter_${status.name}',
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: OmdsBorderRadius.small,
        child: InkWell(
          borderRadius: OmdsBorderRadius.small,
          onTap: () => onTap(status),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: Spacing.xSmall,
              horizontal: Spacing.xSmall,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: OmdsBorderRadius.small,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: foreground, size: 21),
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.jeebText.cardTitle.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        description,
                        style: context.jeebText.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  color: selected
                      ? roles.success
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
