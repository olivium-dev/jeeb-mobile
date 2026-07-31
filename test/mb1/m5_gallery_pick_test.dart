// MB1 ITEM M5 — W4.1, gallery pick.
//
// W4.1 is a PROOF-ONLY rider: MB1 budgets 20 minutes to establish that the
// gallery pick is already shipped, not to write it. The only thing W4.1's
// commit changed is one stale sentence at `chat_screen.dart:113` that claimed
// the surface used "the stub picker until image_picker lands in a later mobile
// task" — false since JEBV4-111, and load-bearing in the wrong direction,
// because it is why writer time was still being budgeted to wire something
// already wired.
//
// A proof-only rider with no instrument is a citation, not evidence. So this
// item attacks it from a DIFFERENT lens than the writer's existing
// `chat_picker_binding_test.dart` (which drives the widget tree and asserts a
// GetIt-registered spy is reached): here the chain is taken apart into its
// three independent links, each able to red on its own —
//
//   M5.1  the CUBIT: "gallery" reaches pickFromGallery, never pickFromCamera,
//         and the picked bytes become the sent message
//   M5.2  the SCREEN: _resolvePicker prefers the DI registration and falls
//         back to the stub — in that order (transposed, it still compiles and
//         still "contains" both)
//   M5.3  the DI BINDING: PhotoPickerService -> ImagePickerPhotoPickerService,
//         the real one, not the stub
//   M5.4  the IMPLEMENTATION: pickFromGallery asks the OS for the gallery
//   M5.5  the stale prose is corrected and DATED, not deleted
//
// NON-CLAIM (GATE.md §3): M5.1 is `suite`; M5.2–M5.5 are `static`. Nothing here
// proves an OS gallery ever opened on a handset — `image_picker` is a platform
// channel and no host test can invoke it. That is a `device` claim and it
// belongs to R1.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

import 'mb1_pack_support.dart';

/// Distinct, tagged payloads per source, so a stub's synthetic bytes can never
/// be mistaken for the spy's and a camera answer can never pass as a gallery
/// answer.
class _SpyPicker implements PhotoPickerService {
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<RawPhoto> pickFromCamera() async {
    cameraCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[11, 11, 11, 11]),
      source: PhotoSource.camera,
    );
  }

  @override
  Future<RawPhoto> pickFromGallery() async {
    galleryCalls++;
    return RawPhoto(
      bytes: Uint8List.fromList(const <int>[77, 78, 79, 80]),
      source: PhotoSource.gallery,
    );
  }
}

class _InertGateway extends ChatGateway {
  final _controller = StreamController<ChatEvent>.broadcast();
  final List<DeliveryChatMessage> sent = <DeliveryChatMessage>[];

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
  ) async {
    sent.add(message);
    return message.copyWith(status: MessageStatus.sent);
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M5.1 — the cubit routes "gallery" to the gallery', () {
    test('sendPhotoFromGallery calls pickFromGallery and NOT pickFromCamera',
        () async {
      final spy = _SpyPicker();
      final gateway = _InertGateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'DLV-MB1-M5',
        gateway: gateway,
        pickerService: spy,
      );
      addTearDown(cubit.close);

      await cubit.sendPhotoFromGallery();

      expect(spy.galleryCalls, 1);
      expect(spy.cameraCalls, 0,
          reason: 'the two rows of the attachment sheet must not be crossed');

      final photo = cubit.state.messages
          .where((m) => m.photoBytes != null)
          .toList();
      expect(photo, hasLength(1),
          reason: 'DENOMINATOR: the pick produced an actual message. A pick '
              'that is called but discarded is indistinguishable from no pick '
              'at the UI.');
      expect(photo.single.photoBytes, <int>[77, 78, 79, 80],
          reason: 'THE picked bytes, not a stub\'s synthetic ones');
      expect(photo.single.photoSource, PhotoSource.gallery);
    });

    test('POS/NEG pair: the camera row still reaches the camera', () async {
      // Without this, M5.1 above is satisfied by a cubit that calls
      // pickFromGallery for everything.
      final spy = _SpyPicker();
      final gateway = _InertGateway();
      addTearDown(gateway.dispose);
      final cubit = ChatCubit(
        deliveryId: 'DLV-MB1-M5',
        gateway: gateway,
        pickerService: spy,
      );
      addTearDown(cubit.close);

      await cubit.sendPhotoFromCamera();

      expect(spy.cameraCalls, 1);
      expect(spy.galleryCalls, 0);
    });
  });

  group('M5.2 — the screen prefers DI over the stub, in that order', () {
    test('_resolvePicker returns the registration first and the stub only as '
        'fallback', () {
      final src = readSource('lib/features/chat/presentation/chat_screen.dart');
      final start = src.indexOf('PhotoPickerService _resolvePicker()');
      expect(start, greaterThan(-1),
          reason: 'the DI-first resolver is gone or renamed');
      final body = src.substring(start, start + 400);

      final diIdx = body.indexOf('sl<PhotoPickerService>()');
      final stubIdx = body.indexOf('StubPhotoPickerService()');
      expect(diIdx, greaterThan(-1));
      expect(stubIdx, greaterThan(-1));
      expect(diIdx, lessThan(stubIdx),
          reason: 'TRANSPOSED, this method still compiles and still contains '
              'both names — and every production surface silently gets '
              'synthetic bytes again. Order is the assertion.');
      expect(body, contains('isRegistered<PhotoPickerService>()'));
    });
  });

  group('M5.3 — the DI binding is the REAL service', () {
    test('PhotoPickerService is bound to ImagePickerPhotoPickerService', () {
      final src = readSource('lib/core/di/injection_container.dart');
      final idx = src.indexOf('registerLazySingleton<PhotoPickerService>');
      expect(idx, greaterThan(-1),
          reason: 'no registration at all means every surface falls back to '
              'the stub');
      final registration = src.substring(idx, idx + 200);
      expect(registration, contains('ImagePickerPhotoPickerService'));
      expect(registration, isNot(contains('StubPhotoPickerService')),
          reason: 'binding the stub in DI is the same bug with extra steps');
    });
  });

  group('M5.4 — the implementation asks the OS for the gallery', () {
    test('pickFromGallery -> ImageSource.gallery, pickFromCamera -> camera',
        () {
      final src = readSource(
        'lib/features/photo_attachment/data/'
        'image_picker_photo_picker_service.dart',
      );
      final gIdx = src.indexOf('Future<RawPhoto> pickFromGallery()');
      final cIdx = src.indexOf('Future<RawPhoto> pickFromCamera()');
      expect(gIdx, greaterThan(-1));
      expect(cIdx, greaterThan(-1));
      expect(src.substring(gIdx, gIdx + 120), contains('ImageSource.gallery'));
      expect(src.substring(cIdx, cIdx + 120), contains('ImageSource.camera'));
    });
  });

  group('M5.5 — the stale prose is corrected and DATED, not deleted', () {
    test('chat_screen.dart no longer claims the stub is used "until '
        'image_picker lands"', () {
      const path = 'lib/features/chat/presentation/chat_screen.dart';

      // POSITIVE CONTROL: the false sentence really was there at the base, so
      // its absence today is a correction rather than a search for a string
      // that never existed.
      final base = gitShow(path, ref: kPreFixBase);
      expect(base, isNotNull,
          reason: 'POS CONTROL COULD NOT RUN: cannot read $path at '
              '$kPreFixBase — unverifiable is rejected, not passed');
      expect(base, contains('until image_picker lands'),
          reason: 'POS CONTROL FAILED: MB1 names chat_screen.dart:113 as the '
              'stale claim; it is not at the base, so W4.1 corrected nothing');

      final now = readSource(path);
      final live = now
          .split('\n')
          .asMap()
          .entries
          .where((e) =>
              e.value.contains('until image_picker lands') &&
              !e.value.contains('used to read'))
          .map((e) => '${e.key + 1}: ${e.value.trim()}')
          .toList();
      expect(live, isEmpty,
          reason: 'the false claim survives as a live statement:\n'
              '${live.join('\n')}');

      // T9 doctrine: dated as history, not silently erased.
      expect(now, contains('Corrected (MB1 W4.1)'));
      expect(now.toLowerCase(), contains('retained not deleted'));
      expect(now, contains('JEBV4-111'),
          reason: 'name WHEN it became false, so the next reader can date it');
    });
  });
}
