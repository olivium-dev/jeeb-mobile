/// b02 — a 500 on the chat history read must NOT render as an empty thread.
/// `ChatCubit.load()` collapsed EVERY history failure into
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
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

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// The Jeeber IS assigned and in transit; the history endpoint is 500ing.
class _FaultingGateway extends ChatGateway {
  _FaultingGateway({this.failing = true});

  bool failing;
  int historyReads = 0;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async {
    historyReads++;
    if (failing) {
      throw StateError('HTTP 500 from GET /v1/conversations/$id/messages');
    }
    return [
      DeliveryChatMessage.text(
        id: 'srv-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 7, 26, 12),
        status: MessageStatus.delivered,
        text: 'On my way with your order',
      ),
    ];
  }

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

class _NoopPicker implements PhotoPickerService {
  const _NoopPicker();
  @override
  Future<RawPhoto> pickFromCamera() => throw UnimplementedError();
  @override
  Future<RawPhoto> pickFromGallery() => throw UnimplementedError();
}

/// The retry CTA inside the error body. MIDNIGHT: the body is now
/// [JeebInfoNote.error] + a kit [JeebCtaButton] (no Material `FilledButton` in
/// the tree at all), so the affordance is addressed by its identifier — the
/// thing that is actually frozen — rather than by a Material runtime type.
final Finder _retryButton = find.descendant(
  of: find.byKey(ChatScreen.historyErrorKey),
  matching: find.bySemanticsIdentifier('chat_history_error_retry'),
);

void main() {
  setUpAll(_loadArb);

  group('ChatCubit: a history-load failure is an ERROR, not an empty thread',
      () {
    test('a 500 on load() raises historyLoadFailed instead of collapsing to '
        'the empty/unknown state', () async {
      final gateway = _FaultingGateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-500',
        gateway: gateway,
        pickerService: const _NoopPicker(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      // RED before the fix: `error` was null and nothing distinguished this
      expect(cubit.state.historyLoadFailed, isTrue);
      expect(cubit.state.error, ChatError.historyLoadFailed);
      expect(cubit.state.isLoadingHistory, isFalse);
    });

    test('an EMPTY (successful) history is still the empty state — the fix '
        'must not turn "no messages" into an error', () async {
      final gateway = _FaultingGateway(failing: false);
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-ok',
        gateway: gateway,
        pickerService: const _NoopPicker(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.historyLoadFailed, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.messages, hasLength(1));
    });

    test('retryLoad() clears the error and reloads the thread', () async {
      final gateway = _FaultingGateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-500',
        gateway: gateway,
        pickerService: const _NoopPicker(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.historyLoadFailed, isTrue);

      gateway.failing = false;
      await cubit.retryLoad();

      expect(cubit.state.historyLoadFailed, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.messages, hasLength(1));
      expect(gateway.historyReads, 2);
    });

    test('a later successful refresh() self-heals the error flag', () async {
      final gateway = _FaultingGateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'conv-500',
        gateway: gateway,
        pickerService: const _NoopPicker(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.historyLoadFailed, isTrue);

      gateway.failing = false;
      await cubit.refresh();

      expect(cubit.state.historyLoadFailed, isFalse);
      expect(cubit.state.messages, hasLength(1));
    });
  });

  group('ChatScreen: the failure renders an error with a retry', () {
    testWidgets('a 500 renders the error state, NOT "No conversation yet"',
        (tester) async {
      final gateway = _FaultingGateway();
      addTearDown(gateway.dispose);

      await tester.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-500',
        counterpartName: 'Kamal Hajj',
        gateway: gateway,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // RED before the fix: the empty state was mounted and there was no error
      expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);
      expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
      expect(find.text('No conversation yet'), findsNothing);
      // The affordance, not just the copy: an error the user cannot act on is
      expect(_retryButton, findsOneWidget);
      expect(find.text("Couldn't load this chat"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping retry re-reads history and paints the thread',
        (tester) async {
      final gateway = _FaultingGateway();
      addTearDown(gateway.dispose);

      await tester.pumpWidget(_host(ChatScreen(
        deliveryId: 'conv-500',
        counterpartName: 'Kamal Hajj',
        gateway: gateway,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ChatScreen.historyErrorKey), findsOneWidget);

      gateway.failing = false;
      await tester.tap(_retryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(ChatScreen.historyErrorKey), findsNothing);
      expect(find.text('On my way with your order'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
