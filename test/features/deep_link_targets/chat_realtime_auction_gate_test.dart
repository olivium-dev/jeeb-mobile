// REGRESSION GATE for the bidder-privacy phase check on the Firestore chat wrap.
//
// The bug this pins: `ChatDetailScreen._wrapRealtime` gated only on
// `conversationResolved`, which is a LOOKUP RESULT ("a conversation row came
// back"), not a PHASE. A row can come back mid-auction — an instrumented probe
// on this branch caught the wrap being reached 8 times with `resolved: true` and
// `phase: ConversationPhase.broadcasting` — and during `broadcasting` every
// bidding Jeeber is still a non-removed participant. The released Firestore
// ruleset authorises purely on that membership, so a listener opened in that
// window streams each rival's offer card (fee, ETA, name) to every other bidder.
//
// HOW THIS FILE IS NOT VACUOUS. `Firebase.apps` is empty in every widget test, so
// the wrap is NEVER constructed here and "no listener was opened" is trivially
// true — asserting it would prove nothing (that is exactly the false green this
// branch already produced once). So neither test asserts absence:
//
//   * the predicate tests call `realtimeChatAdmitted` DIRECTLY. No Firebase, no
//     widget, no ambiguity about what ran.
//   * the screen test asserts a POSITIVE artefact — the `auction_phase` refusal
//     diagnostic — which only exists if the new gate actually evaluated inside
//     `_wrapRealtime` on a live resolution. Delete the gate and the event is
//     absent and the test fails; that was verified by deleting it.
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

/// The live snake_case conversation row, parameterised on the ONE thing this
/// file is about: whether the auction has produced a winner.
///
/// Mid-auction the roster is the client plus N bidders, none removed — the exact
/// membership the Firestore rule would authorise a read for.
Map<String, dynamic> _row({required bool seatedWinner}) => <String, dynamic>{
      'conversation_id': _conversationId,
      'correlation_key': _requestId,
      'phase': seatedWinner ? 'accepted' : 'broadcasting',
      'participants': <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': _sessionUserId,
          'role_in_convo': 'client',
          'removed_at': null,
        },
        <String, dynamic>{
          'user_id': 'jeeber-bidder-a',
          'role_in_convo': seatedWinner ? 'jeeber_winner' : 'jeeber_bidder',
          'removed_at': null,
        },
        <String, dynamic>{
          'user_id': 'jeeber-bidder-b',
          'role_in_convo': 'jeeber_bidder',
          'removed_at': seatedWinner ? '2026-07-28T18:00:00Z' : null,
        },
      ],
    };

class _AuctionDio {
  _AuctionDio({required this.seatedWinner}) {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.path;
          Object? body = const <String, dynamic>{};
          if (path == '/v1/conversations') {
            body = _row(seatedWinner: seatedWinner);
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

  final bool seatedWinner;
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
    test('broadcasting with no winner is REFUSED', () {
      // The leak case. Every bidder is a live member of this conversation.
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.broadcasting,
          hasWinner: false,
        ),
        isFalse,
      );
    });

    test('accepted is admitted', () {
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.accepted,
          hasWinner: false,
        ),
        isTrue,
      );
    });

    test('broadcasting WITH a seated winner is admitted', () {
      // Not a contradiction — the live row keeps reporting `broadcasting` after
      // the accept saga seats a `jeeber_winner`, which is why
      // `DioChatGateway._hasActiveWinner` exists at all. A seated, non-removed
      // winner is direct evidence the auction is over.
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.broadcasting,
          hasWinner: true,
        ),
        isTrue,
      );
    });

    test('unknown is REFUSED — ignorance is not consent', () {
      // `ConversationPhase.fromWire`'s default for an unrecognised phase string.
      // `DioChatGateway.loadPhase` already degrades every unknown/failed read to
      // `broadcasting`, the safe waiting state; this must not be the one place
      // that reads "we did not find out" as "the auction ended".
      expect(
        realtimeChatAdmitted(
          phase: ConversationPhase.unknown,
          hasWinner: false,
        ),
        isFalse,
      );
    });

    test('closed is not a licence on its own', () {
      // A thread that terminated AFTER an accept still carries its winner and is
      // admitted through `hasWinner`. One that terminated WITHOUT an accept
      // (cancelled / expired mid-auction) never removed the bidders, so it is
      // exactly as leaky as `broadcasting`.
      expect(
        realtimeChatAdmitted(phase: ConversationPhase.closed, hasWinner: false),
        isFalse,
      );
      expect(
        realtimeChatAdmitted(phase: ConversationPhase.closed, hasWinner: true),
        isTrue,
      );
    });

    test('every enum value is decided, so a new phase cannot default in', () {
      // If someone adds a phase to the enum, this list stops matching and the
      // author is forced to come here and classify it rather than inherit
      // whichever branch `||` happens to land on.
      expect(
        ConversationPhase.values.where(
          (p) => realtimeChatAdmitted(phase: p, hasWinner: false),
        ),
        <ConversationPhase>[ConversationPhase.accepted],
        reason: 'accepted is the ONLY phase that admits on its own',
      );
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

    testWidgets(
      'a RESOLVED but still-broadcasting conversation refuses with '
      'auction_phase',
      (tester) async {
        GetIt.instance
            .registerSingleton<Dio>(_AuctionDio(seatedWinner: false).dio);
        final role = await _roleCubit();
        addTearDown(role.close);

        await tester.pumpWidget(_host(role));
        await tester.pumpAndSettle();

        final refusals = _refusals(lines);
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
        expect(refusals.single['conversation_id'], _conversationId);
      },
    );

    testWidgets(
      'CONTROL: once a winner is seated the auction gate does NOT refuse',
      (tester) async {
        // Without this the first test is satisfiable by a gate that refuses
        // unconditionally — which would ship the feature permanently dead, the
        // failure mode this branch was already caught in once.
        GetIt.instance
            .registerSingleton<Dio>(_AuctionDio(seatedWinner: true).dio);
        final role = await _roleCubit();
        addTearDown(role.close);

        await tester.pumpWidget(_host(role));
        await tester.pumpAndSettle();

        final reasons =
            _refusals(lines).map((r) => r['reason']).toList(growable: false);
        expect(
          reasons,
          isNot(contains(kRealtimeRefusedAuctionPhase)),
          reason: 'an accepted conversation is past the auction',
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
