import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../client_offers/domain/offers_repository.dart';
import '../../../client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../application/client_home_cubit.dart';
import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';
import '../widgets/replies_card.dart';

class RepliesTab extends StatefulWidget {
  const RepliesTab({super.key, this.onCheckOffers, this.onAccept});

  final void Function(ClientHomeRequest request)? onCheckOffers;

  final void Function(ClientHomeRequest request)? onAccept;

  @override
  State<RepliesTab> createState() => _RepliesTabState();
}

class _RepliesTabState extends State<RepliesTab> {
  bool _openingAcceptSheet = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      buildWhen: _rebuildWhen,
      builder: (context, state) => _RepliesContent(
        state: state,
        onCheckOffers:
            widget.onCheckOffers ?? (r) => _openOfferReview(context, r),
        onAccept: widget.onAccept ?? (r) => _openAcceptConfirm(context, r),
      ),
    );
  }

  static bool _rebuildWhen(ClientHomeState prev, ClientHomeState next) =>
      prev.status != next.status || prev.replies != next.replies;

  static void _openOfferReview(
    BuildContext context,
    ClientHomeRequest request,
  ) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('offer-review', pathParameters: {'id': request.id});
  }

  Future<void> _openAcceptConfirm(
    BuildContext context,
    ClientHomeRequest request,
  ) async {
    if (request.id.isEmpty) return;
    if (_openingAcceptSheet) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<OffersRepository>()) {
      _openOfferReview(context, request);
      return;
    }
    final repository = getIt<OffersRepository>();
    _openingAcceptSheet = true;
    try {
      final snapshot = await repository.fetchOffers(request.id);
      if (!context.mounted) return;
      if (snapshot.offers.isEmpty) {
        _openOfferReview(context, request);
        return;
      }
      await OfferAcceptSheet.show(
        context,
        offer: snapshot.offers.first,
        requestId: request.id,
      );
    } catch (_) {
      if (!context.mounted) return;
      _openOfferReview(context, request);
    } finally {
      _openingAcceptSheet = false;
    }
  }
}

class _RepliesContent extends StatelessWidget {
  const _RepliesContent({
    required this.state,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final ClientHomeState state;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    if (state.status == ClientHomeStatus.failed) {
      return _RepliesError(
        onRetry: () => context.read<ClientHomeCubit>().load(),
      );
    }
    if (state.status == ClientHomeStatus.loading) {
      return const _RepliesLoading();
    }
    if (state.replies.isEmpty) {
      return const _RepliesEmpty();
    }
    return _RepliesList(
      requests: state.replies,
      onCheckOffers: onCheckOffers,
      onAccept: onAccept,
    );
  }
}

class _RepliesLoading extends StatelessWidget {
  const _RepliesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(key: Key('replies-loading'), child: OmdsLoadingState());
  }
}

class _RepliesError extends StatelessWidget {
  const _RepliesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: const Key('replies-error'),
      icon: Icons.cloud_off_outlined,
      title: l10n.homeLoadFailedTitle,
      message: l10n.homeErrorRetry,
      retryLabel: l10n.homeLoadFailedRetry,
      onRetry: onRetry,
    );
  }
}

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: const Key('replies-empty'),
      icon: Icons.mark_chat_unread_outlined,
      title: l10n.homeEmptyTitle,
      subtitle: l10n.homeRepliesEmpty,
    );
  }
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({
    required this.requests,
    required this.onCheckOffers,
    required this.onAccept,
  });

  final List<ClientHomeRequest> requests;
  final void Function(ClientHomeRequest) onCheckOffers;
  final void Function(ClientHomeRequest) onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('replies-tab-list'),
      children: [
        for (final r in requests)
          Semantics(
            label: _a11yLabel(context, r),
            child: RepliesCard(
              request: r,
              onCheckOffers: () => onCheckOffers(r),
              onAccept: () => onAccept(r),
            ),
          ),
      ],
    );
  }

  String _a11yLabel(BuildContext context, ClientHomeRequest r) {
    final l10n = AppLocalizations.of(context);
    return l10n.repliesTabA11yLabel(r.offerCount);
  }
}
