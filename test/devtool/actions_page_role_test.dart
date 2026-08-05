import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/devtool/actions/actions_page.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';

class _MockDevGatewayClient extends Mock implements DevGatewayClient {}

void main() {
  testWidgets('offer initiation uses driver role from a multi-role user', (
    tester,
  ) async {
    final client = _MockDevGatewayClient();
    when(() => client.listUsers()).thenAnswer(
      (_) async => const <DevUser>[
        DevUser(
          id: 'jeeber-1',
          username: 'Multi-role user',
          status: 'active',
          role: 'customer',
          roles: <String>['customer', 'driver'],
        ),
      ],
    );
    when(
      () => client.initiateOffer(
        asUserId: any(named: 'asUserId'),
        asRole: any(named: 'asRole'),
        requestId: any(named: 'requestId'),
        fee: any(named: 'fee'),
        etaMinutes: any(named: 'etaMinutes'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(MaterialApp(home: ActionsPage(client: client)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Request ID'),
      'request-1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    verify(
      () => client.initiateOffer(
        asUserId: 'jeeber-1',
        asRole: 'driver',
        requestId: 'request-1',
        fee: 5,
        etaMinutes: 10,
        note: null,
      ),
    ).called(1);
  });
}
