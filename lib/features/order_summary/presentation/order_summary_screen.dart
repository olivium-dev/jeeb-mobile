import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/order_summary_cubit.dart';
import '../application/order_summary_state.dart';
import '../data/fake_order_summary_repository.dart';
import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';
import 'order_summary_l10n.dart';
import 'widgets/order_summary_pinned.dart';

/// `order-summary` (JM-031, CTO-D3). The standalone accepted-order summary
/// screen at `/orders/:id/summary`.
///
/// CTO-D3: the PRIMARY rendering of `order-summary-pinned` is the reusable
/// [OrderSummaryPinned] header widget injected into `order-chat` (JM-025) +
/// `order-tracking` (JM-032). THIS route is the navigable deep-link TARGET for
/// `transaction-detail → order-summary-pinned` (JM-056, W3) so every blueprint
/// edge stays honest (21_NAV_PLAN §A/§C). It wires BOTH CTAs (the embedded
/// chat/tracking hosts pass only the OTHER screen's CTA).
///
/// Data: `GET /v1/delivery/:deliveryId` (+ best-effort request/offer/user) via
/// [OrderSummaryRepository] resolved from DI. A constructor [repository] /
/// [cubitFactory] override is the widget-test seam.
class OrderSummaryScreen extends StatelessWidget {
  const OrderSummaryScreen({
    super.key,
    required this.deliveryId,
    this.repository,
    this.cubitFactory,
  });

  /// The accepted delivery/order id from the `/orders/:id/summary` path.
  final String deliveryId;

  /// Optional repository override. Production leaves this null and resolves
  /// [OrderSummaryRepository] from GetIt (the Dio impl). Widget tests inject a
  /// scripted instance.
  final OrderSummaryRepository? repository;

  /// Test seam — builds the cubit (e.g. without auto-load) for widget tests.
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
        // redesign-2026-08: the OMDS app bar is gone — the board draws the
        // title as an in-body row beside a tonal Ø40 back circle (10 `tpl 570`).
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.title,
                identifier: 'order_summary_back',
                // Mirrors `backFallbacks['order-summary'] = '/'`; the route is
                // already wrapped, so no RootAwareBackScope here. Without the
                // fallback the circle would dead-end on a deep-link cold start,
                // which is exactly how this route is reached (JM-056).
                onLeadingPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              Expanded(
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
            ],
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
      // The pinned widget owns the 24px board gutter and its own top inset, so
      // the list contributes only the docked-footer bottom rhythm (10 `tpl 622`).
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        0,
        0,
        Spacing.twoXLarge,
      ),
      children: [
        OrderSummaryPinned(
          summary: summary,
          // EDGE: order_summary_open_chat → chat-detail (`/chat/:id`).
          // 21_NAV_PLAN §C, JM-031→JM-025. Falls back to the request/delivery
          // id when no conversation id surfaced (the route resolves either).
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
          // EDGE: order_summary_track → live-tracking (`/orders/:id/tracking`).
          // 21_NAV_PLAN §C, JM-031→JM-032.
          onTrack: () => context.pushNamed(
            'live-tracking',
            pathParameters: {'id': summary.deliveryId},
          ),
        ),
      ],
    );
  }
}
