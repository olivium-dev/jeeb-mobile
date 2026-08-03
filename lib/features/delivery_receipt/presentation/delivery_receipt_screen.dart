import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_receipt_cubit.dart';
import '../application/delivery_receipt_state.dart';
import '../data/dio_delivery_receipt_repository.dart';
import '../data/fake_delivery_receipt_repository.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';
import 'widgets/proof_photo_hero.dart';
import 'widgets/proof_photo_viewer.dart';

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
/// redesign-2026-08 (screen 14): no app bar at all — the question IS the
/// heading (dc-tpl 832-833); an r20 proof hero with a badge and a zoom pill
/// replaces the flat 200px image; the cash statement moved from the peach
/// `primaryContainer` slab to the board's navy card with an emphasized amount;
/// and the two CTAs are the Wave-1 pills, pushed down by real empty space
/// (dc-tpl 845) rather than by a fixed gap.
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
///   - `receipt_proof_zoom_cta`       — opens the full-screen viewer
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
    // No app bar (dc-tpl 827-833): the prompt heading carries the screen, and
    // this is still a mandatory confirm/dispute terminal — there was never a
    // back affordance to lose.
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          identifier: 'receipt_prompt',
          explicitChildNodes: true,
          child: BlocConsumer<DeliveryReceiptCubit, DeliveryReceiptState>(
            listenWhen: (prev, next) =>
                prev.confirmStatus != next.confirmStatus &&
                next.confirmStatus == ReceiptConfirmStatus.succeeded,
            listener: (context, state) {
              // Side effect ONLY in the listener (40_GUARDRAILS_ARCH §3).
              // EDGE (63_W1_TEST_PLAN §3 jm-033 AC2, JM-034):
              // receipt_confirm_cta → rate-jeeber. The canonical post-delivery
              // rating terminal is the blind mutual-rating screen
              // (`mutual-rating`, JM-034 reconciliation — mutual is the
              // compliant terminal). Client mode is the default (no
              // `?mode=jeeber`), so the customer rates the Jeeber. We replace
              // the stack so the mandatory rating cannot be backed out of
              // (D56).
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

    // ONE scroll view holding the whole column, footer included: at default
    // text scale the `Spacer` eats the slack and the CTAs read as docked; at
    // 200% the same column simply scrolls instead of overflowing.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              0,
              Spacing.xLarge,
              Spacing.twoXLarge,
            ),
            child: Column(
              children: [
                const SizedBox(height: Spacing.large),
                // "Did you receive your order?" — the prompt heading, and the
                // only title this screen has (dc-tpl 833).
                Text(
                  l10n.receiptPromptHeading,
                  textAlign: TextAlign.center,
                  style: context.jeebText.h1.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: Spacing.large),
                // receipt_proof_photo (+ receipt_proof_zoom_cta) — the
                // proof-of-delivery photo the Jeeber uploaded (D3). Degrades
                // to a neutral placeholder, without a zoom pill, when absent.
                ProofPhotoHero(
                  proofPhotoUrl: receipt.proofPhotoUrl,
                  photoSemanticLabel: l10n.receiptProofPhotoLabel,
                  badgeText: l10n.receiptProofBadge,
                  zoomCtaText: l10n.receiptProofZoomCta,
                  onZoom: receipt.hasProofPhoto
                      ? () => showProofPhotoViewer(
                            context,
                            url: receipt.proofPhotoUrl!,
                            closeLabel: l10n.receiptProofViewerCloseLabel,
                          )
                      : null,
                ),
                const SizedBox(height: Spacing.medium),
                _CashStatement(receipt: receipt),
                // NOTE (JM-033 AC4, D11): there is intentionally NO commission
                // / platform-fee line on this customer-facing surface. The
                // `receipt_no_commission_line` id is a NEGATIVE assertion — the
                // flow asserts it is NOT visible, so nothing emits it. Do not
                // add it.
                const Spacer(),
                if (state.confirmStatus == ReceiptConfirmStatus.failed) ...[
                  Semantics(
                    identifier: 'receipt_confirm_error',
                    child: Text(
                      _confirmErrorCopy(l10n, state.confirmError),
                      textAlign: TextAlign.center,
                      style: context.jeebText.bodySmall.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.small),
                ],
                // receipt_confirm_cta — Confirm receipt → rating (JM-034).
                // Disabled + spinner while the confirm round-trip is in flight;
                // success fires the listener navigation.
                Semantics(
                  identifier: 'receipt_confirm_cta',
                  container: true,
                  button: true,
                  enabled: !confirming,
                  label: l10n.receiptConfirmCta,
                  onTap: confirming
                      ? null
                      : () =>
                          context.read<DeliveryReceiptCubit>().confirmReceipt(),
                  child: ExcludeSemantics(
                    child: JeebCtaButton.primary(
                      key: const Key('receipt-confirm-cta'),
                      label: l10n.receiptConfirmCta,
                      height: JeebCtaButton.primaryHeightTall,
                      leadingIcon: Icons.check,
                      iconSize: Sizes.large,
                      isLoading: confirming,
                      isEnabled: !confirming,
                      onTap: () =>
                          context.read<DeliveryReceiptCubit>().confirmReceipt(),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.small),
                // receipt_not_yet_cta — Not yet → dispute-open-evidence
                // (JM-060). Inert while a confirm is in flight so it can't tear
                // down mid-call.
                Semantics(
                  identifier: 'receipt_not_yet_cta',
                  container: true,
                  button: true,
                  enabled: !confirming,
                  label: l10n.receiptNotYetCta,
                  onTap: confirming ? null : () => _openDispute(context),
                  child: ExcludeSemantics(
                    child: JeebCtaButton.outline(
                      key: const Key('receipt-not-yet-cta'),
                      label: l10n.receiptNotYetCta,
                      height: JeebCtaButton.outlineHeightTall,
                      // dc-tpl 850 realizes this label at 15.5/w600; the kit's
                      // h50 default is 13.5. Token-derived, no raw fontSize.
                      labelStyle: context.jeebText.cardTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      isEnabled: !confirming,
                      onTap: () => _openDispute(context),
                    ),
                  ),
                ),
              ],
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

/// `receipt_cash_to_jeeber_label` — "Pay **$N** cash to `<Jeeber>`" (D11) over
/// the cash-only reassurance line (dc-tpl 838-844).
///
/// The board paints this navy, not peach: it is the single most important fact
/// on the screen (what the customer owes, to whom, in cash), so it carries the
/// same ink and the same `ctaNavy` shadow as the confirm pill.
class _CashStatement extends StatelessWidget {
  const _CashStatement({required this.receipt});

  final DeliveryReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText =
        Theme.of(context).extension<JeebSemanticColors>()!.mutedText;

    // Cash is the gross order amount paid in person; the Jeeber name degrades
    // to a generic noun when absent. The copy is a localized template with
    // positional placeholders — Maestro keys on the id, not the text.
    //
    // Run-22 P1-A: when the gateway omitted the amount (the live
    // `GET /v1/deliveries/{id}` drops `amount` once the delivery is `Done`),
    // the amount is UNKNOWN — degrade to the amount-less line instead of
    // fabricating "Pay $0.00".
    final jeeberLabel = receipt.jeeberName.isNotEmpty
        ? receipt.jeeberName
        : l10n.receiptJeeberFallback;
    final amountText = receipt.hasKnownAmount
        ? MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency)
        : null;
    final cashText = amountText != null
        ? l10n.receiptCashToJeeber(amountText, jeeberLabel)
        : l10n.receiptCashToJeeberNoAmount(jeeberLabel);

    return Semantics(
      identifier: 'receipt_cash_to_jeeber_label',
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.medium,
          boxShadow: JeebShadows.ctaNavy,
        ),
        child: Row(
          children: [
            Icon(
              // Filled, not `_outlined` (R10: glyphs on navy are solid).
              Icons.payments,
              size: Sizes.xLarge,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _amountLine(context, cashText, amountText),
                  const SizedBox(height: Sizes.threeXSmall),
                  Text(
                    l10n.receiptCashNote,
                    style: context.jeebText.bodySmall
                        .copyWith(color: mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the statement with the money token one weight heavier (dc-tpl
  /// 842-843). `MoneyFormat.format` wraps its result in U+2066…U+2069, so the
  /// isolate travels inside the emphasized span and the split stays RTL-safe;
  /// when the template did not actually contain the token (a locale could
  /// reorder or transform it) we fall back to the plain string rather than
  /// guessing at offsets.
  Widget _amountLine(
    BuildContext context,
    String cashText,
    String? amountText,
  ) {
    final style = context.jeebText.titleProminent.copyWith(
      color: Theme.of(context).colorScheme.onPrimary,
    );
    final start = amountText == null ? -1 : cashText.indexOf(amountText);
    if (amountText == null || start < 0) {
      return Text(cashText, style: style);
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: cashText.substring(0, start)),
          TextSpan(
            text: amountText,
            // w800 degrades to the bundled w700 until Inter-ExtraBold ships.
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: cashText.substring(start + amountText.length)),
        ],
      ),
    );
  }
}
