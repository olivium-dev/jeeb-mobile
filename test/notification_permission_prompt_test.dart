import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/presentation/notification_permission_prompt.dart';

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onEnable,
  required VoidCallback onDismiss,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotificationPermissionPrompt(
          onEnable: onEnable,
          onDismiss: onDismiss,
        ),
      ),
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
      MaterialApp(
        home: Scaffold(
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
