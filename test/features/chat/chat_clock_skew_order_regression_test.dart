// CLOCK-SKEW ORDER regression (chat) — the poll tick that re-sorts a thread
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _conversationId = 'conv-skew';
const _customerId = 'user-customer-0001';
const _jeeberId = 'user-jeeber-0002';

Map<String, Object?> _row(
  String id,
  String author,
  String body, {
  String? createdAtUtc,
}) =>
    <String, Object?>{
      'message_id': id,
      'kind': 'text',
      'subtype': null,
      'author_id': author,
      'audience': null,
      'payload': null,
      'body': body,
      'created_at': ?createdAtUtc,
    };

/// Serves the chat routes off a mutable in-memory thread. Every read is a clean
/// 200. [postFails] makes the SEND fail while reads keep working — the exact
/// shape of a message that is never echoed.
class _ChatWire {
  _ChatWire({List<Map<String, Object?>>? initialRows, this.postFails = false})
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
            if (postFails) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    statusCode: 500,
                    requestOptions: options,
                  ),
                ),
              );
              return;
            }
            body = <String, Object?>{'id': 'srv-posted-${posts.length}'};
          } else if (path.contains('/voice/transcribe')) {
            body = <String, Object?>{
              'url': 'cdn://voice-1',
              'transcript': 'transcribed',
            };
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
  final bool postFails;
  late final Dio dio;
  int historyReads = 0;
  final List<Object?> posts = <Object?>[];
}

/// Never connects — the WS transport is out of scope here.
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

/// A clock the test moves by hand so an optimistic bubble's local send time is
/// deterministically SKEWED relative to the server timestamps on the wire.
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

/// Drives [count] further history re-pulls and waits for each to land AND
/// merge.
Future<void> _awaitPollTicks(_ChatWire wire, int count) async {
  for (var pull = 0; pull < count; pull++) {
    final target = wire.historyReads + 1;
    _bus.add(null);
    var landed = false;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (wire.historyReads >= target) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        landed = true;
        break;
      }
    }
    if (!landed) {
      fail(
        'a push drove no history re-pull (reads stuck at ${wire.historyReads} '
        'of $target); nothing below would prove anything',
      );
    }
  }
}

void main() {
  group('T5 — a re-pull must not re-order a thread by the LOCAL clock', () {
    test(
      'SLOW CLOCK, DoD: a reply that arrived before my message stays above it '
      'across the append path and 3 subsequent push-driven re-pulls, with nothing new on '
      'the wire',
      () async {
        // Their message is server-dated 12:00:00Z. This device believes it is
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 11, 50));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('my reply');
        await cubit.sendText();

        // The append path is already correct — `_appended` skips the sort.
        expect(
          _texts(cubit), <String>['theirs', 'my reply'],
          reason: 'baseline: the append path renders the composed order',
        );

        // Three ticks. The server has NOT echoed my message, so every read
        await _awaitPollTicks(wire, 3);

        expect(
          _texts(cubit), <String>['theirs', 'my reply'],
          reason: 'THE REGRESSION: _pollHistory re-sorts unconditionally, and '
              'the optimistic bubble carries a local clock 10 minutes behind '
              'the server timestamp it is a reply to — so a tick that changed '
              'NOTHING flipped the two rows',
        );
      },
    );

    test(
      'SLOW CLOCK + FAILED SEND: the send never reaches the server and is never '
      'echoed, so the order has to hold indefinitely rather than self-heal',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
          postFails: true,
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 11, 50));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('my failed reply');
        await cubit.sendText();

        expect(
          cubit.state.messages.last.status, MessageStatus.failed,
          reason: 'the POST must actually have failed, or this case is a '
              'duplicate of the one above',
        );
        expect(cubit.state.error, ChatError.sendFailed);

        await _awaitPollTicks(wire, 4);

        expect(
          _texts(cubit), <String>['theirs', 'my failed reply'],
          reason: 'a failed send is never echoed, so `_adoptEcho` never runs '
              'and the self-heal the regression relies on never happens',
        );
      },
    );

    test(
      'FAST CLOCK, DoD: a reply that arrives AFTER my message renders after it, '
      'even though the server dated it 19 minutes EARLIER than my device did',
      () async {
        // This is the other skew direction, and the one the old code got wrong
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'opening',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 20));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('mine');
        await cubit.sendText();
        expect(_texts(cubit), <String>['opening', 'mine']);

        // Their reply lands AFTER my send, server-dated 12:01 — earlier than
        wire.rows = <Map<String, Object?>>[
          _row('srv-01', _jeeberId, 'opening',
              createdAtUtc: '2026-07-27T12:00:00Z'),
          _row('srv-02', _jeeberId, 'their reply',
              createdAtUtc: '2026-07-27T12:01:00Z'),
        ];
        await _awaitPollTicks(wire, 3);

        expect(
          _texts(cubit), <String>['opening', 'mine', 'their reply'],
          reason: 'THE DoD: the reply arrived after my message, so it renders '
              'after it. Sorting my un-echoed bubble by a device clock that '
              'runs fast put their reply above it',
        );
      },
    );

    test(
      'the OWN BUBBLE still shows its real local send time — the fix changes '
      'ORDER, not the rendered clock',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
        );
        final composedAt = DateTime.utc(2026, 7, 27, 11, 50);
        final clock = _TestClock(composedAt);
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('my reply');
        await cubit.sendText();
        await _awaitPollTicks(wire, 2);

        final mine = cubit.state.messages.last;
        expect(mine.text, 'my reply');
        expect(
          mine.sentAt, composedAt,
          reason: 'the bubble renders sentAt as a clock, so re-anchoring the '
              'ORDER must not rewrite it — an own bubble that suddenly showed '
              'the counterpart\'s server time would be a new lie',
        );
        expect(
          mine.hasServerTimestamp, isTrue,
          reason: 'a locally composed message DOES have a real send time; it is '
              'only its position relative to server rows that is unknown',
        );
      },
    );

    test(
      'TWO un-echoed sends keep the order the user typed them in, across ticks',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
          postFails: true,
        );
        // Both sends happen at the same skewed instant — the clock does not even
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 11, 50));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('first');
        await cubit.sendText();
        cubit.composerChanged('second');
        await cubit.sendText();

        await _awaitPollTicks(wire, 3);

        expect(
          _texts(cubit), <String>['theirs', 'first', 'second'],
          reason: 'two drafts stamped with the identical local clock must still '
              'render in send order, below the server row they answer',
        );
      },
    );

    test(
      'a VOICE note whose optimistic bubble is REPLACED in place (upload → '
      'ref-bearing row) keeps its position across ticks',
      () async {
        // `_dispatchVoiceNote` swaps the draft for a freshly CONSTRUCTED message
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 11, 50));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        await cubit.sendVoiceNote(
          audioBytes: <int>[1, 2, 3],
          mimeType: 'audio/m4a',
          durationMs: 1200,
        );

        expect(
          cubit.state.messages.last.kind, MessageKind.voice,
          reason: 'the voice bubble must be the newest row after the send',
        );

        await _awaitPollTicks(wire, 3);

        expect(
          cubit.state.messages.map((m) => m.kind),
          <MessageKind>[MessageKind.text, MessageKind.voice],
          reason: 'the replace-in-place path must carry the ordering anchor '
              'across, or a slow clock sinks the voice note above the row it '
              'answers',
        );
      },
    );

    test(
      'DISCRIMINATING CONTROL — once the server ECHOES my message, the SERVER '
      'timestamp takes over and can legitimately re-order the thread',
      () async {
        // The re-sort is not being disabled. This proves it still runs and still
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _row('srv-01', _jeeberId, 'theirs',
                createdAtUtc: '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 11, 50));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();
        cubit.composerChanged('mine');
        await cubit.sendText();
        expect(_texts(cubit), <String>['theirs', 'mine']);

        // The echo arrives dated 11:59:00Z — BEFORE the 12:00 row.
        wire.rows = <Map<String, Object?>>[
          _row('srv-01', _jeeberId, 'theirs',
              createdAtUtc: '2026-07-27T12:00:00Z'),
          _row('srv-echo', _customerId, 'mine',
              createdAtUtc: '2026-07-27T11:59:00Z'),
        ];
        await _awaitPollTicks(wire, 2);

        expect(
          _texts(cubit), <String>['mine', 'theirs'],
          reason: 'the server clock is authoritative the moment it exists; if '
              'this stayed [theirs, mine] the fix had pinned own bubbles to the '
              'bottom forever and swallowed the echo absorption the re-sort is '
              'there for',
        );
        expect(
          cubit.state.messages.map((m) => m.id),
          <String>['srv-echo', 'srv-01'],
          reason: 'the optimistic bubble adopted the SERVER id, so later '
              'delivery/read receipts land',
        );
      },
    );
  });
}
