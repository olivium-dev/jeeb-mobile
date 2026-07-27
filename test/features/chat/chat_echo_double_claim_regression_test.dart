// OWN-ECHO DOUBLE-CLAIM regression (chat). P0 — MESSAGE LOSS.
//
// THE DEFECT, in `ChatCubit._reconciledWithHistory`:
//
//     final unclaimedOwnEchoes = history.where((m) => m.isMine).toList();
//
// The pool of "own server rows still free to absorb an optimistic bubble" was
// built from the WHOLE history, including rows that are ALREADY ON SCREEN under
// their own server id. The shown-row loop correctly skips a shown row whose id
// the server also returned (`if (serverIds.contains(shown.id)) continue;`) —
// but skipping it never removes that row from `unclaimedOwnEchoes`. So an echo
// that is already claimed, by id, by the bubble it belongs to stays FREE to be
// claimed a SECOND time, by content, by a DIFFERENT optimistic bubble. The
// second bubble is then folded away and never rendered again.
//
// Two ways it bites, both reproduced below:
//
//   A) SEND THE SAME TEXT TWICE. Send "ok"; the server echoes it; send "ok"
//      again; one history fold later the second "ok" is GONE. The user typed
//      two messages, sent two messages, and can see one.
//
//   B) WORSE — THE SECOND SEND FAILED. A failed bubble still matches by content
//      (`_isEchoOfOwnMessage` keys on kind + text, deliberately: status is not
//      load-bearing for identity). So the FAILED bubble is absorbed onto the
//      earlier DELIVERED echo and disappears. The user is shown a delivered
//      message they never sent, the message they did try to send is gone, and
//      because a failed send is never echoed by the server this NEVER
//      SELF-HEALS — no poll tick, no resume, no reload brings it back.
//
// THE FIX: an echo whose id is already on screen is already claimed. Exclude it
// from the pool.
//
//     history.where((m) => m.isMine && !shownById.containsKey(m.id))
//
// WHY THE EXISTING SUITE WAS GREEN WHILE THIS WAS LIVE: every own-echo scenario
// in `chat_interleaved_order_regression_test.dart` and
// `bilateral_empty_thread_regression_test.dart` uses DISTINCT own texts, and
// the double-claim needs TWO own bubbles whose content compares equal with the
// first one's echo already reconciled onto it. `two_party_chat_b2_regression`
// repeats text but never across a fold. The cases below are that gap.
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
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _conversationId = 'conv-echo-claim';
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

/// Serves the chat routes off a mutable in-memory thread. Reads are always a
/// clean 200; [postFails] flips the SEND route to a transport failure so an
/// optimistic bubble can be driven to `MessageStatus.failed` the way the device
/// does it — through `ChatCubit._dispatch`'s catch, not by hand.
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
            if (postFails) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: 'send refused by the test wire',
                ),
              );
              return;
            }
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
  bool postFails = false;
  final List<Object?> posts = <Object?>[];
}

/// Never connects — the WS transport is out of scope here; the defect is in the
/// HTTP history fold and must be provable without a socket.
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

ChatCubit _cubit(
  DioChatGateway gateway, {
  required _TestClock clock,
}) {
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    // Long: every fold below is driven EXPLICITLY by `refresh()`, so the number
    // of folds is exactly what each case says it is. A background tick would
    // make "one fold" unfalsifiable.
    pollInterval: const Duration(minutes: 10),
    clock: clock.call,
  );
  addTearDown(cubit.close);
  return cubit;
}

List<String> _texts(ChatCubit cubit) =>
    cubit.state.messages.map((m) => m.text).toList(growable: false);

void main() {
  group('P0 — an own echo already on screen must not claim a SECOND bubble', () {
    test(
      'A: send "ok", the server echoes it, send "ok" again — one history fold '
      'later BOTH are still on screen',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-01', _jeeberId, 'is it ready?',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 1));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();

        // Send #1, and let the server echo it. After this fold the bubble is on
        // screen under the SERVER id — that is the precondition for the defect.
        cubit.composerChanged('ok');
        await cubit.sendText();
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-ok-1', _customerId, 'ok', '2026-07-27T12:01:05Z'),
        ];
        await cubit.refresh();
        expect(
          cubit.state.messages.map((m) => m.id),
          <String>['srv-01', 'srv-ok-1'],
          reason: 'precondition: the first "ok" has adopted its server id',
        );

        // Send #2 — the same text, as a user answering twice does.
        clock.now = DateTime.utc(2026, 7, 27, 12, 2);
        cubit.composerChanged('ok');
        await cubit.sendText();
        expect(
          _texts(cubit), <String>['is it ready?', 'ok', 'ok'],
          reason: 'precondition: the optimistic second bubble is on screen',
        );

        // ONE fold, BEFORE the server has echoed the second send. `srv-ok-1` is
        // already on screen under its own id — it must not be able to claim the
        // second bubble as well.
        await cubit.refresh();

        expect(
          _texts(cubit), <String>['is it ready?', 'ok', 'ok'],
          reason: 'THE DEFECT: `srv-ok-1` was already claimed by id and was '
              'STILL in `unclaimedOwnEchoes`, so it absorbed the second '
              'optimistic bubble by content and the message the user sent '
              'vanished from their own thread',
        );
        expect(
          cubit.state.messages.where((m) => m.isMine), hasLength(2),
          reason: 'two sends, two own bubbles',
        );
      },
    );

    test(
      'B: the second send FAILED — the failed bubble must not be absorbed onto '
      'the earlier DELIVERED echo (it would never self-heal)',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-01', _jeeberId, 'is it ready?',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 1));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();

        cubit.composerChanged('ok');
        await cubit.sendText();
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-ok-1', _customerId, 'ok', '2026-07-27T12:01:05Z'),
        ];
        await cubit.refresh();
        final firstEcho =
            cubit.state.messages.firstWhere((m) => m.id == 'srv-ok-1');
        expect(
          firstEcho.status, MessageStatus.delivered,
          reason: 'precondition: a decoded history row is `delivered`, which is '
              'what makes the absorbed result a message the user never sent',
        );

        // The network drops. The second send fails the way the device fails it.
        wire.postFails = true;
        clock.now = DateTime.utc(2026, 7, 27, 12, 2);
        cubit.composerChanged('ok');
        await cubit.sendText();
        final failed = cubit.state.messages.last;
        expect(
          failed.status, MessageStatus.failed,
          reason: 'precondition: the second bubble is a FAILED send',
        );

        // A poll tick lands. The server never echoed the failed send, so the
        // history is unchanged.
        await cubit.refresh();

        expect(
          cubit.state.messages.where((m) => m.isMine), hasLength(2),
          reason: 'THE DEFECT: the FAILED bubble was folded into the earlier '
              'DELIVERED echo and vanished — the user is left looking at one '
              '"ok" marked delivered, having watched their retry disappear',
        );
        expect(
          cubit.state.messages.map((m) => m.status),
          contains(MessageStatus.failed),
          reason: 'the failed send must stay visible AND stay failed: it is the '
              'only affordance the user has to retry, and a failed send is '
              'never echoed, so nothing later restores it',
        );

        // ...and it must not silently self-heal on a later fold either. A send
        // that failed is not on the server; folding forever must not change
        // that.
        await cubit.refresh();
        await cubit.refresh();
        expect(
          cubit.state.messages.where((m) => m.isMine), hasLength(2),
          reason: 'repeated folds must be idempotent, not a slow drain',
        );
      },
    );

    test(
      'DISCRIMINATING CONTROL — an echo that is NOT yet on screen still claims '
      'its bubble, one-for-one (the fix must not stop absorbing)',
      () async {
        final wire = _ChatWire(
          initialRows: <Map<String, Object?>>[
            _datedRow('srv-01', _jeeberId, 'is it ready?',
                '2026-07-27T12:00:00Z'),
          ],
        );
        final clock = _TestClock(DateTime.utc(2026, 7, 27, 12, 1));
        final cubit = _cubit(_gateway(wire, viewerId: _customerId),
            clock: clock);

        await cubit.load();

        // TWO identical own sends, NEITHER echoed yet.
        cubit.composerChanged('ok');
        await cubit.sendText();
        clock.now = DateTime.utc(2026, 7, 27, 12, 2);
        cubit.composerChanged('ok');
        await cubit.sendText();
        expect(cubit.state.messages.where((m) => m.isMine), hasLength(2));

        // The server echoes BOTH. Each optimistic bubble must take exactly one
        // echo — not collapse onto a single row, and not duplicate.
        wire.rows = <Map<String, Object?>>[
          ...wire.rows,
          _datedRow('srv-ok-1', _customerId, 'ok', '2026-07-27T12:01:05Z'),
          _datedRow('srv-ok-2', _customerId, 'ok', '2026-07-27T12:02:05Z'),
        ];
        await cubit.refresh();

        expect(
          cubit.state.messages.map((m) => m.id),
          <String>['srv-01', 'srv-ok-1', 'srv-ok-2'],
          reason: 'both echoes are unclaimed, so both are absorbed one-for-one '
              'and both bubbles adopt their server ids',
        );
        expect(_texts(cubit), <String>['is it ready?', 'ok', 'ok']);
      },
    );
  });
}
