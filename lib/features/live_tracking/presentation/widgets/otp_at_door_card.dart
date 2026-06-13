import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// T-MOB-017 AC4: Slides in when status transitions to at_door.
///
/// Shows a brief prompt and a CTA that navigates to the OTP handover screen.
/// Card uses OMDS tokens exclusively — no magic values.
class OtpAtDoorCard extends StatelessWidget {
  const OtpAtDoorCard({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: _CardContent(deliveryId: deliveryId),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: Sizes.small,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Sizes.large),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.trackingAtDoorHeadline,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Text(
            l10n.trackingAtDoorBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.large),
          OmdsLoadingButton(
            text: l10n.trackingAtDoorCta,
            isLoading: false,
            isEnabled: true,
            onTap: () => _navigateToOtp(context),
          ),
        ],
      ),
    );
  }

  void _navigateToOtp(BuildContext context) {
    context.push('/orders/$deliveryId/otp');
  }
}
