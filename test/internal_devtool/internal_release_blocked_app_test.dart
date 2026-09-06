import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/internal_devtool/internal_release_blocked_app.dart';
import '../support/midnight_test_harness.dart';

void main() {
  testWidgets('invalid internal policy renders the JEEB block', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(const InternalReleaseBlockedApp());
    await tester.pump();
    expect(
      find.bySemanticsIdentifier('internal_release_blocked_error'),
      findsOneWidget,
    );
    expect(find.text('Internal build blocked'), findsOneWidget);
  });
}
