import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../otp_handover/presentation/widgets/handover_code_display.dart';

/// T-MOB-017 AC4: Slides in when status transitions to at_door.
///
/// G4 (sprint-009 P0): when the app holds the delivery hand-over code
/// (accept-time persisted, restart-safe) the card renders it INLINE and
/// prominently — the hand-off moment must not hide the code behind a tap.
/// "Show OTP" remains as a secondary route to the full-screen display. When
/// the code is unknown (e.g. reinstall) the CTA leads to the OTP screen's
/// honest SMS-fallback. Card uses OMDS tokens exclusively — no magic values.
class OtpAtDoorCard extends StatelessWidget {
  const OtpAtDoorCard({super.key, required this.deliveryId, this.handoverCode});

  final String deliveryId;

  /// The locally-persisted hand-over code, or null when this device never
  /// received it. Rendered on screen only — NEVER logged (DiagRedaction).
  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: _CardContent(deliveryId: deliveryId, handoverCode: handoverCode),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.deliveryId, required this.handoverCode});

  final String deliveryId;
  final String? handoverCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = handoverCode;
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
            code != null ? l10n.trackingAtDoorShareCode : l10n.trackingAtDoorBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (code != null) ...[
            const SizedBox(height: Spacing.large),
            // G4: the code itself, inline at the hand-off moment.
            HandoverCodeDisplay(
              code: code,
              compact: true,
              semanticsIdentifier: 'tracking_at_door_code',
              displayKey: const Key('tracking.atDoorCode'),
            ),
          ],
          const SizedBox(height: Spacing.large),
          Semantics(
            // QA: uiautomator-addressable handle for the at-door → OTP CTA.
            // `container: true` keeps the identifier its own queryable node;
            // OmdsLoadingButton already exposes the button role.
            identifier: 'tracking_otp_cta',
            container: true,
            child: OmdsLoadingButton(
              key: const Key('tracking.otpCta'),
              text: l10n.trackingAtDoorCta,
              isLoading: false,
              isEnabled: true,
              onTap: () => _navigateToOtp(context),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToOtp(BuildContext context) {
    context.push('/orders/$deliveryId/otp');
  }
}
