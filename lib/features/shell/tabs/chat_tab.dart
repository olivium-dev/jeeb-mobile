import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/network/network_reachability_signals.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/directional_icons.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/application/chat_conversations_cubit.dart';
import '../../chat/application/chat_conversations_state.dart';
import '../../chat/data/dio_chat_conversations_repository.dart';
import '../../chat/domain/chat_conversation_summary.dart';
import '../../order_history/domain/order_summary.dart' show OrderRequestStatus;

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/chat_tab_fixtures.dart';

/// The chat inbox. The read lives in a repository and its failures own a rung
/// of their own — a 503 used to reach the user as "No conversations yet".
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, this.repository, this.cubit});

  static const Key activeDeliveryCardKey = Key('chat-tab-active-delivery');

  /// Test/preview seam. Null resolves through DI.
  final ChatConversationsRepository? repository;

  /// Preview seam for a state the widget cannot reach from a cold load alone
  /// (a warm refresh failure over rendered rows).
  final ChatConversationsCubit? cubit;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  /// R2 seam: Stage 2 registers [ChatConversationsRepository] in the
  /// composition root; until then the Dio fallback keeps the tab working.
  ChatConversationsRepository? _resolveRepository() {
    final ChatConversationsRepository? provided = widget.repository;
    if (provided != null) return provided;
    final GetIt getIt = GetIt.instance;
    if (getIt.isRegistered<ChatConversationsRepository>()) {
      return getIt<ChatConversationsRepository>();
    }
    if (getIt.isRegistered<Dio>()) {
      return DioChatConversationsRepository(getIt<Dio>());
    }
    // SHELL-06: unresolvable DI is a FAILURE, never an empty inbox.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ChatConversationsCubit? provided = widget.cubit;
    if (provided != null) {
      return BlocProvider<ChatConversationsCubit>.value(
        value: provided,
        child: const _ChatTabBody(),
      );
    }
    return BlocProvider<ChatConversationsCubit>(
      create: (_) => ChatConversationsCubit(
        _resolveRepository(),
        reachableSignals: NetworkReachabilitySignals.instance.stream,
        resumeSignals: AppResumeSignals.instance.stream,
      )..load(),
      child: const _ChatTabBody(),
    );
  }
}

class _ChatTabBody extends StatelessWidget {
  const _ChatTabBody();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ChatConversationsCubit cubit =
        context.read<ChatConversationsCubit>();
    return BlocBuilder<ChatConversationsCubit, ChatConversationsState>(
      builder: (BuildContext context, ChatConversationsState state) {
        if (state.status == ChatConversationsStatus.loading ||
            state.status == ChatConversationsStatus.initial) {
          return JeebStateHost(
            child: JeebEmptyState(
              reason: JeebEmptyStateReason.loading,
              variant: JeebEmptyStateVariant.e1,
              identifier: 'chat_tab_loading',
              headline: l10n.chatTabLoadingHeadline,
            ),
          );
        }
        // Error BEFORE empty: a read that did not come back is not evidence
        // that there is nothing to see.
        if (state.status == ChatConversationsStatus.failed) {
          return JeebStateHost(
            onRefresh: cubit.load,
            child: JeebFailureBlock(
              failure: state.error!,
              identifier: 'chat_tab_error',
              variant: JeebEmptyStateVariant.e1,
              onRetry: cubit.load,
            ),
          );
        }
        if (state.conversations.isEmpty) {
          return JeebStateHost(
            onRefresh: cubit.refresh,
            child: JeebEmptyState(
              reason: JeebEmptyStateReason.nothingYet,
              variant: JeebEmptyStateVariant.e1,
              identifier: 'chat_tab_empty',
              headline: l10n.chatTabEmptyTitle,
              body: l10n.chatTabEmptyBody,
            ),
          );
        }
        return JeebPullToRefresh(
          onRefresh: cubit.refresh,
          child: CustomScrollView(
            slivers: <Widget>[
              if (state.refreshError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.medium,
                      Spacing.small,
                      Spacing.medium,
                      0,
                    ),
                    child: JeebRefreshFailedNote(
                      failure: state.refreshError!,
                      identifier: 'chat_tab_refresh_error',
                      onDismiss: cubit.clearRefreshError,
                      onRetry: cubit.refresh,
                    ),
                  ),
                ),
              if (state.skippedRows > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.medium,
                      Spacing.small,
                      Spacing.medium,
                      0,
                    ),
                    child: JeebInfoNote.error(
                      icon: Icons.error_outline,
                      text: l10n.chatPartialLoadBody,
                      identifier: 'chat_tab_partial_note',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.small),
                sliver: SliverList.separated(
                  itemCount: state.conversations.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) =>
                      _ChatTabRow(
                    conversation: state.conversations[index],
                    rowKey: index == 0 ? ChatTab.activeDeliveryCardKey : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatTabRow extends StatelessWidget {
  const _ChatTabRow({required this.conversation, this.rowKey});

  final ChatConversationSummary conversation;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    final String? statusLabel = _statusLabel(l10n, conversation.status);
    return Semantics(
      identifier: 'chat_tab_row_${conversation.chatRouteId}',
      button: true,
      container: true,
      child: InkWell(
        key: rowKey,
        onTap: () => GoRouter.of(context).pushNamed(
          'chat-detail',
          pathParameters: <String, String>{'id': conversation.chatRouteId},
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.medium,
          ),
          child: Row(
            children: <Widget>[
              // Raised-navy disc with a periwinkle glyph — a list marker is
              // not the tile's orange act.
              CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Spacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      conversation.title ?? l10n.chatConversationFallbackTitle,
                      style: context.jeebText.cardTitle
                          .copyWith(color: colorScheme.onSurface),
                    ),
                    if (statusLabel != null) ...<Widget>[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        statusLabel,
                        style: context.jeebText.bodySmall
                            .copyWith(color: semantics.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                DirectionalIcons.disclosure(context),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Localized status, or null for a token we do not recognise — an unknown
  /// status hides the subtitle rather than printing the wire word.
  String? _statusLabel(AppLocalizations l10n, OrderRequestStatus status) =>
      switch (status) {
        OrderRequestStatus.pending => l10n.orderHistoryStatusPending,
        OrderRequestStatus.matched => l10n.orderHistoryStatusMatched,
        OrderRequestStatus.pickedUp => l10n.orderHistoryStatusPickedUp,
        OrderRequestStatus.enRoute => l10n.orderHistoryStatusEnRoute,
        OrderRequestStatus.delivered => l10n.orderHistoryStatusDelivered,
        OrderRequestStatus.cancelled => l10n.orderHistoryStatusCancelled,
        OrderRequestStatus.disputed => l10n.orderHistoryStatusDisputed,
        OrderRequestStatus.unknown => null,
      };
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED: preview canvas + preview tests only.

/// Phone width — the tab fills a shell body in production.
const double _chatTabPhoneWidth = 390;

/// Three ~72 pt rows plus separators need ~230 pt; the rest is headroom for
/// the EN 200% text-scale wrap.
const Size _chatTabListBox = Size(_chatTabPhoneWidth, 340);

/// The failure/empty rungs draw a full illustration over two lines and a CTA,
/// so they need the whole board height rather than a placeholder strip.
const Size _chatTabPlaceholderBox = Size(_chatTabPhoneWidth, 620);

/// One row, with room for it to wrap at 200%.
const Size _chatTabOneRowBox = Size(_chatTabPhoneWidth, 240);

/// What the canned transport was asked for, and what it answered
/// (`'GET /v1/requests → 200 · 3 items'`). Dev-only diagnostics.
final List<String> chatTabPreviewTransportLog = List<String>.empty(
  growable: true,
);

/// Serves one canned answer per request, recording it in
/// [chatTabPreviewTransportLog]. No socket, no DNS, no `dart:io`.
class _ChatTabCannedAdapter implements HttpClientAdapter {
  _ChatTabCannedAdapter(this._answer);

  final Future<ResponseBody> Function(RequestOptions options) _answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    chatTabPreviewTransportLog.add('${options.method} ${options.path}');
    return _answer(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A [Dio] that can only ever answer from [answer]. [SyncTransformer] replaces
/// `FusedTransformer` so decoding stays on this isolate.
Dio _chatTabCannedDio(
  Future<ResponseBody> Function(RequestOptions options) answer,
) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://preview.invalid'))
    ..httpClientAdapter = _ChatTabCannedAdapter(answer)
    ..transformer = SyncTransformer();
  return dio;
}

/// A `{items: [...]}` envelope, served with the JSON content type the tab's
/// `Map<String, dynamic>` response type needs.
Dio _chatTabEnvelopeDio(
  List<Map<String, dynamic>> items, {
  int statusCode = 200,
}) =>
    _chatTabCannedDio((RequestOptions options) async {
      chatTabPreviewTransportLog.add('→ $statusCode · ${items.length} items');
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'items': items}),
        statusCode,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    });

/// One `/v1/requests` row. [conversationId] and [title] are optional because the
/// live gateway row omits BOTH — that omission is a state, not an accident.
Map<String, dynamic> _chatTabRow({
  String? id,
  String? conversationId,
  String? title,
  String status = 'InTransit',
  String tier = 'flash',
}) =>
    <String, dynamic>{
      'id': ?id,
      'conversationId': ?conversationId,
      'title': ?title,
      'status': status,
      'tier': tier,
      // Carried by the real row (see `dio_order_repository._parseOrder`) and
      'createdAt': '2026-08-01T09:14:00Z',
      'pickup': <String, dynamic>{'address': 'Hamra, Beirut'},
      'dropoff': <String, dynamic>{'address': 'Ashrafieh, Beirut'},
    };

/// Hosts the tab over a canned transport. A null [dio] is the DI-missing case:
/// no repository resolves, so the tab must raise its failure rung.
Widget _chatTabHosted(Dio? dio) => ChatTab(
      repository: dio == null ? null : DioChatConversationsRepository(dio),
    );

/// The happy path the widget was written for: three live conversations.
/// Three rows rather than one because what goes wrong in a list is the rhythm —
@JeebPreview(
  group: 'shell',
  name: 'Three conversations',
  size: _chatTabListBox,
)
Widget chatTabThreeConversations() => _chatTabHosted(
      _chatTabEnvelopeDio(<Map<String, dynamic>>[
        _chatTabRow(
          id: 'req-8841',
          conversationId: 'conv-8841',
          title: 'Pharmacy run',
        ),
        _chatTabRow(
          id: 'req-8842',
          conversationId: 'conv-8842',
          title: 'Grocery run',
          status: 'Accepted',
          tier: 'express',
        ),
        _chatTabRow(
          id: 'req-8843',
          conversationId: 'conv-8843',
          status: 'AtDoor',
          tier: 'standard',
        ),
      ]),
    );

/// The cold frame: `GET /v1/requests` is still in flight.
/// Every session starts here, and the tab has no timeout of its own — if the
@JeebPreview(
  group: 'shell',
  name: 'Loading · request in flight',
  size: _chatTabPlaceholderBox,
)
Widget chatTabLoading() {
  chatTabPreviewTransportLog
    ..add('GET /v1/requests')
    ..add('→ (never answers)');
  return ChatTab(repository: ChatTabPreviewFixtures.loading());
}

/// The honest empty inbox: 200 with `{items: []}`.
@JeebPreview(
  group: 'shell',
  name: 'Empty · gateway returned none',
  size: _chatTabPlaceholderBox,
)
Widget chatTabEmpty() =>
    _chatTabHosted(_chatTabEnvelopeDio(const <Map<String, dynamic>>[]));

/// The gateway is down, and the tab now SAYS so.
/// This preview's whole point used to be that a 503 read as an empty inbox.
@JeebPreview(
  group: 'shell',
  name: 'Gateway 503 · failure block',
  size: _chatTabPlaceholderBox,
)
Widget chatTabGatewayError() => _chatTabHosted(
      _chatTabEnvelopeDio(
        <Map<String, dynamic>>[
          _chatTabRow(
            id: 'req-8841',
            conversationId: 'conv-8841',
            title: 'Pharmacy run',
          ),
        ],
        statusCode: 503,
      ),
    );

/// The real row shape: the live `/v1/requests` row omits `conversationId`, and
/// every one of those rows is now routable on its request id (SHELL-02).
@JeebPreview(
  group: 'shell',
  name: 'Real row shape · 3 of 3 survive',
  size: _chatTabListBox,
)
Widget chatTabRealRowShape() => _chatTabHosted(
      _chatTabEnvelopeDio(<Map<String, dynamic>>[
        _chatTabRow(id: 'req-9001', status: 'Ordered'),
        _chatTabRow(id: 'req-9002', conversationId: '', status: 'PickedUp'),
        _chatTabRow(
          id: 'req-9003',
          conversationId: 'conv-9003',
          status: 'InTransit',
        ),
      ]),
    );

/// The layout ceiling: the longest title a real request produces, beside a
/// status token the app does not recognise (which draws NO subtitle).
@JeebPreview(
  group: 'shell',
  name: 'Long title + raw status',
  size: _chatTabOneRowBox,
)
Widget chatTabLongContent() => _chatTabHosted(
      _chatTabEnvelopeDio(<Map<String, dynamic>>[
        _chatTabRow(
          id: 'req-9100',
          conversationId: 'conv-9100',
          title: 'Prescription refill from Pharmacie Al-Muhandis Ashrafieh',
          status: 'awaiting_jeeber_acceptance',
        ),
      ]),
    );

/// One row carried NEITHER id, so it is unroutable and dropped — and the tab
/// says how many rather than silently shortening the list.
@JeebPreview(
  group: 'shell',
  name: 'Partial load · 1 row unroutable',
  size: _chatTabListBox,
)
Widget chatTabPartialLoad() => _chatTabHosted(
      _chatTabEnvelopeDio(<Map<String, dynamic>>[
        _chatTabRow(
          id: 'req-9200',
          conversationId: 'conv-9200',
          title: 'Pharmacy run',
        ),
        _chatTabRow(status: 'InTransit'),
      ]),
    );

/// The WARM failure: rows are on screen, the re-read failed, and the rows stay.
@JeebPreview(
  group: 'shell',
  name: 'Refresh failed over rows',
  size: _chatTabListBox,
)
Widget chatTabRefreshFailed() {
  final ChatConversationsCubit cubit = ChatConversationsCubit(
    ChatTabPreviewFixtures.refreshFailed(),
  );
  chatTabPreviewTransportLog.add('GET /v1/requests');
  unawaited(cubit.load().then((_) => cubit.refresh()));
  return ChatTab(cubit: cubit);
}
