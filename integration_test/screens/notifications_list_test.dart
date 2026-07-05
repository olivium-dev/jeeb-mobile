// Isolated native UI test — NotificationsListScreen (routed notifications).
// Pumped directly with a fake repository seam (populated inbox / empty).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';

import '../support/screen_harness.dart';

class _FakeNotifRepo implements NotificationsRepository {
  const _FakeNotifRepo(this._items);
  final List<NotificationItem> _items;
  @override
  Future<List<NotificationItem>> fetchNotifications() async => _items;
  @override
  Future<void> markRead(String id) async {}
}

const _inbox = <NotificationItem>[
  NotificationItem(
    id: 'n1',
    kind: NotificationKind.offerAccepted,
    title: 'Offer accepted',
    body: 'Your offer on request JB-1001 was accepted.',
    timestamp: '2026-07-04T20:00:00Z',
    read: false,
    ref: 'req-client-001-accepted',
  ),
  NotificationItem(
    id: 'n2',
    kind: NotificationKind.status,
    title: 'Your delivery is on the way',
    body: 'Package #JB-1001 is out for delivery.',
    timestamp: '2026-07-04T18:30:00Z',
    read: false,
  ),
  NotificationItem(
    id: 'n3',
    kind: NotificationKind.topup,
    title: 'Wallet topped up',
    body: 'SAR 250.00 was added to your wallet.',
    timestamp: '2026-07-03T09:15:00Z',
    read: true,
  ),
  NotificationItem(
    id: 'n4',
    kind: NotificationKind.kycApproved,
    title: 'Identity verified',
    body: 'Your KYC has been approved.',
    timestamp: '2026-07-02T12:00:00Z',
    read: true,
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('notifications: populated inbox (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const NotificationsListScreen(repository: _FakeNotifRepo(_inbox)),
      'notifications__populated',
    );
  });

  testWidgets('notifications: empty inbox (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const NotificationsListScreen(repository: _FakeNotifRepo(<NotificationItem>[])),
      'notifications__empty',
    );
  });

  testWidgets('notifications: populated inbox (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const NotificationsListScreen(repository: _FakeNotifRepo(_inbox)),
      'notifications__ar',
      locale: const Locale('ar'),
    );
  });
}
