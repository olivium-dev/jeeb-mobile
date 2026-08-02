import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../application/order_summary_cubit.dart';
import '../application/order_summary_state.dart';
import '../data/fake_order_summary_repository.dart';
import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';
import 'order_summary_l10n.dart';
import 'widgets/order_summary_pinned.dart';

class OrderSummaryScreen extends StatelessWidget {
  const OrderSummaryScreen({
    super.key,
    required this.deliveryId,
    this.repository,
    this.cubitFactory,
  });

  final String deliveryId;

  final OrderSummaryRepository? repository;

  final OrderSummaryCubit Function(
    OrderSummaryRepository repository,
    String deliveryId,
  )? cubitFactory;

  OrderSummaryRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OrderSummaryRepository>()) {
      return sl<OrderSummaryRepository>();
    }
    return FakeOrderSummaryRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OrderSummaryCubit>(
      create: (_) {
        final cubit = cubitFactory?.call(repo, deliveryId) ??
            OrderSummaryCubit(repository: repo, deliveryId: deliveryId);
        cubit.load();
        return cubit;
      },
      child: const _OrderSummaryView(),
    );
  }
}

class _OrderSummaryView extends StatelessWidget {
  const _OrderSummaryView();

  @override
  Widget build(BuildContext context) {
    final l10n = OrderSummaryL10n.of(context);
    return Semantics(
      identifier: 'order_summary_root',
      container: true,
      child: Scaffold(
      appBar: OMDSAppBar(title: l10n.title, showBackButton: true),
      body: SafeArea(
        child: BlocBuilder<OrderSummaryCubit, OrderSummaryState>(
          builder: (context, state) {
            switch (state.status) {
              case OrderSummaryStatus.initial:
              case OrderSummaryStatus.loading:
                return const Center(child: OmdsLoadingState());
              case OrderSummaryStatus.failed:
                return Center(
                  child: OmdsErrorState(
                    message: l10n.errorGeneric,
                    retryLabel: l10n.retryLabel,
                    onRetry: () =>
                        context.read<OrderSummaryCubit>().refresh(),
                  ),
                );
              case OrderSummaryStatus.loaded:
                return _Loaded(summary: state.summary!);
            }
          },
        ),
      ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        Spacing.small,
        0,
        Spacing.xLarge,
      ),
      children: [
        OrderSummaryPinned(
          summary: summary,
          onOpenChat: () => context.pushNamed(
            'chat-detail',
            pathParameters: {
              'id': summary.conversationId.isNotEmpty
                  ? summary.conversationId
                  : (summary.requestId.isNotEmpty
                      ? summary.requestId
                      : summary.deliveryId),
            },
          ),
          onTrack: () => context.pushNamed(
            'live-tracking',
            pathParameters: {'id': summary.deliveryId},
          ),
        ),
      ],
    );
  }
}
