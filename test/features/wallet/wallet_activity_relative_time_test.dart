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
    final now = DateTime.utc(2026, 6, 18, 10, 0);

    expect(l10n.relativeTime('2026-06-18T10:00:00', now: now), 'Just now');
  });

  testWidgets('unparseable timestamp falls back to the raw string',
      (tester) async {
    final l10n = await _resolve(tester);
    expect(l10n.relativeTime('not-a-date'), 'not-a-date');
  });
}
