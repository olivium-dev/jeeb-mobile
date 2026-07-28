import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/chat_cubit.dart';
import '../application/chat_state.dart';
import '../data/in_memory_chat_gateway.dart';
import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';
import '../domain/order_chat_summary.dart';
import 'widgets/broadcast_ttl_indicator.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_date_separator.dart';
import 'widgets/chat_fee_banner.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_offer_only_one_footer.dart';
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

/// Key on the bounded header slot's scrollable, so a test can assert the
/// ordinary case does NOT scroll (a bound that is always engaged would be
/// hiding content rather than budgeting it).
const Key chatHeaderSlotKey = Key('chat-screen-header-slot');

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
/// in-memory implementation by default) and a [PhotoPickerService] (the
/// stub picker until image_picker lands in a later mobile task), and
/// auto-scrolls to the latest message whenever the cubit emits.
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
    this.onViewSummary,
    this.onOpenDispute,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
    this.onFirstMessageBroadcast,
    this.initialTrackingDeliveryId,
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
  /// "Price / time" hint; null falls back to the default "Type a message".
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

  /// JM-025 AC2: tap handler for the pinned strip's view-summary link →
  /// `order-summary-pinned` (JM-031). Required for the link to render.
  final VoidCallback? onViewSummary;

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
          onViewSummary: onViewSummary,
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
        onViewSummary: onViewSummary,
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
    this.onViewSummary,
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
  final VoidCallback? onViewSummary;
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

class _ChatScaffoldState extends State<_ChatScaffold>
    with ResumeRefetchMixin {
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
    final showDispute = widget.onOpenDispute != null &&
        phase != ConversationPhase.broadcasting &&
        phase != ConversationPhase.closed;
    return Scaffold(
      key: ChatScreen.rootKey,
      appBar: ChatAppBar(
        title: widget.counterpartName,
        avatarUrl: widget.counterpartAvatarUrl,
        avatarImage: widget.counterpartAvatarImage,
        showAvatar: context.select<ChatCubit, bool>(
          (c) => c.state.showsCounterpartHeader,
        ),
        actions: showDispute
            ? <Widget>[
                Semantics(
                  identifier: 'order_chat_open_dispute',
                  button: true,
                  label: l10n.escalateTitle,
                  child: IconButton(
                    icon: const Icon(Icons.report_gmailerrorred_outlined),
                    tooltip: l10n.escalateTitle,
                    onPressed: widget.onOpenDispute,
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<ChatCubit, ChatState>(
          listenWhen: (prev, curr) =>
              prev.messages.length != curr.messages.length ||
              prev.error != curr.error ||
              prev.phase != curr.phase,
          listener: (context, state) => _onStateChanged(context, state, l10n),
          builder: (context, state) => _buildBody(state, l10n),
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
      showAcceptedBanner: state.phase == ConversationPhase.accepted &&
          !_bannerDismissed &&
          winnerName != null,
      winnerName: winnerName,
      onBannerDismiss: () => setState(() => _bannerDismissed = true),
      onStartActiveDelivery: widget.onStartActiveDelivery,
      onTrackOrder: _trackOrderCallback(state),
      showRemovedBanner: state.phase == ConversationPhase.closed &&
          state.messages.any(
            (m) => m.kind == MessageKind.offerRejected,
          ),
      broadcastExpiresAt: state.broadcastExpiresAt,
      pinnedSummary: showPinnedSummary ? widget.pinnedSummary : null,
      counterpartName: widget.counterpartName,
      // P3: the link gate is now INDEPENDENT of the strip gate — the host
      // decides who gets the (owner-scoped) link.
      onViewSummary: widget.onViewSummary,
      isOrderChat: widget.isOrderChat,
      viewerIsJeeber: widget.viewerIsJeeber,
    );
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
      showOmdsSnackbar(context, message: message);
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
    this.counterpartName = '',
    this.onViewSummary,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
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
  final String counterpartName;
  final VoidCallback? onViewSummary;
  final bool isOrderChat;
  final bool viewerIsJeeber;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingHistory) return const _ChatHistoryShimmer();
    // b02: the FAILURE branch has to be tested BEFORE the emptiness branch.
    // Ordering them the other way round is the whole defect: a 500 leaves
    // `messages` empty, so an emptiness-first body renders "No conversation
    // yet" over a thread that exists and a Jeeber who is already on the way.
    // Only a read that came back may be interpreted as "there is nothing here".
    final Widget body;
    if (state.historyLoadFailed) {
      body = _ChatHistoryErrorState(l10n: l10n);
    } else if (state.messages.isEmpty) {
      body = _ChatEmptyState(phase: state.phase, l10n: l10n);
    } else {
      body = _ChatMessageList(state: state, controller: scrollController);
    }
    final notice = feeNotice;
    final summary = pinnedSummary;
    final header = <Widget>[
      if (notice != null) _FeeBannerSlot(notice: notice),
      // JM-025 AC2: pinned locked-price summary on the accepted order, above
      // the thread (D71/D11). Carries `order_chat_pinned_summary` +
      // `order_chat_view_summary_link` → order-summary-pinned (JM-031).
      if (summary != null)
        OrderChatPinnedSummary(
          summary: summary,
          counterpartName: counterpartName,
          onViewSummary: onViewSummary,
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
        showAcceptedBanner && winnerName != null && onStartActiveDelivery != null;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (header.isNotEmpty)
            _ChatHeaderSlot(
              maxHeight: math.max(
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
                          0,
                          constraints.maxHeight -
                              kChatComposerReserve *
                                  MediaQuery.textScalerOf(context).scale(1),
                        ),
                      )
                    : 0,
                math.min(
                  constraints.maxHeight * kChatHeaderMaxViewportFraction,
                  constraints.maxHeight -
                      kChatComposerReserve *
                          MediaQuery.textScalerOf(context).scale(1),
                ),
              ),
              children: header,
            ),
          Expanded(child: body),
          if (state.isComposerVisible)
          ChatComposer(
            hintText: composerHint,
            // JM-025: the customer order-chat surface exposes the
            // `order_chat_composer_*` ids the W1 flow drives; every other
            // caller keeps the default `chat_detail_*` ids.
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
/// OMDS only: [OmdsErrorState], which owns the icon/title/message/retry layout
/// and its own theming.
class _ChatHistoryErrorState extends StatelessWidget {
  const _ChatHistoryErrorState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Same constrain-to-viewport + scroll shell as the empty state (run-22
    // "BOTTOM OVERFLOWED BY 6.6 PIXELS"): this column is TALLER than that one
    // (it carries a retry button as well), so it needs the treatment at least
    // as much once banners / the pinned summary / the keyboard stack up.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Semantics(
              identifier: 'chat_history_error',
              child: OmdsErrorState(
                key: ChatScreen.historyErrorKey,
                title: l10n.chatHistoryErrorTitle,
                message: l10n.chatHistoryErrorMessage,
                retryLabel: l10n.chatHistoryErrorRetry,
                onRetry: () => context.read<ChatCubit>().retryLoad(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty conversation placeholder, copy keyed to the conversation [phase].
class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.phase, required this.l10n});

  final ConversationPhase phase;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (phase) {
      ConversationPhase.unknown => (
          l10n.chatNoConversationTitle,
          l10n.chatNoConversationSubtitle,
        ),
      ConversationPhase.broadcasting => (
          l10n.chatBroadcastingTitle,
          l10n.chatBroadcastingEmpty,
        ),
      _ => (l10n.chatEmptyThreadTitle, l10n.chatEmptyThreadSubtitle),
    };
    // Run-22 fix ("BOTTOM OVERFLOWED BY 6.6 PIXELS"): the empty-state column
    // (80dp icon + title + subtitle + paddings) has a fixed natural height, but
    // the slot the chat body hands it shrinks below that once the fee banner /
    // pinned summary / accepted banner / keyboard stack up. A bare Center
    // clamps the child to the incoming max height and the inner Column
    // overflows. Constrain-to-viewport + scroll instead: full-height centering
    // when there is room, graceful scrolling (never a RenderFlex overflow)
    // when there is not.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: OmdsEmptyState(
              key: ChatScreen.emptyStateKey,
              icon: Icons.chat_bubble_outline,
              title: title,
              subtitle: subtitle,
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: Spacing.small),
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
      for (final m in state.messages) _ChatRowData.message(m),
    ];
    if (state.phase == ConversationPhase.broadcasting &&
        state.offerCards.isNotEmpty) {
      rows.add(const _ChatRowData.offerNote());
    }
    return rows;
  }
}

/// Discriminated row model so the [ListView] builder stays declarative.
class _ChatRowData {
  const _ChatRowData._(this.kind, {this.date, this.message});
  const _ChatRowData.date(DateTime date)
      : this._(_ChatRowKind.date, date: date);
  const _ChatRowData.message(DeliveryChatMessage message)
      : this._(_ChatRowKind.message, message: message);
  const _ChatRowData.offerNote() : this._(_ChatRowKind.offerNote);

  final _ChatRowKind kind;
  final DateTime? date;
  final DeliveryChatMessage? message;
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
        return _MessageRow(message: row.message!, state: state);
    }
  }
}

/// A single chat message row — a plain bubble, or an offer card when the
/// message carries an offer payload.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.state});

  final DeliveryChatMessage message;
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    if (!message.isOfferCard) return ChatMessageBubble(message: message);
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

/// Skeleton placeholder shown while the chat history is loading.
///
/// Uses [OmdsListItemShimmer] (the canonical OMDS list-loading primitive) to
/// hint at the upcoming message bubble layout — leading avatar circle plus a
/// title-and-subtitle text pair — instead of a content-free spinner.
class _ChatHistoryShimmer extends StatelessWidget {
  const _ChatHistoryShimmer();

  static const int _placeholderCount = 6;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('chat-screen-history-shimmer'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      itemCount: _placeholderCount,
      itemBuilder: (context, index) => const OmdsListItemShimmer(),
    );
  }
}
