import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

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

/// Which lifecycle bucket the delivery-details hub is rendering. Derived from
/// the wire `statusId` via [DeliveryStatusVocab] (JEBV4-309).
enum _StatusBucket {
  /// Status still loading, or unavailable (no repo / fetch error). The hub
  /// FAILS OPEN — it renders the full legacy action list. Never reached for a
  /// known-Delivered order, so Cancel is never shown on a delivered delivery.
  unknown,

  /// In-progress delivery (Ordered..AtDoor). Live tracking / Verify OTP /
  /// Report stay; Cancel shows only while the MVP free-cancel window is open
  /// (pre-pickup / on-hold).
  active,

  /// Successful completion (Done/delivered/completed). Delivered banner + Rate +
  /// Report + Receipt; Cancel / Verify OTP / Live tracking are hidden.
  delivered,

  /// Any non-delivered terminal (cancelled/expired/disputed/…). Cancelled
  /// banner + Report only.
  cancelled,
}

/// Client order-detail action hub (B-P0).
///
/// Single destination reached from the order list
/// (`order_history_screen.dart` → `context.push('/orders/:id')`) AND from
/// delivery push notifications. It exposes the per-order actions so the
/// otherwise-orphaned child routes are reachable:
///   - `/orders/:id/tracking`  — live tracking
///   - `chat-detail` (named)   — order conversation
///   - `/orders/:id/otp`       — handover OTP confirmation
///   - `/orders/:id/cancel`    — pre-pickup cancellation (free — JEBV4-289)
///   - `/orders/:id/mutual-rate` — post-delivery rating (status-aware entry,
///     JEBV4-308; already-rated deliveries show a read-only summary instead)
///   - `/orders/:id/receipt`   — delivered cash receipt (JM-033)
///   - `/orders/:id/escalate`  — report an issue
///
/// Status-gating (JEBV4-309): the hub is now STATE-AWARE. On mount it reads the
/// delivery's lifecycle `statusId` from `GET /v1/deliveries/{id}` (via
/// [DioOrderChatSummaryRepository.fetchSummary] — the SAME source
/// `ChatDetailScreen` polls, JEBV4-282) and, while the delivery is still
/// non-terminal, re-reads it on a light 5s poll. The wire status is classified
/// through the shared [DeliveryStatusVocab] and the visible action rows are
/// gated per bucket ([_StatusBucket]):
///   - ACTIVE   — Live tracking, Contact, Verify OTP, Report; Cancel only while
///                the pre-pickup / on-hold free-cancel window is open.
///   - DELIVERED — Delivered banner + Rate + Report + Receipt (no Cancel / OTP /
///                tracking).
///   - CANCELLED — Cancelled banner + Report only.
/// If the status is still loading or unavailable the hub FAILS OPEN to the full
/// legacy list, but it can never surface Cancel on a known-Delivered order (the
/// delivered bucket omits it structurally).
///
/// Rating entry (JEBV4-308): the rating row is STATUS-AWARE. It reads the
/// server-owned reveal state (`GET /v1/ratings/jeeb/{id}/status`) first — a
/// not-yet-rated delivery routes to the canonical mandatory terminal
/// (`/orders/:id/mutual-rate`), while an already-rated one shows a read-only
/// summary instead of a re-editable form.
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
    this.ratingRepository,
    this.summaryRepository,
    this.statusPollInterval = const Duration(seconds: 5),
  });

  final String deliveryId;

  /// Test seam — defaults to `sl<RatingRepository>()` at runtime. Injected by
  /// widget tests so the status-aware rating entry can be exercised without the
  /// full DI graph.
  final RatingRepository? ratingRepository;

  /// Test seam for the delivery-status source. Defaults to a
  /// [DioOrderChatSummaryRepository] over the DI `Dio` at runtime. Injected by
  /// widget tests so the state buckets can be exercised without a live gateway.
  final OrderChatSummaryRepository? summaryRepository;

  /// How often to re-read the delivery status while it is still non-terminal.
  /// `null` disables polling entirely (the widget-test seam — an active-bucket
  /// test would otherwise leave a pending periodic timer).
  final Duration? statusPollInterval;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  /// Last-known wire `statusId`. Null/empty ⇒ status not yet resolved or
  /// unavailable ⇒ the hub fails open.
  String? _statusId;
  Timer? _statusPollTimer;
  OrderChatSummaryRepository? _summaryRepo;

  @override
  void initState() {
    super.initState();
    _summaryRepo = _resolveSummaryRepository();
    // Kick off the first read; arm the light poll only while non-terminal and
    // only when polling is enabled (disabled in widget tests).
    unawaited(_loadStatus());
    _startPoll();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    super.dispose();
  }

  /// Resolves the status source from the test seam, falling back to a
  /// [DioOrderChatSummaryRepository] over the DI `Dio`. Returns `null` when
  /// neither is available (previews / isolated tests without DI) so the hub
  /// degrades to the fail-open full list.
  OrderChatSummaryRepository? _resolveSummaryRepository() {
    if (widget.summaryRepository != null) return widget.summaryRepository;
    if (sl.isRegistered<Dio>()) {
      return DioOrderChatSummaryRepository(sl<Dio>());
    }
    return null;
  }

  /// One status read. On success repaints with the fresh `statusId` and stops
  /// the poll once terminal. On any failure the last-known status is kept (the
  /// hub never regresses a known status to fail-open) and the poll keeps trying.
  Future<void> _loadStatus() async {
    final repo = _summaryRepo;
    if (repo == null) return;
    try {
      final summary = await repo.fetchSummary(widget.deliveryId);
      if (!mounted) return;
      if (summary.statusId != _statusId) {
        setState(() => _statusId = summary.statusId);
      }
      if (DeliveryStatusVocab.isTerminal(_statusId)) {
        _statusPollTimer?.cancel();
        _statusPollTimer = null;
      }
    } on OrderChatSummaryException {
      // Unavailable — keep last-known status (fail-open while still null).
    } catch (_) {
      // Defensive: never let a status read crash the hub.
    }
  }

  void _startPoll() {
    final interval = widget.statusPollInterval;
    if (interval == null || _summaryRepo == null) return;
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(interval, (_) => _loadStatus());
  }

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
    // BACK-nav defect fix: reached in-app via `context.push('/orders/:id')` (has
    // a parent) BUT also as the stack ROOT from a delivery push-notification /
    // deep link (`GoRouter.go('/orders/:id')`). The root-aware scope pops to the
    // parent when there is one and otherwise lands on Home instead of exiting.
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

  /// Status loading / unavailable — the legacy full list (every CTA + Cancel).
  /// Preserves the pre-JEBV4-309 behaviour so a hub with no status source keeps
  /// working. The delivered bucket omits Cancel structurally, so this fail-open
  /// path can never expose Cancel on a known-Delivered order.
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

  /// In-progress: tracking / contact / OTP / report stay; Cancel only while the
  /// pre-pickup / on-hold free-cancel window is open (JEBV4-289). Rate is a
  /// delivered-class-only affordance, so it is not shown here.
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

  /// Delivered terminal: Delivered banner + Contact + Rate + Receipt + Report.
  /// No Cancel / Verify OTP / Live tracking.
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

  /// Cancelled (or any non-delivered terminal): Cancelled banner + Report only.
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

  // ---- Individual action descriptors ---------------------------------------

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
        // JEBV4-308: status-aware entry (see class doc). Fire-and-forget the
        // async handler; `_ActionRow` invokes this from a sync `onTap`.
        onTap: (c) {
          _onRateTapped(c);
        },
      );

  _DeliveryAction _receiptAction(AppLocalizations l10n) => _DeliveryAction(
        // JM-033 delivered-receipt route (`delivered-receipt`,
        // `/orders/:id/receipt`) — reachable only from the delivered hub.
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

  /// Role-aware Contact label (run-22 chat-cluster fix): the row names the
  /// COUNTERPART — a customer contacts their Jeeber, a Jeeber contacts the
  /// customer. Reads the app-global [RoleCubit] defensively (this hub is also
  /// mounted from push deep links / isolated tests where the cubit may be
  /// absent) and degrades to the customer wording.
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

  /// Resolves the rating repository from the test seam, falling back to DI.
  /// Returns `null` when neither is available (previews / isolated tests that
  /// do not boot DI) so the caller can degrade to the rating terminal.
  RatingRepository? get _ratingRepository =>
      widget.ratingRepository ??
      (sl.isRegistered<RatingRepository>() ? sl<RatingRepository>() : null);

  /// JEBV4-308: status-aware rating entry. Reads the server-owned reveal state
  /// before navigating so an already-rated delivery shows a read-only summary
  /// instead of the blank re-editable form. If the status is unavailable
  /// (offline / server error / no DI) we degrade to the canonical rating
  /// terminal so the user is never blocked from rating.
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
      // Not yet rated by this user (or status unavailable) → canonical
      // mandatory rating terminal.
      context.push(_mutualRateLocation(context));
      return;
    }
    await _showRatingSummary(context, status);
  }

  /// Canonical blind mutual-rating route for this delivery, role-aware: a
  /// jeeber rates the customer (`?mode=jeeber`), a customer rates the jeeber
  /// (no query). Reads [RoleCubit] defensively (this hub is also mounted from
  /// push deep links / isolated tests where the cubit may be absent).
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

  /// Read-only summary for an already-rated delivery (no re-editable form):
  /// `pendingTheirs` = you submitted, awaiting the counterpart; `bothRated` /
  /// `autoRevealed` = both revealed, showing the counterpart's stars.
  ///
  /// Rendered as a modal bottom sheet (not [OmdsConfirmationDialog], whose
  /// single-action layout puts an `Expanded` inside an `OverflowBar` and throws
  /// a parent-data assertion — that OMDS defect is out of scope for JEBV4-308).
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
      // Unreachable — the caller routes pendingMine to the rating terminal.
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

/// Read-only, non-editable summary of an already-submitted rating (JEBV4-308).
/// Presented instead of the blank rating form when the delivery has already
/// been rated by this user.
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

/// Tone of the terminal-state banner — drives the container/foreground colour
/// roles from the active [ColorScheme].
enum _StatusBannerTone { success, error }

/// A terminal-state banner shown at the top of the delivery-details hub
/// (JEBV4-309). Carries a stable Semantics id + its title text so a Maestro
/// flow can assert the Delivered / Cancelled state.
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

/// Declarative descriptor for one tappable order action.
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

/// A single OMDS settings row wrapped with a QA-targetable Semantics id.
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

/// Destructive cancel action rendered as an outlined primary button to
/// visually separate it from the navigational rows above.
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
