import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/delivery/delivery_status_vocab.dart';

void main() {
  group('DeliveryStatusVocab', () {
    test('maps lifecycle aliases to one canonical stage', () {
      const cases = <String, DeliveryStatusStage>{
        'accepted': DeliveryStatusStage.ordered,
        'picked_up': DeliveryStatusStage.pickedUp,
        'In Transit': DeliveryStatusStage.inTransit,
        'en-route': DeliveryStatusStage.inTransit,
        'at_door': DeliveryStatusStage.atDoor,
        'completed': DeliveryStatusStage.delivered,
        'canceled': DeliveryStatusStage.cancelled,
        'FailedNeedsEscalation': DeliveryStatusStage.otherTerminal,
      };

      for (final entry in cases.entries) {
        expect(
          DeliveryStatusVocab.stageOf(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('Start delivery fails closed outside the pre-start stage', () {
      for (final status in <String?>[
        null,
        '',
        'Picked',
        'InTransit',
        'AtDoor',
        'Done',
        'Cancelled',
        'unexpected',
      ]) {
        expect(
          DeliveryStatusVocab.canStartFromChat(status),
          isFalse,
          reason: '$status must never expose Start delivery',
        );
      }

      for (final status in ['Ordered', 'accepted', 'matched']) {
        expect(
          DeliveryStatusVocab.canStartFromChat(status),
          isTrue,
          reason: status,
        );
      }
    });
  });
}
