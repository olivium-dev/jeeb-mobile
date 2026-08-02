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

/// Structural guarantee: message list always has ≥ 60% of viewport (prevents Column overflow).
const double kChatHeaderMaxViewportFraction = 0.4;

const double kChatComposerReserve = 120;

/// CTA floor for LIVE delivery. Without it a zero-height slot at 320x480 + 2.0 scale + keyboard = unreachable.
const double kChatPinnedCtaReserve = 96;

const Key chatHeaderSlotKey = Key('chat-screen-header-slot');

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

/// MB1 W4.1 TRAP: _resolvePicker reads DI FIRST; stub is fallback for tests only.
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
    this.onSummaryAttentionRefresh,
    this.onOpenDispute,
    this.isOrderChat = false,
    this.viewerIsJeeber = false,
    this.onFirstMessageBroadcast,
    this.initialTrackingDeliveryId,
  }) : assert(
         cubit == null || (gateway == null && pickerService == null),
         'Provide either a cubit or the (gateway, pickerService) pair, not both.',
       );

  final String deliveryId;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final ImageProvider? counterpartAvatarImage;
  final ChatFeeNotice? feeNotice;
  final String? composerHint;
  final VoidCallback? onStartActiveDelivery;
  final void Function(String deliveryId)? onTrackOrder;
  final ChatCubit? cubit;
  final ChatGateway? gateway;
  final PhotoPickerService? pickerService;

  /// JM-025 AC2: locked order summary strip.
  final OrderChatSummary? pinnedSummary;

  final VoidCallback? onViewSummary;
  final VoidCallback? onSummaryAttentionRefresh;
  final VoidCallback? onOpenDispute;

  /// JM-025: customer order-chat surface → `order_chat_composer_*` semantics ids.
  final bool isOrderChat;

  /// Whether the VIEWER is the Jeeber.
  final bool viewerIsJeeber;

  /// JM-025 AC1: one-shot broadcast, returns true if resolved.
  final Future<bool> Function(String requestId, String firstMessage)?
  onFirstMessageBroadcast;

  final String? initialTrackingDeliveryId;

  static const Key rootKey = Key('chat-screen-root');
  static const Key messageListKey = Key('chat-screen-message-list');
  static const Key emptyStateKey = Key('chat-screen-empty');

  /// b02: history-load FAILURE (distinct from empty).
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
        // b02: single push re-pulls THIS conversation via RefreshTopic.chat.
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
        onSummaryAttentionRefresh: onSummaryAttentionRefresh,
        onOpenDispute: onOpenDispute,
        isOrderChat: isOrderChat,
        viewerIsJeeber: viewerIsJeeber,
        onFirstMessageBroadcast: onFirstMessageBroadcast,
      ),
    );
  }

  /// DI-FIRST picker.
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
  final VoidCallback? onViewSummary;
  final VoidCallback? onSummaryAttentionRefresh;
  final VoidCallback? onOpenDispute;
  final bool isOrderChat;
  final bool viewerIsJeeber;

  final Future<bool> Function(String requestId, String firstMessage)?
  onFirstMessageBroadcast;

  @override
  State<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<_ChatScaffold> with ResumeRefetchMixin {
  final ScrollController _scrollController = ScrollController();
  bool _bannerDismissed = false;

  /// Guards one-shot broadcast.
  bool _broadcastFired = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// b02: refetch after backgrounding (cubit survives, its load() never re-runs).
  @override
  void onAppResumed() => context.read<ChatCubit>().refresh();

  void _scheduleScrollToBottom() {
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
    final phase = context.select<ChatCubit, ConversationPhase>(
      (c) => c.state.phase,
    );
    final showDispute =
        widget.onOpenDispute != null &&
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
      counterpartName: widget.counterpartName,
      onViewSummary: widget.onViewSummary,
      onSummaryAttentionRefresh: widget.onSummaryAttentionRefresh,
      isOrderChat: widget.isOrderChat,
      viewerIsJeeber: widget.viewerIsJeeber,
    );
  }

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
    _scheduleScrollToBottom();
    _maybeBroadcastFirstMessage(state);
    final error = state.error;
    if (error == null) return;
    final message = _messageFor(l10n, error);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    context.read<ChatCubit>().acknowledgeError();
  }

  void _maybeBroadcastFirstMessage(ChatState state) {
    final broadcast = widget.onFirstMessageBroadcast;
    if (broadcast == null || _broadcastFired) return;
    String? firstMessage;
    for (final m in state.messages) {
      if (m.isMine) {
        firstMessage = m.text;
        break;
      }
    }
    if (firstMessage == null) return;
    _broadcastFired = true;
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
        return null;
    }
  }
}

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
    this.onSummaryAttentionRefresh,
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
  final VoidCallback? onSummaryAttentionRefresh;
  final bool isOrderChat;
  final bool viewerIsJeeber;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingHistory) return const _ChatHistoryShimmer();
    // b02 TRAP: test FAILURE before emptiness. 500 leaves messages empty.
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
      if (summary != null)
        OrderChatPinnedSummary(
          summary: summary,
          counterpartName: counterpartName,
          onViewSummary: onViewSummary,
          onSummaryAttentionRefresh: onSummaryAttentionRefresh,
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
    // b02 TRAP: overflow. Non-flexible chrome + Expanded body. When keyboard shrinks viewport,
    // chrome height can exceed it → Expanded gets zero → overflow. BOUND chrome to max 40% viewport.
    // At normal scales bound is INERT; only engages when long description + fee + 2.0 scale stack.
    // TRAP: slot must NOT collapse to zero with START-DELIVERY CTA. Hoisting CTA OUT re-creates
    // original overflow. Keep CTA inside, add FLOOR for scroll to it.
    final hasStartDeliveryCta =
        showAcceptedBanner &&
        winnerName != null &&
        onStartActiveDelivery != null;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (header.isNotEmpty)
            _ChatHeaderSlot(
              maxHeight: math.max(
                hasStartDeliveryCta
                    ? math.min(
                        math.min(
                          kChatPinnedCtaReserve,
                          constraints.maxHeight / 3,
                        ),
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

/// Bounded chrome slot (scrollable degradation only at extreme text scales).
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

/// b02 TRAP: history read FAILED — distinguish from "no conversation yet".
/// 500 leaves messages empty so emptiness-first body renders "No conversation" over existing thread.
class _ChatHistoryErrorState extends StatelessWidget {
  const _ChatHistoryErrorState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
      // Only if first message has server timestamp (not 1970 fabrication).
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

/// Skeleton placeholder with OMDS list-loading primitive instead of spinner.
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
