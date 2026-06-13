/// T-MOB-015 — Offer-card Accept / Decline with optimistic UI.
///
/// Tests:
///   - Accept shows loading state optimistically (AC1)
///   - Decline adds to declinedOfferIds optimistically (AC4)
///   - 409 response reverts accept and sets error (AC3)
///   - Multiple accepts blocked while one is in flight
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_state.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

class _RaceGateway extends ChatGateway {
  _RaceGateway({required this.shouldThrow409});

  final bool shouldThrow409;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String id) async =>
      const [];

  @override
  Future<ConversationPhase> loadPhase(String id) async =>
      ConversationPhase.broadcasting;

  @override
  Future<DeliveryChatMessage> send(String id, DeliveryChatMessage m) async =>
      m.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String id) => const Stream.empty();

  @override
  Future<void> acceptOffer(String conversationId, String offerId) async {
    if (shouldThrow409) throw Exception('409 Conflict');
  }
}

ChatCubit _cubit({required bool throw409}) {
  final gw = _RaceGateway(shouldThrow409: throw409);
  final c = ChatCubit(
    deliveryId: 'conv-015',
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(c.close);
  return c;
}

void main() {
  group('Offer accept — optimistic state (AC1)', () {
    test('acceptingOfferId set immediately before gateway resolves', () async {
      final cubit = _cubit(throw409: false);
      await cubit.load();

      // Don't await so we can inspect mid-flight state
      unawaited(cubit.acceptOffer('offer-X'));
      expect(cubit.state.acceptingOfferId, 'offer-X');
    });

    test('acceptingOfferId cleared after successful accept', () async {
      final cubit = _cubit(throw409: false);
      await cubit.load();

      await cubit.acceptOffer('offer-Y');
      expect(cubit.state.acceptingOfferId, isNull);
    });
  });

  group('Offer accept — 409 race revert (AC3)', () {
    test('409 reverts optimistic state and emits sendFailed error', () async {
      final cubit = _cubit(throw409: true);
      await cubit.load();

      await cubit.acceptOffer('offer-race');

      expect(cubit.state.acceptingOfferId, isNull);
      expect(cubit.state.error, ChatError.sendFailed);
    });
  });

  group('Offer accept — guard against double-tap (AC1 race guard)', () {
    test('second acceptOffer is silently dropped while first is in flight',
        () async {
      final cubit = _cubit(throw409: false);
      await cubit.load();

      unawaited(cubit.acceptOffer('offer-A'));
      expect(cubit.state.acceptingOfferId, 'offer-A');

      // Second call with different id — should be no-op
      unawaited(cubit.acceptOffer('offer-B'));
      expect(cubit.state.acceptingOfferId, 'offer-A');
    });
  });

  group('Offer decline — optimistic greyed-out (AC4)', () {
    test('declineOffer marks offerId as declined', () async {
      final cubit = _cubit(throw409: false);
      await cubit.load();

      cubit.declineOffer('offer-decline-1');

      expect(cubit.state.declinedOfferIds, contains('offer-decline-1'));
    });

    test('multiple declines accumulate in the set', () async {
      final cubit = _cubit(throw409: false);
      await cubit.load();

      cubit.declineOffer('offer-A');
      cubit.declineOffer('offer-B');

      expect(cubit.state.declinedOfferIds, containsAll(['offer-A', 'offer-B']));
    });
  });
}
