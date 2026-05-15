import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app.dart';

void main() {
  testWidgets('JeebApp renders without crashing', (tester) async {
    await tester.pumpWidget(const JeebApp());
    expect(find.text('Jeeb Home'), findsOneWidget);
  });
}
