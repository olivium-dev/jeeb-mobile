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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_pending_offers_screen_fixtures.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against.
const Size _jeeberPendingOffersScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _jeeberPendingOffersScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _jeeberPendingOffersScreenFramed(
  Widget screen, {
  Size box = _jeeberPendingOffersScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way its route builds it — no DI, one injected
/// repository — pinned to a device frame.
Widget _jeeberPendingOffersScreenHosted(
  SubmittedOffersRepository repository, {
  Size box = _jeeberPendingOffersScreenPhoneBox,
  bool muteTicker = false,
}) {
  final Widget screen = JeeberPendingOffersScreen(
    repository: repository,
    jeeberId: jeeberPendingOffersScreenJeeberId,
  );
  return _jeeberPendingOffersScreenFramed(
    muteTicker ? TickerMode(enabled: false, child: screen) : screen,
    box: box,
  );
}

/// The reference reading, and the state JM-047 AC1/AC2 assert: two offers still
/// awaiting the customer's decision.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Awaiting decision',
  size: _jeeberPendingOffersScreenPhoneBox,
  matrix: true,
)
Widget jeeberPendingOffersScreenAwaitingDecision() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.awaitingDecision,
      ),
    );

/// sprint-009 offer-lifecycle: the two TERMINAL outcomes beside a still-open
/// offer.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Mixed outcomes · accepted / not selected',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenMixedOutcomes() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.mixedOutcomes,
      ),
    );

/// A read that SUCCEEDED and came back with zero rows.
/// Read this next to [jeeberPendingOffersScreenLoadFailed]: a failed read
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Empty · nothing submitted',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenEmpty() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.none,
      ),
    );

/// The cold read failed: an [OmdsErrorState] with a Retry that re-enters
/// `load()`.
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Load failed · retry',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLoadFailed() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenFailingOffers(),
    );

/// The cold read in flight: an [OmdsLoadingState] spinner and nothing else.
/// Every jeeber sees this — `load()` is fired from `BlocProvider.create` and
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Loading · cold read',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLoading() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStalledOffers(),
      muteTicker: true,
    );

/// A pending list long enough to scroll.
/// The body is a bare `ListView.builder` under an app bar — no count, no
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Long list · scrolls',
  size: _jeeberPendingOffersScreenPhoneBox,
)
Widget jeeberPendingOffersScreenLongList() => _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.manyOffers,
      ),
    );

/// The layout ceiling on the narrowest phone the app supports.
/// Lebanese pricing is the real case: LBP is zero-decimal and everyday amounts
@JeebPreview(
  group: 'jeeber_pending_offers',
  name: 'Longest content · compact 320',
  size: _jeeberPendingOffersScreenCompactBox,
  matrix: true,
)
Widget jeeberPendingOffersScreenLongestContent() =>
    _jeeberPendingOffersScreenHosted(
      const JeeberPendingOffersScreenStaticOffers(
        JeeberPendingOffersScreenOffers.longestContent,
      ),
      box: _jeeberPendingOffersScreenCompactBox,
    );
