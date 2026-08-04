import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/lifecycle/app_resume_signals.dart';
import '../../core/delivery/delivery_status_vocab.dart';
import '../../core/di/injection_container.dart';
import '../../core/formatting/friendly_reference.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../core/router/app_router.dart';
import '../../core/router/root_aware_back_scope.dart';
import '../../core/theme/jeeb_color_roles.dart';
import '../../core/theme/jeeb_semantic_colors.dart';
import '../../core/theme/jeeb_shadows.dart';
import '../../core/theme/jeeb_text_styles.dart';
import '../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../chat/data/dio_order_chat_summary_repository.dart';
import '../chat/domain/order_chat_summary.dart';
import '../rating/domain/entities/rating_status.dart';
import '../rating/domain/rating_repository.dart';

/// Board gutter for the hub body: 24px sides (§4 layout rule), 16 below the
/// top bar, and a 32 bottom so the last block clears the gesture bar.
const EdgeInsetsGeometry _kBandPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.twoXLarge,
);

/// Vertical rhythm between two blocks (§4 layout rule: ~28px).
const double _kBlockGap = 28;

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
  /// Last-known summary. The screen already paid for the whole record to read
  /// one field; MIDNIGHT renders the rest of it (ref, stage, price, jeeber).
  OrderChatSummary? _summary;

  /// True once ONE read attempt has finished, success or failure. Separates
  /// "still loading" from the fail-open "unavailable" the buckets share.
  bool _statusSettled = false;
  StreamSubscription<void>? _refreshSub;
  OrderChatSummaryRepository? _summaryRepo;

  /// Last-known wire `statusId`. Null/empty ⇒ status not yet resolved or
  /// unavailable ⇒ the hub fails open.
  String? get _statusId => _summary?.statusId;

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
    OrderChatSummary? next;
    try {
      next = await repo.fetchSummary(widget.deliveryId);
    } on OrderChatSummaryException {
      // Unavailable — keep last-known status (fail-open while still null).
    } catch (_) {
      // Defensive: never let a status read crash the hub.
    } finally {
      _statusLoadInFlight = false;
    }
    if (!mounted) return;
    final bool changed = next != null && next != _summary;
    if (!_statusSettled || changed) {
      setState(() {
        _statusSettled = true;
        if (next != null) _summary = next;
      });
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
          // §8: the flat scaffold colour is a fallback only — the field paints.
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          // R21's field: base wash + one quiet orange glow top-end, the
          // periwinkle wash top-start, no rings/twinkles, zero motion.
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.topEnd,
            washPlacement: JeebFieldWashPlacement.topStart,
            animateDecor: false,
            // Redesign: an in-body [JeebTopBar], not a Material app bar — the
            // house header shape shared with the two screens this hub sits
            // between (24 Order history, 12 Live tracking).
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JeebTopBar.back(
                    identifier: 'order_detail_back',
                    title: l10n.deliveryDetailsTitle,
                    // R3/R21 both carry a second fact in the header band; here
                    // it is the request `displayId`, absent until the read lands.
                    subtitle: _orderRef,
                    // Same root-awareness the surrounding [RootAwareBackScope]
                    // gives the system gesture: `maybePop` alone would be a dead
                    // circle when the hub IS the stack root (push / deep link).
                    onLeadingPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  Expanded(
                    child: ListView(
                      key: const Key('delivery-detail-list'),
                      padding: _kBandPadding,
                      children: _buildChildren(context, l10n),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Human order reference for the header band. Empty/absent renders nothing —
  /// TODO(midnight): omitted, not faked (the wire only carries it post-accept).
  String? get _orderRef {
    final String ref = _summary?.orderRef.trim() ?? '';
    return ref.isEmpty ? null : ref;
  }

  List<Widget> _buildChildren(BuildContext context, AppLocalizations l10n) {
    // Cold read: the kit skeleton, not a guessed action list. A host with NO
    // status source never enters this branch, so fail-open is untouched.
    if (_summaryRepo != null && !_statusSettled) {
      return [
        JeebEmptyState(
          key: const Key('order-detail-loading'),
          identifier: 'order_detail_loading',
          status: JeebEmptyStateStatus.loading,
          variant: JeebEmptyStateVariant.parcel,
          headline: l10n.deliveryDetailsTitle,
        ),
      ];
    }
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
      JeebOutlinedCard.grouped(
        children: [
          _ActionRow(action: _trackAction(l10n)),
          _ActionRow(action: _chatAction(context, l10n)),
          _ActionRow(action: _otpAction(l10n)),
          _ActionRow(action: _rateAction(l10n)),
          _ActionRow(action: _escalateAction(l10n)),
        ],
      ),
      _CancelFooter(deliveryId: widget.deliveryId),
    ];
  }

  /// In-progress: tracking / contact / OTP / report stay; Cancel only while the
  /// pre-pickup / on-hold free-cancel window is open (JEBV4-289). Rate is a
  /// delivered-class-only affordance, so it is not shown here.
  List<Widget> _activeChildren(BuildContext context, AppLocalizations l10n) {
    final OrderChatSummary? summary = _summary;
    return [
      // R21's in-motion row: the one orange element this surface earns. The
      // terminal buckets already state themselves; active had no band at all.
      if (summary != null) ...[
        _ActiveStatusBand(summary: summary),
        const SizedBox(height: _kBlockGap),
      ],
      JeebOutlinedCard.grouped(
        children: [
          _ActionRow(action: _trackAction(l10n)),
          _ActionRow(action: _chatAction(context, l10n)),
          _ActionRow(action: _otpAction(l10n)),
          _ActionRow(action: _escalateAction(l10n)),
        ],
      ),
      if (DeliveryStatusVocab.isCancelAllowed(_statusId))
        _CancelFooter(deliveryId: widget.deliveryId),
    ];
  }

  /// Delivered terminal: Delivered banner + Contact + Rate + Receipt + Report.
  /// No Cancel / Verify OTP / Live tracking.
  List<Widget> _deliveredChildren(BuildContext context, AppLocalizations l10n) {
    return [
      _StatusBanner(
        semanticsId: 'order-detail-status-delivered',
        icon: Icons.check_circle,
        title: l10n.deliveryDetailDeliveredBanner,
        body: l10n.deliveryDetailDeliveredBannerBody,
        tone: JeebInfoNoteTone.success,
      ),
      const SizedBox(height: _kBlockGap),
      JeebOutlinedCard.grouped(
        children: [
          _ActionRow(action: _chatAction(context, l10n)),
          _ActionRow(action: _rateAction(l10n)),
          _ActionRow(action: _receiptAction(l10n)),
          _ActionRow(action: _escalateAction(l10n)),
        ],
      ),
    ];
  }

  /// Cancelled (or any non-delivered terminal): Cancelled banner + Report only.
  List<Widget> _cancelledChildren(BuildContext context, AppLocalizations l10n) {
    return [
      _StatusBanner(
        semanticsId: 'order-detail-status-cancelled',
        icon: Icons.cancel,
        title: l10n.deliveryDetailCancelledBanner,
        body: l10n.deliveryDetailCancelledBannerBody,
        tone: JeebInfoNoteTone.error,
      ),
      const SizedBox(height: _kBlockGap),
      JeebOutlinedCard.grouped(
        children: [
          _ActionRow(action: _escalateAction(l10n)),
        ],
      ),
    ];
  }

  // ---- Individual action descriptors ---------------------------------------

  _DeliveryAction _trackAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-track',
        title: l10n.trackingTitle,
        leadingIcon: Icons.location_on,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/tracking'),
      );

  _DeliveryAction _chatAction(BuildContext context, AppLocalizations l10n) =>
      _DeliveryAction(
        semanticsId: 'order-detail-chat',
        title: _contactLabel(context, l10n),
        leadingIcon: Icons.chat_bubble,
        onTap: (c) => c.pushNamed(
          'chat-detail',
          pathParameters: {'id': widget.deliveryId},
        ),
      );

  _DeliveryAction _otpAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-otp',
        title: l10n.otpVerifyButton,
        leadingIcon: Icons.lock,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/otp'),
      );

  _DeliveryAction _rateAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-rate',
        title: l10n.ratingPromptTitle,
        leadingIcon: Icons.star,
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
        leadingIcon: Icons.receipt_long,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/receipt'),
      );

  _DeliveryAction _escalateAction(AppLocalizations l10n) => _DeliveryAction(
        semanticsId: 'order-detail-escalate',
        title: l10n.escalateTitle,
        leadingIcon: Icons.report_problem,
        onTap: (c) => c.push('/orders/${widget.deliveryId}/escalate'),
      );

  /// Role-aware Contact label (run-22 chat-cluster fix): the row names the
  /// COUNTERPART — a customer contacts their Jeeber, a Jeeber contacts the
  /// customer. Reads the app-global [RoleCubit] defensively (this hub is also
  /// mounted from push deep links / isolated tests where the cubit may be
  /// absent) and degrades to the customer wording.
  String _contactLabel(BuildContext context, AppLocalizations l10n) {
    return _viewerIsJeeber(context)
        ? l10n.deliveryActionContactCustomer
        : l10n.deliveryActionContact;
  }

  /// Reads [RoleCubit] defensively — this hub is also mounted from push deep
  /// links / isolated tests where the cubit may be absent.
  bool _viewerIsJeeber(BuildContext context) {
    try {
      return context.read<RoleCubit>().state == UserRole.jeeber;
    } on ProviderNotFoundException {
      return false;
    }
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

  /// Canonical mutual-rating route via [mutualRatingLocation]. The name is only
  /// honest on the CLIENT leg — TODO(midnight): omitted, not faked, for jeebers.
  String _mutualRateLocation(BuildContext context) {
    final bool isClient = !_viewerIsJeeber(context);
    return mutualRatingLocation(
      widget.deliveryId,
      isClient: isClient,
      counterpartName:
          isClient ? displayNameOrNull(_summary?.jeeberName) : null,
    );
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

  /// Star ink. §3 ratifies `amber` as the stars/ratings token; `primary` is
  /// ORANGE on Midnight, which spent the §2.2 budget on a read-only summary.
  static Color starInk(BuildContext context) =>
      (Theme.of(context).extension<JeebSemanticColors>() ??
              JeebSemanticColors.midnight())
          .amber;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'delivery-rating-summary',
      container: true,
      // Navy base + one top glow: the sheet rung, the same field R21's own
      // date-filter sheet mounts.
      child: JeebMidnightField(
        variant: JeebFieldVariant.sheet,
        animateDecor: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.xSmall,
              Spacing.xLarge,
              Spacing.large,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: Sizes.threeXLarge,
                  color: starInk(context),
                ),
                const SizedBox(height: Spacing.medium),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.jeebText.h2.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: Spacing.xSmall),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: context.jeebText.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: _kBlockGap),
                JeebCtaButton(
                  key: const Key('delivery-rating-summary-done'),
                  identifier: 'delivery-rating-summary-done',
                  label: doneLabel,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A terminal-state banner shown at the top of the delivery-details hub
/// (JEBV4-309). Carries a stable Semantics id + its title text so a Maestro
/// flow can assert the Delivered / Cancelled state.
///
/// Redesign: a kit [JeebInfoNote] in its stacked form. The success/error tones
/// keep their role colours on every surface — the state IS the message — so no
/// container/foreground pair is computed here any more.
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
  final JeebInfoNoteTone tone;

  @override
  Widget build(BuildContext context) {
    return JeebInfoNote(
      key: Key(semanticsId),
      identifier: semanticsId,
      tone: tone,
      icon: icon,
      title: title,
      text: body,
    );
  }
}

/// R21's in-motion row for the ONE order this hub details: accent frame over an
/// orange-12% fill, glowing Ø9 dot, price at the end. An absent fact draws none.
class _ActiveStatusBand extends StatelessWidget {
  const _ActiveStatusBand({required this.summary});

  /// Ø18 in the board is the glyph box; the live dot itself is Ø9 (R21).
  static const double liveDotSize = 9;

  /// The Ø3 meta separator — a shape, so no l10n key and no bidi hazard.
  static const double metaDotSize = 3;

  /// R21's row padding (`24-order-history.html` tpl 1427).
  static const EdgeInsetsGeometry bandPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
    vertical: 14,
  );

  final OrderChatSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? name = displayNameOrNull(summary.jeeberName);
    final int? eta = summary.etaMinutes;
    final String stage = _stageLabel(summary.statusId, l10n);
    // R21's identity title is the ITEM, not the state; the state belongs to the
    // meta run. Without a description the stage is promoted and not repeated.
    final bool titleIsItem = summary.hasDescription;
    // R21: the status run reads #FFB499 on the lit fill; the lit row carries no
    // periwinkle at all, so everything else steps up to inkSoft (#B9C0F0).
    final Color metaInk = scheme.onSecondaryContainer;
    final Color statusInk = context.jeebRoles.onAccentContainer;
    final List<Widget> meta = <Widget>[
      if (titleIsItem) _MetaText(text: stage, ink: statusInk),
      if (titleIsItem && eta != null) _MetaDot(ink: statusInk),
      if (eta != null)
        _MetaText(text: l10n.deliveryDetailEtaMinutes(eta), ink: statusInk),
      if (name != null && (titleIsItem || eta != null)) _MetaDot(ink: metaInk),
      if (name != null) _MetaText(text: name, ink: metaInk),
    ];

    return JeebAccentFrameCard(
      key: const Key('order-detail-status-active'),
      identifier: 'order-detail-status-active',
      fill: JeebAccentFrameFill.accentTint,
      padding: bandPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                key: const Key('order-detail-live-dot'),
                width: liveDotSize,
                height: liveDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.jeebRoles.accent,
                  boxShadow: JeebShadows.glowDot,
                ),
              ),
              const SizedBox(width: Spacing.xSmall),
              Expanded(
                child: Text(
                  titleIsItem ? summary.description.trim() : stage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.jeebText.cardTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (summary.hasPrice) ...<Widget>[
                const SizedBox(width: Spacing.xSmall),
                Text(
                  summary.priceLabel,
                  maxLines: 1,
                  // `body` w800, not `cardTitle`: R21 keeps the amount a weight
                  // heavier and a size smaller so 2× text does not overflow.
                  style: context.jeebText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
          if (meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.small),
            Row(children: meta),
          ],
        ],
      ),
    );
  }

  /// Canonical stage label for a wire status, tolerating the same spellings the
  /// tracking surfaces accept. Unknown reads as the matched floor.
  static String _stageLabel(String statusId, AppLocalizations l10n) {
    switch (statusId.trim().toLowerCase()) {
      // R3's stepper vocabulary: the pre-accept spellings are "Ordered", not
      // "Matched" — DeliveryStatusVocab._prePickup holds both classes.
      case 'ordered':
      case 'placed':
      case 'created':
      case 'new':
      case 'pending':
      case 'requested':
        return l10n.trackingStepOrdered;
      case 'picked':
      case 'picked_up':
      case 'pickedup':
      case 'at_pickup':
        return l10n.deliveryStagePickedUp;
      case 'intransit':
      case 'in_transit':
      case 'in transit':
      case 'atdoor':
      case 'at_door':
      case 'at door':
      case 'en_route':
        return l10n.deliveryStageInTransit;
      default:
        return l10n.deliveryStageMatched;
    }
  }
}

/// One ellipsizing run in the band's meta row.
class _MetaText extends StatelessWidget {
  const _MetaText({required this.text, required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.jeebText.bodySmall.copyWith(color: ink),
      ),
    );
  }
}

/// The Ø3 meta separator with its own breathing room on both sides (R21).
class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.twoXSmall,
      ),
      child: Container(
        width: _ActiveStatusBand.metaDotSize,
        height: _ActiveStatusBand.metaDotSize,
        decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
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

/// A single kit row inside the hub's grouped card. [JeebListRow] owns the
/// Semantics node itself, so there is no outer wrapper to double the button.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _DeliveryAction action;

  @override
  Widget build(BuildContext context) {
    return JeebListRow(
      key: Key(action.semanticsId),
      identifier: action.semanticsId,
      title: action.title,
      icon: action.leadingIcon,
      onTap: () => action.onTap(context),
    );
  }
}

/// Destructive cancel action rendered as an outline pill below the grouped
/// rows — the board's secondary-action shape (12's "Open dispute"), and still
/// visually separate from the navigational rows above.
class _CancelFooter extends StatelessWidget {
  const _CancelFooter({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebCtaFooter.single(
      // The footer sits INSIDE the already-gutted list, so it keeps only its
      // top rhythm — the 24 gutter would otherwise double.
      padding: const EdgeInsetsDirectional.only(top: _kBlockGap),
      child: JeebCtaButton.outline(
        key: const Key('order-detail-cancel'),
        identifier: 'order-detail-cancel',
        label: l10n.deliveryActionCancel,
        onTap: () => context.push('/orders/$deliveryId/cancel'),
      ),
    );
  }
}
