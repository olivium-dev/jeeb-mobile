import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_receipt_cubit.dart';
import '../application/delivery_receipt_state.dart';
import '../data/dio_delivery_receipt_repository.dart';
import '../data/fake_delivery_receipt_repository.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

/// `delivered-receipt-confirm` (JM-033) — the **customer** confirm-receipt
/// prompt, reached at `/orders/:id/receipt` (auto-advanced from order-tracking
/// when the Jeeber marks delivered, JM-032; also a deep-link target).
///
/// REWRITE of the orphaned finance-receipt screen (wrong contract: it rendered
/// goods cost / delivery fee / **Commission** in hardcoded LBP). The blueprint
/// contract is a delivery-acknowledgement prompt:
///   - "Did you receive your order?" prompt (signature root `receipt_prompt`).
///   - "Pay $N cash to `<Jeeber>`" — the cash-on-delivery line (D11), customer
///     pays the Jeeber in person.
///   - The proof-of-delivery photo the Jeeber uploaded (D3, D1m sink).
///   - Confirm  → rating screen (JM-034). Records the COD settlement +
///     transitions the delivery to `Done` (D70) before navigating.
///   - Not yet  → dispute-open-evidence (JM-060).
///   - **NO commission / platform-fee line** is shown (JM-033 AC4, D11) — the
///     10% economics live on the jeeber/wallet surfaces, never the customer's.
///
/// Owns the [DeliveryReceiptCubit] lifecycle (load + confirm). [repository] is
/// optional — production resolves [DeliveryReceiptRepository] from GetIt when
/// registered, else constructs the Dio impl over the shared `sl<Dio>()` (the
/// DI registration is integrator-owned and requested in 50_ROUTE_REQUESTS.md;
/// the screen works against `:4010` either way). Pass an explicit repository
/// only in widget tests.
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.13):
///   - `receipt_prompt`               — screen root (signature id)
///   - `receipt_cash_to_jeeber_label` — "Pay $N cash to `<Jeeber>`" (D11)
///   - `receipt_proof_photo`          — proof-of-delivery photo (D3)
///   - `receipt_confirm_cta`          — Confirm → rate-jeeber (JM-034)
///   - `receipt_not_yet_cta`          — Not yet → dispute-open-evidence (JM-060)
///   - `receipt_no_commission_line`   — NEVER rendered (AC4 negative assertion)
class DeliveryReceiptScreen extends StatelessWidget {
  const DeliveryReceiptScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  /// Optional repository override. Production leaves this null (resolves DI /
  /// constructs the Dio impl); widget tests inject a scripted instance.
  final DeliveryReceiptRepository? repository;

  DeliveryReceiptRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    // Prefer the DI-bound interface once the integrator registers it
    // (50_ROUTE_REQUESTS.md). Until then, construct the Dio impl over the
    // shared Dio so the running app reaches the real mock (:4010) — `sl<Dio>()`
    // is registered at boot. A DI-less widget/router test (no GetIt configured)
    // falls back to the in-memory fake so mount-and-find stays green without a
    // network/keystore — mirrors ClientOffersScreen's Fake fallback.
    if (sl.isRegistered<DeliveryReceiptRepository>()) {
      return sl<DeliveryReceiptRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioDeliveryReceiptRepository(sl<Dio>());
    }
    return FakeDeliveryReceiptRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<DeliveryReceiptCubit>(
      create: (_) => DeliveryReceiptCubit(
        repository: repo,
        deliveryId: deliveryId,
      )..load(),
      child: const _DeliveryReceiptView(),
    );
  }
}

class _DeliveryReceiptView extends StatelessWidget {
  const _DeliveryReceiptView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.receiptTitle,
        // Mandatory confirm/dispute path — no back affordance (the customer
        // resolves via Confirm or Not yet). Mirrors the post-delivery terminal.
        showBackButton: false,
        centerTitle: false,
      ),
      body: Semantics(
        identifier: 'receipt_prompt',
        explicitChildNodes: true,
        child: BlocConsumer<DeliveryReceiptCubit, DeliveryReceiptState>(
          listenWhen: (prev, next) =>
              prev.confirmStatus != next.confirmStatus &&
              next.confirmStatus == ReceiptConfirmStatus.succeeded,
          listener: (context, state) {
            // Side effect ONLY in the listener (40_GUARDRAILS_ARCH §3).
            // EDGE (63_W1_TEST_PLAN §3 jm-033 AC2, JM-034): receipt_confirm_cta
            // → rate-jeeber. The canonical post-delivery rating terminal is the
            // blind mutual-rating screen (`mutual-rating`, JM-034 reconciliation
            // — mutual is the compliant terminal). Client mode is the default
            // (no `?mode=jeeber`), so the customer rates the Jeeber. We replace
            // the stack so the mandatory rating cannot be backed out of (D56).
            final id = state.receipt?.deliveryId;
            if (id != null && id.isNotEmpty) {
              context.goNamed(
                'mutual-rating',
                pathParameters: <String, String>{'id': id},
              );
            }
          },
          builder: (context, state) {
            switch (state.status) {
              case DeliveryReceiptStatus.initial:
              case DeliveryReceiptStatus.loading:
                return const OmdsLoadingState();
              case DeliveryReceiptStatus.failed:
                return OmdsErrorState(
                  key: const Key('receipt-load-error'),
                  message: _errorCopy(l10n, state.error),
                  retryLabel: l10n.receiptRetryAction,
                  onRetry: () =>
                      context.read<DeliveryReceiptCubit>().refresh(),
                );
              case DeliveryReceiptStatus.loaded:
                final receipt = state.receipt;
                if (receipt == null) {
                  return OmdsErrorState(
                    message: _errorCopy(l10n, DeliveryReceiptFailure.unknown),
                    retryLabel: l10n.receiptRetryAction,
                    onRetry: () =>
                        context.read<DeliveryReceiptCubit>().refresh(),
                  );
                }
                return _LoadedBody(receipt: receipt, state: state);
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.notFound:
        return l10n.receiptErrorNotFound;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.receipt, required this.state});

  final DeliveryReceipt receipt;
  final DeliveryReceiptState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirming = state.isConfirming;
    // "Pay $N cash to `<Jeeber>`" (D11). Cash is the gross order amount paid in
    // person; the Jeeber name degrades to a generic noun when absent. The copy
    // is a localized template with positional placeholders — Maestro keys on
    // the id, not the text (i18n-safe).
    //
    // Run-22 P1-A: when the gateway omitted the amount (the live
    // `GET /v1/deliveries/{id}` drops `amount` once the delivery is `Done`),
    // the amount is UNKNOWN — degrade to the amount-less line instead of
    // fabricating "Pay $0.00".
    final jeeberLabel = receipt.jeeberName.isNotEmpty
        ? receipt.jeeberName
        : l10n.receiptJeeberFallback;
    final cashText = receipt.hasKnownAmount
        ? l10n.receiptCashToJeeber(
            MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency),
            jeeberLabel,
          )
        : l10n.receiptCashToJeeberNoAmount(jeeberLabel);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: Sizes.fiveXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.medium),
        // "Did you receive your order?" — the prompt heading.
        Text(
          l10n.receiptPromptHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.large),
        // receipt_proof_photo — the proof-of-delivery photo the Jeeber
        // uploaded (D3). Degrades to a neutral placeholder when absent.
        Semantics(
          identifier: 'receipt_proof_photo',
          image: true,
          label: l10n.receiptProofPhotoLabel,
          child: ClipRRect(
            borderRadius: OmdsBorderRadius.medium,
            child: receipt.hasProofPhoto
                ? OmdsCachedImage(
                    url: receipt.proofPhotoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: Sizes.twoXLarge,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Spacing.large),
        // receipt_cash_to_jeeber_label — "Pay $N cash to `<Jeeber>`" (D11).
        Semantics(
          identifier: 'receipt_cash_to_jeeber_label',
          child: Container(
            padding: const EdgeInsets.all(Spacing.medium),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: OmdsBorderRadius.medium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    cashText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // NOTE (JM-033 AC4, D11): there is intentionally NO commission /
        // platform-fee line on this customer-facing surface. The
        // `receipt_no_commission_line` id is a NEGATIVE assertion — the flow
        // asserts it is NOT visible, so nothing emits it. Do not add it.
        if (state.confirmStatus == ReceiptConfirmStatus.failed) ...[
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'receipt_confirm_error',
            child: Text(
              _confirmErrorCopy(l10n, state.confirmError),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.twoXLarge),
        // receipt_confirm_cta — Confirm receipt → rating (JM-034). Disabled +
        // spinner while the confirm round-trip is in flight; success fires the
        // listener navigation.
        Semantics(
          identifier: 'receipt_confirm_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptConfirmCta,
          onTap: confirming
              ? null
              : () => context.read<DeliveryReceiptCubit>().confirmReceipt(),
          child: ExcludeSemantics(
            child: OmdsLoadingButton(
              key: const Key('receipt-confirm-cta'),
              text: l10n.receiptConfirmCta,
              isLoading: confirming,
              isEnabled: !confirming,
              onTap: () =>
                  context.read<DeliveryReceiptCubit>().confirmReceipt(),
            ),
          ),
        ),
        const SizedBox(height: Spacing.small),
        // receipt_not_yet_cta — Not yet → dispute-open-evidence (JM-060). Inert
        // while a confirm is in flight so it can't tear down mid-call.
        Semantics(
          identifier: 'receipt_not_yet_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptNotYetCta,
          onTap: confirming ? null : () => _openDispute(context),
          child: ExcludeSemantics(
            child: OMDSOutlinedButton(
              key: const Key('receipt-not-yet-cta'),
              text: l10n.receiptNotYetCta,
              enabled: !confirming,
              onTap: () => _openDispute(context),
            ),
          ),
        ),
      ],
    );
  }

  /// EDGE (63_W1_TEST_PLAN §3 jm-033 AC3, JM-060): receipt_not_yet_cta →
  /// dispute-open-evidence. The registered route is `escalate`
  /// (`/orders/:id/escalate`), the blueprint `dispute-open-evidence` target
  /// (JM-060 extends `EscalateScreen`; it exposes `dispute_reason`). Push so the
  /// customer can return to the receipt prompt if they opened the dispute by
  /// mistake (the dispute is the non-terminal branch).
  void _openDispute(BuildContext context) {
    context.pushNamed(
      'escalate',
      pathParameters: <String, String>{'id': receipt.deliveryId},
    );
  }

  static String _confirmErrorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.notFound:
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
    }
  }
}
