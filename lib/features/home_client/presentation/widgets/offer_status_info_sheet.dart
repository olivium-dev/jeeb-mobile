import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

/// Selectable guide to every offer status returned by the offers API.
class OfferStatusInfoSheet extends StatelessWidget {
  const OfferStatusInfoSheet({super.key, this.selectedStatus});

  final ClientOfferStatus? selectedStatus;

  static Future<ClientOfferStatus?> show(
    BuildContext context, {
    ClientOfferStatus? selectedStatus,
  }) {
    return showModalBottomSheet<ClientOfferStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (_) => OfferStatusInfoSheet(selectedStatus: selectedStatus),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = (MediaQuery.sizeOf(context).height * 0.78)
        .clamp(420.0, 640.0)
        .toDouble();
    return Semantics(
      identifier: 'offer_status_info_sheet',
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const _SheetDragHandle(),
              _SheetHeader(title: l10n.offerStatusSheetTitle),
              Expanded(
                child: SingleChildScrollView(
                  // D5: showModalBottomSheet strips MediaQuery.padding, so the
                  // nav-bar inset has to come from viewPadding or rows are cut.
                  padding: EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.xSmall,
                    Spacing.xLarge,
                    Spacing.xLarge + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.offerStatusSheetIntro,
                        key: const Key('offer-status-sheet-intro'),
                        style: context.jeebText.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Spacing.medium),
                      _StatusGroupLabel(text: l10n.offerStatusGroupActive),
                      _StatusRow(
                        status: ClientOfferStatus.pending,
                        icon: Icons.schedule_outlined,
                        title: l10n.offerStatusPendingTitle,
                        description: l10n.offerStatusPendingDescription,
                        tone: _StatusTone.warning,
                        selected: selectedStatus == ClientOfferStatus.pending,
                      ),
                      _StatusRow(
                        status: ClientOfferStatus.submitted,
                        icon: Icons.send_outlined,
                        title: l10n.offerStatusSubmittedTitle,
                        description: l10n.offerStatusSubmittedDescription,
                        tone: _StatusTone.info,
                        selected: selectedStatus == ClientOfferStatus.submitted,
                      ),
                      _StatusRow(
                        status: ClientOfferStatus.edited,
                        icon: Icons.edit_outlined,
                        title: l10n.offerStatusEditedTitle,
                        description: l10n.offerStatusEditedDescription,
                        tone: _StatusTone.accent,
                        selected: selectedStatus == ClientOfferStatus.edited,
                      ),
                      const SizedBox(height: Spacing.medium),
                      _StatusGroupLabel(text: l10n.offerStatusGroupClosed),
                      _StatusRow(
                        status: ClientOfferStatus.accepted,
                        icon: Icons.check_circle_outline,
                        title: l10n.offerStatusAcceptedTitle,
                        description: l10n.offerStatusAcceptedDescription,
                        tone: _StatusTone.success,
                        selected: selectedStatus == ClientOfferStatus.accepted,
                      ),
                      _StatusRow(
                        status: ClientOfferStatus.withdrawn,
                        icon: Icons.undo_outlined,
                        title: l10n.offerStatusWithdrawnTitle,
                        description: l10n.offerStatusWithdrawnDescription,
                        tone: _StatusTone.neutral,
                        selected: selectedStatus == ClientOfferStatus.withdrawn,
                      ),
                      _StatusRow(
                        status: ClientOfferStatus.expired,
                        icon: Icons.timer_off_outlined,
                        title: l10n.offerStatusExpiredTitle,
                        description: l10n.offerStatusExpiredDescription,
                        tone: _StatusTone.warning,
                        selected: selectedStatus == ClientOfferStatus.expired,
                      ),
                      _StatusRow(
                        status: ClientOfferStatus.superseded,
                        icon: Icons.cancel_outlined,
                        title: l10n.offerStatusNotSelectedTitle,
                        description: l10n.offerStatusNotSelectedDescription,
                        tone: _StatusTone.neutral,
                        selected:
                            selectedStatus == ClientOfferStatus.superseded,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.small,
        Spacing.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.jeebText.titleProminent.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            key: const Key('offer-status-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    // D5: rows clip hard at the viewport edge; the hairline makes that read as
    // an intentional boundary instead of sliced glyphs.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Divider(
          key: const Key('offer-status-header-divider'),
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _StatusGroupLabel extends StatelessWidget {
  const _StatusGroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Text(
        text,
        style: context.jeebText.label.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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
  });

  final ClientOfferStatus status;
  final IconData icon;
  final String title;
  final String description;
  final _StatusTone tone;
  final bool selected;

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
          onTap: () => Navigator.of(context).pop(status),
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

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      child: Center(
        child: Container(
          width: Spacing.twoXLarge,
          height: Spacing.twoXSmall,
          decoration: BoxDecoration(
            color: colors.glassBorderVivid,
            borderRadius: OmdsBorderRadius.pill,
          ),
        ),
      ),
    );
  }
}
