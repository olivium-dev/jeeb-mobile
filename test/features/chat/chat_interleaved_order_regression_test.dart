// INTERLEAVED-TRAFFIC ORDER regression (chat).
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _conversationId = 'conv-interleaved';
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

Map<String, Object?> _datedRow(
  String id,
  String author,
  String body,
  String createdAtUtc,
) =>
    <String, Object?>{
      ..._textRow(id, author, body),
      'created_at': createdAtUtc,
    };

/// Serves the routes the chat client calls, off a mutable in-memory thread.
/// Every read is a clean 200 — none of this is a transport failure.
class _ChatWire {
  _ChatWire({List<Map<String, Object?>>? initialRows})
      : rows = initialRows ?? <Map<String, Object?>>[] {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? body;
          if (options.method == 'GET' && path.contains('/messages')) {
            historyReads++;
            body = <String, Object?>{'messages': rows};
          } else if (path.endsWith('/messages')) {
            posts.add(options.data);
            body = <String, Object?>{'id': 'srv-posted-${posts.length}'};
          } else if (path.endsWith('/accept')) {
            accepts++;
            body = <String, Object?>{'deliveryId': 'del-accepted-1'};
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
  int accepts = 0;
  final List<Object?> posts = <Object?>[];
}

/// Never connects — the WS transport is out of scope; a unit test must not open
/// a real socket.
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

/// A clock the test advances by hand, so an optimistic bubble's send time is
/// deterministic relative to the wire timestamps.
class _TestClock {
  _TestClock(this._now);
  DateTime _now;
  DateTime call() => _now;
  set now(DateTime value) => _now = value;
}

/// The push bus the cubit under test subscribes to. One per case.
late StreamController<void> _bus;

ChatCubit _cubit(
  DioChatGateway gateway, {
  required _TestClock clock,
}) {
  _bus = StreamController<void>.broadcast();
  addTearDown(_bus.close);
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    clock: clock.call,
    refreshSignals: _bus.stream,
  );
  addTearDown(cubit.close);
  return cubit;
}

List<String> _texts(ChatCubit cubit) =>
    cubit.state.messages.map((m) => m.text).toList(growable: false);

/// Drives ONE history re-pull off the push bus and waits for it to land AND
/// merge. N4: the trigger moved from a 60 s clock to a push; the interleave
Future<void> _awaitPollTick(_ChatWire wire) async {
  final before = wire.historyReads;
  _bus.add(null);
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (wire.historyReads > before) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return;
    }
  }
  fail('a push drove no history re-pull; nothing below would prove anything');
}

void main() {
  group('T1 — counterpart traffic arriving AFTER an own send (the missing case)',
      () {
    test(
      'a reply the server ordered after my message renders after it, on the '
      'legacy timestamp-less wire',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        expect(cubit.state.messages, hasLength(1));

        // The customer sends. Only the optimistic bubble exists client-side.
        cubit.composerChanged('mine-1');
        await cubit.sendText();
        expect(_texts(cubit), <String>['row-01 jeeber', 'mine-1']);

        // The server persists it and the jeeber replies AFTER it — the reply is
        wire.rows = <Map<String, Object?>>[
          _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          _textRow('srv-echo-1', _customerId, 'mine-1'),
          _textRow('srv-reply-1', _jeeberId, 'reply-after-mine'),
        ];
        await _awaitPollTick(wire);

        final texts = _texts(cubit);
        final mineIndex = texts.indexOf('mine-1');
        final replyIndex = texts.indexOf('reply-after-mine');
        expect(mineIndex, isNonNegative, reason: 'own message must survive');
        expect(replyIndex, isNonNegative, reason: 'reply must be merged');
        expect(
          replyIndex, greaterThan(mineIndex),
          reason: 'THE DEFECT: the reply arrived after my send and the server '
              'array says so, but an undated row anchored at the epoch sorted '
              'above my real-clock bubble — the thread read "all of theirs, '
              'then all of mine" for the whole session',
        );
        expect(
          texts.where((t) => t == 'mine-1'), hasLength(1),
          reason: 'the own server echo must be ABSORBED onto the optimistic '
              'bubble, not appended as a second copy and not dropped',
        );
        expect(
          cubit.state.messages.map((m) => m.id), contains('srv-echo-1'),
          reason: 'absorbing the echo means adopting the SERVER id, which is '
              'what ties my message into the server sequence (and what later '
              'delivery/read receipts are keyed by)',
        );
      },
    );

    test(
      'the same three-way interleave on the DATED wire the gateway now emits: '
      'send A, reply B, send A again',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-01', _jeeberId, 'row-01 jeeber',
                '2026-07-27T12:00:00.1234567Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 5));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();

        cubit.composerChanged('a-1');
        await cubit.sendText();
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-a1', _customerId, 'a-1', '2026-07-27T12:05:02.5Z'),
          _datedRow('srv-b1', _jeeberId, 'b-1', '2026-07-27T12:06:00.75Z'),
        ];
        await _awaitPollTick(wire);

        clock.now = DateTime.utc(2026, 7, 27, 12, 7);
        cubit.composerChanged('a-2');
        await cubit.sendText();
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-a2', _customerId, 'a-2', '2026-07-27T12:07:02.25Z'),
        ];
        await _awaitPollTick(wire);

        expect(
          _texts(cubit),
          <String>['row-01 jeeber', 'a-1', 'b-1', 'a-2'],
          reason: 'THE DoD: with interleaved traffic the three sends render in '
              'the order they happened',
        );
        expect(
          cubit.state.messages.every((m) => m.hasServerTimestamp), isTrue,
          reason: 'every row on this wire is dated, and both own bubbles were '
              'reconciled onto their dated server echoes',
        );
        expect(
          cubit.state.messages.map((m) => m.id),
          <String>['srv-01', 'srv-a1', 'srv-b1', 'srv-a2'],
          reason: 'the poll must absorb the own echoes rather than drop them: '
              'dropping them is what left the optimistic bubbles pinned to the '
              'local clock',
        );
      },
    );

    test(
      'DISCRIMINATING CONTROL — when the server orders the reply BEFORE my '
      'message, that is what renders (the order check tracks the wire, it is '
      'not hardwired)',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        cubit.composerChanged('mine-1');
        await cubit.sendText();

        wire.rows = <Map<String, Object?>>[
          _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          _textRow('srv-reply-1', _jeeberId, 'reply-before-mine'),
          _textRow('srv-echo-1', _customerId, 'mine-1'),
        ];
        await _awaitPollTick(wire);

        final texts = _texts(cubit);
        expect(
          texts.indexOf('reply-before-mine'),
          lessThan(texts.indexOf('mine-1')),
        );
      },
    );
  });

  group('T1b — a slow device clock must not reorder the thread', () {
    test(
      'a message composed on a device whose clock runs 5 minutes behind still '
      'renders BELOW the reply that prompted it',
      () async {
        // Routing the optimistic append through the full chronological sort
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-01', _jeeberId, 'row-01',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 5));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        // A reply lands, stamped by the SERVER at 12:10 — ten minutes ahead of
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-b1', _jeeberId, 'their reply', '2026-07-27T12:10:00Z'),
        ];
        await cubit.refresh();
        expect(_texts(cubit), <String>['row-01', 'their reply']);

        cubit.composerChanged('my reply to their reply');
        await cubit.sendText();

        expect(
          _texts(cubit),
          <String>['row-01', 'their reply', 'my reply to their reply'],
          reason: 'the user composed this last and must see it last, whatever '
              'the device clock says',
        );

        // Once the server dates it, the server time is authoritative and the
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-a1', _customerId, 'my reply to their reply',
              '2026-07-27T12:11:00Z'),
        ];
        await cubit.refresh();
        expect(
          _texts(cubit),
          <String>['row-01', 'their reply', 'my reply to their reply'],
        );
        expect(cubit.state.messages.last.id, 'srv-a1');
      },
    );
  });

  group('T2 — the epoch anchor is retired', () {
    test(
      'no message in a rendered thread is anchored in 1970: undated rows sit '
      'immediately below the earliest REAL timestamp, in server order',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01'),
            _textRow('srv-02', _customerId, 'row-02'),
            _textRow('srv-03', _jeeberId, 'row-03'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        cubit.composerChanged('mine-1');
        await cubit.sendText();

        final undated = cubit.state.messages
            .where((m) => !m.hasServerTimestamp)
            .toList(growable: false);
        expect(
          undated, hasLength(3),
          reason: 'the three timestamp-less rows are still flagged as undated',
        );
        expect(
          undated.every((m) => m.sentAt.isBefore(clock())), isTrue,
          reason: 'monotonically BELOW the oldest local bubble',
        );
        expect(
          undated.every((m) => m.sentAt.year == 2026), isTrue,
          reason: 'THE FIX: the anchor is no longer pinned inside 1970-01-01 — '
              'that window is what put every undated row below every locally '
              'composed one and what leaked "1970"/"00:00" to any consumer '
              'that skipped the hasServerTimestamp check',
        );
        expect(
          _texts(cubit),
          <String>['row-01', 'row-02', 'row-03', 'mine-1'],
          reason: 'server array order is preserved inside the band, and the '
              'band stays below the un-echoed own bubble',
        );
      },
    );

    test(
      'HONESTY — an anchor that now LOOKS like a real 2026 instant still does '
      'not claim to be a send time',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        cubit.composerChanged('mine-1');
        await cubit.sendText();

        final row = cubit.state.messages.first;
        expect(row.text, 'row-01');
        expect(
          row.hasServerTimestamp, isFalse,
          reason: 'the FLAG, not the value of sentAt, is the discriminator; '
              'deriving honesty from a magic 1970 window is what forced the '
              'anchor to the epoch in the first place',
        );
      },
    );

    test(
      'DOCUMENTED LIMIT — when NOTHING in the thread is dated there is no '
      'reference point, so the band keeps its provisional anchors and only its '
      'relative order is meaningful',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01'),
            _textRow('srv-02', _jeeberId, 'row-02'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();

        expect(_texts(cubit), <String>['row-01', 'row-02']);
        expect(
          cubit.state.messages.every((m) => !m.hasServerTimestamp), isTrue,
          reason: 'no surface may read these anchors at all',
        );
      },
    );
  });

  group('T3 — acceptOffer must not destroy the thread', () {
    test(
      'a post-accept history read that decodes to NOTHING leaves the thread '
      "and the customer's own bubble intact",
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
          // Isolate the accept path: no poll tick may interleave.
        );

        await cubit.load();
        cubit.composerChanged('mine-1');
        await cubit.sendText();
        expect(cubit.state.messages, hasLength(2));

        // The accept resolves, but the history read that follows it decodes to
        wire.rows = <Map<String, Object?>>[];
        await cubit.acceptOffer('offer-1');

        expect(wire.accepts, 1, reason: 'the accept must have been issued');
        expect(
          cubit.state.messages, hasLength(2),
          reason: 'THE DEFECT: acceptOffer did messages: _ordered(history) — a '
              'full replace on the customer core path — so an empty decode '
              'blanked the thread and destroyed the own bubble',
        );
        expect(_texts(cubit), containsAll(<String>['row-01 jeeber', 'mine-1']));
        expect(cubit.state.acceptedDeliveryId, 'del-accepted-1');
      },
    );

    test(
      'acceptOffer still adopts the post-accept history and absorbs the own '
      'echo exactly once',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        cubit.composerChanged('mine-1');
        await cubit.sendText();

        wire.rows = <Map<String, Object?>>[
          _textRow('srv-01', _jeeberId, 'row-01 jeeber'),
          _textRow('srv-echo-1', _customerId, 'mine-1'),
          _textRow('srv-sys-1', _jeeberId, 'offer accepted'),
        ];
        await cubit.acceptOffer('offer-1');

        expect(
          _texts(cubit),
          <String>['row-01 jeeber', 'mine-1', 'offer accepted'],
          reason: 'the accept re-fetch is still adopted, in server order; the '
              'own bubble is absorbed by its echo rather than duplicated',
        );
        expect(cubit.state.messages, hasLength(3));
      },
    );

    test(
      'DISCRIMINATING CONTROL — a genuinely empty thread that never had any '
      'content still ends up empty after an accept',
      () async {
        final wire = _ChatWire();
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 30));
        final cubit = _cubit(
          _gateway(wire, viewerId: _customerId),
          clock: clock,
        );

        await cubit.load();
        await cubit.acceptOffer('offer-1');

        expect(
          cubit.state.messages, isEmpty,
          reason: 'the retain rule keeps what was SHOWN; it must not invent '
              'rows, or the assertions above would be vacuous',
        );
      },
    );
  });

  group('T4 — the decode diagnostic stays', () {
    test(
      'a lossy decode is still reported instead of looking like an empty '
      'conversation',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            <String, Object?>{'kind': 'text', 'body': 'no identity'},
            _textRow('srv-ok', _jeeberId, 'the one good row'),
          ],
        );
        final gateway = _gateway(wire, viewerId: _customerId);

        final batch = await gateway.loadHistorySince(_conversationId, 'cur-1');

        expect(batch.malformedCount, 1);
        expect(batch.messages, hasLength(1));
      },
    );
  });
}
