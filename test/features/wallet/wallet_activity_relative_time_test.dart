// T11 / SW-03 family: wallet activity relative-time must be computed off the
// server INSTANT, not the raw wall clock. A gateway timestamp that drops the
// `Z` used to be read as device-local, so a fresh row read "4h ago" on a device
// 4h ahead of UTC. WalletActivityL10n now normalizes through ServerTime.
//
// The core assertion is host-timezone-independent: a zone-less string and its
// Z-marked twin denote the SAME instant, so they must produce the SAME label
// (they only diverged before the fix, and only on a non-UTC host).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_l10n.dart';

import '../../support/sync_app_localizations.dart';

Future<WalletActivityL10n> _resolve(WidgetTester tester) async {
  late WalletActivityL10n l10n;
  await tester.pumpWidget(
    wrapForTest(
      Builder(
        builder: (context) {
          l10n = WalletActivityL10n.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  testWidgets('zone-less and Z-marked timestamps give the same relative label',
      (tester) async {
    final l10n = await _resolve(tester);
    final now = DateTime.utc(2026, 6, 18, 10, 5); // 5 min after the row instant

    expect(
      l10n.relativeTime('2026-06-18T10:00:00', now: now),
      l10n.relativeTime('2026-06-18T10:00:00Z', now: now),
    );
  });

  testWidgets('a just-happened server instant reads "Just now", not hours ago',
      (tester) async {
    final l10n = await _resolve(tester);
    // now == the row instant; a mis-parsed zone-less string would have skewed
    // this by the host offset. Compared as instants it is 0 → "Just now".
    final now = DateTime.utc(2026, 6, 18, 10, 0);

    expect(l10n.relativeTime('2026-06-18T10:00:00', now: now), 'Just now');
  });

  testWidgets('unparseable timestamp falls back to the raw string',
      (tester) async {
    final l10n = await _resolve(tester);
    expect(l10n.relativeTime('not-a-date'), 'not-a-date');
  });
}
