import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

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
          onFirstMessageBroadcast: onFirstMessageBroadcast,
        ),
      );
    }
    return BlocProvider<ChatCubit>(
      create: (_) => ChatCubit(
        deliveryId: deliveryId,
        gateway: gateway ?? InMemoryChatGateway(),
        pickerService: pickerService ?? StubPhotoPickerService(),
        initialDeliveryId: initialTrackingDeliveryId,
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
        onFirstMessageBroadcast: onFirstMessageBroadcast,
      ),
    );
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
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _bannerDismissed = false;

  /// JM-025 AC1: guards the one-shot compose→broadcast. Set the instant the
  /// first outgoing message appears so a re-emit (status promotion, scroll)
  /// can't fire the broadcast twice.
  bool _broadcastFired = false;

  @override
  void initState() {
    super.initState();
    // Observe app lifecycle so a thread left open while the app was
    // backgrounded refetches on resume. The screen-scoped ChatCubit survives a
    // background (the process is not killed), so its one-shot create-time
    // load() never re-runs — without this the thread shows stale messages until
    // an app restart (BUG-chat-cache-staleness).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ChatCubit>().refresh();
    }
  }

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
    // JM-025 AC2: render the pinned summary only on the accepted/active order
    // (D71/D11), and only when the host resolved one. The broadcasting/compose
    // and Jeeber variants pass null.
    final showPinnedSummary = widget.pinnedSummary != null &&
        widget.onViewSummary != null &&
        state.phase == ConversationPhase.accepted;
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
      onViewSummary: showPinnedSummary ? widget.onViewSummary : null,
      isOrderChat: widget.isOrderChat,
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

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingHistory) return const _ChatHistoryShimmer();
    final body = state.messages.isEmpty
        ? _ChatEmptyState(phase: state.phase, l10n: l10n)
        : _ChatMessageList(state: state, controller: scrollController);
    final notice = feeNotice;
    final summary = pinnedSummary;
    return Column(
      children: [
        if (notice != null) _FeeBannerSlot(notice: notice),
        // JM-025 AC2: pinned locked-price summary on the accepted order, above
        // the thread (D71/D11). Carries `order_chat_pinned_summary` +
        // `order_chat_view_summary_link` → order-summary-pinned (JM-031).
        if (summary != null && onViewSummary != null)
          OrderChatPinnedSummary(
            summary: summary,
            counterpartName: counterpartName,
            onViewSummary: onViewSummary!,
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
    return Center(
      child: OmdsEmptyState(
        key: ChatScreen.emptyStateKey,
        icon: Icons.chat_bubble_outline,
        title: title,
        subtitle: subtitle,
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
    final rows = <_ChatRowData>[
      _ChatRowData.date(state.messages.first.sentAt),
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
