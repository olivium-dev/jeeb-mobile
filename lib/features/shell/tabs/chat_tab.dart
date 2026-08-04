import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/previews/jeeb_preview.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  static const Key activeDeliveryCardKey = Key('chat-tab-active-delivery');

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  List<_ConversationSummary> _conversations = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final dio = getIt<Dio>();
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/requests',
        queryParameters: {'status': 'active', 'page': 1, 'pageSize': 20},
      );
      final items = response.data?['items'] as List? ?? [];
      final summaries = <_ConversationSummary>[];
      for (final raw in items) {
        if (raw is Map<String, dynamic>) {
          final convId = raw['conversationId'] as String?;
          if (convId == null || convId.isEmpty) continue;
          summaries.add(_ConversationSummary(
            requestId: raw['id'] as String? ?? '',
            conversationId: convId,
            title: raw['title'] as String? ?? 'Delivery',
            status: raw['status'] as String? ?? '',
            tier: raw['tier'] as String? ?? '',
          ));
        }
      }
      if (mounted) {
        setState(() {
          _conversations = summaries;
          _loading = false;
        });
      }
    } on DioException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantics = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    if (_loading) {
      return const Center(child: OmdsLoadingState());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: OmdsEmptyState(
          key: const Key('chat-tab-empty'),
          icon: Icons.chat_bubble_outline,
          title: l10n.chatTitle,
          subtitle: l10n.chatEmpty,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return InkWell(
          key: index == 0 ? ChatTab.activeDeliveryCardKey : null,
          onTap: () => GoRouter.of(context).pushNamed(
            'chat-detail',
            pathParameters: {'id': conv.chatRouteId},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.medium,
            ),
            child: Row(
              children: [
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
                    children: [
                      Text(
                        conv.title,
                        style: context.jeebText.cardTitle
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        conv.status,
                        style: context.jeebText.bodySmall
                            .copyWith(color: semantics.mutedText),
                      ),
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
        );
      },
    );
  }
}

class _ConversationSummary {
  const _ConversationSummary({
    required this.requestId,
    required this.conversationId,
    required this.title,
    required this.status,
    required this.tier,
  });

  final String requestId;
  final String conversationId;
  final String title;
  final String status;
  final String tier;

  String get chatRouteId => requestId.isNotEmpty ? requestId : conversationId;
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width — the tab fills a shell body in production.
const double _chatTabPhoneWidth = 390;

/// A row is a 40 pt avatar inside 16 pt vertical padding (~72 pt), so three of
/// them plus separators need ~230 pt; the rest is headroom for the EN 200%
const Size _chatTabListBox = Size(_chatTabPhoneWidth, 340);

/// `OmdsEmptyState` is an 80 pt icon over a headline and a subtitle, centred and
/// wrapped in 32 pt padding. Measured: it needs exactly 384 pt in the EN 200%
const Size _chatTabPlaceholderBox = Size(_chatTabPhoneWidth, 400);

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

/// A [Dio] that can only ever answer from [answer].
/// [SyncTransformer] replaces the default `FusedTransformer` so decoding can
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

/// A request that never answers — the load stays in flight forever.
Dio _chatTabStalledDio() => _chatTabCannedDio((RequestOptions options) {
      chatTabPreviewTransportLog.add('→ (never answers)');
      return Completer<ResponseBody>().future;
    });

/// One `/v1/requests` row. [conversationId] and [title] are optional because the
/// live gateway row omits BOTH — that omission is a state, not an accident.
Map<String, dynamic> _chatTabRow({
  required String id,
  String? conversationId,
  String? title,
  String status = 'InTransit',
  String tier = 'flash',
}) =>
    <String, dynamic>{
      'id': id,
      'conversationId': ?conversationId,
      'title': ?title,
      'status': status,
      'tier': tier,
      // Carried by the real row (see `dio_order_repository._parseOrder`) and
      'createdAt': '2026-08-01T09:14:00Z',
      'pickup': <String, dynamic>{'address': 'Hamra, Beirut'},
      'dropoff': <String, dynamic>{'address': 'Ashrafieh, Beirut'},
    };

/// Registers [dio] as the ambient gateway client for its subtree, or — when
/// [dio] is null — guarantees that NO client is registered.
/// Installation happens in `build`, not just `initState`, on purpose: the canvas
class _ChatTabGetItDioScope extends StatefulWidget {
  const _ChatTabGetItDioScope({required this.dio, required this.child});

  final Dio? dio;
  final Widget child;

  @override
  State<_ChatTabGetItDioScope> createState() => _ChatTabGetItDioScopeState();
}

class _ChatTabGetItDioScopeState extends State<_ChatTabGetItDioScope> {
  @override
  void dispose() {
    final GetIt getIt = GetIt.instance;
    final Dio? mine = widget.dio;
    if (mine != null &&
        getIt.isRegistered<Dio>() &&
        identical(getIt<Dio>(), mine)) {
      getIt.unregister<Dio>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GetIt getIt = GetIt.instance;
    if (getIt.isRegistered<Dio>()) {
      getIt.unregister<Dio>();
    }
    final Dio? dio = widget.dio;
    if (dio != null) {
      getIt.registerSingleton<Dio>(dio);
    }
    return widget.child;
  }
}

Widget _chatTabHosted(Dio? dio) =>
    _ChatTabGetItDioScope(dio: dio, child: const ChatTab());

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
  size: Size(_chatTabPhoneWidth, 200),
)
Widget chatTabLoading() => _chatTabHosted(_chatTabStalledDio());

/// The honest empty inbox: 200 with `{items: []}`.
/// `OmdsEmptyState` is the tab's whole surface here — 80 pt icon, headline,
@JeebPreview(
  group: 'shell',
  name: 'Empty · gateway returned none',
  size: _chatTabPlaceholderBox,
)
Widget chatTabEmpty() =>
    _chatTabHosted(_chatTabEnvelopeDio(const <Map<String, dynamic>>[]));

/// The gateway is down — and the tab cannot say so.
/// `_loadConversations` catches `DioException` and only flips `_loading` to
@JeebPreview(
  group: 'shell',
  name: 'Gateway 503 · reads as empty',
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

/// The contract mismatch, rendered: three active requests in, one row out.
/// The live `/v1/requests` row is `{id, createdAt, pickup, dropoff, status,
@JeebPreview(
  group: 'shell',
  name: 'Real row shape · 1 of 3 survives',
  size: _chatTabOneRowBox,
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

/// The layout ceiling: the longest title a real request produces, beside a raw
/// wire status.
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
