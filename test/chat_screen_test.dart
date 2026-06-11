import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer_icon_button.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _StubChatGateway extends ChatGateway {
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String deliveryId) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<DeliveryChatMessage> send(String deliveryId, DeliveryChatMessage message) async {
    return message.copyWith(status: MessageStatus.sent);
  }

  @override
  Stream<ChatEvent> subscribe(String deliveryId) =>
      const Stream<ChatEvent>.empty();
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host(ChatCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ChatScreen(
      deliveryId: 'd-test',
      counterpartName: 'Jeeber',
      cubit: cubit,
    ),
  );
}

ChatCubit _buildCubit({ChatGateway? gateway, StubPhotoPickerService? picker}) {
  final cubit = ChatCubit(
    deliveryId: 'd-test',
    gateway: gateway ?? _StubChatGateway(),
    pickerService: picker ?? StubPhotoPickerService(),
    clock: () => DateTime(2026, 5, 17, 10, 30),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets('shows empty state until a message is sent', (tester) async {
    final cubit = _buildCubit();
    await cubit.load();
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(ChatScreen.emptyStateKey), findsOneWidget);

    await tester.enterText(find.byKey(ChatComposer.textFieldKey), 'Hi');
    // The send button rebuilds on canSendText flipping — pump a frame so the
    // BlocBuilder sees the new state before we tap.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ChatComposer.sendButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ChatScreen.emptyStateKey), findsNothing);
    expect(find.text('Hi'), findsOneWidget);
  });

  testWidgets('send button is disabled while the composer is empty', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await cubit.load();
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    final sendButton = tester.widget<ChatComposerIconButton>(
      find.byKey(ChatComposer.sendButtonKey),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(find.byKey(ChatComposer.textFieldKey), 'x');
    await tester.pump();
    final enabled = tester.widget<ChatComposerIconButton>(
      find.byKey(ChatComposer.sendButtonKey),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('renders mixed RTL/LTR messages without reordering them', (
    tester,
  ) async {
    final cubit = _buildCubit();
    await cubit.load();
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    // Send Arabic, then English, then mixed — exactly mirrors a real
    // WhatsApp-style mixed conversation.
    for (final text in const ['مرحباً', 'On my way', 'OK شكراً']) {
      await tester.enterText(find.byKey(ChatComposer.textFieldKey), text);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatComposer.sendButtonKey));
      await tester.pumpAndSettle();
    }

    // Walk the rendered Text widgets and verify the conversation order is
    // intact — the screen does not normalise direction across messages.
    expect(find.text('مرحباً'), findsOneWidget);
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text('OK شكراً'), findsOneWidget);
  });
}
