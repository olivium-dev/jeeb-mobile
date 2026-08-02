import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/previews/jeeb_preview.dart';

/// Entry-point for the chat experience.
///
/// Lists active conversations backed by the mock backend. Each card
/// corresponds to a delivery or request that has a linked conversation.
/// Tapping navigates to `/chat/:id` (handled by [ChatDetailScreen]).
// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; only conversations-inbox UX ever built — see docs/project-understanding/reconciliation/orphans.md
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
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: Spacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        conv.status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(DirectionalIcons.disclosure(context)),
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

  /// Request id (== correlationKey). Empty when the gateway omits it.
  final String requestId;
  final String conversationId;
  final String title;
  final String status;
  final String tier;

  /// BUG-18 client side: prefer the request id (== correlationKey) over the
  /// conversation id. Chat-detail resolves correlationKey-first, so routing by
  /// requestId avoids a guaranteed 404 probe; fall back to the conversationId
  /// only when the gateway omitted the request id.
  String get chatRouteId => requestId.isNotEmpty ? requestId : conversationId;
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/shell/chat_tab_preview_test.dart
// ===========================================================================
//
// **The seam.** [ChatTab] takes no repository and no cubit: it reaches into the
// service locator (`GetIt.instance<Dio>()`) from `initState`, GETs
// `/v1/requests?status=active`, and parses the envelope inline. The locator is
// therefore the only seam it offers, so every preview here mounts the tab under
// [_ChatTabGetItDioScope], which registers a [Dio] whose [HttpClientAdapter]
// answers from a canned map. Nothing opens a socket: the adapter is the
// transport, so the request never reaches `dart:io`. [jeebPreviewHost]'s
// `CatalogNetworkGuard` is, as always, the net rather than the plan.
//
// That the previews stay independent of each other is not luck. The tab
// resolves its client SYNCHRONOUSLY inside `initState` — `isRegistered<Dio>()`
// and `getIt<Dio>()` both run before the first `await` — so each tab captures
// the transport its own scope installed during the same depth-first mount pass,
// even when the canvas has six of them on screen at once.
// [_ChatTabGetItDioScope] re-installs on every build for the same reason (see
// its doc).
//
// **Fixture data.** [ChatTab] is an orphan (JEBV4-227: zero references, only
// the conversations-inbox UX was ever built) and has no widget test, so there
// is no existing fixture to lift. The envelope shape instead comes from the
// sibling consumer of the SAME endpoint, `dio_order_repository.dart`
// (`{items: [ {id, createdAt, pickup, dropoff, status, tier} ]}`), and the row
// titles from `test/features/home_client/in_progress_tab_test.dart`
// ("Pharmacy run" / "Grocery run"), so the previews and the rest of the app
// describe the same gateway.
//
// Three things these previews make visible, all of them in the widget rather
// than in the fixtures:
//
//  * `on DioException { _loading = false }` swallows the failure, so a 503
//    renders the SAME "No conversations yet." screen as a genuinely empty
//    inbox, with no retry affordance — see `Gateway 503 · reads as empty`;
//  * rows the gateway sends WITHOUT a `conversationId` are dropped silently,
//    and the real `/v1/requests` row carries neither `conversationId` nor
//    `title` — see `Real row shape · 1 of 3 survives`;
//  * `conv.status` and the `'Delivery'` title fallback are printed raw, so the
//    AR RTL rendering of every preview shows English wire tokens.

/// Phone width — the tab fills a shell body in production.
const double _chatTabPhoneWidth = 390;

/// A row is a 40 pt avatar inside 16 pt vertical padding (~72 pt), so three of
/// them plus separators need ~230 pt; the rest is headroom for the EN 200%
/// rendering to grow into before the `ListView` starts scrolling.
const Size _chatTabListBox = Size(_chatTabPhoneWidth, 340);

/// `OmdsEmptyState` is an 80 pt icon over a headline and a subtitle, centred and
/// wrapped in 32 pt padding. Measured: it needs exactly 384 pt in the EN 200%
/// rendering (and the same in AR), so anything shorter would make the FIXTURE
/// report a `RenderFlex` overflow that says nothing about the tab. 400 pt keeps
/// a little headroom over that.
const Size _chatTabPlaceholderBox = Size(_chatTabPhoneWidth, 400);

/// One row, with room for it to wrap at 200%.
const Size _chatTabOneRowBox = Size(_chatTabPhoneWidth, 240);

/// What the canned transport was asked for, and what it answered
/// (`'GET /v1/requests → 200 · 3 items'`). Dev-only diagnostics.
///
/// It exists because two of the states below are — by the widget's own design —
/// pixel-identical: a swallowed 503 and an empty inbox both render
/// "No conversations yet.". Text alone cannot tell those previews apart, so the
/// render test pins them here instead, at the transport. Not const-initialized
/// on purpose: it is appended to.
///
/// PUBLIC by necessity: `test/previews/shell/chat_tab_preview_test.dart` clears
/// and asserts on it. It is the one declaration below this banner that is not
/// a preview function and not private.
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
///
/// [SyncTransformer] replaces the default `FusedTransformer` so decoding can
/// never hop to an isolate, and no timeouts are set so a stalled answer leaves
/// no pending timer behind for the render test to trip over.
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
      // ignored by ChatTab. Present so the fixture is the gateway's envelope
      // rather than a shape only this widget would ever receive.
      'createdAt': '2026-08-01T09:14:00Z',
      'pickup': <String, dynamic>{'address': 'Hamra, Beirut'},
      'dropoff': <String, dynamic>{'address': 'Ashrafieh, Beirut'},
    };

/// Registers [dio] as the ambient gateway client for its subtree, or — when
/// [dio] is null — guarantees that NO client is registered.
///
/// Installation happens in `build`, not just `initState`, on purpose: the canvas
/// mounts many previews into one process against a single global locator, and a
/// tab whose element is recycled (scrolled out and back) re-reads `GetIt` at
/// that moment. Re-installing on every build keeps the right client registered
/// at the instant this subtree mounts or re-mounts. The registration is undone
/// on dispose, but only if it is still ours.
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
///
/// Three rows rather than one because what goes wrong in a list is the rhythm —
/// the hairline `Divider`, the 16 pt vertical padding, and the trailing
/// disclosure chevron lining up down the column. The chevron comes from
/// `DirectionalIcons.disclosure`, so the AR RTL rendering is where you check it
/// actually flipped to `chevron_left` instead of merely moving.
///
/// The third row deliberately arrives WITHOUT a `title`: the tab substitutes the
/// hardcoded literal `'Delivery'`, which stays English in the AR rendering.
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
///
/// Every session starts here, and the tab has no timeout of its own — if the
/// gateway never answers, this spinner IS the rest of the session. Held open by
/// an adapter that never completes, so it is the one preview that cannot be
/// pumped to settlement; its render test drives fixed frames instead.
///
/// What to check in the canvas: the indicator is centred in the tab rather than
/// pinned top-left, and it survives the AR RTL dark rendering (a spinner tinted
/// `colorScheme.primary` against the dark surface is easy to lose).
@JeebPreview(
  group: 'shell',
  name: 'Loading · request in flight',
  size: Size(_chatTabPhoneWidth, 200),
)
Widget chatTabLoading() => _chatTabHosted(_chatTabStalledDio());

/// The honest empty inbox: 200 with `{items: []}`.
///
/// `OmdsEmptyState` is the tab's whole surface here — 80 pt icon, headline,
/// subtitle, and no CTA — which makes it the state most exposed to the 200%
/// rendering: three stacked elements, centred, with no scroll of their own.
@JeebPreview(
  group: 'shell',
  name: 'Empty · gateway returned none',
  size: _chatTabPlaceholderBox,
)
Widget chatTabEmpty() =>
    _chatTabHosted(_chatTabEnvelopeDio(const <Map<String, dynamic>>[]));

/// The gateway is down — and the tab cannot say so.
///
/// `_loadConversations` catches `DioException` and only flips `_loading` to
/// false, so a 503 lands on the same `OmdsEmptyState` as a genuinely empty
/// inbox: same icon, same "No conversations yet.", no error copy, no retry, and
/// no pull-to-refresh (the body is a bare `ListView`/`Center`, never a
/// `RefreshIndicator`). Compare this rendering side by side with
/// `Empty · gateway returned none` — they are identical, which is the point.
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
///
/// The live `/v1/requests` row is `{id, createdAt, pickup, dropoff, status,
/// tier, amount}` — no `conversationId` and no `title` (see
/// `dio_order_repository._parseOrder`, which consumes the same endpoint). The
/// tab `continue`s past every row whose `conversationId` is null or empty, with
/// no counter and no diagnostic, so those two rows vanish. The one row that does
/// carry a conversation id has no title either, so it renders as the hardcoded
/// English `'Delivery'` — in Arabic too.
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
///
/// Three squeezes meet in this row and none of them can ellipsize — both `Text`s
/// are unconstrained (`maxLines` unset, no `overflow`), so at 200% they wrap and
/// grow the row instead of clipping, while the 40 pt `CircleAvatar` and the
/// chevron do NOT scale with the text. The status line is `conv.status` printed
/// verbatim: `'awaiting_jeeber_acceptance'` is what the user reads, untranslated
/// and unspaced, and it is the string most likely to wrap mid-token in the
/// narrow column left between the avatar and the chevron.
///
/// Measured while writing this preview: the GEOMETRY is sound. At 200% the row
/// grows to ~432 pt and the `ListView` scrolls rather than overflowing, and the
/// AR rendering mirrors properly — the avatar moves to the trailing (right)
/// edge and `DirectionalIcons.disclosure` really does flip to `chevron_left`.
/// What breaks in Arabic is the CONTENT, not the layout.
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
