/// NEW-BUG-01 anti-drift guard (Sprint-2 Contract 5c).
///
/// The bug: the app rendered "Offer accepted! You are now chatting" + the
/// counterpart header for a conversation that was still `broadcasting` (request
/// pending, no winner) because three layers defaulted/hard-coded to
/// [ConversationPhase.accepted]:
///   1. `DioChatGateway.loadPhase` returned a constant `accepted` (no network).
///   2. the abstract `ChatGateway.loadPhase` default returned `accepted`.
///   3. `ChatState.phase` defaulted to `accepted`.
///
/// These tests pin the FROZEN fix:
///   * `DioChatGateway.loadPhase` READS the real conversation aggregate
///     (`GET /v1/conversations?correlationKey={id}`) and only returns `accepted`
///     when the wire phase is `accepted` AND an active `jeeber_winner`
///     participant is present; it degrades to `broadcasting` on any failure.
///   * the abstract default + the `ChatState` default are `broadcasting`.
///   * the "Offer accepted!" banner renders for an `accepted` phase and NOT for
///     a `broadcasting` phase.
///
/// Revert any one of the three to `accepted` and a test here FAILS.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/conversation_lookup.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

void main() {
  // -------------------------------------------------------------------------
  // 1) DioChatGateway.loadPhase — REAL network read + jeeber_winner gating.
  // -------------------------------------------------------------------------
  group('DioChatGateway.loadPhase — reads the conversation aggregate', () {
    late _RecordingAdapter adapter;
    late Dio dio;
    late DioChatGateway gateway;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      gateway = DioChatGateway(dio: dio, currentUserId: 'me-id');
    });

    test('GETs /v1/conversations?correlationKey={id} (not a constant)',
        () async {
      adapter.onGet = (_) => _json({'phase': 'broadcasting', 'participants': []});

      await gateway.loadPhase('req-XYZ');

      expect(adapter.lastGetPath, '/v1/conversations');
      expect(adapter.lastGetQuery?['correlationKey'], 'req-XYZ');
    });

    test('a broadcasting conversation resolves to broadcasting '
        '(NOT accepted — the NEW-BUG-01 false positive)', () async {
      adapter.onGet = (_) => _json({
            'conversation_id': 'req-XYZ',
            'phase': 'broadcasting',
            'participants': [
              {'user_id': 'client-1', 'role_in_convo': 'client'},
              {'user_id': 'j-1', 'role_in_convo': 'jeeber_offerer'},
            ],
          });

      expect(await gateway.loadPhase('req-XYZ'),
          ConversationPhase.broadcasting);
    });

    test('accepted phase WITH an active jeeber_winner resolves to accepted',
        () async {
      adapter.onGet = (_) => _json({
            'phase': 'accepted',
            'participants': [
              {'user_id': 'client-1', 'role_in_convo': 'client'},
              {
                'user_id': 'j-win',
                'role_in_convo': 'jeeber_winner',
                'removed_at': null,
              },
              {
                'user_id': 'j-loser',
                'role_in_convo': 'jeeber_offerer',
                'removed_at': '2026-06-21T10:00:00Z',
              },
            ],
          });

      expect(await gateway.loadPhase('req-XYZ'), ConversationPhase.accepted);
    });

    test('accepted phase but NO active winner degrades to broadcasting '
        '(gate on phase==accepted AND jeeber_winner)', () async {
      adapter.onGet = (_) => _json({
            'phase': 'accepted',
            'participants': [
              {'user_id': 'client-1', 'role_in_convo': 'client'},
              // The only winner has been removed → not active.
              {
                'user_id': 'j-1',
                'role_in_convo': 'jeeber_winner',
                'removed_at': '2026-06-21T10:00:00Z',
              },
            ],
          });

      expect(await gateway.loadPhase('req-XYZ'),
          ConversationPhase.broadcasting);
    });

    test('a 404 — the server ANSWERING "no such conversation" — degrades to '
        'broadcasting, NEVER accepted', () async {
      adapter.getStatus = 404;

      expect(await gateway.loadPhase('req-XYZ'),
          ConversationPhase.broadcasting);
    });

    test('a flag-off 503 THROWS ChatReadUnavailableException instead of '
        'claiming broadcasting (and still never claims accepted)', () async {
      // UPDATED (chat-resolution tri-state). This used to assert
      // `503 → broadcasting`. NEW-BUG-01's requirement is "NEVER a false
      // accepted", and a throw satisfies it — but returning `broadcasting`
      // ALSO manufactured a false POSITIVE in the other direction: a server
      // fault was reported to the user as "this request is still broadcasting,
      // no offers yet", over deliveries that were already accepted and in
      // transit. "Could not find out" is now its own outcome.
      adapter.getStatus = 503;

      await expectLater(
        gateway.loadPhase('req-XYZ'),
        throwsA(isA<ChatReadUnavailableException>()),
      );
    });

    test('a transport failure with NO response (network down) THROWS — it is '
        'not evidence of any phase', () async {
      // The adapter itself blows up with no HTTP response at all — Dio wraps
      // this as a DioException with `response == null`, which is exactly what
      // "the phone has no network" looks like on the wire.
      adapter.onGet = (_) => throw const SocketException('Network unreachable');

      await expectLater(
        gateway.loadPhase('req-XYZ'),
        throwsA(isA<ChatReadUnavailableException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2) Production defaults must NOT be `accepted`.
  // -------------------------------------------------------------------------
  group('phase defaults (revert→FAIL guards)', () {
    test('ChatState default phase is broadcasting, not accepted', () {
      expect(const ChatState().phase, ConversationPhase.broadcasting);
    });

    test('abstract ChatGateway.loadPhase default is broadcasting', () async {
      final gw = _BareGateway();
      expect(await gw.loadPhase('anything'), ConversationPhase.broadcasting);
    });
  });

  // -------------------------------------------------------------------------
  // 3) Widget: the accepted banner gates on phase==accepted.
  // -------------------------------------------------------------------------
  group('OfferAcceptedBanner gating (widget)', () {
    setUpAll(_loadArb);

    testWidgets('broadcasting → compose/waiting, NO accepted banner',
        (tester) async {
      final cubit = _makeCubit(ConversationPhase.broadcasting);
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();

      expect(find.byType(OfferAcceptedBanner), findsNothing);
      // Composer stays visible while broadcasting (compose/waiting shell).
      expect(find.byType(ChatComposer), findsOneWidget);
    });

    testWidgets('accepted → the "Offer accepted!" banner renders',
        (tester) async {
      final cubit = _makeCubit(ConversationPhase.accepted);
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();

      expect(find.byType(OfferAcceptedBanner), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ChatCubit _makeCubit(ConversationPhase phase) {
  final cubit = ChatCubit(
    deliveryId: 'conv-test-001',
    gateway: _PhaseGateway(phase),
    pickerService: StubPhotoPickerService(),
  )..load();
  addTearDown(cubit.close);
  return cubit;
}

Widget _app(ChatCubit cubit) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (ctx) => ChatScreen(
              deliveryId: 'conv-test-001',
              counterpartName: 'Kamal Hajj',
              cubit: ctx.read<ChatCubit>(),
            ),
          ),
        ),
      ),
    );

/// A minimal gateway that returns a fixed phase and no live events — exercises
/// the real cubit/widget render path without a backend.
class _PhaseGateway extends ChatGateway {
  _PhaseGateway(this._phase);
  final ConversationPhase _phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async => _phase;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => const Stream<ChatEvent>.empty();
}

/// A gateway that does NOT override loadPhase — exposes the abstract default.
class _BareGateway extends ChatGateway {
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];
  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async => m;
  @override
  Stream<ChatEvent> subscribe(String id) => const Stream.empty();
}

// --- Localization (sync ARB load, mirrors the m1plus widget harness) --------

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;
  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);
  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

// --- Dio recording adapter (records path + query, returns scripted JSON) -----

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  ResponseBody Function(String path)? onGet;
  int getStatus = 200;

  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastGetPath = options.path;
    lastGetQuery = options.queryParameters;
    if (getStatus != 200) {
      return ResponseBody.fromString('{}', getStatus, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return onGet?.call(options.path) ?? _json(const {});
  }
}
