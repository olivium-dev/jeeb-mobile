import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../live_tracking_l10n.dart';

/// JM-032 AC4 (D88): the no-show action sheet — shown when the customer reports
/// the Jeeber never arrived. Offers two recovery paths:
///   * `tracking_noshow_reassign_cta`    → offer-review-list (pick another offer)
///   * `tracking_noshow_rebroadcast_cta` → waiting-no-coverage (send out again)
///
/// EXEMPT: OmdsBottomSheet lacks a `show` static factory with a scroll-safe body
/// (mirrors `cancellation_success_sheet.dart`); uses Flutter's
/// `showModalBottomSheet` with an OMDS-token-only child. The sheet pops itself
/// before invoking the navigation callback so the chosen route replaces it.
class TrackingNoShowSheet extends StatelessWidget {
  const TrackingNoShowSheet({
    super.key,
    required this.onReassign,
    required this.onRebroadcast,
    required this.onKeepWaiting,
  });

  final VoidCallback onReassign;
  final VoidCallback onRebroadcast;
  final VoidCallback onKeepWaiting;

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onReassign,
    required VoidCallback onRebroadcast,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (sheetContext) => TrackingNoShowSheet(
        onReassign: () {
          Navigator.of(sheetContext).pop();
          onReassign();
        },
        onRebroadcast: () {
          Navigator.of(sheetContext).pop();
          onRebroadcast();
        },
        onKeepWaiting: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'tracking_noshow_sheet',
      container: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.noShowTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.noShowBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'tracking_noshow_reassign_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowReassignCta,
                  onTap: onReassign,
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'tracking_noshow_rebroadcast_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowRebroadcastCta,
                  variant: OmdsButtonVariant.outlined,
                  onTap: onRebroadcast,
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'tracking_noshow_keep_cta',
                button: true,
                child: OmdsPrimaryButton(
                  text: l10n.noShowKeepCta,
                  variant: OmdsButtonVariant.text,
                  onTap: onKeepWaiting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
