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
          counterpartName: counterpartName,
          counterpartAvatarUrl: counterpartAvatarUrl,
          counterpartAvatarImage: counterpartAvatarImage,
          feeNotice: feeNotice,
          composerHint: composerHint,
          onStartActiveDelivery: onStartActiveDelivery,
          onTrackOrder: onTrackOrder,
        ),
      );
    }
    return BlocProvider<ChatCubit>(
      create: (_) => ChatCubit(
        deliveryId: deliveryId,
        gateway: gateway ?? InMemoryChatGateway(),
        pickerService: pickerService ?? StubPhotoPickerService(),
      )..load(),
      child: _ChatScaffold(
        counterpartName: counterpartName,
        counterpartAvatarUrl: counterpartAvatarUrl,
        counterpartAvatarImage: counterpartAvatarImage,
        feeNotice: feeNotice,
        composerHint: composerHint,
        onStartActiveDelivery: onStartActiveDelivery,
        onTrackOrder: onTrackOrder,
      ),
    );
  }
}

class _ChatScaffold extends StatefulWidget {
  const _ChatScaffold({
    required this.counterpartName,
    this.counterpartAvatarUrl,
    this.counterpartAvatarImage,
    this.feeNotice,
    this.composerHint,
    this.onStartActiveDelivery,
    this.onTrackOrder,
  });

  final String counterpartName;
  final String? counterpartAvatarUrl;
  final ImageProvider? counterpartAvatarImage;
  final ChatFeeNotice? feeNotice;
  final String? composerHint;
  final VoidCallback? onStartActiveDelivery;
  final void Function(String deliveryId)? onTrackOrder;

  @override
  State<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<_ChatScaffold> {
  final ScrollController _scrollController = ScrollController();
  bool _bannerDismissed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    return Scaffold(
      key: ChatScreen.rootKey,
      appBar: ChatAppBar(
        title: widget.counterpartName,
        avatarUrl: widget.counterpartAvatarUrl,
        avatarImage: widget.counterpartAvatarImage,
        showAvatar: context.select<ChatCubit, bool>(
          (c) => c.state.showsCounterpartHeader,
        ),
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
    final error = state.error;
    if (error == null) return;
    final message = _messageFor(l10n, error);
    if (message != null) {
      showOmdsSnackbar(context, message: message);
    }
    context.read<ChatCubit>().acknowledgeError();
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

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingHistory) return const _ChatHistoryShimmer();
    final body = state.messages.isEmpty
        ? _ChatEmptyState(phase: state.phase, l10n: l10n)
        : _ChatMessageList(state: state, controller: scrollController);
    final notice = feeNotice;
    return Column(
      children: [
        if (notice != null) _FeeBannerSlot(notice: notice),
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
