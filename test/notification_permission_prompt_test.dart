import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/presentation/notification_permission_prompt.dart';

import 'support/sync_app_localizations.dart';

/// COPY-18: the copy is l10n-resolved now, so the host must carry the
/// delegates.
Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onEnable,
  required VoidCallback onDismiss,
  Locale locale = const Locale('en'),
}) {
  return tester.pumpWidget(
    wrapForTest(
      Scaffold(
        body: NotificationPermissionPrompt(
          onEnable: onEnable,
          onDismiss: onDismiss,
        ),
      ),
      locale: locale,
    ),
  );
}

void main() {
  testWidgets('renders the capturable prompt boundary + both actions',
      (tester) async {
    await _pump(tester, onEnable: () {}, onDismiss: () {});

    expect(
      find.bySemanticsLabel(RegExp(r'.*')),
      findsWidgets,
      reason: 'sanity: prompt builds',
    );
    expect(find.byKey(const Key('notif_perm_title')), findsOneWidget);
    expect(find.byKey(const Key('notif_perm_enable')), findsOneWidget);
    expect(find.byKey(const Key('notif_perm_dismiss')), findsOneWidget);
    expect(find.text('Turn on notifications'), findsOneWidget);
  });

  testWidgets('resolves the ARABIC copy from the ARB, not an English default',
      (tester) async {
    await _pump(
      tester,
      onEnable: () {},
      onDismiss: () {},
      locale: const Locale('ar'),
    );

    expect(find.byKey(const Key('notif_perm_title')), findsOneWidget);
    expect(find.text('تفعيل الإشعارات'), findsOneWidget);
    expect(find.text('Turn on notifications'), findsNothing);
  });

  testWidgets('Enable invokes onEnable, not onDismiss', (tester) async {
    var enabled = 0;
    var dismissed = 0;
    await _pump(
      tester,
      onEnable: () => enabled++,
      onDismiss: () => dismissed++,
    );

    await tester.tap(find.byKey(const Key('notif_perm_enable')));
    await tester.pump();

    expect(enabled, 1);
    expect(dismissed, 0);
  });

  testWidgets('Not now invokes onDismiss, not onEnable', (tester) async {
    var enabled = 0;
    var dismissed = 0;
    await _pump(
      tester,
      onEnable: () => enabled++,
      onDismiss: () => dismissed++,
    );

    await tester.tap(find.byKey(const Key('notif_perm_dismiss')));
    await tester.pump();

    expect(dismissed, 1);
    expect(enabled, 0);
  });

  testWidgets('custom copy overrides the defaults', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        Scaffold(
          body: NotificationPermissionPrompt(
            onEnable: () {},
            onDismiss: () {},
            title: 'Bytarjim',
            body: 'Body copy',
            enableLabel: 'Yes',
            dismissLabel: 'Later',
          ),
        ),
      ),
    );

    expect(find.text('Bytarjim'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
