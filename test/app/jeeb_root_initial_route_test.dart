import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/app/app_restarter.dart';
import 'package:jeeb_mobile/app/bootstrap.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';

void main() {
  testWidgets('root consumes the pending launch once across app restart', (
    tester,
  ) async {
    final bootstrap = Completer<BootstrapResult>();
    await tester.pumpWidget(
      JeebRoot(
        devToolInitiallyPending: true,
        bootstrapFuture: bootstrap.future,
      ),
    );

    final firstBootstrap = tester.widget<JeebBootstrap>(
      find.byType(JeebBootstrap),
    );
    if (!kDevToolEnabled) {
      expect(firstBootstrap.consumeDevToolInitialOpen, isNull);
      expect(find.byType(AppRestarter), findsNothing);
      return;
    }

    final consume = firstBootstrap.consumeDevToolInitialOpen!;
    expect(consume(), isTrue);
    expect(consume(), isFalse, reason: 'consumption must be synchronous');

    await tester.pump();
    final restartContext = tester.element(find.byType(JeebBootstrap));
    AppRestarter.restart(restartContext);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final restartedBootstrap = tester.widget<JeebBootstrap>(
      find.byType(JeebBootstrap),
    );
    expect(restartedBootstrap.consumeDevToolInitialOpen!(), isFalse);
  });
}
