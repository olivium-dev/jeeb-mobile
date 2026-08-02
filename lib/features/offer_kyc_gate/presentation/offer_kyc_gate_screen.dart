import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/offer_kyc_gate_cubit.dart';
import '../application/offer_kyc_gate_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart';

class OfferKycGateScreen extends StatelessWidget {
  const OfferKycGateScreen({super.key, this.cubit, this.gateway})
      : assert(cubit == null || gateway == null,
            'Provide either a cubit or a gateway, not both.');

  final OfferKycGateCubit? cubit;

  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<OfferKycGateCubit>.value(
        value: provided,
        child: const _OfferKycGateView(),
      );
    }
    return BlocProvider<OfferKycGateCubit>(
      create: (_) => OfferKycGateCubit(gateway: gateway ?? _resolveGateway()),
      child: const _OfferKycGateView(),
    );
  }

  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    return FakeKycGateway();
  }
}

class _OfferKycGateView extends StatelessWidget {
  const _OfferKycGateView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'offer_kyc_gate',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.offerKycGateTitle,
          showBackButton: true,
          onBackPressed: () => _popToDeliveryTab(context),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(Icons.verified_user_outlined,
                size: Sizes.sixXLarge, color: theme.colorScheme.primary),
            const SizedBox(height: Spacing.large),
            Text(l10n.offerKycGateHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.small),
            Text(l10n.offerKycGateBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const _GateStatusLine(),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'gate_topup_note',
              container: true,
              child: Text(l10n.gateTopupNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'gate_start_kyc_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.gateStartKycCta,
                onTap: () => context.goNamed('kyc-status'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'gate_register_link',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () => context.goNamed('delivery-register-prompt'),
                child: Text(l10n.gateRegisterLink),
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'gate_back_cta',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () => _popToDeliveryTab(context),
                child: Text(l10n.gateBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _popToDeliveryTab(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _GateStatusLine extends StatelessWidget {
  const _GateStatusLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<OfferKycGateCubit, OfferKycGateState>(
      builder: (context, state) {
        if (state.phase != OfferKycGatePhase.ready) {
          return const SizedBox.shrink();
        }
        final (title, body, color) = switch (state.status) {
          KycStatus.pending => (
              l10n.kycStatusPendingTitle,
              l10n.kycStatusPendingBody,
              context.jeebRoles.warning,
            ),
          KycStatus.rejected => (
              l10n.kycStatusRejectedTitle,
              l10n.kycStatusRejectedBody,
              theme.colorScheme.error,
            ),
          KycStatus.resubmitRequested => (
              l10n.kycStatusResubmitTitle,
              l10n.kycStatusResubmitBody,
              context.jeebRoles.warning,
            ),
          _ => (null, null, null),
        };
        if (title == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
          child: Column(
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: Spacing.twoXSmall),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _offerKycGateScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _offerKycGateScreenCompactCanvas = Size(332, 612);

/// Every state is the same gate behind the same app bar, differing only in what
/// the canned `fetchStatus()` does — and four of them differ in nothing at all
Widget _offerKycGateScreenHosted(
  KycGateway gateway, {
  required String caption,
  OfferKycGateScreenWindow window = OfferKycGateScreenWindows.phone,
}) =>
    OfferKycGateScreenPreviewHost(
      window: window,
      caption: caption,
      screen: OfferKycGateScreen(gateway: gateway),
    );

/// The canonical gate: the reconciled JM-044 entry for a jeeber who has never
/// started KYC.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Not submitted',
  size: _offerKycGateScreenPhoneCanvas,
  matrix: true,
)
Widget offerKycGateScreenNotSubmitted() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(),
      caption: 'Not submitted · phone 390 × 844',
    );

/// `ready(pending)` — the state the W2 RD-1 fix was written against.
/// The JM-044 entry a `pending` jeeber takes: the gate adds "Submission
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Pending',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenPending() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.pending),
      caption: 'Pending · phone 390 × 844',
    );

/// `ready(rejected)` — the longest content this screen can carry, and its
/// sharpest contradiction.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Rejected',
  size: _offerKycGateScreenPhoneCanvas,
  matrix: true,
)
Widget offerKycGateScreenRejected() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.rejected),
      caption: 'Rejected · phone 390 × 844',
    );

/// `ready(resubmitRequested)` — the E19 tri-state, which had no mocked state on
/// ANY dev surface before this wave.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Resubmit requested',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenResubmitRequested() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(
        status: KycStatus.resubmitRequested,
      ),
      caption: 'Resubmit requested · phone 390 × 844',
    );

/// `OfferKycGatePhase.loading` — the cold-start frame, held open by a
/// `fetchStatus()` that never resolves.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Loading',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenLoading() => _offerKycGateScreenHosted(
      const OfferKycGateScreenPendingGateway(),
      caption: 'Loading · phone 390 × 844',
    );

/// `OfferKycGatePhase.error` — `GET /v1/kyc/status` threw.
/// `OfferKycGateCubit.loadStatus` catches everything and emits `error`, and
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Status read failed',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenStatusReadFailed() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFailingGateway(),
      caption: 'Status read failed · phone 390 × 844',
    );

/// `ready(approved)` — the state the screen's dartdoc says cannot happen.
/// It is reachable: nothing in this file, in [OfferKycGateCubit] or in the
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Approved (should be unreachable)',
  size: _offerKycGateScreenPhoneCanvas,
)
Widget offerKycGateScreenApproved() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.approved),
      caption: 'Approved · phone 390 × 844',
    );

/// The worst case the app supports: the longest state on the smallest display
/// at the largest text.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Rejected · compact · 200% text',
  size: _offerKycGateScreenCompactCanvas,
)
Widget offerKycGateScreenCompactLargeText() => _offerKycGateScreenHosted(
      const OfferKycGateScreenFakeGateway(status: KycStatus.rejected),
      caption: 'Rejected · compact 320 × 568 · 200% text',
      window: OfferKycGateScreenWindows.compactLargeText,
    );
