import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/lifecycle/app_resume_signals.dart';
import '../../core/delivery/delivery_status_vocab.dart';
import '../../core/di/injection_container.dart';
import '../../core/diagnostics/diag.dart';
import '../../core/lifecycle/deferred_refresh_gate.dart';
import '../../core/formatting/friendly_reference.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/network/network_reachability_signals.dart';
import '../../core/notifications/domain/active_chat_thread.dart';
import '../../core/role/role_cubit.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import '../chat/application/order_compose_coordinator.dart';
import '../chat/data/dev_chat_fixture_gateway.dart';
import '../chat/data/dio_chat_gateway.dart';
import '../chat/data/dio_order_broadcast_service.dart';
import '../chat/data/dio_order_chat_summary_repository.dart';
import '../chat/data/firebase_custom_token_identity.dart';
import '../chat/data/firestore_chat_message_mapper.dart';
import '../chat/data/firestore_chat_realtime_source.dart';
import '../chat/data/gateway_chat_firebase_token_minter.dart';
import '../chat/data/in_memory_chat_gateway.dart';
import '../chat/data/realtime_chat_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/domain/chat_realtime_admission.dart';
import '../chat/domain/conversation_lookup.dart';
import '../chat/domain/delivery_chat_message.dart';
import '../chat/domain/order_broadcast_service.dart';
import '../chat/domain/order_chat_summary.dart';
import '../chat/presentation/chat_screen.dart';
import '../chat/presentation/widgets/chat_app_bar.dart';
import '../kyc/domain/cdn_asset_gateway.dart';
import '../otp_handover/domain/handover_code_store.dart';
import '../photo_attachment/data/stub_photo_picker_service.dart';
import '../photo_attachment/domain/photo_picker_service.dart';
import '../request_summary/data/dio_request_submission_service.dart';
import '../request_summary/domain/recipient_phone_resolver.dart';
import 'dev_chat_detail_fixtures.dart';


String _mutualRateRoute(String deliveryId, {required bool isClient}) =>
    '/orders/$deliveryId/mutual-rate${isClient ? '' : '?mode=jeeber'}';

const List<Duration> kChatResolutionRetryBackoff = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

const int kChatResolutionReconnectPreemptLimit = 4;

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.debugGateway,
    this.debugPhase,
    this.debugHasWinner = false,
    this.debugSummary,
    this.debugCounterpartName = '',
    this.refreshSignals,
  });

  final String chatId;

  final Stream<void>? refreshSignals;

  final ChatGateway? debugGateway;

  final ConversationPhase? debugPhase;

  final bool debugHasWinner;

  final OrderChatSummary? debugSummary;

  final String debugCounterpartName;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with RouteAware, ResumeRefetchMixin {
  String _resolvedConversationId = '';
  String _counterpartName = '';

  String _resolvedRequestId = '';

  ConversationPhase _phase = ConversationPhase.unknown;

  bool _hasWinner = false;

  OrderChatSummary? _summary;

  bool _resolvedIsJeeber = false;

  DeferredRefreshGate? _summaryRefreshGate;

  @visibleForTesting
  bool get debugSummaryRefreshArmed => _summaryRefreshGate != null;

  @visibleForTesting
  int get debugSummaryRefetchCount => _summaryRefetchCount;
  int _summaryRefetchCount = 0;

  @visibleForTesting
  int get debugSummaryFetchCount => _summaryFetchCount;
  int _summaryFetchCount = 0;

  bool _summaryRefreshInFlight = false;

  bool _ratingNavFired = false;

  ChatGateway? _gateway;

  DioChatGateway? _httpGateway;

  bool _loading = true;

  bool _resolutionUnavailable = false;

  @visibleForTesting
  bool get debugResolutionUnavailable => _resolutionUnavailable;

  Timer? _resolutionRetryTimer;

  int _resolutionRetryAttempt = 0;

  bool _resolutionRetryInFlight = false;

  int _resolutionRetryCount = 0;

  @visibleForTesting
  int get debugResolutionRetryCount => _resolutionRetryCount;

  StreamSubscription<void>? _reachabilitySub;

  @visibleForTesting
  int get debugReconnectPreemptCount => _reconnectPreemptCount;
  int _reconnectPreemptCount = 0;

  @visibleForTesting
  int get debugReconnectCoalescedCount => _reconnectCoalescedCount;
  int _reconnectCoalescedCount = 0;

  @override
  void initState() {
    super.initState();
    _reachabilitySub = NetworkReachabilitySignals.instance.stream.listen(
      (_) => _onNetworkReachable(),
    );
    final debugGateway = widget.debugGateway;
    if (debugGateway != null) {
      _finalize(
        widget.chatId,
        debugGateway,
        widget.debugCounterpartName,
        requestId: widget.chatId,
        phase: widget.debugPhase ?? ConversationPhase.unknown,
        hasWinner: widget.debugHasWinner,
        summary: widget.debugSummary,
      );
      return;
    }
    _resolveAndBuild();
  }

  @override
  void onAppResumed() {
    if (_summaryRefreshGate != null) unawaited(_refreshSummary());
    if (_resolutionUnavailable) _retryResolutionSilently();
  }


  bool _onScreen = false;

  Set<String> get _openThreadIds => <String>{
    widget.chatId,
    _resolvedConversationId,
    _resolvedRequestId,
  };

  void _publishOpenThread() {
    if (!_onScreen) return;
    ActiveChatThread.instance.enter(this, () => _openThreadIds);
  }

  RouteObserver<ModalRoute<void>>? _subscribedObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && _subscribedObserver == null) {
      _subscribedObserver = appRouteObserver..subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    ActiveChatThread.instance.leave(this);
  }

  @override
  void didPush() {
    _onScreen = true;
    _publishOpenThread();
    _summaryRefreshGate?.setPollingVisible(true);
  }

  @override
  void didPopNext() {
    _onScreen = true;
    _publishOpenThread();
    _summaryRefreshGate?.setPollingVisible(true);
    if (_summaryRefreshGate != null) unawaited(_refreshSummary());
  }

  @override
  void didPushNext() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
    _summaryRefreshGate?.setPollingVisible(false);
  }

  @override
  void didPop() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
    _summaryRefreshGate?.setPollingVisible(false);
  }

  @override
  void dispose() {
    _reachabilitySub?.cancel();
    _reachabilitySub = null;
    _subscribedObserver?.unsubscribe(this);
    ActiveChatThread.instance.leave(this);
    unawaited(_summaryRefreshGate?.dispose());
    _summaryRefreshGate = null;
    _cancelResolutionRetry();
    final gateway = _gateway;
    if (gateway is RealtimeChatGateway) {
      unawaited(gateway.dispose());
      unawaited(_httpGateway?.dispose());
    } else if (gateway is DioChatGateway) {
      unawaited(gateway.dispose());
    }
    _httpGateway = null;
    super.dispose();
  }

  Future<void> _resolveAndBuild() async {
    final devGateway = DevChatDetailFixtures.resolveGateway(widget.chatId);
    if (devGateway != null) {
      final devPhase = devGateway is DevChatFixtureGateway
          ? devGateway.phase
          : ConversationPhase.unknown;
      _finalize(
        widget.chatId,
        devGateway,
        '',
        phase: devPhase,
        hasWinner: devPhase == ConversationPhase.accepted,
      );
      return;
    }

    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) {
      debugPrint(
        '[chat-detail] Dio not registered — falling back to in-memory',
      );
      _finalize(widget.chatId, InMemoryChatGateway(), '');
      return;
    }

    final isJeeber = _readRole(context) == UserRole.jeeber;
    _resolvedIsJeeber = isJeeber;

    final dio = getIt<Dio>();
    final currentUserId = await _resolveSessionUserId(getIt);

    var conversationId = widget.chatId;
    Map<String, dynamic>? conversationData;

    Future<ConversationLookup> resolveByCorrelationKey() async {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          '/v1/conversations',
          queryParameters: <String, Object?>{'correlationKey': widget.chatId},
        );
        final data = resp.data;
        final resolvedId = _stringField(data, const [
          'id',
          'conversationId',
          'conversation_id',
        ]);
        if (data != null && resolvedId.isNotEmpty) {
          conversationData = data;
          conversationId = resolvedId;
          return ConversationLookup.resolved;
        }
        return ConversationLookup.absent;
      } on DioException catch (e) {
        return classifyLookupFailure(e);
      } catch (e) {
        return classifyLookupFailure(e);
      }
    }

    Future<ConversationLookup> resolveByMessagesProbe() async {
      try {
        await dio.get<dynamic>('/v1/conversations/$conversationId/messages');
        conversationData = <String, dynamic>{
          'id': conversationId,
          'phase': 'accepted',
        };
        return ConversationLookup.resolved;
      } on DioException catch (e) {
        return classifyLookupFailure(e);
      } catch (e) {
        return classifyLookupFailure(e);
      }
    }

    final isComposeSentinel =
        widget.chatId.isEmpty || widget.chatId == kComposeConversationSentinel;
    var lookup = ConversationLookup.absent;
    if (!isComposeSentinel) {
      lookup = await resolveByCorrelationKey();
      if (lookup != ConversationLookup.resolved) {
        final probe = await resolveByMessagesProbe();
        lookup = switch ((lookup, probe)) {
          (_, ConversationLookup.resolved) => ConversationLookup.resolved,
          (ConversationLookup.unavailable, _) ||
          (_, ConversationLookup.unavailable) => ConversationLookup.unavailable,
          _ => ConversationLookup.absent,
        };
      }
    }

    if (!mounted) return;
    if (lookup == ConversationLookup.unavailable) {
      setState(() {
        _resolutionUnavailable = true;
        _gateway = null;
        _loading = false;
      });
      _scheduleResolutionRetry();
      return;
    }

    final conversationResolved = conversationData != null;

    final title = await _resolveTitle(dio, conversationData);
    final resolvedRequestId = _stringField(conversationData, const [
      'requestId',
      'correlationKey',
      'request_id',
      'correlation_key',
    ]);
    final resolvedByCorrelationKey = resolvedRequestId.isNotEmpty;
    final requestId = resolvedByCorrelationKey
        ? resolvedRequestId
        : widget.chatId;
    final phase = ConversationPhase.fromWire(
      conversationData?['phase'] as String?,
    );
    final winnerId = _stringField(conversationData, const [
      'winnerJeeberId',
      'winner_jeeber_id',
    ]);
    final hasWinner = winnerId.isNotEmpty || _hasSeatedWinner(conversationData);
    final rosterVerdict = _rosterVerdict(conversationData);

    OrderChatSummary? summary;
    final shouldTrackSummary =
        resolvedByCorrelationKey &&
        (phase == ConversationPhase.accepted || hasWinner);
    if (shouldTrackSummary) {
      summary = await _resolveSummary(
        dio,
        requestId,
        conversationId,
        ownerScopedReads: !isJeeber,
      );
    }

    final gatewayConversationId = conversationResolved
        ? conversationId
        : kComposeConversationSentinel;
    final getItForGateway = GetIt.instance;
    final httpGateway = DioChatGateway(
      dio: dio,
      currentUserId: currentUserId,
      conversationCorrelationKey: requestId,
      handoverCodeStore: getItForGateway.isRegistered<HandoverCodeStore>()
          ? getItForGateway<HandoverCodeStore>()
          : null,
      assetGateway: getItForGateway.isRegistered<CdnAssetGateway>()
          ? getItForGateway<CdnAssetGateway>()
          : null,
    );
    if (!mounted) return;
    _finalize(
      gatewayConversationId,
      _wrapRealtime(
        httpGateway,
        dio,
        currentUserId,
        conversationId: gatewayConversationId,
        conversationResolved: conversationResolved,
        phase: phase,
        roster: rosterVerdict,
      ),
      title,
      requestId: requestId,
      phase: phase,
      hasWinner: hasWinner,
      summary: summary,
    );
    if (shouldTrackSummary &&
        !isJeeber &&
        !_isTerminalStatus(summary?.statusId)) {
      _armSummaryRefresh();
    }
  }

  ChatGateway _wrapRealtime(
    DioChatGateway inner,
    Dio dio,
    String currentUserId, {
    required String conversationId,
    required bool conversationResolved,
    required ConversationPhase phase,
    required ChatRosterVerdict roster,
  }) {
    if (!conversationResolved ||
        conversationId.isEmpty ||
        conversationId == kComposeConversationSentinel) {
      return inner;
    }
    if (currentUserId.isEmpty) return inner;
    if (!realtimeChatAdmitted(phase: phase, roster: roster)) {
      Diag.event('chat_realtime_contested_admitted', <String, Object?>{
        'conversation_id': conversationId,
        'reason': kRealtimeRefusedAuctionPhase,
        'phase': phase.name,
        'roster': roster.name,
      });
    }
    if (Firebase.apps.isEmpty) {
      Diag.event('chat_realtime_unavailable', <String, Object?>{
        'conversation_id': conversationId,
        'reason': 'no_firebase_app',
      });
      return inner;
    }
    _httpGateway = inner;
    return RealtimeChatGateway(
      inner: inner,
      realtime: FirestoreChatRealtimeSource(
        firestore: () => FirebaseFirestore.instance,
        identity: FirebaseCustomTokenIdentity(
          auth: FirebaseAuth.instance,
          minter: GatewayChatFirebaseTokenMinter(dio: dio),
          jeebUserId: currentUserId,
        ),
        mapper: FirestoreChatMessageMapper(currentUserId: currentUserId),
      ),
    );
  }

  Future<String> _resolveTitle(
    Dio dio,
    Map<String, dynamic>? conversationData,
  ) async {
    if (conversationData == null) return '';


    final winnerId = conversationData['winnerJeeberId'] as String?;
    if (winnerId != null && winnerId.isNotEmpty) {
      try {
        final resp = await dio.get<Map<String, dynamic>>('/users/$winnerId');
        return resp.data?['name'] as String? ?? '';
      } on DioException {
      }
    }

    return '';
  }

  Future<OrderChatSummary?> _resolveSummary(
    Dio dio,
    String requestId,
    String conversationId, {
    required bool ownerScopedReads,
  }) async {
    final summaryId = requestId.isNotEmpty ? requestId : conversationId;
    if (summaryId.isEmpty) return null;
    try {
      return await DioOrderChatSummaryRepository(
        dio,
        ownerScopedReads: ownerScopedReads,
      ).fetchSummary(summaryId);
    } on OrderChatSummaryException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void _armSummaryRefresh() {
    if (_summaryRefreshGate != null) return;
    final signals =
        widget.refreshSignals ??
        resolvePushRefreshStream(topics: const {RefreshTopic.order});
    if (signals == null) return;
    _summaryRefreshGate = DeferredRefreshGate(
      onRefresh: _refreshSummary,
      signals: signals,
      visible: _onScreen,
      debugLabel: 'ChatDetailScreen.summary',
    );
  }

  Future<void> _refreshSummary() async {
    if (!mounted) return;
    _summaryRefetchCount++;
    if (_summaryRefreshInFlight) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) return;
    _summaryRefreshInFlight = true;
    _summaryFetchCount++;
    final OrderChatSummary? next;
    try {
      next = await _resolveSummary(
        getIt<Dio>(),
        _resolvedRequestId,
        _resolvedConversationId,
        ownerScopedReads: !_resolvedIsJeeber,
      );
    } finally {
      _summaryRefreshInFlight = false;
    }
    if (!mounted || next == null) return;
    if (next != _summary) {
      setState(() => _summary = next);
    }
    if (_isDeliveredStatus(next.statusId)) {
      _navigateToRatingOnce();
    }
  }

  void _navigateToRatingOnce() {
    if (_ratingNavFired || !mounted) return;
    _ratingNavFired = true;
    final isJeeber = _readRole(context) == UserRole.jeeber;
    context.go(_mutualRateRoute(_deliveryId, isClient: !isJeeber));
  }

  static bool _isDeliveredStatus(String? statusId) =>
      DeliveryStatusVocab.isDelivered(statusId);

  static bool _isTerminalStatus(String? statusId) =>
      DeliveryStatusVocab.isTerminal(statusId);

  Future<String> _resolveSessionUserId(GetIt getIt) async {
    if (!getIt.isRegistered<AuthTokenStore>()) return '';
    try {
      return (await getIt<AuthTokenStore>().userId) ?? '';
    } catch (_) {
      return '';
    }
  }

  String _stringField(
    Map<String, dynamic>? data,
    List<String> keys, {
    String fallback = '',
  }) {
    if (data == null) return fallback;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  bool _hasSeatedWinner(Map<String, dynamic>? data) {
    final participants = data?['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
  }

  ChatRosterVerdict _rosterVerdict(Map<String, dynamic>? data) {
    final participants = data?['participants'];
    if (participants is! List) return ChatRosterVerdict.unknown;
    final rows = participants.whereType<Map>().toList(growable: false);
    if (rows.isEmpty) return ChatRosterVerdict.unknown;

    var seatedWinner = false;
    var liveBidder = false;
    for (final p in rows) {
      if (p['removed_at'] != null) continue;
      final raw = p['role_in_convo'];
      final role = raw is String ? raw.trim().toLowerCase() : '';
      if (role.startsWith('client') || role == 'admin' || role == 'support') {
        continue;
      }
      if (role.contains('winner')) {
        seatedWinner = true;
        continue;
      }
      liveBidder = true;
    }

    if (liveBidder) return ChatRosterVerdict.contested;
    return seatedWinner ? ChatRosterVerdict.settled : ChatRosterVerdict.unknown;
  }

  void _finalize(
    String conversationId,
    ChatGateway gateway,
    String title, {
    String requestId = '',
    ConversationPhase phase = ConversationPhase.unknown,
    bool hasWinner = false,
    OrderChatSummary? summary,
  }) {
    if (!mounted) return;
    setState(() {
      _resolvedConversationId = conversationId;
      _gateway = gateway;
      _counterpartName = title;
      _resolvedRequestId = requestId;
      _phase = phase;
      _hasWinner = hasWinner;
      _summary = summary;
      _loading = false;
      _resolutionUnavailable = false;
    });
    _cancelResolutionRetry();
  }

  UserRole _readRole(BuildContext context) {
    try {
      return context.read<RoleCubit>().state;
    } on ProviderNotFoundException {
      return UserRole.client;
    }
  }

  String get _deliveryId => _resolvedRequestId.isNotEmpty
      ? _resolvedRequestId
      : _resolvedConversationId;

  String _headerTitle(AppLocalizations l10n, bool isJeeber) {
    final resolved = displayNameOrNull(_counterpartName);
    if (resolved != null) return resolved;
    if (_phase == ConversationPhase.accepted || _hasWinner) {
      return isJeeber
          ? l10n.chatPartyCustomerFallback
          : l10n.chatPartyJeeberFallback;
    }
    final id = _resolvedRequestId.isNotEmpty
        ? _resolvedRequestId
        : widget.chatId;
    if (id.isEmpty || id == kComposeConversationSentinel) return l10n.navChat;
    return friendlyReference(id);
  }

  bool _isComposeState(bool isJeeber) =>
      !isJeeber &&
      !_hasWinner &&
      _phase != ConversationPhase.accepted &&
      _phase != ConversationPhase.closed;

  Future<bool> _createBroadcastAndGoWaiting(
    String routeId,
    String firstMessage,
  ) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) return false;
    final dio = getIt<Dio>();
    final coordinator = OrderComposeCoordinator(
      submission: DioRequestSubmissionService(
        dio,
        getIt<RecipientPhoneResolver>(),
      ),
      broadcast: _resolveBroadcastService(dio),
    );
    final existing = _resolvedRequestId.isNotEmpty
        ? _resolvedRequestId
        : routeId;
    final realId = await coordinator.createAndBroadcast(
      existingRequestId: existing,
      firstMessage: firstMessage,
    );
    if (realId == null) {
      if (mounted) {
        showOmdsErrorSnackbar(
          context,
          message: AppLocalizations.of(context).chatCreateRequestFailed,
        );
      }
      return false;
    }
    if (!mounted) return true;
    context.goNamed('waiting-no-coverage', pathParameters: {'id': realId});
    return true;
  }

  OrderBroadcastService _resolveBroadcastService(Dio dio) =>
      DioOrderBroadcastService(dio);

  PhotoPickerService _resolvePicker() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoPickerService>()) {
      return getIt<PhotoPickerService>();
    }
    return StubPhotoPickerService();
  }

  void _retryResolution() {
    if (!mounted) return;
    _cancelResolutionRetry();
    setState(() {
      _resolutionUnavailable = false;
      _loading = true;
    });
    unawaited(_resolveAndBuild());
  }

  void _scheduleResolutionRetry() {
    if (!mounted || !_resolutionUnavailable) return;
    _resolutionRetryTimer?.cancel();
    final step = _resolutionRetryAttempt < kChatResolutionRetryBackoff.length
        ? _resolutionRetryAttempt
        : kChatResolutionRetryBackoff.length - 1;
    final delay = kChatResolutionRetryBackoff[step];
    _resolutionRetryAttempt++;
    _resolutionRetryTimer = Timer(delay, _retryResolutionSilently);
  }

  void _retryResolutionSilently() {
    if (!mounted || !_resolutionUnavailable) return;
    if (_resolutionRetryInFlight) {
      _scheduleResolutionRetry();
      return;
    }
    _resolutionRetryInFlight = true;
    _resolutionRetryCount++;
    unawaited(
      _resolveAndBuild().whenComplete(() {
        _resolutionRetryInFlight = false;
        _scheduleResolutionRetry();
      }),
    );
  }

  void _cancelResolutionRetry() {
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = null;
    _resolutionRetryAttempt = 0;
    _reconnectPreemptCount = 0;
  }

  void _onNetworkReachable() {
    if (!mounted || !_resolutionUnavailable) return;
    if (_resolutionRetryInFlight) {
      _reconnectCoalescedCount++;
      Diag.event('chat_resolution_reconnect', <String, Object?>{
        'action': 'coalesced',
        'count': _reconnectCoalescedCount,
      });
      return;
    }
    if (_reconnectPreemptCount >= kChatResolutionReconnectPreemptLimit) {
      Diag.event('chat_resolution_reconnect', <String, Object?>{
        'action': 'budget_exhausted',
        'count': _reconnectPreemptCount,
      });
      return;
    }
    _reconnectPreemptCount++;
    Diag.event('chat_resolution_reconnect', <String, Object?>{
      'action': 'preempt',
      'count': _reconnectPreemptCount,
    });
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = null;
    _retryResolutionSilently();
  }

  Widget _buildResolutionError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isJeeber = _readRole(context) == UserRole.jeeber;
    return Semantics(
      identifier: 'chat_resolution_error',
      child: OmdsErrorStatePage(
        appBar: ChatAppBar(title: _headerTitle(l10n, isJeeber)),
        title: l10n.chatHistoryErrorTitle,
        message: l10n.chatHistoryErrorMessage,
        retryLabel: l10n.chatHistoryErrorRetry,
        onRetry: _retryResolution,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: OmdsLoadingState()));
    }
    if (_resolutionUnavailable) return _buildResolutionError(context);
    final isJeeber = _readRole(context) == UserRole.jeeber;
    final compose = _isComposeState(isJeeber);
    final isClientAccepted =
        !isJeeber && (_phase == ConversationPhase.accepted || _hasWinner);
    final isClientDisputable =
        !isJeeber &&
        !compose &&
        _phase != ConversationPhase.broadcasting &&
        _phase != ConversationPhase.closed;

    return ChatScreen(
      deliveryId: _resolvedConversationId,
      counterpartName: _headerTitle(AppLocalizations.of(context), isJeeber),
      gateway: _gateway!,
      pickerService: _resolvePicker(),
      isOrderChat: !isJeeber,
      viewerIsJeeber: isJeeber,
      onStartActiveDelivery: isJeeber
          ? () => context.push('/jeeber/deliveries/$_deliveryId/active')
          : null,
      onTrackOrder: isJeeber
          ? null
          : (deliveryId) => context.push('/orders/$deliveryId/tracking'),
      onFirstMessageBroadcast: compose
          ? (requestId, firstMessage) =>
                _createBroadcastAndGoWaiting(requestId, firstMessage)
          : null,
      pinnedSummary: _summary,
      onSummaryAttentionRefresh: isJeeber ? null : _refreshSummary,
      onViewSummary: isClientAccepted
          ? () => context.pushNamed(
              'order-summary',
              pathParameters: {'id': _deliveryId},
            )
          : null,
      onOpenDispute: isClientDisputable
          ? () => context.pushNamed(
              'escalate',
              pathParameters: {'id': _deliveryId},
            )
          : null,
    );
  }
}
