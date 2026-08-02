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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/chat_detail_screen_fixtures.dart';
import '../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/deep_link_targets/chat_detail_screen_preview_test.dart
// ===========================================================================
//
// [ChatDetailScreen] is the `/chat/:id` deep-link target, not the conversation
// surface — [ChatScreen] is that, and it carries its own previews. What is
// reviewable HERE is the wiring this screen does above it: which header title
// it resolves out of a counterpart name that may be a synthetic handle, whether
// the thread lands in compose or accepted, and whether the pinned locked-price
// strip is fed.
//
// The states are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/chat_detail_screen_fixtures.dart` as
// [ChatDetailScreenPreviewState] descriptors, shared with the on-device Screen
// Catalog entry for this screen (`devtool/catalog/entries/batch_03_entries.dart`),
// so the designer's in-app browser and this canvas cannot drift. Read that
// file's header before editing these — in particular the note on which states
// are unreachable.
//
// [_chatDetailScreenHosted] below and `_chatDetail` in the catalog entry are
// the same two lines, deliberately not shared: the coverage detector
// (`tool/preview_inventory.dart`) grades a section that names a widget but
// never BUILDS it as MALFORMED, so a section that only called a factory in the
// fixtures library would report this screen as half-edited. The data — which
// gateway, which phase, which winner flag, which name, which summary — is what
// drifts, and that is single-sourced.
//
// Four things about this harness are worth knowing before editing it:
//
//  * **Every state goes through `debugGateway`.** That seam short-circuits the
//    whole async GetIt/Dio resolution in [_ChatDetailScreenState.initState], so
//    no preview ever constructs a [DioChatGateway], mints a Firebase token or
//    opens a Firestore listener. The guard in [jeebPreviewHost] is the net
//    here, not the plan.
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest, exactly as they do in the Screen Catalog, and that is why the
//    frame below is pinned in the TREE rather than left to the host: an
//    unpinned chat measures 800 pt in the render tests, where none of the
//    layout under review applies. Note the render surface is 800x600, so a
//    `SizedBox` asking for 844 is enforced down to what the host has.
//  * **TWO STATES OF THIS SCREEN CANNOT BE PREVIEWED AT ALL**, and their
//    absence is the point rather than an omission. The `_loading` spinner and
//    the `_resolutionUnavailable` error body (THE THIRD STATE — "we could not
//    find out", with the retry) both live on the async resolution path, and
//    `debugGateway` is a seam AROUND that path. Neither the catalog nor this
//    canvas can show the one body this screen was specifically written to own.
//  * **The JEEBER leg is missing for the same kind of reason.** The role is
//    read only from an ambient `RoleCubit`, and `RoleCubit` cannot be built
//    without a real [SharedPreferences] — async and plugin-backed, so no
//    preview function can produce one. The "Customer" header fallback and the
//    Start-delivery CTA are therefore unreviewable here; the role-aware wiring
//    is asserted instead in
//    `test/features/deep_link_targets/chat_detail_screen_role_aware_test.dart`.
//
// The states below are the three the Screen Catalog names, plus the six it does
// not that are the ones that break:
//
//   * **Empty vs failed vs fresh compose.** Three bodies that all render "there
//     is nothing here", from three completely different causes, and only one of
//     them is entitled to make a claim about server data. They are previewed
//     adjacently on purpose.
//   * **Loading.** The cold read in flight, under a fully resolved header — and
//     with no composer, because the whole body is replaced while it runs.
//   * **Unnamed counterpart.** Run-22 §T5: a synthetic `jeeb-<hash>` handle in
//     the header slot, which must be suppressed in favour of "Your Jeeber".
//   * **Longest content.** The tallest header this screen can stack (full
//     pinned strip + a long counterpart name beside the dispute action) over
//     the longest message a customer types.

/// The phone the order-chat is designed against (Figma 56535:6659).
const Size _chatDetailScreenPhoneBox = Size(390, 844);

/// Mounts one designed [ChatDetailScreenPreviewState] through the `debugGateway`
/// seam, pinned to a device-sized frame inside whatever box the host gives it.
Widget _chatDetailScreenHosted(ChatDetailScreenPreviewState state) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: _chatDetailScreenPhoneBox.width,
      height: _chatDetailScreenPhoneBox.height,
      child: ChatDetailScreen(
        chatId: state.chatId,
        debugGateway: state.gateway(),
        debugPhase: state.phase,
        debugHasWinner: state.hasWinner,
        debugCounterpartName: state.counterpartName,
        debugSummary: state.summary,
      ),
    ),
  );
}

/// JM-025 AC1 — the request is out and nothing has answered yet.
///
/// The composer is live and the header carries the short order reference
/// (`friendlyReference` of the route param), because there is no counterpart to
/// name yet. The next message the customer sends BROADCASTS the request rather
/// than posting into a conversation — this is the one state where that is true.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compose · no offers yet',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenCompose() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.compose);

/// The auction, open: the same request plus the offer cards that have landed.
///
/// **The offer cards overflow at this width, and the stripes are real.**
/// [OfferCardBubble] lays Accept + Decline out as a `Row(mainAxisSize: min)`
/// with no [Wrap] and no [Flexible] inside a bubble capped at 250 pt — a
/// pre-existing widget defect, measured and documented in that widget's own
/// preview library. The app ships 390, so widening this frame would only hide
/// it.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Broadcasting · offer cards landing',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenBroadcasting() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.broadcasting);

/// JM-025 AC2 — an offer was accepted.
///
/// The reference reading, and one of the two the matrix is for: the header
/// resolves the winner's real name, the pinned locked-price strip mounts above
/// the thread with every optional chip populated, and the dispute affordance
/// appears. In AR the whole strip mirrors and at 200% text its chips are what
/// run out of room first.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Accepted · pinned summary',
  size: _chatDetailScreenPhoneBox,
  matrix: true,
)
Widget chatDetailScreenAccepted() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.accepted);

/// Run-22 §T5 regression guard, made visible: the accepted counterpart's only
/// "name" on file is a synthetic account handle (`jeeb-e1a35ea8a520`).
///
/// The header must fall back to the role generic ("Your Jeeber") and NEVER
/// render the handle. Same code path as an empty name and a raw UUID, so this
/// one card guards all three. Read it directly against
/// [chatDetailScreenAccepted]: the only difference between the two is what the
/// app bar is allowed to say.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Accepted · unnamed counterpart',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenAcceptedUnnamed() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.acceptedUnnamed);

/// Fresh compose (Fix 5): the route param is the `new` sentinel, so there is no
/// backend conversation and both resolution probes are skipped entirely.
///
/// Two things are true only here — the header shows the Chat tab label, because
/// there is no real id to shorten into a reference; and the empty body reads
/// "No conversation yet" rather than either phase-specific empty. Read it
/// against [chatDetailScreenEmptyAccepted]: same shape, opposite meaning.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Fresh compose · no conversation yet',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenFreshCompose() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.freshCompose);

/// A read that SUCCEEDED and came back with zero rows on an accepted thread:
/// "Say hello".
///
/// This is the only one of the three empty-looking states entitled to make a
/// claim about the server's data.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Empty · accepted thread',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenEmptyAccepted() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.emptyAccepted);

/// The cold history read FAILED: error copy plus a retry, not an empty thread.
///
/// The pinned strip stays — the summary resolved even though the messages did
/// not — so the user can still see the order they are waiting on. That the two
/// reads fail independently is precisely why the body must not claim the thread
/// is empty.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'History load failed',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenHistoryFailed() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.historyFailed);

/// The cold read in flight: shimmer rows under a fully resolved header.
///
/// Note what is NOT on screen — no composer, because the body is replaced
/// wholesale while `isLoadingHistory` is set. It is also the state that cannot
/// settle ([OmdsListItemShimmer] repeats forever), so its render test drives
/// fixed pumps instead of `pumpAndSettle`.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Loading · cold history',
  size: _chatDetailScreenPhoneBox,
)
Widget chatDetailScreenLoadingHistory() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.loadingHistory);

/// Layout ceiling: the longest message a customer types, under the tallest
/// header this screen can stack.
///
/// Full pinned strip + a counterpart name long enough to contest the app bar
/// with the dispute action. Read the AR RTL and 200% renderings rather than the
/// English one — the English stays plausible long after the other two break.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Longest content',
  size: _chatDetailScreenPhoneBox,
  matrix: true,
)
Widget chatDetailScreenLongestContent() =>
    _chatDetailScreenHosted(ChatDetailScreenPreviewFixtures.longestContent);
