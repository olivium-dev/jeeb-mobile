import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../jeeber_request_feed/data/dio_submitted_offers_repository.dart';
import '../../jeeber_request_feed/domain/submitted_offer.dart';
import '../../jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../jeeber_request_feed/presentation/pending_offer_row.dart';

class JeeberPendingOffersScreen extends StatelessWidget {
  const JeeberPendingOffersScreen({super.key, this.repository, this.jeeberId});

  final SubmittedOffersRepository? repository;

  final String? jeeberId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SubmittedOffersCubit>(
      create: (_) => SubmittedOffersCubit(
        repository: repository ?? _resolveRepository(),
        lifecycleSignals: sl.isRegistered<OfferLifecycleSignals>()
            ? sl<OfferLifecycleSignals>().stream
            : null,
      )..load(),
      child: const _PendingOffersView(),
    );
  }

  SubmittedOffersRepository _resolveRepository() {
    if (sl.isRegistered<Dio>()) {
      return DioSubmittedOffersRepository(
        dio: sl<Dio>(),
        jeeberId: jeeberId,
        tokenStore: sl.isRegistered<AuthTokenStore>()
            ? sl<AuthTokenStore>()
            : null,
      );
    }
    return const _EmptySubmittedOffersRepository();
  }
}

class _EmptySubmittedOffersRepository implements SubmittedOffersRepository {
  const _EmptySubmittedOffersRepository();

  @override
  Future<List<SubmittedOffer>> listSubmitted() async =>
      const <SubmittedOffer>[];

  @override
  Future<bool> withdraw(String offerId) async => false;
}

class _PendingOffersView extends StatelessWidget {
  const _PendingOffersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_pending_offers_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.pendingOffersTitle,
          showBackButton: true,
          leading: Semantics(
            identifier: 'pending_offers_back',
            button: true,
            container: true,
            child: BackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
        body: BlocBuilder<SubmittedOffersCubit, SubmittedOffersState>(
          builder: (context, state) {
            final cubit = context.read<SubmittedOffersCubit>();
            if (state.status == SubmittedOffersStatus.loading &&
                state.offers.isEmpty) {
              return const OmdsLoadingState();
            }
            if (state.status == SubmittedOffersStatus.error &&
                state.offers.isEmpty) {
              return OmdsErrorState(
                message: l10n.offerSubmissionErrorGeneric,
                retryLabel: l10n.offerSubmissionRetryButton,
                onRetry: () => cubit.load(),
              );
            }
            if (state.offers.isEmpty) {
              return OmdsEmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: l10n.pendingOffersEmptyTitle,
                subtitle: l10n.pendingOffersEmptyBody,
              );
            }
            return OmdsPullToRefresh(
              onRefresh: cubit.load,
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: Spacing.small,
                ),
                itemCount: state.offers.length,
                itemBuilder: (_, index) {
                  final offer = state.offers[index];
                  return PendingOfferRow(
                    index: index,
                    offer: offer,
                    isWithdrawing: state.isWithdrawing(offer.id),
                    onWithdraw: () => cubit.withdraw(offer.id),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
