import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_l10n.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

void main() {
  final en = NotificationsL10n(
    AppLocalizations(const Locale('en'), const {}),
    false,
  );
  final ar = NotificationsL10n(
    AppLocalizations(const Locale('ar'), const {}),
    true,
  );

  group('relativeTime — UTC instants, device-local age (SW-03)', () {
    test('Z-marked timestamp diffs exactly against a UTC now', () {
      expect(
        en.relativeTime('2026-07-03T10:00:00Z',
            now: DateTime.utc(2026, 7, 3, 10, 5)),
        '5m ago',
      );
    });

    test('zone-less timestamp is treated as UTC — never device-local '
        '(the "2h stale" leak)', () {
      expect(
        en.relativeTime('2026-07-03T10:00:00',
            now: DateTime.utc(2026, 7, 3, 10, 5)),
        '5m ago',
      );
    });

    test('mixing a LOCAL now with a UTC timestamp stays exact (epoch diff)',
        () {
      final localNow =
          DateTime.utc(2026, 7, 3, 12, 0).toLocal(); // same instant, local zone
      expect(
        en.relativeTime('2026-07-03T10:00:00Z', now: localNow),
        '2h ago',
      );
      expect(
        en.relativeTime('2026-07-03T10:00:00', now: localNow),
        '2h ago',
        reason: 'zone-less server strings must age identically to Z-marked',
      );
    });

    test('buckets: just now / minutes / hours / days', () {
      final now = DateTime.utc(2026, 7, 3, 12, 0);
      expect(en.relativeTime('2026-07-03T11:59:40Z', now: now), 'Just now');
      expect(en.relativeTime('2026-07-03T11:15:00Z', now: now), '45m ago');
      expect(en.relativeTime('2026-07-03T09:00:00Z', now: now), '3h ago');
      expect(en.relativeTime('2026-07-01T12:00:00Z', now: now), '2d ago');
    });

    test('Arabic copy for the same instants', () {
      final now = DateTime.utc(2026, 7, 3, 12, 0);
      expect(ar.relativeTime('2026-07-03T11:55:00Z', now: now), 'قبل 5 د');
      expect(ar.relativeTime('2026-07-03T09:00:00', now: now), 'قبل 3 س');
    });

    test('unparseable timestamp falls back to the raw string', () {
      expect(en.relativeTime('not-a-date'), 'not-a-date');
    });
  });
}
