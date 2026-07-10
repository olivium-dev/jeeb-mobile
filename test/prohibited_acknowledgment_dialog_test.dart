import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_item.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';

import 'support/sync_app_localizations.dart';

class _FakeRepo implements ProhibitedAcknowledgmentRepository {
  _FakeRepo({this.items = const []});

  final List<ProhibitedItem> items;
  final bool alreadyAcked = false;
  bool localSaved = false;

  @override
  Future<List<ProhibitedItem>> fetchItems() async => items;

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => alreadyAcked;

  @override
  Future<void> saveLocalAcknowledgment() async => localSaved = true;
}

void main() {
  group('ProhibitedAcknowledgmentDialog', () {
    testWidgets('renders item list when loaded', (tester) async {
      final repo = _FakeRepo(
        items: const [
          ProhibitedItem(id: 'arak', name: 'Arak'),
          ProhibitedItem(id: 'knife', name: 'Knife'),
        ],
      );

      await tester.pumpWidget(wrapForTest(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showProhibitedAcknowledgmentDialog(
              context,
              repository: repo,
            ),
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Arak'), findsOneWidget);
      expect(find.text('Knife'), findsOneWidget);
    });

    testWidgets('Acknowledge CTA dismisses dialog (AC2)', (tester) async {
      final repo = _FakeRepo(
        items: const [ProhibitedItem(id: 'arak', name: 'Arak')],
      );

      bool? result;
      await tester.pumpWidget(wrapForTest(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showProhibitedAcknowledgmentDialog(
                context,
                repository: repo,
              );
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Find and tap acknowledge button
      await tester.tap(find.text('I understand, Continue'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
