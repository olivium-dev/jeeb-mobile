// REGRESSION GATE for the bidder-privacy check on the Firestore chat wrap.
//
// The original bug: `ChatDetailScreen._wrapRealtime` gated only on
// `conversationResolved`, which is a LOOKUP RESULT ("a conversation row came
// back"), not a PHASE. A row can come back mid-auction, and during
// `broadcasting` every bidding Jeeber is still a non-removed participant. The
// released Firestore ruleset authorises purely on that membership, so a
// listener opened in that window streams each rival's offer card (fee, ETA,
// name) to every other bidder.
//
// THE HOLE THIS FILE NOW ALSO PINS — and the reason it previously could not.
// The first fix gated on `phase == accepted || hasWinner`. An auditor then
// observed 8 arrivals of `phase=broadcasting hasWinner=true admitted=TRUE`, and
// this file structurally COULD NOT ask whether that was safe: its one fixture
// welded `removed_at` to `seatedWinner`, so "a winner is seated" and "the losing
// bidders were removed" were the same boolean and never disagreed. They disagree
// in production. `jeeb-gateway`'s post-accept saga seats the winner
// (`JeebOffersController.cs:673`) and removes the losers
// (`:693-702`, `RemoveOthers = true`) in SEPARATE calls inside one best-effort
// block whose `catch` logs a warning and swallows (`:704-710`) so the accept
// still returns 200. "Winner seated, losers still active, phase still
// broadcasting" is therefore a designed outcome, and it is the leak.
//
// The fixture below takes the two facts as INDEPENDENT axes, and
// `a seated winner with a live bidder still on the bench is REFUSED` is the case
// the welded version could not express.
//
// HOW THIS FILE IS NOT VACUOUS. `Firebase.apps` is empty in every widget test, so
// the wrap is NEVER constructed here and "no listener was opened" is trivially
// true — asserting it would prove nothing (that is exactly the false green this
// branch already produced once). So no test asserts absence:
//
//   * the predicate tests call `realtimeChatAdmitted` DIRECTLY, over the whole
//     4 x 3 product. No Firebase, no widget, no ambiguity about what ran.
//   * the screen tests assert a POSITIVE artefact — the `auction_phase` refusal
//     diagnostic and its `roster` discriminator — which only exists if the gate
//     actually evaluated inside `_wrapRealtime` on a live resolution.
//   * every refusal test is paired with a CONTROL that must NOT refuse, so a
//     gate that simply says no to everything (feature permanently dead, the
//     other failure mode this branch was caught in) fails here.
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

/// The live snake_case conversation row, parameterised on THREE independent
/// facts — because in production they are independent:
///
///   * [phase] — what the row's `phase` string claims. The live gateway leaves
///     it at `broadcasting` long after an accept, so it is not a proxy for
///     anything.
///   * [seatedWinner] — did step 3 of the accept saga run (a `jeeber_winner`
///     seated, `removed_at` null).
///   * [biddersRemoved] — did step 4 run (the losing bidders soft-removed).
///
/// The previous version of this file had one boolean driving both of the last
/// two, so `seatedWinner && !biddersRemoved` — the leak — was unreachable.
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
        // question: while `removed_at` is null the Firestore rule authorises
        // them to read this thread.
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

/// Every `chat_realtime_unavailable` record the screen emitted, decoded.
List<Map<String, Object?>> _refusals(List<String> lines) => lines
    .map((line) => line.substring(Diag.prefix.length + 1))
    .map((json) => jsonDecode(json) as Map<String, dynamic>)
    .where((record) => record['name'] == 'chat_realtime_unavailable')
    .map((record) => (record['data'] as Map).cast<String, Object?>())
    .toList();

void main() {
  group('realtimeChatAdmitted — the auction predicate', () {
    test('broadcasting with a live bidder bench is REFUSED', () {
      // The original leak case. Every bidder is a live member of this
      // conversation and the Firestore rule authorises all of them.
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.broadcasting,
          roster: ChatRosterVerdict.contested,
        ),
        isFalse,
      );
    });

    // THE RESIDUAL HOLE. `phase == accepted || hasWinner` said TRUE here — the
    // auditor observed 8 such arrivals admitted — because a seated winner was
    // taken as proof the whole accept saga ran. It only proves step 3 ran.
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
      // the chat / deep-link / notification suites, 18 resolutions reach the
      // wrap and 8 of them are `broadcasting` with a settled roster — accepted
      // threads the live gateway never re-labelled. Refusing them would ship
      // the feature dead.
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
      // the legacy camelCase row carries `winnerJeeberId` instead. `unknown` is
      // "we did not find out", so the phase has to carry the decision — and
      // only `accepted` can, because the saga never advances the phase without
      // removing the losers in the same call.
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
      // author is forced to come here and classify it rather than inherit
      // whichever branch the boolean logic happens to land on. The literal map
      // is the same table written in the doc comment on `realtimeChatAdmitted`;
      // a divergence between the two is now a test failure, which is the point
      // — the previous doc claimed "unknown -> refused" flat while the code
      // admitted `unknown` with a winner, and nothing caught it.
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
      'a RESOLVED but still-broadcasting conversation refuses with '
      'auction_phase',
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
          reason: 'the AUCTION refused first — not the Firebase capability '
              'probe, which would also have refused and would have hidden this',
        );
        expect(refusals.single['phase'], ConversationPhase.broadcasting.name);
        expect(refusals.single['roster'], ChatRosterVerdict.contested.name);
        expect(refusals.single['conversation_id'], _conversationId);
      },
    );

    // THE CASE THE WELDED FIXTURE COULD NOT ASK. Winner seated (step 3 of the
    // accept saga ran) but the losing bidder never removed (step 4 threw and was
    // swallowed; the accept still returned 200). `hasWinner` is TRUE here, so
    // the previous gate admitted — and `jeeber-bidder-b` is still a non-removed
    // participant, i.e. still authorised by the membership rule to read the
    // winner's and the client's whole thread.
    testWidgets(
      'a seated winner with a LIVE bidder still on the bench is REFUSED',
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
              'finished; the loser bench is what proves it finished',
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
    // "refuse everything". Same stale `broadcasting` label, same seated winner —
    // but the bench IS cleared. This is the main live shape (8 of the 18
    // instrumented resolutions), and it must still be admitted.
    testWidgets(
      'CONTROL: stale broadcasting + seated winner + CLEARED bench is admitted',
      (tester) async {
        final refusals = await pumpWith(
          tester,
          _row(phase: 'broadcasting', seatedWinner: true, biddersRemoved: true),
        );

        final reasons = refusals.map((r) => r['reason']).toList(growable: false);
        expect(
          reasons,
          isNot(contains(kRealtimeRefusedAuctionPhase)),
          reason: 'refusing this would refuse the 8 post-accept rows the live '
              'gateway never re-labelled — i.e. ship the feature dead',
        );
        expect(
          reasons,
          contains('no_firebase_app'),
          reason: 'flow reached the NEXT refusal, so the gate let it through',
        );
      },
    );

    testWidgets(
      'CONTROL: once the phase is accepted the auction gate does NOT refuse',
      (tester) async {
        // Without this the refusal tests are satisfiable by a gate that refuses
        // unconditionally — which would ship the feature permanently dead, the
        // failure mode this branch was already caught in once.
        final refusals = await pumpWith(
          tester,
          _row(phase: 'accepted', seatedWinner: true, biddersRemoved: true),
        );

        final reasons = refusals.map((r) => r['reason']).toList(growable: false);
        expect(
          reasons,
          isNot(contains(kRealtimeRefusedAuctionPhase)),
          reason: 'an accepted conversation with an empty bench is past the '
              'auction',
        );
        // It DOES refuse — on capability, one check later. That is the honest
        // state of a widget test: `Firebase.initializeApp` never ran, so
        // `Firebase.apps` is empty and no listener can be constructed. Asserting
        // it here is what stops this control from silently becoming a test that
        // merely observed nothing at all.
        expect(
          reasons,
          contains('no_firebase_app'),
          reason: 'flow reached the NEXT refusal, so the gate let it through',
        );
      },
    );
  });
}
