// BILATERAL EMPTY-THREAD regression.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../../support/sync_app_localizations.dart';

const _conversationId = 'conv-empty-thread';
const _customerId = 'user-customer-0001';
const _jeeberId = 'user-jeeber-0002';

// ---------------------------------------------------------------------------

Map<String, Object?> _textRow(String id, String author, String body) =>
    <String, Object?>{
      'message_id': id,
      'kind': 'text',
      'subtype': null,
      'author_id': author,
      'audience': null,
      'payload': null,
      'body': body,
    };

Map<String, Object?> _imageRow(String id, String author, String url) =>
    <String, Object?>{
      'message_id': id,
      'kind': 'image',
      'subtype': null,
      'author_id': author,
      'audience': null,
      'payload': <String, Object?>{'url': url},
      'body': null,
    };

/// A 12-row thread, alternating authors, mixing text and image — the same mix
/// the captured body had (36 text / 8 image across 2 authors).
List<Map<String, Object?>> _thread() => <Map<String, Object?>>[
      _textRow('srv-01', _customerId, 'row-01 customer'),
      _textRow('srv-02', _jeeberId, 'row-02 jeeber'),
      _imageRow('srv-03', _customerId, 'chat_attachment/a.jpg'),
      _textRow('srv-04', _jeeberId, 'row-04 jeeber'),
      _textRow('srv-05', _customerId, 'row-05 customer'),
      _textRow('srv-06', _jeeberId, 'row-06 jeeber'),
      _imageRow('srv-07', _jeeberId, 'chat_attachment/b.jpg'),
      _textRow('srv-08', _customerId, 'row-08 customer'),
      _textRow('srv-09', _jeeberId, 'row-09 jeeber'),
      _textRow('srv-10', _customerId, 'row-10 customer'),
      _textRow('srv-11', _jeeberId, 'row-11 jeeber'),
      _textRow('srv-12', _customerId, 'row-12 customer'),
    ];

/// Serves the three routes the chat client actually calls, from a mutable
/// in-memory thread. Rejects nothing — every read is a clean 200, which is the
/// whole point: the bug was never a transport failure.
class _ChatWire {
  _ChatWire({List<Map<String, Object?>>? initialRows})
      : rows = initialRows ?? _thread() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? body;
          // Both the full-history read and the (unused-in-prod) delta read
          if (options.method == 'GET' && path.contains('/messages')) {
            historyReads++;
            body = <String, Object?>{'messages': rows};
          } else if (path.endsWith('/messages')) {
            posts.add(options.data);
            body = <String, Object?>{'id': 'srv-posted-${posts.length}'};
          } else if (path == '/v1/conversations') {
            body = <String, Object?>{
              'phase': 'accepted',
              'participants': <Object?>[
                <String, Object?>{
                  'role_in_convo': 'jeeber_winner',
                  'removed_at': null,
                },
              ],
            };
          }
          handler.resolve(
            Response<dynamic>(
              data: body,
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
  }

  List<Map<String, Object?>> rows;
  late final Dio dio;
  int historyReads = 0;
  final List<Object?> posts = <Object?>[];
}

/// Never connects to anything — the WS transport is out of scope here and a
/// real socket must not be opened from a unit test.
class _DeadSocket implements ChatSocket {
  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();
  @override
  Stream<Object> get errors => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  void send(Map<String, Object?> envelope) {}
  @override
  Future<void> close() async {}
}

DioChatGateway _gateway(_ChatWire wire, {required String viewerId}) {
  final gateway = DioChatGateway(
    dio: wire.dio,
    currentUserId: viewerId,
    socketFactory: (_) => _DeadSocket(),
  );
  addTearDown(gateway.dispose);
  return gateway;
}

/// The push bus the cubit under test subscribes to. One per case.
late StreamController<void> _bus;

ChatCubit _cubit(DioChatGateway gateway) {
  _bus = StreamController<void>.broadcast();
  addTearDown(_bus.close);
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    clock: () => DateTime(2026, 7, 27, 12, 30),
    refreshSignals: _bus.stream,
  );
  addTearDown(cubit.close);
  return cubit;
}

Iterable<String> _ids(ChatCubit cubit) => cubit.state.messages.map((m) => m.id);

/// `pumpAndSettle` with a hard 10 s ceiling — a never-settling frame loop must
/// fail the test fast, not stall the suite.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );

void main() {
  // b02 P0: the resume bus is a process-wide singleton with a coalescing floor;
  setUp(() async => AppResumeSignals.debugReset());

  group('a timestamp-less 200 body renders as a thread, not as empty', () {
    test('STATE 1 (on open) — the jeeber decodes every row, in server order',
        () async {
      final wire = _ChatWire();
      final cubit = _cubit(_gateway(wire, viewerId: _jeeberId));

      await cubit.load();

      expect(
        cubit.state.messages, hasLength(12),
        reason: 'a 200 carrying 12 rows must decode to 12 messages; the bug '
            'decoded 0 of 44 on the device',
      );
      expect(
        _ids(cubit),
        wire.rows.map((r) => r['message_id']),
        reason: 'decoded order must be the server array order — the ordering '
            'anchor is derived from the wire position, so it must not fall '
            'back to the (random uuid) id tie-break',
      );
      expect(
        cubit.state.messages.every((m) => !m.hasServerTimestamp),
        isTrue,
        reason: 'every row here is timestamp-less: the messages render but no '
            'surface may claim a send time for them',
      );
      // Authorship still resolves from author_id vs the viewer.
      expect(cubit.state.messages.where((m) => m.isMine), hasLength(6));
    });

    test('STATE 1 (on open) — the customer decodes the same thread', () async {
      final wire = _ChatWire();
      final cubit = _cubit(_gateway(wire, viewerId: _customerId));

      await cubit.load();

      expect(cubit.state.messages, hasLength(12));
      expect(
        cubit.state.messages.where((m) => m.isMine), hasLength(6),
        reason: 'the bug was bilateral — both viewers decoded zero',
      );
    });

    // N4: was "STATE 2 (poll tick) — a safety-net poll neither loses nor
    test('STATE 2 (push re-pull) — a push-driven re-pull neither loses nor '
        'duplicates', () async {
      final wire = _ChatWire();
      final cubit = _cubit(_gateway(wire, viewerId: _jeeberId));

      await cubit.load();
      final afterLoad = _ids(cubit).toList();

      // The server gains one counterpart row while the thread is open.
      wire.rows = [..._thread(), _textRow('srv-13', _customerId, 'row-13')];
      _bus.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        wire.historyReads, greaterThan(1),
        reason: 'the push must have driven a re-pull for this to mean anything',
      );
      expect(_ids(cubit), [...afterLoad, 'srv-13']);
      expect(
        _ids(cubit).toSet(), hasLength(13),
        reason: 'the re-pull must not duplicate rows it has already merged',
      );
    });

    test(
      'STATE 3 (background → resume) — refresh keeps the thread AND the '
      "sender's own just-sent messages",
      () async {
        final wire = _ChatWire();
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
        );

        await cubit.load();
        expect(cubit.state.messages, hasLength(12));

        // The customer sends two messages. The server accepts them but has not
        cubit.composerChanged('own-message-A');
        await cubit.sendText();
        cubit.composerChanged('own-message-B');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(14));

        // Android `resumed` — the trigger that collapsed the thread on device.
        await cubit.refresh();

        expect(
          cubit.state.messages, hasLength(14),
          reason: 'refresh must not replace the thread with an empty/partial '
              'decode; this is the exact transition that blanked the device',
        );
        expect(
          cubit.state.messages.map((m) => m.text),
          containsAll(<String>['own-message-A', 'own-message-B']),
          reason: "the sender's own messages must stay visible in the sender's "
              'own thread even before the server echoes them',
        );
        expect(
          _ids(cubit).take(12),
          wire.rows.map((r) => r['message_id']),
          reason: 'server rows keep their order; un-echoed own bubbles trail '
              'them (they carry a real clock time, the rows do not)',
        );
      },
    );

    test(
      'STATE 3b — once the server echoes an own message under its own id, the '
      'optimistic bubble is absorbed rather than duplicated',
      () async {
        final wire = _ChatWire();
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
        );

        await cubit.load();
        cubit.composerChanged('own-message-A');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(13));

        // The server now returns that message, with a SERVER id that can never
        wire.rows = [
          ..._thread(),
          _textRow('srv-echo-A', _customerId, 'own-message-A'),
        ];

        await cubit.refresh();

        expect(
          cubit.state.messages, hasLength(13),
          reason: 'the echoed row replaces the optimistic bubble — 13, not 14',
        );
        expect(
          cubit.state.messages.where((m) => m.text == 'own-message-A'),
          hasLength(1),
        );
        expect(_ids(cubit), contains('srv-echo-A'));
      },
    );

    test(
      'STATE 4 (a push arrives) — an inbound message is added and nothing '
      'already rendered is lost',
      () async {
        // Scoped claim: no chat push path calls back into ChatCubit today
        final wire = _ChatWire();
        final cubit = _cubit(
          _gateway(wire, viewerId: _jeeberId),
        );

        await cubit.load();
        expect(cubit.state.messages, hasLength(12));

        wire.rows = [
          ..._thread(),
          _textRow('srv-pushed', _customerId, 'pushed message'),
        ];
        // A push wakes the thread; the refetch it triggers must ADD the pushed
        await cubit.refresh();

        expect(cubit.state.messages, hasLength(13));
        expect(_ids(cubit).last, 'srv-pushed');
      },
    );

    testWidgets(
      'STATE 1 + 3 on the real screen — ChatScreen shows bubbles, never the '
      'empty state, across a background → resume cycle',
      (tester) async {
        final wire = _ChatWire();
        // The screen owns the cubit here (production wiring): inside
        await tester.pumpWidget(
          wrapForTest(
            ChatScreen(
              deliveryId: _conversationId,
              counterpartName: 'Counterpart',
              gateway: _gateway(wire, viewerId: _jeeberId),
              pickerService: StubPhotoPickerService(),
            ),
          ),
        );
        await _settle(tester);

        expect(
          find.byKey(ChatScreen.emptyStateKey), findsNothing,
          reason: 'THE DEVICE SYMPTOM: a full thread rendered as the empty '
              'state for both participants',
        );
        expect(find.byKey(ChatScreen.messageListKey), findsOneWidget);
        // The list auto-scrolls to the newest message, so assert on rows that
        expect(find.text('row-12 customer'), findsOneWidget);
        expect(find.text('row-11 jeeber'), findsOneWidget);
        // No fabricated clock/date over timestamp-less rows.
        expect(find.textContaining('1970'), findsNothing);
        expect(find.text('00:00'), findsNothing);

        // b02 P0: a bare `inactive → resumed` is now a FOCUS FLAP that
        for (final s in const <AppLifecycleState>[
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(s);
          await tester.pump();
        }
        await _settle(tester);
        expect(
          wire.historyReads, greaterThan(1),
          reason: 'the resume must actually have re-read history, or the '
              'assertion below proves nothing',
        );

        expect(
          find.byKey(ChatScreen.emptyStateKey), findsNothing,
          reason: 'the resume-driven refresh is what collapsed the thread on '
              'device; it must leave it rendered',
        );
        expect(find.text('row-12 customer'), findsOneWidget);
        expect(find.text('row-11 jeeber'), findsOneWidget);
      },
    );
  });

  group('negative controls — these checks CAN go red', () {
    testWidgets(
      'a genuinely empty 200 still renders the empty state (so the '
      '"no empty state" assertion above is discriminating, not vacuous)',
      (tester) async {
        final wire = _ChatWire(initialRows: <Map<String, Object?>>[]);

        await tester.pumpWidget(
          wrapForTest(
            ChatScreen(
              deliveryId: _conversationId,
              counterpartName: 'Counterpart',
              gateway: _gateway(wire, viewerId: _jeeberId),
              pickerService: StubPhotoPickerService(),
            ),
          ),
        );
        await _settle(tester);

        expect(wire.historyReads, 1);
        expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
        expect(find.byKey(ChatScreen.messageListKey), findsNothing);
      },
    );

    test(
      'the decoder still rejects — and now COUNTS — a row with no identity, so '
      'relaxing the timestamp rule did not turn the validator into a no-op',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            // No message_id.
            <String, Object?>{
              'kind': 'text',
              'author_id': _customerId,
              'body': 'unidentifiable',
            },
            // No author_id.
            <String, Object?>{
              'message_id': 'srv-x',
              'kind': 'text',
              'body': 'authorless',
            },
            // Unknown kind.
            <String, Object?>{
              'message_id': 'srv-y',
              'author_id': _customerId,
              'kind': 'some_future_kind',
              'body': 'unknown kind',
            },
            _textRow('srv-ok', _customerId, 'the one good row'),
          ],
        );
        final gateway = _gateway(wire, viewerId: _jeeberId);

        final messages = await gateway.loadHistory(_conversationId);

        expect(
          messages.map((m) => m.id), ['srv-ok'],
          reason: 'identity and content are still required; only the timestamp '
              'rule was relaxed',
        );
      },
    );

    test(
      'a lossy decode is no longer silent: malformedCount survives to the '
      'delta batch instead of being swallowed as "empty conversation"',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            <String, Object?>{'kind': 'text', 'body': 'no identity'},
            _textRow('srv-ok', _customerId, 'good'),
          ],
        );
        final gateway = _gateway(wire, viewerId: _jeeberId);

        final batch = await gateway.loadHistorySince(_conversationId, 'cur-1');

        expect(batch.malformedCount, 1);
        expect(batch.messages, hasLength(1));
      },
    );
  });
}
