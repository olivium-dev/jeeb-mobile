import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../otp_handover/presentation/widgets/handover_code_display.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// prominently — the hand-off moment must not hide the code behind a tap.
class OtpAtDoorCard extends StatelessWidget {
  const OtpAtDoorCard({super.key, required this.deliveryId, this.handoverCode});

  final String deliveryId;

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
            HandoverCodeDisplay(
              code: code,
              compact: true,
              semanticsIdentifier: 'tracking_at_door_code',
              displayKey: const Key('tracking.atDoorCode'),
            ),
          ],
          const SizedBox(height: Spacing.large),
          Semantics(
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The delivery every fixture belongs to — the id from
/// `test/live_tracking_handover_code_test.dart`. It is never rendered; it only
const String _otpAtDoorCardDeliveryId = 'DLV-770001';

/// Phone width, and tall enough that the two 1.0 renderings sit clear of the
/// box edge with the EN 200% rendering mostly in frame.
const Size _otpAtDoorCardBox = Size(390, 480);

/// The card as the tracking screen builds it.
Widget _otpAtDoorCardHosted({String? handoverCode}) => OtpAtDoorCard(
      deliveryId: _otpAtDoorCardDeliveryId,
      handoverCode: handoverCode,
    );

/// A neutral stand-in for the live map behind the card — enough shape to judge
/// the top corners and the upward shadow against, and deliberately text-free.
class _OtpAtDoorCardMapBackdrop extends StatelessWidget {
  const _OtpAtDoorCardMapBackdrop();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        // A couple of "roads", so the card's edge is judged against contrast
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.surfaceContainerHighest,
            colors.surfaceContainer,
            colors.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.navigation_rounded,
          size: 48,
          color: colors.primary,
        ),
      ),
    );
  }
}

/// G4, the hand-off moment: the device knows the code, so the code is ON SCREEN.
/// This is the state sprint-009 P0 §G4 bought — before it, the customer had to
@JeebPreview(group: 'live_tracking', name: 'Code known · 1234', size: _otpAtDoorCardBox)
Widget otpAtDoorCardWithCode() => _otpAtDoorCardHosted(handoverCode: '1234');

/// No code on this device — the branch that dead-ended live deliveries.
/// Reachable two ways: a reinstall (the code is persisted locally at accept
@JeebPreview(group: 'live_tracking', name: 'Code unknown', size: Size(390, 400))
Widget otpAtDoorCardWithoutCode() => _otpAtDoorCardHosted();

/// Bidi guard, made visible: a code whose reading is destroyed by reordering.
/// `0450` is chosen so a failure is unmistakable — a leading zero that must
@JeebPreview(group: 'live_tracking', name: 'Bidi guard · 0450', size: _otpAtDoorCardBox)
Widget otpAtDoorCardLeadingZeroCode() => _otpAtDoorCardHosted(handoverCode: '0450');

/// The narrowest phone the app supports (320 pt), pinned to that width by the
/// preview itself.
@JeebPreview(group: 'live_tracking', name: 'Narrow phone · 320 pt', size: Size(320, 520))
Widget otpAtDoorCardNarrowPhone() => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 320, child: _otpAtDoorCardHosted(handoverCode: '9061')),
    );

/// The card as the customer actually meets it: anchored to the bottom of the
/// tracking screen, over the map.
@JeebPreview(group: 'live_tracking', name: 'Bottom-anchored over map', size: Size(390, 560))
Widget otpAtDoorCardOverMap() => Column(
      children: <Widget>[
        const Expanded(child: _OtpAtDoorCardMapBackdrop()),
        _otpAtDoorCardHosted(handoverCode: '7788'),
      ],
    );
