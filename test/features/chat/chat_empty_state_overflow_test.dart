/// Run-22 chat-cluster regression — the chat empty state must never RenderFlex
/// overflow ("BOTTOM OVERFLOWED BY 6.6 PIXELS" in the run-22 screenshots).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';

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

/// Empty-thread gateway: no history, a fixed phase, no inbound events.
class _EmptyGateway extends ChatGateway {
  _EmptyGateway(this.phase);
  final ConversationPhase phase;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async => phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

Future<void> _pumpAtHeight(
  WidgetTester tester,
  Size size,
  ConversationPhase phase, {
  OrderChatSummary? pinnedSummary,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final gateway = _EmptyGateway(phase);
  addTearDown(gateway.dispose);
  await tester.pumpWidget(_host(ChatScreen(
    deliveryId: 'conv-empty-1',
    counterpartName: 'Kamal Hajj',
    gateway: gateway,
    isOrderChat: pinnedSummary != null,
    pinnedSummary: pinnedSummary,
    onViewSummary: pinnedSummary == null ? null : () {},
  )));
  // Let the cubit's load() resolve and the empty state mount.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // b02: the pinned header's expand choice is SESSION state and widget
  setUp(ChatHeaderExpansionStore.instance.reset);
  setUpAll(_loadArb);

  testWidgets('empty thread lays out at a short phone height (no overflow)',
      (tester) async {
    await _pumpAtHeight(
      tester,
      const Size(320, 480),
      ConversationPhase.unknown,
    );
    expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty thread survives an aggressively constrained height — the '
      'run-22 "BOTTOM OVERFLOWED BY 6.6 PIXELS" class', (tester) async {
    // 240dp total: after the app bar + composer there is far less vertical
    await _pumpAtHeight(
      tester,
      const Size(320, 240),
      ConversationPhase.unknown,
    );
    expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'broadcasting empty thread (TTL banner stacked above) still fits',
      (tester) async {
    await _pumpAtHeight(
      tester,
      const Size(320, 320),
      ConversationPhase.broadcasting,
    );
    expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'P3/M20: empty thread + the pinned strip carrying a 300-char initial '
      'requirement still lays out at a short phone height (R2 guard)',
      (tester) async {
    await _pumpAtHeight(
      tester,
      const Size(320, 480),
      ConversationPhase.accepted,
      pinnedSummary: OrderChatSummary(
        deliveryId: 'del-empty-1',
        orderRef: 'ORD-1',
        description: 'apples ' * 45, // 315 chars
      ),
    );
    expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);
    // b02: the strip is collapsed by default, so the initial-requirement row is
    await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
    await tester.pump();
    expect(
      find.bySemanticsIdentifier('order_chat_request_description'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
