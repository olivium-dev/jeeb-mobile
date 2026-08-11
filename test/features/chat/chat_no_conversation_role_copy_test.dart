/// Close-out 2026-08-11: the no-conversation (404) chat empty state told BOTH
/// sides to "check back once a Jeeber is assigned" — nonsense on the jeeber's
/// phone, where the reader IS that jeeber.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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
  _delegate = _SyncLocDelegate({
    'en': File('lib/l10n/app_en.arb').readAsStringSync(),
    'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
  });
}

class _EmptyGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.unknown;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

Future<void> _pump(WidgetTester tester, UserRole role) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final gateway = _EmptyGateway();
  addTearDown(gateway.dispose);
  await tester.pumpWidget(
    BlocProvider(
      create: (_) => RoleCubit(prefs: prefs, initialRole: role),
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ChatScreen(
          deliveryId: 'conv-empty-role',
          counterpartName: 'Kamal Hajj',
          gateway: gateway,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(ChatHeaderExpansionStore.instance.reset);
  setUpAll(_loadArb);

  testWidgets('client reads the client wording', (tester) async {
    await _pump(tester, UserRole.client);

    expect(
      find.textContaining('once a Jeeber is assigned'),
      findsOneWidget,
    );
  });

  testWidgets('jeeber is NOT told to wait for a jeeber', (tester) async {
    await _pump(tester, UserRole.jeeber);

    expect(find.textContaining('once a Jeeber is assigned'), findsNothing);
    expect(
      find.textContaining('as soon as the client starts one'),
      findsOneWidget,
    );
  });
}
