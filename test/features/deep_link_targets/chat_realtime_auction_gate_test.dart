// REGRESSION GATE for the bidder-privacy check on the Firestore chat wrap.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_realtime_admission.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_app_localizations.dart';

const _sessionUserId = 'd1000000-0000-4000-8000-000000000001';
const _conversationId = 'c0ffee00-1111-4222-8333-444444444444';
const _requestId = 'req-auction-0001';
const _removedAt = '2026-07-28T18:00:00Z';

Map<String, dynamic> _row({
  required String phase,
  required bool seatedWinner,
  required bool biddersRemoved,
}) => <String, dynamic>{
      'conversation_id': _conversationId,
      'correlation_key': _requestId,
      'phase': phase,
      'participants': <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': _sessionUserId,
          'role_in_convo': 'client',
          'removed_at': null,
        },
        // The jeeber who won (or, pre-accept, just another bidder).
        <String, dynamic>{
          'user_id': 'jeeber-bidder-a',
          'role_in_convo': seatedWinner ? 'jeeber_winner' : 'jeeber_bidder',
          'removed_at': null,
        },
        // The LOSER. Whether they still hold a live membership is the whole
        <String, dynamic>{
          'user_id': 'jeeber-bidder-b',
          'role_in_convo': 'jeeber_bidder',
          'removed_at': biddersRemoved ? _removedAt : null,
        },
      ],
    };

class _AuctionDio {
  _AuctionDio({required this.row}) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
            body = row;
          } else if (path == '/v1/conversations/$_conversationId/messages') {
            body = const <String, dynamic>{'messages': <dynamic>[]};
          }
          handler.resolve(
            Response(data: body, statusCode: 200, requestOptions: options),
          );
        },
      ),
    );
  }

  final Map<String, dynamic> row;
  late final Dio dio;
}

class _StubAuthTokenStore extends AuthTokenStore {
  _StubAuthTokenStore(this._uid) : super(storage: const FlutterSecureStorage());
  final String? _uid;
  @override
  Future<String?> get userId async => _uid;
}

Widget _host(RoleCubit role) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<RoleCubit>.value(
        value: role,
        child: const ChatDetailScreen(chatId: _requestId),
      ),
    );

Future<RoleCubit> _roleCubit() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return RoleCubit(prefs: prefs, initialRole: UserRole.client);
}

List<Map<String, Object?>> _events(List<String> lines, String name) => lines
    .map((line) => line.substring(Diag.prefix.length + 1))
    .map((json) => jsonDecode(json) as Map<String, dynamic>)
    .where((record) => record['name'] == name)
    .map((record) => (record['data'] as Map).cast<String, Object?>())
    .toList();

/// Every `chat_realtime_contested_admitted` record — the RETIRED auction gate's
/// telemetry. Its presence means the predicate said `contested`; it no longer
List<Map<String, Object?>> _refusals(List<String> lines) =>
    _events(lines, 'chat_realtime_contested_admitted');

/// Every `chat_realtime_unavailable` record — the refusals that REMAIN real.
/// This is the load-bearing witness for the b04 change. The retired gate used to
List<Map<String, Object?>> _capabilityRefusals(List<String> lines) =>
    _events(lines, 'chat_realtime_unavailable');

void main() {
  group('realtimeChatAdmitted — the auction predicate', () {
    test('broadcasting with a live bidder bench is REFUSED', () {
      // The original leak case. Every bidder is a live member of this
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.broadcasting,
          roster: ChatRosterVerdict.contested,
        ),
        isFalse,
      );
    });

    // THE RESIDUAL HOLE. `phase == accepted || hasWinner` said TRUE here — the
    test('a seated winner does NOT admit while a bidder is still seated', () {
      for (final phase in ConversationPhase.values) {
        expect(
          realtimeChatAdmitted(
            phase: phase,
            roster: ChatRosterVerdict.contested,
          ),
          isFalse,
          reason: 'phase=${phase.name}: a contested roster is a live rival '
              'reader, whatever the phase string claims — INCLUDING accepted, '
              'where the roster is the stronger witness',
        );
      }
    });

    test('a settled roster is admitted in every phase', () {
      // Not belt-and-braces: this is the MAIN LIVE SHAPE. Instrumented across
      for (final phase in ConversationPhase.values) {
        expect(
          realtimeChatAdmitted(
            phase: phase,
            roster: ChatRosterVerdict.settled,
          ),
          isTrue,
          reason: 'phase=${phase.name}: winner seated, bench empty, nothing '
              'left in the room to leak',
        );
      }
    });

    test('with NO roster in hand, only accepted admits', () {
      // The messages-probe resolution returns a row with no `participants`, and
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.accepted,
          roster: ChatRosterVerdict.unknown,
        ),
        isTrue,
      );
      for (final phase in <ConversationPhase>[
        ConversationPhase.broadcasting,
        ConversationPhase.closed,
        ConversationPhase.unknown,
      ]) {
        expect(
          realtimeChatAdmitted(phase: phase, roster: ChatRosterVerdict.unknown),
          isFalse,
          reason: 'phase=${phase.name} with no roster is ignorance, and '
              'ignorance is not consent',
        );
      }
    });

    test('the WHOLE 4 x 3 product is pinned, cell by cell', () {
      // If someone adds a phase or a roster verdict, this stops matching and the
      const expected = <ConversationPhase, Map<ChatRosterVerdict, bool>>{
        ConversationPhase.accepted: <ChatRosterVerdict, bool>{
          ChatRosterVerdict.settled: true,
          ChatRosterVerdict.contested: false,
          ChatRosterVerdict.unknown: true,
        },
        ConversationPhase.broadcasting: <ChatRosterVerdict, bool>{
          ChatRosterVerdict.settled: true,
          ChatRosterVerdict.contested: false,
          ChatRosterVerdict.unknown: false,
        },
        ConversationPhase.closed: <ChatRosterVerdict, bool>{
          ChatRosterVerdict.settled: true,
          ChatRosterVerdict.contested: false,
          ChatRosterVerdict.unknown: false,
        },
        ConversationPhase.unknown: <ChatRosterVerdict, bool>{
          ChatRosterVerdict.settled: true,
          ChatRosterVerdict.contested: false,
          ChatRosterVerdict.unknown: false,
        },
      };
      expect(
        expected.keys.toSet(),
        ConversationPhase.values.toSet(),
        reason: 'a new phase must be classified here, not defaulted',
      );
      for (final phase in ConversationPhase.values) {
        final row = expected[phase]!;
        expect(
          row.keys.toSet(),
          ChatRosterVerdict.values.toSet(),
          reason: 'a new roster verdict must be classified here',
        );
        for (final roster in ChatRosterVerdict.values) {
          expect(
            realtimeChatAdmitted(phase: phase, roster: roster),
            row[roster],
            reason: 'phase=${phase.name} roster=${roster.name}',
          );
        }
      }
    });
  });

  group('ChatDetailScreen — the gate runs on a live resolution', () {
    late List<String> lines;

    setUp(() {
      lines = <String>[];
      Diag.enabledOverride = true;
      Diag.sink = lines.add;
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
      sl.registerSingleton<AuthTokenStore>(_StubAuthTokenStore(_sessionUserId));
    });

    tearDown(() {
      Diag.resetForTest();
      final sl = GetIt.instance;
      if (sl.isRegistered<Dio>()) sl.unregister<Dio>();
      if (sl.isRegistered<AuthTokenStore>()) sl.unregister<AuthTokenStore>();
    });

    Future<List<Map<String, Object?>>> pumpWith(
      WidgetTester tester,
      Map<String, dynamic> row,
    ) async {
      GetIt.instance.registerSingleton<Dio>(_AuctionDio(row: row).dio);
      final role = await _roleCubit();
      addTearDown(role.close);
      await tester.pumpWidget(_host(role));
      await tester.pumpAndSettle();
      return _refusals(lines);
    }

    testWidgets(
      'a RESOLVED but still-broadcasting conversation is classified '
      'contested, reported, and ADMITTED',
      (tester) async {
        final refusals = await pumpWith(
          tester,
          _row(
            phase: 'broadcasting',
            seatedWinner: false,
            biddersRemoved: false,
          ),
        );

        expect(
          refusals,
          isNotEmpty,
          reason: 'the wrap was reached — resolution succeeded, uid is set',
        );
        expect(
          refusals.single['reason'],
          kRealtimeRefusedAuctionPhase,
          reason: 'the predicate still classifies this row as contested and '
              'still reports it — it just no longer refuses on it',
        );
        expect(refusals.single['phase'], ConversationPhase.broadcasting.name);
        expect(refusals.single['roster'], ChatRosterVerdict.contested.name);
        expect(
          _capabilityRefusals(lines),
          isNotEmpty,
          reason: 'control reached the Firebase capability probe, which it '
              'could not do while the auction gate returned early',
        );
        expect(refusals.single['conversation_id'], _conversationId);
      },
    );

    // THE CASE THE WELDED FIXTURE COULD NOT ASK. Winner seated (step 3 of the
    testWidgets(
      'a seated winner with a LIVE bidder still on the bench is ADMITTED, '
      'and still reports itself',
      (tester) async {
        final refusals = await pumpWith(
          tester,
          _row(
            phase: 'broadcasting',
            seatedWinner: true,
            biddersRemoved: false,
          ),
        );

        expect(
          refusals,
          isNotEmpty,
          reason: 'the wrap was reached — resolution succeeded, uid is set',
        );
        expect(
          refusals.single['reason'],
          kRealtimeRefusedAuctionPhase,
          reason: 'a seated winner proves the saga STARTED, not that it '
              'finished; the loser bench is what proves it finished — still '
              'worth reporting, because that roster is a real server defect',
        );
        // THE b04 ASSERTION. Before the gate was retired it returned `inner`
        expect(
          _capabilityRefusals(lines),
          isNotEmpty,
          reason: 'contested must now FALL THROUGH to the capability probe; '
              'if this is empty the auction gate is still short-circuiting',

        );
        expect(
          refusals.single['roster'],
          ChatRosterVerdict.contested.name,
          reason: 'the ROSTER arm refused, and the diagnostic says so — a '
              'device capture carrying only the phase could not tell this '
              'from a genuine mid-auction row',
        );
      },
    );

    // CONTROL for the test above, and the one that stops the fix from being
    testWidgets(
      'CONTROL: stale broadcasting + seated winner + CLEARED bench is admitted',
      (tester) async {
        final refusals = await pumpWith(
          tester,
          _row(phase: 'broadcasting', seatedWinner: true, biddersRemoved: true),
        );

        expect(
          refusals,
          isEmpty,
          reason: 'a CLEARED bench is settled, so the predicate does not even '
              'classify it contested — no telemetry at all. Classifying this '
              'row would mean the 8 post-accept rows the live gateway never '
              're-labelled all report as defects',
        );
        expect(
          _capabilityRefusals(lines).map((r) => r['reason']),
          contains('no_firebase_app'),
          reason: 'flow reached the NEXT refusal, so nothing stopped it earlier',
        );
      },
    );

    testWidgets(
      'CONTROL: once the phase is accepted the auction gate does NOT refuse',
      (tester) async {
        // Without this the refusal tests are satisfiable by a gate that refuses
        final refusals = await pumpWith(
          tester,
          _row(phase: 'accepted', seatedWinner: true, biddersRemoved: true),
        );

        expect(
          refusals,
          isEmpty,
          reason: 'an accepted conversation with an empty bench is past the '
              'auction — settled, not contested',
        );
        // It DOES refuse — on capability, one check later. That is the honest
        expect(
          _capabilityRefusals(lines).map((r) => r['reason']),
          contains('no_firebase_app'),
          reason: 'flow reached the NEXT refusal, so nothing stopped it earlier',
        );
      },
    );
  });
}
