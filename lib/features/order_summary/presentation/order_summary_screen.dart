import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/order_summary_cubit.dart';
import '../application/order_summary_state.dart';
import '../data/fake_order_summary_repository.dart';
import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';
import 'order_summary_l10n.dart';
import 'widgets/order_summary_pinned.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/order_summary_screen_fixtures.dart';

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

/// MIDNIGHT (M3-05). No tile was ever drawn for this screen; it is derived from
/// R12 `Review & send`, the ticket screen it sits next to in the same journey.
class _OrderSummaryView extends StatelessWidget {
  const _OrderSummaryView();

  @override
  Widget build(BuildContext context) {
    final l10n = OrderSummaryL10n.of(context);
    return BlocBuilder<OrderSummaryCubit, OrderSummaryState>(
      builder: (context, state) {
        final OrderSummary? summary =
            state.status == OrderSummaryStatus.loaded ? state.summary : null;
        return Scaffold(
          backgroundColor: Colors.transparent,
          // R12 draws no radial of its own past the top-end bloom, so the
          // content field keeps its default glow and stays still (§Motion 1).
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            animateDecor: false,
            child: SafeArea(
              child: Semantics(
                identifier: 'order_summary_root',
                // Both flags or this node swallows every nested identifier.
                container: true,
                explicitChildNodes: true,
                child: Column(
                  children: [
                    JeebTopBar.back(
                      title: l10n.title,
                      identifier: 'order_summary_back',
                      // Mirrors `backFallbacks['order-summary'] = '/'`; the
                      // route is already wrapped, so no RootAwareBackScope.
                      onLeadingPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    Expanded(child: _body(context, l10n, state)),
                    if (summary != null) ?_footer(context, summary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    OrderSummaryL10n l10n,
    OrderSummaryState state,
  ) {
    switch (state.status) {
      case OrderSummaryStatus.initial:
      case OrderSummaryStatus.loading:
        return _StateBlock(
          status: JeebEmptyStateStatus.loading,
          headline: l10n.title,
          identifier: 'order_summary_loading',
        );
      case OrderSummaryStatus.failed:
        return _failure(context, l10n, state.error);
      case OrderSummaryStatus.loaded:
        final OrderSummary? summary = state.summary;
        if (summary == null) return _notFound(l10n);
        return SingleChildScrollView(
          // The ticket owns the 24 gutter and R12's 18 top gap; the docked
          // footer owns the bottom.
          child: OrderSummaryPinned(summary: summary),
        );
    }
  }

  /// A 404 is an ABSENCE, not a fault: it takes the empty rung of the family,
  /// and no Retry, because refetching a deleted order cannot succeed.
  Widget _notFound(OrderSummaryL10n l10n) => _StateBlock(
        status: JeebEmptyStateStatus.empty,
        headline: l10n.notFoundTitle,
        body: l10n.notFoundBody,
        identifier: 'order_summary_empty',
      );

  Widget _failure(
    BuildContext context,
    OrderSummaryL10n l10n,
    OrderSummaryFailure? failure,
  ) {
    if (failure == OrderSummaryFailure.notFound) return _notFound(l10n);
    return _StateBlock(
      status: JeebEmptyStateStatus.error,
      headline: l10n.errorTitle,
      body: failure == OrderSummaryFailure.network
          ? l10n.errorNetworkBody
          : l10n.errorServerBody,
      identifier: 'order_summary_error',
      action: JeebCtaButton.primary(
        label: l10n.retryLabel,
        identifier: 'order_summary_retry_cta',
        onTap: () => context.read<OrderSummaryCubit>().refresh(),
      ),
    );
  }

  /// R12 docks its act below the scroll area so it stays reachable at every
  /// text scale; the ids are the frozen ones, re-homed onto the docked pills.
  Widget? _footer(BuildContext context, OrderSummary summary) =>
      OrderSummaryPinned.ctaFooter(
        context,
        padding: JeebCtaFooter.docked,
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
      );
}

/// The empty / loading / error rungs of the §2.7 family, on E4's parcel: the
/// subject of this screen IS an order, and E4 is the tile that draws one.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.status,
    required this.headline,
    required this.identifier,
    this.body,
    this.action,
  });

  final JeebEmptyStateStatus status;
  final String headline;
  final String identifier;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: status,
          variant: JeebEmptyStateVariant.parcel,
          headline: headline,
          body: body,
          identifier: identifier,
          action: action,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _orderSummaryScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _orderSummaryScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map reads the four that pin
final class OrderSummaryScreenCaptions {
  OrderSummaryScreenCaptions._();

  /// The reference reading: an accepted order with every field populated.
  static const String loaded = 'preview · loaded · every field populated';

  /// The fetch is on the wire and nothing has come back.
  static const String coldRead = 'preview · cold read · fetch in flight';

  /// A 404 on the delivery read.
  static const String notFound = 'preview · error · NOT FOUND (404)';

  /// Offline / gateway unreachable — the same picture as [notFound].
  static const String networkFailure = 'preview · error · NETWORK (offline)';

  /// Every optional field absent, every required one defaulted.
  static const String minimalPayload = 'preview · minimal payload · 0.00 + uuid';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content · 7-digit SYP';

  /// The same content on the narrowest supported device.
  static const String compact = 'preview · loaded · 320x568 viewport';

  /// No repository, no DI — the shipped fake answers instead.
  static const String unconfiguredDi =
      'preview · unconfigured DI · FABRICATED order';
}

/// Mounts the real screen on one shared designed state, framed, captioned and
/// frozen.
Widget _orderSummaryScreenHosted(
  OrderSummaryScreenDesignedState state,
  String caption, {
  Size box = _orderSummaryScreenPhoneBox,
}) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderSummaryScreenCaption(caption: caption),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: OrderSummaryScreen(
                deliveryId: state.deliveryId,
                repository: state.repository,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _OrderSummaryScreenCaption extends StatelessWidget {
  const _OrderSummaryScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// CATALOG · "Loaded". The reference reading: an accepted express order with a
/// rating, a review count, an ETA and an item line, and BOTH CTAs — this route
@JeebPreview(
  group: 'order_summary',
  name: 'Loaded · both CTAs',
  size: _orderSummaryScreenPhoneBox,
  matrix: true,
)
Widget orderSummaryScreenLoaded() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.loaded,
      OrderSummaryScreenCaptions.loaded,
    );

/// CATALOG · "Loading". Cold start: the fetch is in flight and nothing has come
/// back.
@JeebPreview(
  group: 'order_summary',
  name: 'Loading · cold read',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenColdRead() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.coldRead,
      OrderSummaryScreenCaptions.coldRead,
    );

/// CATALOG · "Failed — Not Found". The accepted order is gone, or the deep link
/// carried an id this account cannot see.
@JeebPreview(
  group: 'order_summary',
  name: 'Error · not found',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenNotFound() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.notFound,
      OrderSummaryScreenCaptions.notFound,
    );

/// The offline failure — the one where Retry could actually work, and the one
/// the copy could actually help with ("check your connection").
@JeebPreview(
  group: 'order_summary',
  name: 'Error · network',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenNetworkFailure() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.networkFailure,
      OrderSummaryScreenCaptions.networkFailure,
    );

/// The emptiest LOADED body this screen can reach: every optional field absent
/// and every required one defaulted by the parser.
@JeebPreview(
  group: 'order_summary',
  name: 'Minimal payload',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenMinimalPayload() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.minimalPayload,
      OrderSummaryScreenCaptions.minimalPayload,
    );

/// The ceiling on every axis at once: a seven-digit SYP price, a three-part
/// name, the longest tier label, a four-hour ETA, a five-digit review count and
@JeebPreview(
  group: 'order_summary',
  name: 'Longest content',
  size: _orderSummaryScreenPhoneBox,
  matrix: true,
)
Widget orderSummaryScreenLongestContent() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.longestContent,
      OrderSummaryScreenCaptions.longestContent,
    );

/// The reference order on the narrowest viewport the app supports.
/// 320 pt is where the header row runs out of slack first: the avatar and the
@JeebPreview(
  group: 'order_summary',
  name: 'Compact viewport',
  size: _orderSummaryScreenCompactBox,
)
Widget orderSummaryScreenCompact() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.loaded,
      OrderSummaryScreenCaptions.compact,
      box: _orderSummaryScreenCompactBox,
    );

/// NO repository and NO DI: what a misconfigured build actually shows.
/// This is the one preview that does not hand the screen a fixture — it hands
@JeebPreview(
  group: 'order_summary',
  name: 'Unconfigured DI · fabricated summary',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenUnconfiguredDi() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.unconfiguredDi,
      OrderSummaryScreenCaptions.unconfiguredDi,
    );
