import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/offer_accept_cubit.dart';
import '../../application/offer_accept_state.dart';
import '../../data/fake_offers_repository.dart';
import '../../domain/offer.dart';
import '../../domain/offers_repository.dart';

class OfferAcceptSheet extends StatelessWidget {
  const OfferAcceptSheet({
    super.key,
    required this.offer,
    required this.requestId,
    this.repository,
    this.onConfirmed,
    this.onCancelled,
    this.initialState,
  });

  final Offer offer;

  final String requestId;

  final OffersRepository? repository;

  final void Function(OfferAcceptResult result)? onConfirmed;

  final VoidCallback? onCancelled;

  final OfferAcceptState? initialState;

  OffersRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OffersRepository>()) return sl<OffersRepository>();
    return FakeOffersRepository();
  }

  static Future<void> show(
    BuildContext context, {
    required Offer offer,
    required String requestId,
    OffersRepository? repository,
  }) {
    final rootContext = context;
    final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
      alpha: UIConstants.opacityHigh,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => OfferAcceptSheet(
        offer: offer,
        requestId: requestId,
        repository: repository,
        onConfirmed: (result) {
          Navigator.of(sheetContext).pop();
          final deliveryId = result.deliveryId;
          rootContext.goNamed(
            'chat-detail',
            pathParameters: {'id': requestId},
            queryParameters: {
              if (deliveryId != null && deliveryId.isNotEmpty)
                'deliveryId': deliveryId,
            },
          );
        },
        onCancelled: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OfferAcceptCubit>(
      create: (_) => OfferAcceptCubit(
        repository: repo,
        requestId: requestId,
        offerId: offer.id,
        initialState: initialState,
      ),
      child: _OfferAcceptView(
        offer: offer,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }
}

class _OfferAcceptView extends StatelessWidget {
  const _OfferAcceptView({
    required this.offer,
    this.onConfirmed,
    this.onCancelled,
  });

  final Offer offer;
  final void Function(OfferAcceptResult result)? onConfirmed;
  final VoidCallback? onCancelled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    final jeeberDisplayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    return BlocConsumer<OfferAcceptCubit, OfferAcceptState>(
      listenWhen: (prev, next) =>
          prev.status != next.status &&
          next.status == OfferAcceptStatus.succeeded,
      listener: (context, state) {
        onConfirmed?.call(state.result ?? OfferAcceptResult.empty);
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.isSubmitting,
          child: Semantics(
            identifier: 'offer_accept_sheet',
            explicitChildNodes: true,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.small,
                  Spacing.xLarge,
                  Spacing.xLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetDragHandle(),
                    const SizedBox(height: Spacing.large),
                    Semantics(
                      identifier: 'offer_accept_jeeber_name',
                      child: Text(
                        l10n.offerAcceptTitle(jeeberDisplayName),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'offer_accept_price_label',
                      child: Text(
                        l10n.offersCardFee(feeFormatted, offer.currency),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'offer_accept_other_offers_note',
                      child: Text(
                        l10n.chatOfferAcceptOnlyOne,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (state.status == OfferAcceptStatus.failed &&
                        state.error != null) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'offer_accept_error',
                        liveRegion: true,
                        child: Container(
                          key: const Key('offer-accept-error'),
                          padding: const EdgeInsets.all(Spacing.small),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: OmdsBorderRadius.small,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: Spacing.small),
                              Expanded(
                                child: Text(
                                  _failureCopy(l10n, state.error!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXLarge),
                    Semantics(
                      identifier: 'offer_accept_confirm_cta',
                      container: true,
                      button: true,
                      label: l10n.chatOfferAccept,
                      onTap: state.isSubmitting
                          ? null
                          : () => context.read<OfferAcceptCubit>().confirm(),
                      child: ExcludeSemantics(
                        child: OmdsLoadingButton(
                          key: const Key('offer-accept-confirm-cta'),
                          text: state.isSubmitting
                              ? l10n.chatOfferAccepting
                              : l10n.chatOfferAccept,
                          isLoading: state.isSubmitting,
                          onTap: () =>
                              context.read<OfferAcceptCubit>().confirm(),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          borderRadius: OmdsBorderRadius.uiSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'offer_accept_cancel_cta',
                      container: true,
                      button: true,
                      label: l10n.actionCancel,
                      onTap: state.isSubmitting ? null : onCancelled,
                      child: ExcludeSemantics(
                        child: OmdsPrimaryButton(
                          key: const Key('offer-accept-cancel-cta'),
                          text: l10n.actionCancel,
                          variant: OmdsButtonVariant.outlined,
                          isEnabled: !state.isSubmitting,
                          onTap: () => onCancelled?.call(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _failureCopy(AppLocalizations l10n, OffersFailure failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.jeeberAtCapacity:
        return l10n.offersErrorJeeberAtCapacity;
      case OffersFailure.rateLimited:
      case OffersFailure.unknown:
        return l10n.offersErrorGeneric;
    }
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
