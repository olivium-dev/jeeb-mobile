// Isolated native UI test — ProhibitedItemReportScreen (Jeeber reports a
// prohibited item on a request). A self-contained StatefulWidget: it takes only
// a `requestId`, holds a local TextEditingController, and its actions
// (Attach Photo / Report Item → Navigator.pop) fire on tap only, so no
// cubit/DI/seam is needed for the idle-form render. Pumped directly. Copy is
// hardcoded English (not localized); the ar shot exercises RTL mirroring of the
// same layout.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';

import '../support/screen_harness.dart';

Widget _screen() => const ProhibitedItemReportScreen(requestId: 'REQ-1');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prohibited-item-report: idle form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'prohibited-item-report__idle',
    );
  });

  testWidgets('prohibited-item-report: idle form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'prohibited-item-report__idle-ar',
      locale: const Locale('ar'),
    );
  });
}
