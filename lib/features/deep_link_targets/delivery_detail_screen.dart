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
/// `ChatDetailScreen` reads, JEBV4-282) and re-reads it when a `delivery` push
/// says the status moved. The wire status is classified
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
    this.refreshSignals,
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

  /// The push→refetch bus. A `delivery` push re-reads the status ONCE; there is
  /// no cadence behind it. Defaults to the DI-registered `PushRefreshSignals`
  /// stream at runtime (via [resolvePushRefreshStream]); `null` in a bare widget
  /// test with no DI, which then simply never receives an event.
  ///
  /// This REPLACED a 5s `Timer.periodic`. That timer was the single most
  /// expensive poll in the app: it was completely UNGATED (no lifecycle, no
  /// visibility gate), so it kept firing while the app was backgrounded and,
  /// because this route sits UNDER the order chat in the navigator stack, it kept
  /// firing while the user was in the chat. And [OrderChatSummaryRepository.fetchSummary]
  /// fans ONE tick out into THREE gateway reads — `GET /v1/deliveries/{id}`,
  /// `GET /v1/requests/{id}` and `GET /v1/offers` — so a single 5s timer produced
  /// the three-endpoint 5s storm measured on the customer chat screen.
  final Stream<void>? refreshSignals;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen>
    with ResumeRefetchMixin {
  /// Last-known wire `statusId`. Null/empty ⇒ status not yet resolved or
  /// unavailable ⇒ the hub fails open.
  String? _statusId;
  StreamSubscription<void>? _refreshSub;
  OrderChatSummaryRepository? _summaryRepo;

  @override
  void initState() {
    super.initState();
    _summaryRepo = _resolveSummaryRepository();
    // Every read on this screen is now ONE-SHOT. There are exactly three
    // triggers, none of them a cadence:
    //   1. screen open        — this call
    //   2. a `delivery` push  — the subscription below
    //   3. foreground resume  — onAppResumed (coalesced)
    // If the user does nothing and no push arrives, no second call happens.
    unawaited(_loadStatus());
    // b02 wave D — `{order}`. This hub paints ONE delivery's status. It sits
    // BELOW the chat route in the stack for the whole conversation, so before
    // the topic filter every inbound chat message fired a `fetchSummary` here
    // as well as on the chat screen above it — two of the four
    // `GET /v1/deliveries/{id}` reads measured on a single resume.
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

  /// One catch-up read on return to the foreground. A push that landed while the
  /// process was backgrounded may have been dropped or coalesced by the OS, so a
  /// single read on resume is the backstop. Explicitly allowed by the mandate —
  /// it is caused by the user returning to the app, not by a clock.
  ///
  /// b02 P0 — the trigger is now [AppResumeSignals], not the raw `resumed`
  /// notification: "one catch-up read" was only ever one read per NOTIFICATION,
  /// and the platform is free to deliver twenty of those in two seconds.
  @override
  void onAppResumed() => unawaited(_loadStatus());

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

  /// One status read. On success repaints with the fresh `statusId`. On any
  /// failure the last-known status is kept (the hub never regresses a known
  /// status to fail-open) and the next trigger tries again.
  Future<void> _loadStatus() async {
    final repo = _summaryRepo;
    if (repo == null) return;
    // SINGLE FLIGHT (b02 wave D). Same defect as `ChatDetailScreen`: this
    // screen's own doc comment above promises "exactly three triggers, none of
    // them a cadence", and on a resume TWO of the three (the lifecycle
    // observer, and the push the OS delivered on the way back to the
    // foreground) fire inside one round trip. The reads then race, and the
    // loser can repaint `_statusId` from the older snapshot — a hub that
    // briefly shows a status the delivery has already left.
    //
    // Dropped, not queued: the in-flight read was issued after the event that
    // prompted the second trigger, so it already sees at least as much.
    if (_statusLoadInFlight) return;
    _statusLoadInFlight = true;
    try {
      final summary = await repo.fetchSummary(widget.deliveryId);
      if (!mounted) return;
      if (summary.statusId != _statusId) {
        setState(() => _statusId = summary.statusId);
      }
    } on OrderChatSummaryException {
      // Unavailable — keep last-known status (fail-open while still null).
    } catch (_) {
      // Defensive: never let a status read crash the hub.
    } finally {
      _statusLoadInFlight = false;
    }
  }

  /// Single-flight latch for [_loadStatus]. See the note there.
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/deep_link_targets/delivery_detail_screen_preview_test.dart
// ===========================================================================
//
// [DeliveryDetailScreen] renders ONE thing that varies: the list of actions a
// delivery is currently entitled to. Which list you get is decided entirely by
// the wire `statusId` (JEBV4-309, [_StatusBucket]), so every preview below is
// just a different canned status — there is no other axis.
//
// The fakes are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/delivery_detail_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_03_entries.dart`), so the designer's browser
// and this canvas name the same states with the same data. Both seams the hub
// exposes — `summaryRepository:` and `ratingRepository:` — are supplied on every
// preview, which is what keeps them off GetIt: `_resolveSummaryRepository`
// falls back to a [DioOrderChatSummaryRepository] over the DI `Dio` when the
// seam is null, and `GET /v1/deliveries/{id}` is a GET, so the
// [CatalogNetworkGuard] in [jeebPreviewHost] would not have stopped it. Network
// -free by construction, not by the net.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen needs a `Router` ABOVE it to build at all.** Its body is
//    wrapped in [RootAwareBackScope] → `BackButtonListener`, whose
//    `didChangeDependencies` reads `Router.maybeOf(context)!.backButtonDispatcher`;
//    under the plain `MaterialApp` both the canvas host and the render harness
//    provide, that is null and the screen throws before it paints.
//    [_DeliveryDetailScreenHost] supplies one via `Router.withConfig` over a
//    local [GoRouter].
//  * **Every row navigates, so the canvas is honest to tap in.** All six
//    destinations (`tracking`, `otp`, `cancel`, `receipt`, `escalate`,
//    `mutual-rate`) plus the named `chat-detail` route exist in that local
//    router as stand-ins that name the leg they caught. Without them a tap
//    throws `GoException: no routes for location`, which is a fact about the
//    preview rather than about the screen.
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it — the same nesting
//    the Screen Catalog produces. The frame is therefore pinned in the TREE as
//    well as in `size:`, because an unpinned screen is 800 pt wide in the render
//    tests and none of the layout under review applies there. (The render
//    surface is 800x600, so the phone box's 844 is enforced down to what the
//    host has; the compact 320x568 box fits and is exact.)
//
// What these previews are for — the states that break:
//
//  * **`Status pending` and `Status unavailable` are the SAME picture.** The
//    hub has no loading state and no error state: while `_statusId` is null it
//    fails open to the full legacy list, whether the read is still in flight or
//    came back 500. Both are previewed, adjacently and deliberately, because
//    the identity is the point — there is nothing on that surface that says
//    "we don't know yet", and nothing to retry with.
//  * **`Status pending` is also the FIRST FRAME of every delivery**, including
//    a delivered one: `_loadStatus()` is started in `initState` and the first
//    build runs before it resolves. The class doc's "never reached for a
//    known-Delivered order, so Cancel is never shown on a delivered delivery"
//    holds only once the status is KNOWN — until then Cancel, Verify OTP and
//    Live tracking are all on screen for a delivery that is already done.
//  * **`Expired` renders the CANCELLED banner.** `_bucket` folds every
//    non-delivered terminal into `_StatusBucket.cancelled`, so an expired
//    broadcast, a disputed delivery and a failed one all tell the customer
//    their delivery "was cancelled". Previewed as its own state because the
//    copy is wrong for the status that produced it, and that is invisible from
//    the delivered/cancelled pair alone.
//  * **The pre-pickup / in-transit pair is the free-cancel window** (JEBV4-289)
//    opening and closing. It is one row's worth of difference and the only way
//    to see `DeliveryStatusVocab.isCancelAllowed` move.
//
// Two states are NOT previewable from here and both are worth knowing about.
// The read-only rating summary sheet (JEBV4-308) and the delivered-receipt
// route are reachable only AFTER a tap — the sheet is scripted (the delivered
// preview seeds an already-rated status, so tapping Rate opens it in the canvas
// rather than navigating), the receipt is a stand-in. And the role-aware
// Contact label ("Contact customer" for a Jeeber) cannot be previewed at all:
// it reads [RoleCubit], whose constructor requires a real `SharedPreferences`
// instance, so every preview here shows the client wording the hub degrades to.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryDetailScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports, and roughly what an Android
/// multi-window split leaves a foreground app. Every action row is an icon +
/// label + chevron on ONE line, so this is where a long localized label runs
/// out of room first.
const Size _deliveryDetailScreenCompactBox = Size(320, 568);

/// Every child route this hub can push, as a path leg under `/orders/:id`.
///
/// Kept as data rather than six `GoRoute`s so a row added upstairs without a
/// matching leg here fails loudly in the canvas (a tap that finds no route)
/// instead of quietly doing nothing.
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
  /// the path.
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic route id, not shipped copy, and a latin
          // identifier reorders visually inside an RTL paragraph.
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
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt every frame would drop the navigation state the screen's
/// own `push`/`canPop` calls depend on. `Router.withConfig` is what
/// `MaterialApp.router` does internally, so this adds a Router and nothing else
/// — theme, locale and text scale still come from the preview host above it.
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
          // and in the canvas that is whatever GetIt happens to hold. An empty
          // stream is the honest preview of "no push arrived".
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
      // legs above.
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
///
/// Six affordances at once: Live tracking, Contact, Verify OTP, Rate, Report
/// and Cancel. It is the longest list the hub can produce and the only one that
/// offers Rate and Cancel together, which no real lifecycle state does — a
/// delivery is either still cancellable or already rateable, never both. Read
/// this as the cost of failing open: on a delivery that is already Done, the
/// customer is offered Cancel and Verify OTP until the read lands.
///
/// Matrixed because it is the fullest row stack the screen has: six OMDS rows
/// of icon + label + chevron, mirrored in AR, at the 200% ceiling.
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
///
/// That identity is why both are previewed. There is no error copy, no retry
/// and no "status unavailable" note anywhere on the hub: `_loadStatus` swallows
/// [OrderChatSummaryException] and leaves `_statusId` null, which is the same
/// input the in-flight state produces. A customer whose delivery has been
/// cancelled for an hour still sees Live tracking and Verify OTP here, with
/// nothing to tell them the screen is guessing.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Status unavailable · fails open',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenStatusUnavailable() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.statusUnavailable);

/// ACTIVE, pre-pickup (`Ordered`): the free-cancel window (JEBV4-289) is open.
///
/// Live tracking + Contact + Verify OTP + Report, and the outlined Cancel
/// button below them. No Rate row — rating is a delivered-class affordance —
/// and no banner.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Active · pre-pickup (cancel open)',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenActivePrePickup() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.ordered);

/// ACTIVE, parcel in hand (`InTransit`): the same bucket with the Cancel button
/// withdrawn.
///
/// Read next to the pre-pickup preview — one row of difference, and it is the
/// only rendering of `DeliveryStatusVocab.isCancelAllowed` returning false on a
/// non-terminal delivery. Note what does NOT change: the list gives no reason
/// for the withdrawal, so a customer who saw Cancel five minutes ago finds it
/// simply gone.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Active · in transit (cancel closed)',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenActiveInTransit() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.inTransit);

/// DELIVERED (`Done`): the success banner, then Contact + Rate + Receipt +
/// Report. Cancel, Verify OTP and Live tracking are structurally absent — this
/// bucket does not build them, which is what makes "Cancel on a delivered
/// order" unreachable once the status is known.
///
/// Seeded with an ALREADY-RATED reveal state, so tapping Rate in the canvas
/// opens the read-only summary sheet (JEBV4-308) in place instead of pushing
/// the mutual-rating terminal. Swap to `notYetRated` to review the routing leg.
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
///
/// The shortest surface the hub can render — two children — which is the state
/// to look at for a screen that reads as empty rather than as final.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Cancelled · banner + Report only',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenCancelled() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.cancelled);

/// `Expired` — a broadcast nobody accepted — rendered as **"Cancelled"**.
///
/// `_bucket` sends every non-delivered terminal (`expired`, `disputed`,
/// `failedneedsescalation`, `rated`) down the same branch, and that branch
/// hardcodes the cancelled banner. The customer is told their delivery "was
/// cancelled" for three lifecycle outcomes that are not a cancellation, one of
/// which (`disputed`) has an open case attached. Previewed as its own state
/// because it is indistinguishable from a real cancellation on screen, which is
/// exactly the problem.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Expired → Cancelled banner',
  size: _deliveryDetailScreenPhoneBox,
)
Widget deliveryDetailScreenExpiredTerminal() =>
    _deliveryDetailScreenHosted(DeliveryDetailScreenFixtures.expired);

/// The delivered hub at the 320x568 floor.
///
/// The banner is the piece that runs out of room first: `Icon + Expanded(title
/// + body)` inside a container that already spends `Spacing.medium` on padding
/// twice over, so the body ("This delivery is complete.") is the longest run of
/// text the screen has to wrap. Matrixed because AR changes both strings'
/// lengths and the 200% rendering is where the banner starts pushing the rows
/// below it off the first screenful.
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
