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

class DeliveryReceiptScreen extends StatelessWidget {
  const DeliveryReceiptScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  final DeliveryReceiptRepository? repository;

  DeliveryReceiptRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
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
        Text(
          l10n.receiptPromptHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.large),
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
