import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Single-line banner above the status content shown only for terminal
/// lifecycle states. Active deliveries don't render it (returning null is
/// the screen's responsibility; this widget renders a SizedBox otherwise so
class DeliveryLifecycleBanner extends StatelessWidget {
  const DeliveryLifecycleBanner({super.key, required this.lifecycle});

  static const Key rootKey = Key('delivery-status-lifecycle-banner');

  final DeliveryLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = lifecycle == DeliveryLifecycle.completed;
    final isCancelled = lifecycle == DeliveryLifecycle.cancelled;
    if (!isCompleted && !isCancelled) {
      return const SizedBox.shrink();
    }
    // Completed is a success state -> semantic success role (was the brand
    final roles = context.jeebRoles;
    final background =
        isCompleted ? roles.successContainer : colorScheme.errorContainer;
    final foreground = isCompleted
        ? roles.onSuccessContainer
        : colorScheme.onErrorContainer;
    final icon =
        isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined;
    final message = isCompleted
        ? l10n.deliveryCompletedBanner
        : l10n.deliveryCancelledBanner;
    return Container(
      key: rootKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryLifecycleBanner] — run with

/// The subtitle row the screen paints directly under the banner. It is the
/// only content on the status screen that carries a per-delivery string, which
Widget _deliveryLifecycleBannerDeliveryIdSubtitle(String deliveryId) => Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Text(
          AppLocalizations.of(context).deliveryStatusIdSubtitle(deliveryId),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );

/// Rebuilds the banner's production stacking order from `_ReadyView`: the
/// banner(s), the gap the screen inserts ONLY for terminal lifecycles, then the
Widget _deliveryLifecycleBannerHosted({
  required List<DeliveryLifecycle> lifecycles,
  required String deliveryId,
  double width = 390,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      child: Padding(
        // `_ReadyView`'s horizontal padding, so the band is 350 dp at 390 dp.
        padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final DeliveryLifecycle lifecycle in lifecycles) ...<Widget>[
              DeliveryLifecycleBanner(lifecycle: lifecycle),
              // The screen gates its own gap on the same condition the banner
              if (lifecycle != DeliveryLifecycle.active)
                const SizedBox(height: Spacing.medium),
            ],
            _deliveryLifecycleBannerDeliveryIdSubtitle(deliveryId),
          ],
        ),
      ),
    ),
  );
}

/// The success terminal: `completed` on a 390 dp phone.
/// Worth looking at for the COLOR ROLE, not the layout. The band used to be the
@JeebPreview(group: 'delivery_status', name: 'Completed', size: Size(390, 240))
Widget deliveryLifecycleBannerCompleted() => _deliveryLifecycleBannerHosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.completed],
      deliveryId: 'd-2481',
    );

/// The failure terminal: `cancelled`, on the M3 `errorContainer` pair.
/// This is the state a user lands on after the sender cancels pre-pickup (BR-4)
@JeebPreview(group: 'delivery_status', name: 'Cancelled', size: Size(390, 240))
Widget deliveryLifecycleBannerCancelled() => _deliveryLifecycleBannerHosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.cancelled],
      deliveryId: 'd-3067',
    );

/// The state that must render NOTHING: `active`, i.e. every in-flight delivery.
/// This is the contract the widget's doc comment states and the one no other
@JeebPreview(group: 'delivery_status', name: 'Active · collapsed', size: Size(390, 120))
Widget deliveryLifecycleBannerActive() => _deliveryLifecycleBannerHosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.active],
      deliveryId: 'd-4192',
    );

/// Small-phone width (320 dp), the narrowest width the app ships to, carrying
/// the LONGER of the two sentences ("Delivered successfully", 22 chars).
@JeebPreview(group: 'delivery_status', name: 'Small phone 320dp', size: Size(320, 260))
Widget deliveryLifecycleBannerSmallPhone() => _deliveryLifecycleBannerHosted(
      lifecycles: const <DeliveryLifecycle>[DeliveryLifecycle.completed],
      deliveryId: 'd-5510',
      width: 320,
    );

/// Both terminal bands in one card, for the only comparison that matters:
/// success container against error container, side by side, in the same theme.
@JeebPreview(group: 'delivery_status', name: 'Terminal pair · contrast', size: Size(390, 300))
Widget deliveryLifecycleBannerTerminalPair() => _deliveryLifecycleBannerHosted(
      lifecycles: const <DeliveryLifecycle>[
        DeliveryLifecycle.completed,
        DeliveryLifecycle.cancelled,
      ],
      deliveryId: 'd-6733',
    );
