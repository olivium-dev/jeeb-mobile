import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/motion/jeeb_motion_primitives.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../core/motion/jeeb_motion_tokens.dart';
import '../../../core/widgets/jeeb/jeeb_chat_bubble.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/chat_connection_state.dart';
import '../application/chat_cubit.dart';
import '../application/chat_state.dart';
import '../data/in_memory_chat_gateway.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';
import '../domain/connection_status.dart';
import '../domain/delivery_chat_message.dart';
import '../domain/order_chat_summary.dart';
import 'chat_connection_banner.dart';
import 'widgets/broadcast_ttl_indicator.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_date_separator.dart';
import 'widgets/chat_fee_banner.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_offer_only_one_footer.dart';
import 'widgets/chat_quick_reply_bar.dart';
import 'widgets/jeeber_removed_banner.dart';
import 'widgets/offer_accepted_banner.dart';
import 'widgets/offer_card_bubble.dart';
import 'widgets/order_chat_pinned_summary.dart';

/// The share of the chat viewport the header chrome (fee banner + pinned
/// summary + accepted/removed banners + TTL indicator) may occupy.
///
/// This is the structural guarantee behind the "BOTTOM OVERFLOWED BY 16 PIXELS"
/// fix: whatever the chrome contains, the message list keeps at least
/// `1 - kChatHeaderMaxViewportFraction` of the available height, so the
/// surrounding `Column`'s `Expanded` child can never be allocated zero. 0.4 was
/// chosen because the collapsed header (56 dp) + the compact accepted banner
/// (64 dp) come to ~120 dp, which is ~29% of the ~410 dp that remains on a
/// 411×914 dp phone once the app bar, the composer and an open keyboard are
/// subtracted — i.e. the ordinary case sits comfortably inside the bound and
/// never touches it.
const double kChatHeaderMaxViewportFraction = 0.4;

/// Vertical room reserved for the composer plus a minimum message list, taken
/// off the header's budget before the fraction is applied — at a text scale of
/// 1.0, and scaled with the user's text scale because the composer grows with
/// it.
///
/// The composer is non-flexible too, so on a very short viewport (a 320x400 dp
/// phone with a 200 dp keyboard — measured) 40% of the height for the header
/// still left the Column 1.6 px over budget once the composer took its own
/// intrinsic height, and 62 px over at a 2.0 text scale.
///
/// The header's allowance is therefore
/// `clamp(min(height * fraction, height - reserve), 0, ...)`. On a 320x480 dp
/// phone at a 2.0 text scale with the keyboard open the allowance reaches zero
/// and the header yields its space entirely. That is the correct priority when
/// there is genuinely no room — being able to read the thread and send a
/// message outranks the order summary, and the header returns in full the
/// moment the keyboard closes.
const double kChatComposerReserve = 120;

/// Minimum height the bounded header slot keeps while it holds the
/// Start-delivery CTA — the Jeeber's primary action during a LIVE delivery.
///
/// Without a floor, [kChatComposerReserve] drives the slot's allowance to 0 dp
/// on a 320x480 dp phone with the keyboard up at a 2.0 text scale. A
/// ZERO-HEIGHT VIEWPORT CANNOT SCROLL, so the CTA became unreachable while
/// remaining present in the widget tree — which is exactly why a
/// `findsOneWidget` assertion missed it and the suite asserted a 0 dp header as
/// correct. Expansion persists for the session, so one expand hid the CTA on
/// every subsequent keyboard open.
///
/// Hoisting the CTA OUT of the slot is not the answer either: it then becomes
/// non-flexible chrome and re-creates the original overflow (measured 54 px at
/// 411x914 and 88 px at 320x480 + 2.0). At that smallest size the CTA and the
/// composer genuinely cannot both fit — no placement makes them.
///
/// So the CTA stays inside the slot and the slot gets this floor, capped at a
/// third of the viewport so the thread and composer keep priority. Degradation
/// becomes a SCROLL, which is reachable, instead of a clip, which is not.
const double kChatPinnedCtaReserve = 96;

/// Vertical room the quick-reply row adds to the non-flexible chrome when it is
/// visible.
///
/// It is folded into the composer reserve rather than left to the `Expanded`
/// body, because the row is a non-flexible `Column` child exactly like the
/// composer: without it the bounded header slot (see [kChatComposerReserve])
/// would keep budgeting for a composer alone and the message list could be
/// starved by the difference.
const double kChatQuickReplyReserve = 48;

/// Key on the bounded header slot's scrollable, so a test can assert the
/// ordinary case does NOT scroll (a bound that is always engaged would be
/// hiding content rather than budgeting it).
const Key chatHeaderSlotKey = Key('chat-screen-header-slot');

/// Key on the bounded BOTTOM slot's scrollable (quick replies + composer), the
/// twin of [chatHeaderSlotKey]. Same assertion available: the ordinary case
/// must not scroll.
const Key chatComposerSlotKey = Key('chat-screen-composer-slot');

/// Jeeber-only balance-deduction notice configuration for [ChatScreen].
///
/// When supplied, [ChatScreen] renders a [ChatFeeBanner] between the app bar
/// and the message list. The [amount] is a pre-formatted currency string from
/// the gateway fee config — the UI never computes it. Absent (null) on the
/// client variant of the thread.
class ChatFeeNotice {
  const ChatFeeNotice({
    required this.amount,
    this.trailing = ChatFeeBannerTrailing.dismiss,
    this.onDismiss,
    this.onOrderPicked,
  });

  final String amount;
  final ChatFeeBannerTrailing trailing;
  final VoidCallback? onDismiss;
  final VoidCallback? onOrderPicked;
}

/// WhatsApp-style 1:1 chat between the client and the Jeeber for an active
/// delivery (T-mobile-016 / JEEB-69).
///
/// The screen owns a [ChatCubit], wires it to a [ChatGateway] (the MVP
/// in-memory implementation by default) and a [PhotoPickerService], and
/// auto-scrolls to the latest message whenever the cubit emits.
///
/// MB1 W4.1 — the picker sentence used to read *"the stub picker until
/// image_picker lands in a later mobile task"*. That has been false since
/// JEBV4-111: the DI graph registers the REAL `ImagePickerPhotoPickerService`
/// (`injection_container.dart:471-472`), [_resolvePicker] reads DI FIRST, and
/// `ChatCubit.sendPhotoFromGallery` (`chat_cubit.dart:772`) drives it. The
/// stub is the fallback for tests and unregistered graphs only. Left standing,
/// the comment reads as an open TODO for work that is already shipped — which
/// is how MB1 came to carry a 20-minute "gallery pick" item for a feature that
/// needed no code at all.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.deliveryId,
    required this.counterpartName,
    this.counterpartAvatarUrl,
    this.counterpartAvatarImage,
    this.feeNotice,
    this.composerHint,
    this.onStartActiveDelivery,
    this.onTrackOrder,
    this.cubit,
    this.gateway,
    this.pickerService,
    this.pinnedSummary,
    this.pinnedSummaryFallback,
    this.onViewSummary,
    this.onSummaryAttentionRefresh,
    this.onOpenDispute,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
    this.onFirstMessageBroadcast,
    this.initialTrackingDeliveryId,
    this.outbox,
    this.currentUserId = '',
  }) : assert(
         cubit == null || (gateway == null && pickerService == null),
         'Provide either a cubit or the (gateway, pickerService) pair, not both.',
       );

  /// Backing delivery this chat thread belongs to. Used as the gateway
  /// channel id and as the prefix for outgoing message ids.
  final String deliveryId;

  /// Display name in the app bar — the Jeeber's name on the client side, the
  /// client's name on the Jeeber side.
  final String counterpartName;

  /// Optional counterpart avatar (CDN url). Shown in the post-approval header.
  final String? counterpartAvatarUrl;

  /// Optional pre-resolved avatar image (e.g. a bundled [AssetImage] in the
  /// dev capture seam). Takes precedence over [counterpartAvatarUrl].
  final ImageProvider? counterpartAvatarImage;

  /// Jeeber-only fee notice rendered above the thread. Null hides the banner
  /// (client variant). See [ChatFeeNotice].
  final ChatFeeNotice? feeNotice;

  /// Composer hint override. The Jeeber variant passes the localized
  /// "Price / time" hint; null falls back to the board's "Message…".
  final String? composerHint;

  /// Jeeber-only entry point into the active-delivery screen. When non-null,
  /// the [OfferAcceptedBanner] renders a "Start delivery" CTA once the offer
  /// is accepted. Null on the client variant (the client never starts a
  /// delivery), so the CTA is hidden there. Wired by the host that builds the
  /// Jeeber's chat, where the delivery id is in scope.
  final VoidCallback? onStartActiveDelivery;

  /// Client-only entry point into live tracking, invoked with the
  /// server-created delivery id captured from the accept response. When
  /// non-null AND an accept surfaced a delivery id, the [OfferAcceptedBanner]
  /// renders a "Track order" CTA that routes to
  /// `/orders/<deliveryId>/tracking`. Null on the Jeeber variant. Hidden until
  /// a delivery id is available, so it is never a dead end (G5 fix).
  final void Function(String deliveryId)? onTrackOrder;

  /// Pre-built cubit for widget tests / hosts that own the lifecycle.
  final ChatCubit? cubit;

  /// Optional gateway + picker overrides when [cubit] is not supplied.
  final ChatGateway? gateway;
  final PhotoPickerService? pickerService;

  /// JM-025 AC2 (D71/D11): the locked order summary for the pinned strip. When
  /// non-null AND the conversation is accepted/active, [OrderChatPinnedSummary]
  /// renders above the message list with `order_chat_pinned_summary` +
  /// `order_chat_view_summary_link`. Null on the broadcasting/compose state and
  /// on the Jeeber variant (no client-side pinned summary there).
  final OrderChatSummary? pinnedSummary;

  /// F44: what the header slot renders INSTEAD when [pinnedSummary] is null
  /// because its read failed — never a silently vanished strip.
  final Widget? pinnedSummaryFallback;

  /// JM-025 AC2: tap handler for the pinned strip's view-summary link →
  /// `order-summary-pinned` (JM-031). Required for the link to render.
  final VoidCallback? onViewSummary;

  /// Fired when the customer EXPANDS the pinned summary — an explicit,
  /// user-caused request to look at this data. The host answers it with one
  /// catch-up read of the delivery row. See [OrderChatPinnedSummary].
  final VoidCallback? onSummaryAttentionRefresh;

  /// JM-025 AC3: tap handler for the dispute affordance → `dispute-open-evidence`
  /// (JM-060). When non-null AND the order is accepted/active, the app bar
  /// shows `order_chat_open_dispute`. Null hides it (e.g. broadcasting/closed).
  final VoidCallback? onOpenDispute;

  /// JM-025: marks this thread as the customer order-chat surface. Flips the
  /// composer's Semantics ids to `order_chat_composer_input` /
  /// `order_chat_composer_send` (63_W1_TEST_PLAN §2.5) so the W1 flow drives
  /// them. Defaults false → the legacy `chat_detail_*` ids (jeeber/active chat).
  final bool isOrderChat;

  /// Whether the VIEWER of this thread is the Jeeber (run-22 chat-cluster fix).
  /// Drives the role-aware party naming on the pinned order-summary strip:
  /// the customer sees the winning Jeeber's name, the Jeeber sees the
  /// customer's. Defaults false (customer viewer).
  final bool viewerIsJeeber;

  /// JM-025 AC1 (D83): compose-state hook. When non-null, the FIRST message the
  /// client sends broadcasts the request and the host routes to
  /// `waiting-no-coverage` (JM-026). Invoked exactly once, after the first
  /// successful send, with the request/conversation id to broadcast. Null on
  /// the accepted/active thread (no compose entry).
  /// Invoked with the request/conversation id to broadcast AND the text of the
  /// composed first message (used as the created request's description when no
  /// real request exists yet — JM-024 → JM-025). Returns `true` when the host
  /// resolved a real request and routed onward; `false` lets the composer
  /// re-arm so the user can retry (e.g. a failed create).
  final Future<bool> Function(String requestId, String firstMessage)?
  onFirstMessageBroadcast;

  /// Server-created delivery id known to the host BEFORE the chat loads — set
  /// when the client accepted the offer from the review-list sheet and was
  /// routed here with the accept response's `deliveryId`. Seeds the cubit's
  /// tracking id so the client "Track order" CTA is reachable on an
  /// already-accepted order (the in-chat accept path captures it from the
  /// accept response instead). Null on the broadcasting/compose entry and the
  /// Jeeber variant. Ignored when an explicit [cubit] is supplied (tests own
  /// the lifecycle).
  final String? initialTrackingDeliveryId;

  /// OFF-04 seam. Null falls back to the DI-registered [ChatOutbox]; when
  /// neither resolves the cubit keeps the pre-outbox in-memory behaviour.
  final ChatOutbox? outbox;

  /// Sender id stamped on outbox rows, resolved by the host from the session.
  final String currentUserId;

  static const Key rootKey = Key('chat-screen-root');
  static const Key messageListKey = Key('chat-screen-message-list');
  static const Key emptyStateKey = Key('chat-screen-empty');

  /// b02: the history-load FAILURE body (error copy + retry). Distinct from
  /// [emptyStateKey] on purpose — a test that cannot tell the two apart is the
  /// reason a 500 shipped looking like an empty thread.
  static const Key historyErrorKey = Key('chat-screen-history-error');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<ChatCubit>.value(
        value: provided,
        child: _ChatScaffold(
          deliveryId: deliveryId,
          counterpartName: counterpartName,
          counterpartAvatarUrl: counterpartAvatarUrl,
          counterpartAvatarImage: counterpartAvatarImage,
          feeNotice: feeNotice,
          composerHint: composerHint,
          onStartActiveDelivery: onStartActiveDelivery,
          onTrackOrder: onTrackOrder,
          pinnedSummary: pinnedSummary,
          pinnedSummaryFallback: pinnedSummaryFallback,
          onViewSummary: onViewSummary,
          onSummaryAttentionRefresh: onSummaryAttentionRefresh,
          onOpenDispute: onOpenDispute,
          isOrderChat: isOrderChat,
          viewerIsJeeber: viewerIsJeeber,
          onFirstMessageBroadcast: onFirstMessageBroadcast,
        ),
      );
    }
    return BlocProvider<ChatCubit>(
      create: (_) => ChatCubit(
        deliveryId: deliveryId,
        gateway: gateway ?? InMemoryChatGateway(),
        pickerService: pickerService ?? _resolvePicker(),
        initialDeliveryId: initialTrackingDeliveryId,
        // OFF-04: the durable send queue. Null keeps the pre-outbox behaviour.
        outbox: outbox ?? _resolveOutbox(),
        currentUserId: currentUserId,
        // b02 polling→push: a chat push re-pulls THIS conversation. Resolved
        // through the ONE existing helper (`resolvePushRefreshStream`), which
        // returns null under a bare widget test so the cubit simply never
        // re-pulls — the same degradation `dashboard_tab` and
        // `request_feed_screen` already rely on.
        //
        // b02 wave D — `{chat}`. The 60s `kChatHistorySafetyNetPollInterval`
        // history poll IS deleted now (N4); this claim was written by #187,
        // whose own subject line said "polls RETAINED", and was false for two
        // days (I-16). It is true as of this branch: the inbound re-pull
        // triggers are this bus, the mount `..load()` below, the resume
        // refetch in `_ChatScaffoldState.onAppResumed`, and the error-state
        // retry inside the cubit. No clock.
        // Narrowing to `chat` matters in BOTH directions here.
        // Outbound, it stops one inbound message from waking five other
        // surfaces. Inbound, it stops every unrelated `delivery` / `offer` /
        // `new_request` push on this device from firing a redundant
        // `GET /v1/conversations/{id}/messages` on the open thread.
        refreshSignals: resolvePushRefreshStream(
          topics: const {RefreshTopic.chat},
        ),
      )..load(),
      child: _ChatScaffold(
        deliveryId: deliveryId,
        counterpartName: counterpartName,
        counterpartAvatarUrl: counterpartAvatarUrl,
        counterpartAvatarImage: counterpartAvatarImage,
        feeNotice: feeNotice,
        composerHint: composerHint,
        onStartActiveDelivery: onStartActiveDelivery,
        onTrackOrder: onTrackOrder,
        pinnedSummary: pinnedSummary,
        pinnedSummaryFallback: pinnedSummaryFallback,
        onViewSummary: onViewSummary,
        onSummaryAttentionRefresh: onSummaryAttentionRefresh,
        onOpenDispute: onOpenDispute,
        isOrderChat: isOrderChat,
        viewerIsJeeber: viewerIsJeeber,
        onFirstMessageBroadcast: onFirstMessageBroadcast,
      ),
    );
  }

  /// P4/P5 — DI-FIRST picker. The bare `StubPhotoPickerService()` default was
  /// the second half of the camera/gallery bug: a host that omitted
  /// [pickerService] silently got SYNTHETIC bytes instead of the real camera /
  /// gallery, so tapping "+ → Camera" never opened the OS camera. The stub
  /// remains the fallback for widget tests and the dev catalog, where `sl` is
  /// not populated. Same shape as `KycWizardScreen._resolvePicker`.
  PhotoPickerService _resolvePicker() {
    if (sl.isRegistered<PhotoPickerService>()) return sl<PhotoPickerService>();
    return StubPhotoPickerService();
  }

  /// R2 DI seam for the OFF-04 outbox: registered by `registerChatDependencies`
  /// in Stage 2, absent under widget tests and the dev catalog.
  ChatOutbox? _resolveOutbox() =>
      sl.isRegistered<ChatOutbox>() ? sl<ChatOutbox>() : null;
}

class _ChatScaffold extends StatefulWidget {
  const _ChatScaffold({
    required this.deliveryId,
    required this.counterpartName,
    this.counterpartAvatarUrl,
    this.counterpartAvatarImage,
    this.feeNotice,
    this.composerHint,
    this.onStartActiveDelivery,
    this.onTrackOrder,
    this.pinnedSummary,
    this.pinnedSummaryFallback,
    this.onViewSummary,
    this.onSummaryAttentionRefresh,
    this.onOpenDispute,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
    this.onFirstMessageBroadcast,
  });

  final String deliveryId;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final ImageProvider? counterpartAvatarImage;
  final ChatFeeNotice? feeNotice;
  final String? composerHint;
  final VoidCallback? onStartActiveDelivery;
  final void Function(String deliveryId)? onTrackOrder;
  final OrderChatSummary? pinnedSummary;
  final Widget? pinnedSummaryFallback;
  final VoidCallback? onViewSummary;

  /// Fired when the customer EXPANDS the pinned summary — an explicit,
  /// user-caused request to look at this data. The host answers it with one
  /// catch-up read of the delivery row. See [OrderChatPinnedSummary].
  final VoidCallback? onSummaryAttentionRefresh;
  final VoidCallback? onOpenDispute;
  final bool isOrderChat;
  final bool viewerIsJeeber;

  /// Invoked with the request/conversation id to broadcast AND the text of the
  /// composed first message (used as the created request's description when no
  /// real request exists yet — JM-024 → JM-025). Returns `true` when the host
  /// resolved a real request and routed onward; `false` lets the composer
  /// re-arm so the user can retry (e.g. a failed create).
  final Future<bool> Function(String requestId, String firstMessage)?
  onFirstMessageBroadcast;

  @override
  State<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<_ChatScaffold> with ResumeRefetchMixin {
  final ScrollController _scrollController = ScrollController();
  bool _bannerDismissed = false;

  /// JM-025 AC1: guards the one-shot compose→broadcast. Set the instant the
  /// first outgoing message appears so a re-emit (status promotion, scroll)
  /// can't fire the broadcast twice.
  bool _broadcastFired = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Refetch a thread left open while the app was backgrounded. The
  /// screen-scoped ChatCubit survives a background (the process is not killed),
  /// so its one-shot create-time `load()` never re-runs — without this the
  /// thread shows stale messages until an app restart
  /// (BUG-chat-cache-staleness).
  ///
  /// b02 P0 — driven by [AppResumeSignals] rather than the raw `resumed`
  /// notification: `ChatCubit.refresh()` reconciles optimistic local rows
  /// against the server list, so firing it twenty times in two seconds is not
  /// merely twenty reads, it is twenty chances to reconcile against a partial
  /// response.
  @override
  void onAppResumed() => context.read<ChatCubit>().refresh();

  void _scheduleScrollToBottom() {
    // Defer the scroll until after the next frame so the list has actually
    // sized in the new entry before we try to jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: UIConstants.animationFast,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // JM-025 AC3: surface the dispute affordance on the accepted/active order
    // (D70). The mock conversation phase for an accepted order is `accepted`; an
    // in-flight (active/in-transit) delivery is tracked on the delivery, not the
    // conversation, so its conversation may report a phase the chat-service
    // contract doesn't enumerate — that lands as `unknown` here. The HOST only
    // wires `onOpenDispute` for the client's accepted/active order (it is null on
    // compose and on the Jeeber variant), so the handler's presence is the
    // authoritative "this is a disputable order" signal. We therefore show the
    // affordance whenever the host wired it AND we are not in a state that
    // definitively forbids it: hidden only while still `broadcasting` (no winner
    // yet) or once `closed` (terminated). This keeps the active-delivery seam
    // (jeeb.seam.journey=active_delivery) honest even when its conversation phase
    // does not literally read `accepted`.
    final phase = context.select<ChatCubit, ConversationPhase>(
      (c) => c.state.phase,
    );
    final showDispute =
        widget.onOpenDispute != null &&
        phase != ConversationPhase.broadcasting &&
        phase != ConversationPhase.closed;
    return Semantics(
      identifier: widget.isOrderChat ? 'order_chat_root' : 'chat_detail_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        key: ChatScreen.rootKey,
        // MIDNIGHT: the field paints the page; the Scaffold contributes nothing.
        backgroundColor: Colors.transparent,
        appBar: ChatAppBar(
          title: widget.counterpartName,
          avatarUrl: widget.counterpartAvatarUrl,
          avatarImage: widget.counterpartAvatarImage,
          showAvatar: context.select<ChatCubit, bool>(
            (c) => c.state.showsCounterpartHeader,
          ),
          // The counterpart's rating rides on the resolved summary
          // (`OrderChatSummary.rating`, really populated from `jeeberRating`).
          // 0 hides the line — this is NOT screen 12's nulled tracking rating,
          // and the two models must never be merged.
          rating: widget.pinnedSummary?.rating ?? 0,
          // The kit's trailing slot is ONE circular action. The board draws a
          // phone here; no phone number reaches this surface, so the slot keeps
          // the existing dispute affordance instead of a dead call button.
          trailing: showDispute
              ? JeebTopBarAction(
                  icon: Icons.report_gmailerrorred_outlined,
                  onPressed: widget.onOpenDispute!,
                  identifier: 'order_chat_open_dispute',
                  semanticLabel: l10n.escalateTitle,
                  iconSize: Sizes.medium + Sizes.threeXSmall,
                )
              : null,
        ),
        // R20 is a board-still tile (03-MOTION-NOTES: 0 animated elements), so
        // the field draws its layers at rest and nothing ticks behind the thread.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.bottom,
          animateDecor: false,
          child: SafeArea(
            bottom: false,
            child: BlocConsumer<ChatCubit, ChatState>(
              listenWhen: (prev, curr) =>
                  prev.messages.length != curr.messages.length ||
                  prev.error != curr.error ||
                  // A repeat refresh failure carries the SAME ChatError, so
                  // without this the second one never re-notifies.
                  prev.refreshFailure != curr.refreshFailure ||
                  prev.phase != curr.phase,
              listener: (context, state) =>
                  _onStateChanged(context, state, l10n),
              builder: (context, state) => _buildBody(state, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ChatState state, AppLocalizations l10n) {
    final winnerName = _extractWinnerName(state);
    // JM-025 AC2 / P3: render the pinned summary whenever the HOST resolved one.
    // The host is the authority on WHEN a summary exists (chat_detail_screen only
    // resolves it for an accepted/won order), so the two extra conditions here
    // were wrong for the Jeeber leg and are removed:
    //   * `onViewSummary != null` — the order-summary route is owner-scoped, so
    //     the Jeeber legitimately has no link; that must not suppress the strip.
    //   * `state.phase == accepted` — the live conversation row can still read
    //     `broadcasting` post-accept, and DioChatGateway.loadPhase hard-returns
    //     `broadcasting` when the correlation key equals the conversation id.
    final showPinnedSummary = widget.pinnedSummary != null;
    return _ChatBody(
      state: state,
      l10n: l10n,
      scrollController: _scrollController,
      feeNotice: widget.feeNotice,
      composerHint: widget.composerHint,
      showAcceptedBanner:
          state.phase == ConversationPhase.accepted &&
          !_bannerDismissed &&
          winnerName != null,
      winnerName: winnerName,
      onBannerDismiss: () => setState(() => _bannerDismissed = true),
      onStartActiveDelivery: widget.onStartActiveDelivery,
      onTrackOrder: _trackOrderCallback(state),
      showRemovedBanner:
          state.phase == ConversationPhase.closed &&
          state.messages.any((m) => m.kind == MessageKind.offerRejected),
      broadcastExpiresAt: state.broadcastExpiresAt,
      pinnedSummary: showPinnedSummary ? widget.pinnedSummary : null,
      pinnedSummaryFallback: widget.pinnedSummaryFallback,
      counterpartName: widget.counterpartName,
      // P3: the link gate is now INDEPENDENT of the strip gate — the host
      // decides who gets the (owner-scoped) link.
      onViewSummary: widget.onViewSummary,
      onSummaryAttentionRefresh: widget.onSummaryAttentionRefresh,
      onTrackSummary: _trackSummaryCallback(),
      isOrderChat: widget.isOrderChat,
      viewerIsJeeber: widget.viewerIsJeeber,
      // The compose-state guard is LOAD-BEARING, not cosmetic: in that state
      // the first outgoing message broadcasts the request AND becomes its
      // description, so a quick-tapped "I'm home" would create a request
      // described "I'm home".
      quickRepliesEnabled: widget.onFirstMessageBroadcast == null,
    );
  }

  /// The strip's Track pill, built from the RESOLVED SUMMARY's delivery id.
  ///
  /// Deliberately NOT [_trackOrderCallback]: that one additionally requires
  /// `state.canTrackDelivery`, an accept-response id captured during THIS
  /// session, so it is null on a cold open of an already-accepted thread —
  /// which is exactly the case the strip is drawn for.
  VoidCallback? _trackSummaryCallback() {
    final handler = widget.onTrackOrder;
    final summary = widget.pinnedSummary;
    if (handler == null || summary == null || summary.deliveryId.isEmpty) {
      return null;
    }
    return () => handler(summary.deliveryId);
  }

  /// Builds the zero-arg banner callback only when both a host route handler
  /// is wired AND the accept surfaced a delivery id. Returns null otherwise,
  /// so the "Track order" CTA stays hidden (never a dead end).
  VoidCallback? _trackOrderCallback(ChatState state) {
    final handler = widget.onTrackOrder;
    if (handler == null || !state.canTrackDelivery) return null;
    final deliveryId = state.acceptedDeliveryId!;
    return () => handler(deliveryId);
  }

  String? _extractWinnerName(ChatState state) {
    for (final m in state.messages.reversed) {
      if (m.kind == MessageKind.offerAccepted) {
        return m.systemOfferPayload?.jeeberName;
      }
    }
    return widget.counterpartName;
  }

  void _onStateChanged(
    BuildContext context,
    ChatState state,
    AppLocalizations l10n,
  ) {
    // Auto-scroll on any message-count change. The hasClients guard inside the
    // scheduler covers the empty-list / mid-dispose cases.
    _scheduleScrollToBottom();
    // JM-025 AC1 (D83): in the compose state, the FIRST message the client
    // sends broadcasts the request. We fire the host's broadcast hook the
    // instant the first outgoing message lands (optimistic append) — the
    // host then routes to `waiting-no-coverage` (JM-026). One-shot, guarded by
    // `_broadcastFired` so a status promotion / re-emit doesn't re-broadcast.
    _maybeBroadcastFirstMessage(state);
    final error = state.error;
    if (error == null) return;
    final message = _messageFor(l10n, error);
    if (message != null) {
      final ChatCubit cubit = context.read<ChatCubit>();
      showJeebErrorSnack(
        context,
        message: message,
        identifier: 'chat_screen_error_snack',
        // F34: a dropped frame is only recoverable by re-reading the thread.
        onRetry: error == ChatError.messageDropped ? cubit.retryLoad : null,
      );
    }
    context.read<ChatCubit>().acknowledgeError();
  }

  /// Fires [onFirstMessageBroadcast] exactly once, the first time an outgoing
  /// message appears in the compose-state thread. No-op outside compose mode.
  void _maybeBroadcastFirstMessage(ChatState state) {
    final broadcast = widget.onFirstMessageBroadcast;
    if (broadcast == null || _broadcastFired) return;
    // The first outgoing message is the composed request description: create
    // the request from it (JM-024 → JM-025 AC1). There is exactly one `isMine`
    // message at this point (the optimistic append that triggered this call).
    String? firstMessage;
    for (final m in state.messages) {
      if (m.isMine) {
        firstMessage = m.text;
        break;
      }
    }
    if (firstMessage == null) return;
    _broadcastFired = true;
    // Re-arm the one-shot guard if the host could not resolve a real request
    // (e.g. the create failed), so the next send retries instead of dead-ending.
    broadcast(widget.deliveryId, firstMessage).then((resolved) {
      if (!resolved && mounted) {
        setState(() => _broadcastFired = false);
      }
    });
  }

  String? _messageFor(AppLocalizations l10n, ChatError error) {
    switch (error) {
      case ChatError.pickCancelled:
        return null;
      case ChatError.permissionDenied:
        return l10n.chatErrorPermissionDenied;
      case ChatError.pickUnavailable:
        return l10n.chatErrorPickUnavailable;
      case ChatError.sendFailed:
        return l10n.chatErrorSendFailed;
      case ChatError.voiceUploadFailed:
        return l10n.chatVoiceUploadFailed;
      case ChatError.attachmentUploadFailed:
        return l10n.chatErrorAttachmentUploadFailed;
      case ChatError.refreshFailed:
      case ChatError.messageDropped:
        // F35/F34: the thread on screen is stale or short a message; a one-shot
        // notice is the honest surface, the rows stay put.
        return l10n.chatRefreshFailedBody;
      case ChatError.historyLoadFailed:
        // Rendered as a BODY state (error + retry), not a one-shot toast: the
        // thread is empty BECAUSE of this failure, so the user has to be able
        // to see it and act on it for as long as it lasts. A snackbar here
        // would flash once and leave "No conversation yet" behind it — exactly
        // the collapse this state exists to prevent.
        return null;
    }
  }
}

/// Counted, never read: [ChatConnectionState.pendingCount] is a list length,
/// and the banner renders only the count.
final ChatMessage _chatPendingPlaceholder = ChatMessage(
  clientId: '',
  conversationId: '',
  senderId: '',
  body: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

/// Routes the cubit state to the shimmer / empty-state / message-list body.
class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.l10n,
    required this.scrollController,
    this.feeNotice,
    this.composerHint,
    this.showAcceptedBanner = false,
    this.winnerName,
    this.onBannerDismiss,
    this.onStartActiveDelivery,
    this.onTrackOrder,
    this.showRemovedBanner = false,
    this.broadcastExpiresAt,
    this.pinnedSummary,
    this.pinnedSummaryFallback,
    this.counterpartName = '',
    this.onViewSummary,
    this.onSummaryAttentionRefresh,
    this.onTrackSummary,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
    this.quickRepliesEnabled = true,
  });

  final ChatState state;
  final AppLocalizations l10n;
  final ScrollController scrollController;
  final ChatFeeNotice? feeNotice;
  final String? composerHint;
  final bool showAcceptedBanner;
  final String? winnerName;
  final VoidCallback? onBannerDismiss;
  final VoidCallback? onStartActiveDelivery;
  final VoidCallback? onTrackOrder;
  final bool showRemovedBanner;
  final DateTime? broadcastExpiresAt;
  final OrderChatSummary? pinnedSummary;

  /// F44 stand-in shown in the header slot when the summary read failed.
  final Widget? pinnedSummaryFallback;
  final String counterpartName;
  final VoidCallback? onViewSummary;

  /// Fired when the customer EXPANDS the pinned summary — an explicit,
  /// user-caused request to look at this data. The host answers it with one
  /// catch-up read of the delivery row. See [OrderChatPinnedSummary].
  final VoidCallback? onSummaryAttentionRefresh;

  /// Routes the pinned strip's glass `Track` pill to live tracking. Null hides
  /// the pill (no route wired, or no delivery id on the summary).
  final VoidCallback? onTrackSummary;
  final bool isOrderChat;
  final bool viewerIsJeeber;

  /// False in the compose state, where the first outgoing message becomes the
  /// request's description — see the note at the `_ChatBody` construction.
  final bool quickRepliesEnabled;

  /// R6 — only Network/Timeout may blame connectivity. A 500/401/403 is a
  /// server or session fault; the failure block and the snack already say so.
  static bool _blamesConnectivity(AppFailure? failure) =>
      failure != null &&
      (failure.kind == AppFailureKind.network ||
          failure.kind == AppFailureKind.timeout);

  /// B4 — driven by the EXISTING transport, not a second socket: instantiating
  /// `ChatConnectionCubit` here would open a duplicate WS to this conversation.
  bool get _showsConnectionBanner =>
      _blamesConnectivity(state.historyFailure) ||
      _blamesConnectivity(state.refreshFailure) ||
      state.outboxPending > 0;

  ChatConnectionState _connectionStateFrom(ChatState state) =>
      ChatConnectionState(
        status: _blamesConnectivity(state.historyFailure)
            ? ConnectionStatus.disconnected
            : _blamesConnectivity(state.refreshFailure)
                ? ConnectionStatus.reconnecting
                : ConnectionStatus.connected,
        pending: List<ChatMessage>.filled(
          state.outboxPending,
          _chatPendingPlaceholder,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingHistory) {
      return Semantics(
        identifier: 'chat_screen_loading',
        container: true,
        child: const ChatThreadSkeleton(),
      );
    }
    // b02: the FAILURE branch has to be tested BEFORE the emptiness branch.
    // Ordering them the other way round is the whole defect: a 500 leaves
    // `messages` empty, so an emptiness-first body renders "No conversation
    // yet" over a thread that exists and a Jeeber who is already on the way.
    // Only a read that came back may be interpreted as "there is nothing here".
    final Widget body;
    if (state.historyLoadFailed) {
      body = _ChatHistoryErrorState(failure: state.historyFailure);
    } else if (state.messages.isEmpty) {
      body = _ChatEmptyState(phase: state.phase, l10n: l10n);
    } else {
      body = _ChatMessageList(state: state, controller: scrollController);
    }
    final notice = feeNotice;
    final summary = pinnedSummary;
    final header = <Widget>[
      // EP-11 / OFF-30: the thread had no connection indicator at all. Inside
      // the bounded header slot, so it cannot re-open the overflow defect.
      if (_showsConnectionBanner)
        ChatConnectionBanner(
          state: _connectionStateFrom(state),
          // Over RENDERED rows the recovery must not blank them: `retryLoad`
          // flips the skeleton in and empties the thread on a second failure.
          onReconnect: () => state.historyLoadFailed
              ? context.read<ChatCubit>().retryLoad()
              : context.read<ChatCubit>().refresh(),
        ),
      if (notice != null) _FeeBannerSlot(notice: notice),
      // F44: the summary read failed, so the slot says so instead of vanishing.
      if (summary == null && pinnedSummaryFallback != null)
        pinnedSummaryFallback!,
      // JM-025 AC2: pinned locked-price summary on the accepted order, above
      // the thread (D71/D11). Carries `order_chat_pinned_summary` +
      // `order_chat_view_summary_link` → order-summary-pinned (JM-031).
      if (summary != null)
        OrderChatPinnedSummary(
          summary: summary,
          counterpartName: counterpartName,
          onViewSummary: onViewSummary,
          onSummaryAttentionRefresh: onSummaryAttentionRefresh,
          onTrack: onTrackSummary,
          viewerIsJeeber: viewerIsJeeber,
        ),
      if (showAcceptedBanner && winnerName != null)
        OfferAcceptedBanner(
          jeeberName: winnerName!,
          onDismiss: onBannerDismiss,
          onStartActiveDelivery: onStartActiveDelivery,
          onTrackOrder: onTrackOrder,
        ),
      if (showRemovedBanner) const JeeberRemovedBanner(),
      if (state.phase == ConversationPhase.broadcasting)
        BroadcastTtlIndicator(expiresAt: broadcastExpiresAt),
    ];
    // b02 — "BOTTOM OVERFLOWED BY 16 PIXELS", fixed at its cause.
    //
    // ROOT CAUSE (measured, not guessed — see
    // `test/features/chat/chat_header_overflow_test.dart`): this Column mixes
    // NON-FLEXIBLE chrome (fee banner, pinned summary, accepted banner, removed
    // banner, TTL indicator, composer) with a single `Expanded` body. A Column
    // gives its non-flexible children their full intrinsic height FIRST and
    // divides only what is left among the flex children. When the keyboard
    // shrinks the viewport, the chrome's intrinsic height can exceed the whole
    // viewport: `Expanded` is then allocated ZERO, and the Column overflows by
    // exactly the excess. It was 16 px because the chrome was 16 px taller than
    // the shrunken body.
    //
    // It is NOT `resizeToAvoidBottomInset` (unset → true; the Scaffold shrinks
    // correctly, which is precisely how the layout ends up over-constrained) and
    // NOT a double-counted `SafeArea` (`SafeArea(bottom: false)`, and the
    // AppBar has already consumed the top padding).
    //
    // THE FIX is the BOUND: the chrome is given a maximum of
    // [kChatHeaderMaxViewportFraction] of the available height, so the message
    // list can never be starved to zero and the Column can never be asked to
    // lay out more than it has. The collapsed header + compact banner fit inside
    // that bound with room to spare at normal text scales (asserted), so the
    // bound is inert in the ordinary case; it exists so that a long request
    // description, a fee banner and a 2.0 text scale arriving together degrade
    // by scrolling a bounded region instead of overflowing an unbounded one.
    // THE SLOT MUST NOT COLLAPSE TO ZERO WHILE IT HOLDS THE START-DELIVERY CTA.
    //
    // "Start delivery" is the Jeeber's primary action during a LIVE delivery.
    // The bound below clamps to 0 dp on a small phone with the keyboard up at a
    // 2.0 text scale, and a ZERO-HEIGHT VIEWPORT CANNOT SCROLL — so the CTA was
    // unreachable while still being present in the widget tree, which is why a
    // `findsOneWidget` assertion did not catch it and the suite asserted
    // `_headerHeight == 0` as correct.
    //
    // Hoisting the CTA OUT of the slot does not work either: it becomes
    // non-flexible chrome and re-creates the original overflow (measured: 54 px
    // at 411x914, 88 px at 320x480+2.0). At that smallest size the CTA and the
    // composer genuinely do not both fit — no placement makes them.
    //
    // So the slot keeps the CTA and is given a FLOOR instead of a zero clamp:
    // enough height to scroll to the CTA, never more than the bound. Degradation
    // stays a scroll, which is reachable, rather than a clip, which is not.
    final hasStartDeliveryCta =
        showAcceptedBanner &&
        winnerName != null &&
        onStartActiveDelivery != null;

    // The canned lines are CLIENT-voice ("I'm home", "Call me at the door"),
    // and this screen also hosts the Jeeber leg — so the row is gated on the
    // viewer's role as well as on the phase and the compose hook.
    final showQuickReplies =
        state.isComposerVisible &&
        state.phase != ConversationPhase.broadcasting &&
        quickRepliesEnabled &&
        !viewerIsJeeber;
    // The row is a second non-flexible Column child, so it comes out of the
    // same budget the composer does — never out of the message list.
    final chromeReserve =
        kChatComposerReserve + (showQuickReplies ? kChatQuickReplyReserve : 0);

    // MIDNIGHT — the SECOND over-constraint, measured at 320x480 + 220 dp
    // keyboard + text scale 2.0: the bottom band (quick replies 64 + composer
    // 190) wants 254 dp of a 202 dp body and overflowed by 52 px. The composer
    // is 190 there and only 106 at 411 dp, because the hint wraps to three
    // lines in a 135 dp field — an intrinsic height [kChatComposerReserve]
    // cannot predict, so no reserve constant can fix it. The bound can: the
    // band is given what the header left and degrades by SCROLLING, exactly
    // like [_ChatHeaderSlot]. Inert whenever the band fits, which is every
    // device class below a 2.0 scale on a 320 dp phone.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double headerAllowance = header.isEmpty
            ? 0.0
            : math.max(
                // The FLOOR — only when the slot holds the Start-delivery CTA,
                // and never more than a third of the viewport so the thread and
                // composer keep priority everywhere else. Without this the
                // clamp is 0 and the CTA cannot be scrolled to.
                hasStartDeliveryCta
                    ? math.min(
                        math.min(
                          kChatPinnedCtaReserve,
                          constraints.maxHeight / 3,
                        ),
                        // The floor must never itself overflow the Column: it
                        // can only claim what the composer does not need. At
                        // 320x480 + keyboard + 2.0 this is ~20 dp, so the CTA
                        // is genuinely unreachable there and the pre-existing
                        // priority order stands (read the thread, send a
                        // message, then the order summary). At the real device
                        // class it is the full 96 dp and the CTA is reachable.
                        math.max(
                          0.0,
                          constraints.maxHeight -
                              chromeReserve *
                                  MediaQuery.textScalerOf(context).scale(1),
                        ),
                      )
                    : 0.0,
                math.min(
                  constraints.maxHeight * kChatHeaderMaxViewportFraction,
                  constraints.maxHeight -
                      chromeReserve * MediaQuery.textScalerOf(context).scale(1),
                ),
              );
        return Column(
          children: [
            if (header.isNotEmpty)
              _ChatHeaderSlot(maxHeight: headerAllowance, children: header),
            Expanded(child: body),
            _ChatComposerSlot(
              maxHeight: math.max(0.0, constraints.maxHeight - headerAllowance),
              children: [
                if (showQuickReplies) const ChatQuickReplyBar(),
                if (state.isComposerVisible)
                  ChatComposer(
                    hintText: composerHint ?? l10n.chatComposerHintMessage,
                    // JM-025: the customer order-chat surface exposes the
                    // `order_chat_composer_*` ids the W1 flow drives; every
                    // other caller keeps the default `chat_detail_*` ids.
                    inputIdentifier: isOrderChat
                        ? 'order_chat_composer_input'
                        : 'chat_detail_message_input',
                    sendIdentifier: isOrderChat
                        ? 'order_chat_composer_send'
                        : 'chat_detail_send_button',
                    onVoiceRecordingComplete: (bytes, mime, ms) =>
                        context.read<ChatCubit>().sendVoiceNote(
                          audioBytes: bytes,
                          mimeType: mime,
                          durationMs: ms,
                        ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The bounded chrome slot above the message list.
///
/// Everything that is not the thread and not the composer lives here. The slot
/// takes its children's intrinsic height up to [maxHeight] and no further, which
/// is what stops the surrounding `Column` from ever asking for more height than
/// the (keyboard-shrunk) viewport has — see the root-cause note in `_ChatBody`.
///
/// The scroll view is the DEGRADATION path, not the fix: at normal text scales
/// the collapsed header + compact banner are well inside the bound and the
/// scrollable has zero extent (asserted in
/// `test/features/chat/chat_header_overflow_test.dart`). It only engages when a
/// user has expanded the header AND is at a large text scale AND several banners
/// are stacked — the case where something has to give, and scrolling a bounded
/// header is the option that keeps every element reachable.
class _ChatHeaderSlot extends StatelessWidget {
  const _ChatHeaderSlot({required this.maxHeight, required this.children});

  final double maxHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        key: chatHeaderSlotKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// The bounded bottom band — quick replies + composer — the twin of
/// [_ChatHeaderSlot].
///
/// Both are non-flexible Column children whose intrinsic height the reserve
/// constants only ESTIMATE: the composer's hint wraps at small widths and large
/// text scales, so its real height (190 dp at 320x480 + 2.0) can exceed
/// [kChatComposerReserve] by 70 dp and the Column overflows by the difference.
/// Bounding the band to what the header left makes the excess a SCROLL — the
/// send circle stays reachable — instead of a clip.
class _ChatComposerSlot extends StatelessWidget {
  const _ChatComposerSlot({required this.maxHeight, required this.children});

  final double maxHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        key: chatComposerSlotKey,
        // The band is pinned to the bottom, so an overflowing one must reveal
        // its END (the send circle), not its start.
        reverse: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Adapts a [ChatFeeNotice] config into the rendered [ChatFeeBanner].
class _FeeBannerSlot extends StatelessWidget {
  const _FeeBannerSlot({required this.notice});

  final ChatFeeNotice notice;

  @override
  Widget build(BuildContext context) {
    return ChatFeeBanner(
      amount: notice.amount,
      trailing: notice.trailing,
      onDismiss: notice.onDismiss,
      onOrderPicked: notice.onOrderPicked,
    );
  }
}

/// b02: the history read FAILED — say so, and offer a way out.
///
/// Rendered instead of [_ChatEmptyState] whenever
/// [ChatState.historyLoadFailed] is set. The distinction is the entire point:
/// the empty state asserts "this delivery doesn't have a chat thread", which is
/// a claim about the SERVER'S DATA, and a 500 is not evidence for it. Rendering
/// it anyway is how a Firestore outage reached users as an empty chat while
/// their Jeeber was in transit, with nothing to tap.
///
/// MIDNIGHT: the same two kit primitives the `/chat/:id` container's
/// resolution error uses — [JeebInfoNote.error] carries the statement and a
/// navy [JeebCtaButton] carries the retry — so a transport failure looks
/// identical whichever of the two layers caught it. Replaces `OmdsErrorState`,
/// the last pre-redesign surface this body could show.
class _ChatHistoryErrorState extends StatelessWidget {
  const _ChatHistoryErrorState({this.failure});

  /// The classified cold-load failure. Null falls back to the generic copy.
  final AppFailure? failure;

  @override
  Widget build(BuildContext context) {
    // Same constrain-to-viewport + scroll shell the empty state uses, now the
    // kit's [JeebStateHost] rather than a second hand-rolled copy of it.
    return JeebStateHost(
      child: JeebFailureBlock.compact(
        key: ChatScreen.historyErrorKey,
        failure: failure ?? const UnknownFailure(),
        identifier: 'chat_history_error',
        variant: JeebEmptyStateVariant.e1,
        // The frozen id: the block's own rule would mint `_retry_cta`.
        retryIdentifier: 'chat_history_error_retry',
        onRetry: () => context.read<ChatCubit>().retryLoad(),
      ),
    );
  }
}

/// Empty conversation placeholder, copy keyed to the conversation [phase].
///
/// MIDNIGHT: the empty family is [JeebEmptyState] — `compact`, because this
/// block sits inside the thread column rather than owning the screen. The
/// broadcasting phase takes the `radar` variant: "waiting for Jeebers" IS E2's
/// subject, and reusing it keeps one waiting illustration in the app.
class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.phase, required this.l10n});

  final ConversationPhase phase;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (phase) {
      ConversationPhase.unknown => (
        l10n.chatNoConversationTitle,
        // The client-side wording ("once a Jeeber is assigned") is nonsense for
        // the assigned jeeber, who IS that Jeeber.
        context.read<RoleCubit?>()?.state == UserRole.jeeber
            ? l10n.chatNoConversationSubtitleJeeber
            : l10n.chatNoConversationSubtitle,
      ),
      ConversationPhase.broadcasting => (
        l10n.chatBroadcastingTitle,
        l10n.chatBroadcastingEmpty,
      ),
      _ => (l10n.chatEmptyThreadTitle, l10n.chatEmptyThreadSubtitle),
    };
    final variant = phase == ConversationPhase.broadcasting
        ? JeebEmptyStateVariant.radar
        : JeebEmptyStateVariant.e1;
    // Run-22 fix ("BOTTOM OVERFLOWED BY 6.6 PIXELS"): the empty-state column
    // (80dp icon + title + subtitle + paddings) has a fixed natural height, but
    // the slot the chat body hands it shrinks below that once the fee banner /
    // pinned summary / accepted banner / keyboard stack up. A bare Center
    // clamps the child to the incoming max height and the inner Column
    // overflows. Constrain-to-viewport + scroll instead: full-height centering
    // when there is room, graceful scrolling (never a RenderFlex overflow)
    // when there is not.
    return JeebStateHost(
      // R20 is a board-still tile, so its in-thread empty block draws at rest —
      // the call-site equivalent of the field's `animateDecor`.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: JeebEmptyState.compact(
          key: ChatScreen.emptyStateKey,
          variant: variant,
          headline: title,
          body: subtitle,
          identifier: 'chat_screen_empty',
        ),
      ),
    );
  }
}

/// Scrollable timeline: a leading date separator, the message bubbles / offer
/// cards, and (in the broadcasting phase) a trailing "accept only one" note.
class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({required this.state, required this.controller});

  final ChatState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Semantics(
      identifier: 'chat_detail_message_list',
      child: ListView.builder(
        key: ChatScreen.messageListKey,
        controller: controller,
        // The 24 gutter lives on the rows themselves (so a bubble's 78%
        // ceiling is measured against the same column the board draws); this
        // is the thread's own top/bottom air.
        padding: const EdgeInsets.symmetric(vertical: Spacing.medium),
        itemCount: rows.length,
        itemBuilder: (context, index) =>
            _ChatRow(row: rows[index], state: state),
      ),
    );
  }

  List<_ChatRowData> _rows() {
    final first = state.messages.first;
    final rows = <_ChatRowData>[
      // Lead with a date separator ONLY when the server actually dated the
      // first message. A row that arrived with no timestamp carries an ordering
      // anchor inside 1970 — a "1 Jan 1970" divider over a live thread would be
      // a fabrication.
      if (first.hasServerTimestamp) _ChatRowData.date(first.sentAt),
    ];
    // CLUSTERING: consecutive messages from the same author tighten into one
    // visual block. This is how the board's single "voice + photo" bubble is
    // rendered honestly — the wire carries two messages and we draw two.
    DeliveryChatMessage? previous;
    for (final m in state.messages) {
      final clustered =
          previous != null &&
          !previous.isSystemNotice &&
          !m.isSystemNotice &&
          previous.author == m.author;
      rows.add(_ChatRowData.message(m, clustered: clustered));
      previous = m;
    }
    if (state.phase == ConversationPhase.broadcasting &&
        state.offerCards.isNotEmpty) {
      rows.add(const _ChatRowData.offerNote());
    }
    return rows;
  }
}

/// Discriminated row model so the [ListView] builder stays declarative.
class _ChatRowData {
  const _ChatRowData._(
    this.kind, {
    this.date,
    this.message,
    this.clustered = false,
  });
  const _ChatRowData.date(DateTime date)
    : this._(_ChatRowKind.date, date: date);
  const _ChatRowData.message(
    DeliveryChatMessage message, {
    bool clustered = false,
  }) : this._(_ChatRowKind.message, message: message, clustered: clustered);
  const _ChatRowData.offerNote() : this._(_ChatRowKind.offerNote);

  final _ChatRowKind kind;
  final DateTime? date;
  final DeliveryChatMessage? message;

  /// True when the previous row is a message from the same author.
  final bool clustered;
}

enum _ChatRowKind { date, message, offerNote }

/// Renders one timeline row from its [row] descriptor.
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.row, required this.state});

  final _ChatRowData row;
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    switch (row.kind) {
      case _ChatRowKind.date:
        return ChatDateSeparator(date: row.date!);
      case _ChatRowKind.offerNote:
        return const ChatOfferOnlyOneFooter();
      case _ChatRowKind.message:
        return _MessageRow(
          message: row.message!,
          state: state,
          clustered: row.clustered,
        );
    }
  }
}

/// A single chat message row — a plain bubble, or an offer card when the
/// message carries an offer payload.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.state,
    this.clustered = false,
  });

  final DeliveryChatMessage message;
  final ChatState state;
  final bool clustered;

  @override
  Widget build(BuildContext context) {
    if (!message.isOfferCard) {
      return ChatMessageBubble(
        message: message,
        clustered: clustered,
        // OFF-05: the failed-send copy promises "Tap the bubble to retry".
        onRetry: message.status == MessageStatus.failed && message.isMine
            ? () => context.read<ChatCubit>().retryMessage(message.id)
            : null,
        // F36: an unresolved image tile gets a way back.
        onImageRetry: message.imageLoadFailed
            ? () => context.read<ChatCubit>().retryImage(message.id)
            : null,
      );
    }
    final offerId = message.offerPayload?.offerId ?? '';
    final isAccepting = state.acceptingOfferId == offerId;
    final isDeclined = state.declinedOfferIds.contains(offerId);
    return Opacity(
      opacity: isDeclined ? 0.4 : 1.0,
      child: OfferCardBubble(
        message: message,
        onAccept: (id) => context.read<ChatCubit>().acceptOffer(id),
        onDecline: isDeclined
            ? null
            : (id) => context.read<ChatCubit>().declineOffer(id),
        isAccepting: isAccepting,
        acceptDisabled:
            (state.acceptingOfferId != null && !isAccepting) || isDeclined,
      ),
    );
  }
}

/// Placeholder bubbles in the kit's own geometry, shown while a thread is
/// unknown — the history read here, the conversation resolution in the
/// `/chat/:id` container. ONE skeleton for both, so the two loading frames
/// cannot drift.
///
/// One deliberate refusal: **no outgoing (tinted) placeholder**. A tinted
/// bubble is the board's "you said this"; drawing one before a single message
/// has loaded would assert content that may not exist. Every placeholder is an
/// incoming rest-glass shell.
///
/// It renders through [JeebChatBubble] rather than re-deriving the radii, fill
/// and padding, so the loading frame and the resolved thread cannot drift.
///
/// The pulse is the kit's `jBreathe`, not a local controller — same .45→1
/// curve, but on `JMotionLoop`'s reduce-motion contract.
///
/// It keeps a frame scheduled for as long as the screen is loading, and several
/// suites depend on that: their `pumpAndSettle()` is what lets the async lookup
/// land (`chat_detail_active_thread_test` fails against a motionless
/// placeholder). A skeleton with no motion also reads as an empty thread that
/// finished loading, which is precisely the wrong statement.
class ChatThreadSkeleton extends StatelessWidget {
  const ChatThreadSkeleton({super.key});

  /// Width of each placeholder as a fraction of the thread column — unequal on
  /// purpose, so the shell reads as "messages are coming" rather than as a
  /// rendered thread. Below the kit's own 0.78 ceiling.
  static const List<double> _widthFractions = <double>[0.62, 0.44, 0.7];

  /// One full breath — `jBreathe`'s fast end (1.6s).
  static const Duration pulseDuration = JeebMotion.breatheDurationMin;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: JBreathe(
        duration: pulseDuration,
        child: Padding(
          // The thread's own gutter (24) and top inset (16) — html:31.
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.medium,
            Spacing.xLarge,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final fraction in _widthFractions) ...<Widget>[
                JeebChatBubble(
                  side: JeebChatBubbleSide.incoming,
                  maxWidthFraction: fraction,
                  // An empty line box: the bubble supplies the fill and the
                  // 18/18/18/6 corners, this supplies its height.
                  child: const SizedBox(
                    width: double.infinity,
                    height: Sizes.small,
                  ),
                ),
                const SizedBox(height: Spacing.small),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
