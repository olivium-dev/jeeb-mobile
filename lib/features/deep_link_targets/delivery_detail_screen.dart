import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/lifecycle/app_resume_signals.dart';
import '../../core/delivery/delivery_status_vocab.dart';
import '../../core/di/injection_container.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../core/router/root_aware_back_scope.dart';
import '../../l10n/app_localizations.dart';
import '../chat/data/dio_order_chat_summary_repository.dart';
import '../chat/domain/order_chat_summary.dart';
import '../rating/domain/entities/rating_status.dart';
import '../rating/domain/rating_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../core/previews/jeeb_preview.dart';
import '../../devtool/catalog/fixtures/delivery_detail_screen_fixtures.dart';

enum _StatusBucket {
  unknown,

  active,

  delivered,

  cancelled,
}

class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
    this.ratingRepository,
    this.summaryRepository,
    this.refreshSignals,
  });

  final String deliveryId;

  final RatingRepository? ratingRepository;

  final OrderChatSummaryRepository? summaryRepository;

  final Stream<void>? refreshSignals;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen>
    with ResumeRefetchMixin {
  String? _statusId;
  StreamSubscription<void>? _refreshSub;
  OrderChatSummaryRepository? _summaryRepo;

  @override
  void initState() {
    super.initState();
    _summaryRepo = _resolveSummaryRepository();
    unawaited(_loadStatus());
    _refreshSub =
        (widget.refreshSignals ??
                resolvePushRefreshStream(topics: const {RefreshTopic.order}))
            ?.listen((_) => unawaited(_loadStatus()));
  }

  @override
  void dispose() {
    unawaited(_refreshSub?.cancel());
    _refreshSub = null;
    super.dispose();
  }

  @override
  void onAppResumed() => unawaited(_loadStatus());

  OrderChatSummaryRepository? _resolveSummaryRepository() {
    if (widget.summaryRepository != null) return widget.summaryRepository;
    if (sl.isRegistered<Dio>()) {
      return DioOrderChatSummaryRepository(sl<Dio>());
    }
    return null;
  }

  Future<void> _loadStatus() async {
    final repo = _summaryRepo;
    if (repo == null) return;
    if (_statusLoadInFlight) return;
    _statusLoadInFlight = true;
    try {
      final summary = await repo.fetchSummary(widget.deliveryId);
      if (!mounted) return;
      if (summary.statusId != _statusId) {
        setState(() => _statusId = summary.statusId);
      }
    } on OrderChatSummaryException {
    } catch (_) {
    } finally {
      _statusLoadInFlight = false;
    }
  }

  bool _statusLoadInFlight = false;

  _StatusBucket get _bucket {
    final id = _statusId;
    if (id == null || id.isEmpty) return _StatusBucket.unknown;
    if (DeliveryStatusVocab.isDelivered(id)) return _StatusBucket.delivered;
    if (DeliveryStatusVocab.isTerminal(id)) return _StatusBucket.cancelled;
    return _StatusBucket.active;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RootAwareBackScope(
      fallbackLocation: '/',
      child: Semantics(
        identifier: 'order-detail-root',
        container: true,
        child: Scaffold(
          appBar: OMDSAppBar(
            title: l10n.deliveryDetailsTitle,
            showBackButton: true,
          ),
          body: ListView(
            key: const Key('delivery-detail-list'),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            children: _buildChildren(context, l10n),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(BuildContext context, AppLocalizations l10n) {
    switch (_bucket) {
      case _StatusBucket.unknown:
        return _failOpenChildren(context, l10n);
      case _StatusBucket.active:
        return _activeChildren(context, l10n);
      case _StatusBucket.delivered:
        return _deliveredChildren(context, l10n);
      case _StatusBucket.cancelled:
        return _cancelledChildren(context, l10n);
    }
  }

  List<Widget> _failOpenChildren(BuildContext context, AppLocalizations l10n) {
    return [
      const SizedBox(height: Spacing.medium),
      _ActionRow(action: _trackAction(l10n)),
      _ActionRow(action: _chatAction(context, l10n)),
      _ActionRow(action: _otpAction(l10n)),
      _ActionRow(action: _rateAction(l10n)),
      _ActionRow(action: _escalateAction(l10n)),
      const SizedBox(height: Spacing.medium),
      _CancelButton(deliveryId: widget.deliveryId),
    ];
  }

  List<Widget> _activeChildren(BuildContext context, AppLocalizations l10n) {
    return [
      const SizedBox(height: Spacing.medium),
      _ActionRow(action: _trackAction(l10n)),
      _ActionRow(action: _chatAction(context, l10n)),
      _ActionRow(action: _otpAction(l10n)),
      _ActionRow(action: _escalateAction(l10n)),
      if (DeliveryStatusVocab.isCancelAllowed(_statusId)) ...[
        const SizedBox(height: Spacing.medium),
        _CancelButton(deliveryId: widget.deliveryId),
      ],
    ];
  }

  List<Widget> _deliveredChildren(BuildContext context, AppLocalizations l10n) {
    return [
      const SizedBox(height: Spacing.medium),
      _StatusBanner(
        semanticsId: 'order-detail-status-delivered',
        icon: Icons.check_circle_outline,
        title: l10n.deliveryDetailDeliveredBanner,
        body: l10n.deliveryDetailDeliveredBannerBody,
        tone: _StatusBannerTone.success,
      ),
      const SizedBox(height: Spacing.medium),
      _ActionRow(action: _chatAction(context, l10n)),
      _ActionRow(action: _rateAction(l10n)),
      _ActionRow(action: _receiptAction(l10n)),
      _ActionRow(action: _escalateAction(l10n)),
    ];
  }

  List<Widget> _cancelledChildren(BuildContext context, AppLocalizations l10n) {
    return [
      const SizedBox(height: Spacing.medium),
      _StatusBanner(
        semanticsId: 'order-detail-status-cancelled',
        icon: Icons.cancel_outlined,
        title: l10n.deliveryDetailCancelledBanner,
        body: l10n.deliveryDetailCancelledBannerBody,
        tone: _StatusBannerTone.error,
      ),
      const SizedBox(height: Spacing.medium),
      _ActionRow(action: _escalateAction(l10n)),
    ];
  }

  _DeliveryAction _trackAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-track',
        title: l10n.trackingTitle,
        leadingIcon: Icons.location_on_outlined,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/tracking'),
      );

  _DeliveryAction _chatAction(BuildContext context, AppLocalizations l10n) =>
      _DeliveryAction(
        semanticsId: 'order-detail-chat',
        title: _contactLabel(context, l10n),
        leadingIcon: Icons.chat_bubble_outline,
        onTap: (c) => c.pushNamed(
          'chat-detail',
          pathParameters: {'id': widget.deliveryId},
        ),
      );

  _DeliveryAction _otpAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-otp',
        title: l10n.otpVerifyButton,
        leadingIcon: Icons.lock_outline,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/otp'),
      );

  _DeliveryAction _rateAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-rate',
        title: l10n.ratingPromptTitle,
        leadingIcon: Icons.star_outline,
        onTap: (c) {
          _onRateTapped(c);
        },
      );

  _DeliveryAction _receiptAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-receipt',
        title: l10n.deliveryActionReceipt,
        leadingIcon: Icons.receipt_long_outlined,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/receipt'),
      );

  _DeliveryAction _escalateAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-escalate',
        title: l10n.escalateTitle,
        leadingIcon: Icons.report_problem_outlined,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/escalate'),
      );

  String _contactLabel(BuildContext context, AppLocalizations l10n) {
    UserRole role;
    try {
      role = context.read<RoleCubit>().state;
    } on ProviderNotFoundException {
      role = UserRole.client;
    }
    return role == UserRole.jeeber
        ? l10n.deliveryActionContactCustomer
        : l10n.deliveryActionContact;
  }

  RatingRepository? get _ratingRepository =>
      widget.ratingRepository ??
      (sl.isRegistered<RatingRepository>() ? sl<RatingRepository>() : null);

  Future<void> _onRateTapped(BuildContext context) async {
    final repo = _ratingRepository;
    if (repo == null) {
      context.push(_mutualRateLocation(context));
      return;
    }
    RatingStatus? status;
    try {
      status = await repo.fetchRatingStatus(deliveryId: widget.deliveryId);
    } on RatingRepositoryException {
      status = null;
    }
    if (!context.mounted) return;
    if (status == null ||
        status.revealState == RatingRevealState.pendingMine) {
      context.push(_mutualRateLocation(context));
      return;
    }
    await _showRatingSummary(context, status);
  }

  String _mutualRateLocation(BuildContext context) {
    UserRole role;
    try {
      role = context.read<RoleCubit>().state;
    } on ProviderNotFoundException {
      role = UserRole.client;
    }
    final suffix = role == UserRole.jeeber ? '?mode=jeeber' : '';
    return '/orders/${widget.deliveryId}/mutual-rate$suffix';
  }

  Future<void> _showRatingSummary(
    BuildContext context,
    RatingStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final counterpart = status.counterpartRating;
    final revealedBody = counterpart == null
        ? l10n.mutualRatingNoCounterRating
        : l10n.mutualRatingTheirStars(counterpart.stars);
    final (title, content) = switch (status.revealState) {
      RatingRevealState.pendingTheirs => (
          l10n.mutualRatingAwaitingTitle,
          l10n.mutualRatingAwaitingBody,
        ),
      RatingRevealState.autoRevealed => (
          l10n.mutualRatingAutoRevealedTitle,
          revealedBody,
        ),
      RatingRevealState.bothRated => (
          l10n.mutualRatingRevealedTitle,
          revealedBody,
        ),
      RatingRevealState.pendingMine => (
          l10n.mutualRatingAwaitingTitle,
          l10n.mutualRatingAwaitingBody,
        ),
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _RatingSummarySheet(
        title: title,
        content: content,
        doneLabel: l10n.mutualRatingDone,
      ),
    );
  }
}

class _RatingSummarySheet extends StatelessWidget {
  const _RatingSummarySheet({
    required this.title,
    required this.content,
    required this.doneLabel,
  });

  final String title;
  final String content;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery-rating-summary',
      container: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.star_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                content,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'delivery-rating-summary-done',
                button: true,
                container: true,
                child: OmdsPrimaryButton(
                  key: const Key('delivery-rating-summary-done'),
                  text: doneLabel,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StatusBannerTone { success, error }

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.semanticsId,
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
  });

  final String semanticsId;
  final IconData icon;
  final String title;
  final String body;
  final _StatusBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg) = switch (tone) {
      _StatusBannerTone.success => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      _StatusBannerTone.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    };
    return Semantics(
      identifier: semanticsId,
      container: true,
      label: title,
      child: Container(
        key: Key(semanticsId),
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Spacing.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Spacing.twoXSmall),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAction {
  const _DeliveryAction({
    required this.semanticsId,
    required this.title,
    required this.leadingIcon,
    required this.onTap,
  });

  final String semanticsId;
  final String title;
  final IconData leadingIcon;
  final void Function(BuildContext) onTap;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _DeliveryAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: action.semanticsId,
      button: true,
      child: OmdsSettingsRow(
        key: Key(action.semanticsId),
        title: action.title,
        leadingIcon: action.leadingIcon,
        onTap: () => action.onTap(context),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'order-detail-cancel',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('order-detail-cancel'),
        text: l10n.deliveryActionCancel,
        variant: OmdsButtonVariant.outlined,
        onTap: () => context.push('/orders/$deliveryId/cancel'),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryDetailScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports, and roughly what an Android
/// multi-window split leaves a foreground app. Every action row is an icon +
const Size _deliveryDetailScreenCompactBox = Size(320, 568);

/// Every child route this hub can push, as a path leg under `/orders/:id`.
/// Kept as data rather than six `GoRoute`s so a row added upstairs without a
const List<String> _deliveryDetailScreenLegs = <String>[
  'tracking',
  'otp',
  'cancel',
  'receipt',
  'escalate',
  'mutual-rate',
];

/// Catches a pushed route and names it, so a tap in the canvas shows WHICH
/// destination the row resolved to.
class _DeliveryDetailScreenRouteStandIn extends StatelessWidget {
  const _DeliveryDetailScreenRouteStandIn({required this.leg, this.query = ''});

  final String leg;

  /// The raw query string, which is how the rating leg carries its role
  /// (`?mode=jeeber`) — the one destination whose target depends on more than
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic route id, not shipped copy, and a latin
          query.isEmpty ? leg : '$leg?$query',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [DeliveryDetailScreen] so it can build, and gives
/// every row somewhere to land.
/// Stateful, and the router is built once and disposed with the host: a
class _DeliveryDetailScreenHost extends StatefulWidget {
  const _DeliveryDetailScreenHost({
    required this.summaryRepository,
    required this.ratingRepository,
  });

  final OrderChatSummaryRepository summaryRepository;
  final RatingRepository ratingRepository;

  @override
  State<_DeliveryDetailScreenHost> createState() =>
      _DeliveryDetailScreenHostState();
}

class _DeliveryDetailScreenHostState extends State<_DeliveryDetailScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/orders/${DeliveryDetailScreenFixtures.deliveryId}',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (_, GoRouterState state) => DeliveryDetailScreen(
          deliveryId: state.pathParameters['id']!,
          summaryRepository: widget.summaryRepository,
          ratingRepository: widget.ratingRepository,
          // Explicit, not inherited: left null this resolves the DI push bus,
          refreshSignals: const Stream<void>.empty(),
        ),
        routes: <RouteBase>[
          for (final String leg in _deliveryDetailScreenLegs)
            GoRoute(
              path: leg,
              builder: (_, GoRouterState state) =>
                  _DeliveryDetailScreenRouteStandIn(
                leg: leg,
                query: state.uri.query,
              ),
            ),
        ],
      ),
      // Pushed BY NAME with a path parameter, so it cannot be folded into the
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, _) =>
            const _DeliveryDetailScreenRouteStandIn(leg: 'chat-detail'),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

/// Pins the hub to a device-sized frame inside whatever box the canvas gives
/// it, with both repository seams supplied.
Widget _deliveryDetailScreenHosted(
  OrderChatSummaryRepository status, {
  RatingRepository rating = DeliveryDetailScreenFixtures.notYetRated,
  Size box = _deliveryDetailScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: _DeliveryDetailScreenHost(
        summaryRepository: status,
        ratingRepository: rating,
      ),
    ),
  );
}

/// The status read is still in flight — the FIRST FRAME of every delivery, and
/// the state a slow network holds for as long as it lasts.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Status pending · fails open',
  size: _deliveryDetailScreenPhoneBox,
  matrix: true,
)
Widget deliveryDetailScreenStatusPending() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.statusPending);

/// The status read FAILED (a 500, a dropped transport, the delivery service
/// down) — and the surface is IDENTICAL to the one above.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Status unavailable · fails open',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenStatusUnavailable() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.statusUnavailable);

/// ACTIVE, pre-pickup (`Ordered`): the free-cancel window (JEBV4-289) is open.
/// Live tracking + Contact + Verify OTP + Report, and the outlined Cancel
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Active · pre-pickup (cancel open)',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenActivePrePickup() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.ordered);

/// ACTIVE, parcel in hand (`InTransit`): the same bucket with the Cancel button
/// withdrawn.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Active · in transit (cancel closed)',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenActiveInTransit() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.inTransit);

/// DELIVERED (`Done`): the success banner, then Contact + Rate + Receipt +
/// Report. Cancel, Verify OTP and Live tracking are structurally absent — this
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Delivered · banner + Rate + Receipt',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenDelivered() => _deliveryDetailScreenHosted(
      DeliveryDetailScreenFixtures.delivered,
      rating: DeliveryDetailScreenFixtures.alreadyRated,
    );

/// CANCELLED: the error-toned banner and Report, and nothing else at all.
/// The shortest surface the hub can render — two children — which is the state
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Cancelled · banner + Report only',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenCancelled() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.cancelled);

/// `Expired` — a broadcast nobody accepted — rendered as **"Cancelled"**.
/// `_bucket` sends every non-delivered terminal (`expired`, `disputed`,
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Expired → Cancelled banner',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenExpiredTerminal() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.expired);

/// The delivered hub at the 320x568 floor.
/// The banner is the piece that runs out of room first: `Icon + Expanded(title
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact 320 pt · delivered',
  size: _deliveryDetailScreenCompactBox,
  matrix: true,
)
Widget deliveryDetailScreenCompactDelivered() => _deliveryDetailScreenHosted(
      DeliveryDetailScreenFixtures.delivered,
      rating: DeliveryDetailScreenFixtures.alreadyRated,
      box: _deliveryDetailScreenCompactBox,
    );
