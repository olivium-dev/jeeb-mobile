// P4 + P5 (b01-20260725) — THE pin for the root cause.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:jeeb_mobile/features/deep_link_targets/chat_detail_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Records which pick method the surface actually invoked. Returns tiny,
/// distinctly-tagged payloads so a stub's synthetic bytes can never be mistaken
/// for the spy's.
class _SpyPickerService implements PhotoPickerService {
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<RawPhoto> pickFromCamera() async {
    cameraCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      source: PhotoSource.camera,
    );
  }

  @override
  Future<RawPhoto> pickFromGallery() async {
    galleryCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[5, 6, 7, 8]),
      source: PhotoSource.gallery,
    );
  }
}

/// Inert 1:1 gateway: no network, no timers, no polling. Accepted phase so the
/// composer (and therefore the attach button) renders.
class _InertGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async => message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

/// Opens the attachment sheet and taps one of its two rows. The sheet is the
/// OMDS media picker: row 1 is Camera, row 2 is Gallery.
Future<void> _tapAttachThen(
  WidgetTester tester, {
  required bool camera,
}) async {
  await tester.tap(find.byKey(ChatComposer.attachButtonKey));
  await tester.pumpAndSettle();
  final l10n = _en();
  await tester.tap(
    find.text(camera ? l10n['chatAttachmentCamera']! : l10n['chatAttachmentGallery']!),
  );
  await tester.pumpAndSettle();
}

Map<String, String> _en() => <String, String>{
      'chatAttachmentCamera': 'Camera',
      'chatAttachmentGallery': 'Gallery',
    };

void main() {
  late _SpyPickerService spy;
  late _InertGateway gateway;

  setUp(() async {
    spy = _SpyPickerService();
    gateway = _InertGateway();
    // `reset()` is ASYNC — awaiting it matters, or the registration below is
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<PhotoPickerService>(spy);
  });

  tearDown(() async {
    await gateway.dispose();
    await GetIt.instance.reset();
  });

  group('TC-C1 — ChatDetailScreen binds the DI picker (the root-cause pin)', () {
    testWidgets('Gallery routes to the registered picker, not the stub',
        (tester) async {
      await tester.pumpWidget(_wrap(ChatDetailScreen(
        chatId: 'conv-1',
        debugGateway: gateway,
        debugPhase: ConversationPhase.accepted,
        debugHasWinner: true,
      )));
      await tester.pumpAndSettle();

      await _tapAttachThen(tester, camera: false);

      expect(
        spy.galleryCalls,
        1,
        reason: 'the OS gallery must be reached through the DI-registered '
            'PhotoPickerService — a StubPhotoPickerService here is the P5 bug',
      );
      expect(spy.cameraCalls, 0);
      // The stub's synthetic gallery payload is a 3 MB block of 0xA0. The spy's
      final sent = tester
          .widget<ChatScreen>(find.byType(ChatScreen));
      expect(sent.pickerService, same(spy));
      expect(sent.pickerService, isNot(isA<StubPhotoPickerService>()));
    });

    testWidgets('Camera routes to the registered picker, not the stub',
        (tester) async {
      await tester.pumpWidget(_wrap(ChatDetailScreen(
        chatId: 'conv-1',
        debugGateway: gateway,
        debugPhase: ConversationPhase.accepted,
        debugHasWinner: true,
      )));
      await tester.pumpAndSettle();

      await _tapAttachThen(tester, camera: true);

      expect(
        spy.cameraCalls,
        1,
        reason: 'the OS camera must be reached through the DI-registered '
            'PhotoPickerService — a StubPhotoPickerService here is the P4 bug',
      );
      expect(spy.galleryCalls, 0);
    });
  });

  group('TC-C2 — ChatScreen own default resolves from DI', () {
    testWidgets('no pickerService argument ⇒ the DI spy is used', (tester) async {
      await tester.pumpWidget(_wrap(ChatScreen(
        deliveryId: 'conv-2',
        counterpartName: 'Kamal',
        gateway: gateway,
      )));
      await tester.pumpAndSettle();

      await _tapAttachThen(tester, camera: true);

      expect(
        spy.cameraCalls,
        1,
        reason: 'ChatScreen omitting pickerService must fall back to DI, not to '
            'the synthetic stub — otherwise a future host reintroduces the bug '
            'purely by omission',
      );
    });

    testWidgets('with NO DI registration the stub is still the safe fallback',
        (tester) async {
      await GetIt.instance.reset();

      await tester.pumpWidget(_wrap(ChatScreen(
        deliveryId: 'conv-3',
        counterpartName: 'Kamal',
        gateway: gateway,
      )));
      await tester.pumpAndSettle();

      // The unregistered path must not throw — widget tests and the dev catalog
      await _tapAttachThen(tester, camera: true);
      expect(spy.cameraCalls, 0);
    });
  });
}
