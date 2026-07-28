// LATE-COUNTERPART-ROW ORDER regression (chat).
//
// THE TRADE THIS FILE POLICES. `ChatCubit._anchorAfter` gives a freshly
// composed draft an ordering position. It was written as:
//
//     return newest == null ? draft.sentAt : newest.add(_anchorStep);
//
// — one microsecond past the newest dated row CURRENTLY ON SCREEN. That pins a
// draft to what the DEVICE HAS SEEN, not to when it was composed, and the two
// are not the same thing. The chat safety-net poll was demoted from 5s to 60s
// (`kChatHistorySafetyNetPollInterval`), so a row the server dated between the
// last fetch and compose time is unseen for up to SIXTY SECONDS. Every such row
// then sorts BELOW the draft, because the draft was anchored to a moment before
// the counterpart even spoke.
//
// That is strictly worse than what it replaced. The bug it fixed needs a SKEWED
// device clock to fire; this one fires on a PERFECTLY CORRECT one, on the
// ordinary "they typed while I was typing" path, every single time.
//
// THE FIX: the newest row on screen is a FLOOR, not a pin. A draft is ordered by
// the local clock, but never earlier than one step past what is already
// rendered:
//
//     max(newestOnScreen + _anchorStep, draft.sentAt)
//
// Both defects are then closed at once, and the floor is what closes the skew
// one: a device running slow cannot pull its draft above traffic it has already
// rendered, because the floor dominates. A device running normally orders by its
// own clock, so a counterpart row the server dated BEFORE the compose instant
// sorts above the draft, which is what actually happened.
//
// WHY THE EXISTING SUITE WAS GREEN WHILE THIS WAS LIVE:
// `chat_interleaved_order_regression_test.dart` T1b covers the SLOW-CLOCK
// direction only, and every other case lets the server echo the own bubble
// before checking order — an echoed bubble is ordered by the server's own
// timestamp and the anchor stops mattering. The case below keeps the draft
// UN-ECHOED (a 60s poll gap is exactly that window) and dates the counterpart
// row inside the gap. It is RED before the fix.
//
// Everything here runs through the REAL `DioChatGateway` decode and the REAL
// `ChatCubit` merge paths, off raw wire bodies. Ids/authors are synthetic.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _conversationId = 'conv-late-row';
const _customerId = 'user-customer-0001';
const _jeeberId = 'user-jeeber-0002';

Map<String, Object?> _datedRow(
  String id,
  String author,
  String body,
  String createdAtUtc,
) =>
    <String, Object?>{
      'message_id': id,
      'kind': 'text',
      'subtype': null,
      'author_id': author,
      'audience': null,
      'payload': null,
      'body': body,
      'created_at': createdAtUtc,
    };

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

class _TestClock {
  _TestClock(this._now);
  DateTime _now;
  DateTime call() => _now;
  set now(DateTime value) => _now = value;
}

ChatCubit _cubit(DioChatGateway gateway, {required _TestClock clock}) {
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    // Every fold is driven explicitly by `refresh()`. The REAL cadence is 60s,
    // which is the whole point: the window in which the device has not yet seen
    // a counterpart row is a minute wide, not a tick wide.
    clock: clock.call,
  );
  addTearDown(cubit.close);
  return cubit;
}

List<String> _texts(ChatCubit cubit) =>
    cubit.state.messages.map((m) => m.text).toList(growable: false);

void main() {
  group('D — a counterpart row the server dated BEFORE my message renders '
      'BEFORE it', () {
    test(
      'their 10:30:30 message, unseen inside the 60s poll gap, sorts above my '
      '10:31 draft',
      () async {
        // On screen: one message of theirs, dated 10:30.
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-them-1', _jeeberId, 'seen at 10:30',
                '2026-07-27T10:30:00Z'),
          ],
        );
        // The device clock is CORRECT — no skew anywhere in this case. That is
        // what makes this defect worse than the one it replaced. The read
        // happens at 10:30, agreeing with the server to the second.
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 10, 30));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        expect(_texts(cubit), <String>['seen at 10:30']);

        // A MINUTE PASSES — one whole safety-net poll interval, the window the
        // 5s → 60s demotion opened. I compose at 10:31. Unknown to this device,
        // they already sent something at 10:30:30, inside that gap, so it is
        // not on screen.
        clock.now = DateTime.utc(2026, 7, 27, 10, 31);
        cubit.composerChanged('my reply at 10:31');
        await cubit.sendText();

        // The next fold reveals it. My send is still UN-ECHOED, so its anchor
        // is what orders it — which is exactly the state a 60s gap leaves.
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-them-2', _jeeberId, 'late 10:30:30',
              '2026-07-27T10:30:30Z'),
        ];
        await cubit.refresh();

        expect(
          _texts(cubit),
          <String>['seen at 10:30', 'late 10:30:30', 'my reply at 10:31'],
          reason: 'THE DEFECT: the draft was pinned to the newest row ON SCREEN '
              '(10:30) + 1us instead of to the clock it was composed on '
              '(10:31), so a message the counterpart sent BEFORE mine rendered '
              'AFTER it — on a correct clock, on the ordinary "they typed while '
              'I was typing" path',
        );
      },
    );

    test(
      'DISCRIMINATING CONTROL — a counterpart row the server dated AFTER my '
      'message still renders AFTER it',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-them-1', _jeeberId, 'seen at 10:30',
                '2026-07-27T10:30:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 10, 30));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        clock.now = DateTime.utc(2026, 7, 27, 10, 31);
        cubit.composerChanged('my reply at 10:31');
        await cubit.sendText();

        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-them-2', _jeeberId, 'later 10:31:30',
              '2026-07-27T10:31:30Z'),
        ];
        await cubit.refresh();

        expect(
          _texts(cubit),
          <String>['seen at 10:30', 'my reply at 10:31', 'later 10:31:30'],
          reason: 'the order tracks the wire in BOTH directions — it is not '
              'hardwired to put counterpart traffic first',
        );
      },
    );

    test(
      'THE OTHER HORN — a device 20 minutes FAST does NOT let a reply the '
      'server dated 12:01 jump above the message it answers',
      () async {
        // Same shape as the first case: a counterpart row lands, dated between
        // the newest row on screen and what the device clock reads. Here it must
        // sort BELOW the draft, and there it must sort ABOVE it. Only an anchor
        // expressed in SERVER time can tell the two apart — which is why the fix
        // is not simply "fall back to the local clock". This case also lives in
        // `chat_clock_skew_order_regression_test.dart`; it is repeated here so
        // the trade is visible in one file and cannot be re-broken by reading
        // only half of it.
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-them-1', _jeeberId, 'opening',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 20));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('mine');
        await cubit.sendText();

        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-them-2', _jeeberId, 'their reply',
              '2026-07-27T12:01:00Z'),
        ];
        await cubit.refresh();

        expect(
          _texts(cubit),
          <String>['opening', 'mine', 'their reply'],
          reason: 'the reply arrived AFTER my send; a 20-minute-fast device '
              'clock must not be what decides otherwise',
        );
      },
    );

    test(
      'the SKEW defence is not traded away: a device 5 minutes BEHIND still '
      'renders its draft below the reply that prompted it',
      () async {
        // This is the defect the on-screen pin was introduced to fix. The floor
        // is what keeps it fixed: `newestOnScreen + 1us` dominates a slow clock.
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-them-1', _jeeberId, 'row-01',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 5));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();

        // Their reply, stamped by the SERVER at 12:10 — ten minutes ahead of
        // what this device believes the time is.
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-them-2', _jeeberId, 'their reply',
              '2026-07-27T12:10:00Z'),
        ];
        await cubit.refresh();
        expect(_texts(cubit), <String>['row-01', 'their reply']);

        cubit.composerChanged('my reply to their reply');
        await cubit.sendText();

        expect(
          _texts(cubit),
          <String>['row-01', 'their reply', 'my reply to their reply'],
          reason: 'the user composed this AFTER reading their reply and must '
              'see it last, whatever the device clock says',
        );
      },
    );

    test(
      'successive sends still step monotonically when the clock does not move '
      'between them',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-them-1', _jeeberId, 'seen at 10:30',
                '2026-07-27T10:30:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 10, 31));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();

        // Three sends inside the same clock reading — a fast typist on a device
        // whose clock resolution is coarser than the taps.
        for (final body in <String>['first', 'second', 'third']) {
          cubit.composerChanged(body);
          await cubit.sendText();
        }

        expect(
          _texts(cubit),
          <String>['seen at 10:30', 'first', 'second', 'third'],
          reason: 'anchoring off the local clock alone would tie all three at '
              'the same instant; the floor is what makes each step past the '
              'previous one',
        );
      },
    );
  });
}
