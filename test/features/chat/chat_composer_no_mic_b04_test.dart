// FIX-B04 — the chat mic affordance is hidden.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arb);
  final Map<String, String> _arb;
  @override
  bool isSupported(Locale l) => _arb.containsKey(l.languageCode);
  @override
  Future<AppLocalizations> load(Locale l) async =>
      debugLoadAppLocalizationsSync(l, _arb[l.languageCode]!);
  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

/// Minimal compose-thread gateway (empty history, broadcasting phase).
class _ComposeGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();
  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.broadcasting;
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async => const [];
  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);
  @override
  Stream<ChatEvent> subscribe(String id) => _controller.stream;
  Future<void> dispose() => _controller.close();
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

void main() {
  setUpAll(_loadArb);

  testWidgets('B-04 — the composer renders NO mic affordance', (tester) async {
    final gw = _ComposeGateway();
    addTearDown(gw.dispose);
    final cubit = ChatCubit(
      deliveryId: 'conv-1',
      gateway: gw,
      pickerService: StubPhotoPickerService(),
    )..load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: BlocProvider<ChatCubit>.value(
            value: cubit,
            child: const ChatComposer(
              // The real chat screen passes a voice callback here; even so the
              onVoiceRecordingComplete: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The mic affordance is gone: no mic glyph, no voice semantics node.
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(
      find.bySemanticsIdentifier('chat_detail_voice_button'),
      findsNothing,
    );

    // The real composer affordances still render (attach + send + input).
    expect(find.byKey(ChatComposer.attachButtonKey), findsOneWidget);
    expect(find.byKey(ChatComposer.sendButtonKey), findsOneWidget);
    expect(find.byKey(ChatComposer.textFieldKey), findsOneWidget);
  });
}

void _noop(List<int> bytes, String mime, int ms) {}
