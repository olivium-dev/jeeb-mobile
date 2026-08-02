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
