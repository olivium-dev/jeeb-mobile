import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';

/// Pins the ONE place the counterpart leg is chosen. The regression this guards
/// against: a viewer being shown their OWN name/photo as the party they rate.
void main() {
  const summary = OrderChatSummary(
    deliveryId: 'DLV-1',
    jeeberName: 'Jeeber Jane',
    jeeberAvatarUrl: 'http://192.168.2.39:10090/api/users/jbr-1/avatar?v=aa',
    clientName: 'Client Carl',
    clientAvatarUrl: 'http://192.168.2.39:10090/api/users/cli-1/avatar?v=bb',
  );

  group('OrderChatSummaryCounterpart — the viewer never sees themselves', () {
    test('client viewer resolves the JEEBER identity', () {
      expect(summary.counterpartName(viewerIsJeeber: false), 'Jeeber Jane');
      expect(
        summary.counterpartAvatarUrl(viewerIsJeeber: false),
        contains('jbr-1'),
      );
    });

    test('jeeber viewer resolves the CLIENT identity', () {
      expect(summary.counterpartName(viewerIsJeeber: true), 'Client Carl');
      expect(
        summary.counterpartAvatarUrl(viewerIsJeeber: true),
        contains('cli-1'),
      );
    });

    test('the two legs never resolve to the same party', () {
      expect(
        summary.counterpartAvatarUrl(viewerIsJeeber: true),
        isNot(summary.counterpartAvatarUrl(viewerIsJeeber: false)),
      );
    });
  });

  group('absent identity degrades to the letter placeholder', () {
    const bare = OrderChatSummary(deliveryId: 'DLV-2');

    test('an empty avatar becomes null, never an empty-src image', () {
      expect(bare.counterpartAvatarUrl(viewerIsJeeber: false), isNull);
      expect(bare.counterpartAvatarUrl(viewerIsJeeber: true), isNull);
    });

    test('an empty name stays empty for the caller to fall back on', () {
      expect(bare.counterpartName(viewerIsJeeber: false), isEmpty);
      expect(bare.counterpartName(viewerIsJeeber: true), isEmpty);
    });

    test('a one-sided payload only fills the leg it belongs to', () {
      const jeeberOnly = OrderChatSummary(
        deliveryId: 'DLV-3',
        jeeberName: 'Jeeber Jane',
        jeeberAvatarUrl: 'http://host/api/users/jbr-1/avatar',
      );
      expect(jeeberOnly.counterpartAvatarUrl(viewerIsJeeber: false), isNotNull);
      expect(jeeberOnly.counterpartAvatarUrl(viewerIsJeeber: true), isNull);
    });
  });
}
