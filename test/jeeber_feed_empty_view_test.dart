import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// The empty view always renders inside a Scaffold in production; wrap it so
/// the `OmdsSwitchTile`'s Ink finds a Material ancestor in tests.
Widget _host(Widget child, {Locale locale = const Locale('en')}) =>
    wrapForTest(Scaffold(body: child), locale: locale);

void main() {
  testWidgets('renders greeting, accept-orders switch, and empty text',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const JeeberFeedEmptyView(profileName: 'Kamal', profileAvatarUrl: 'x'),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Kamal'), findsOneWidget);
    expect(find.text('Accept orders'), findsOneWidget);
    expect(find.text('No Requests yet'), findsOneWidget);
    expect(find.text('All requests will show up here'), findsOneWidget);
    expect(find.byType(OmdsSwitchTile), findsOneWidget);
  });

  testWidgets('toggles the accept-orders switch', (tester) async {
    bool? toggled;
    await tester.pumpWidget(
      _host(
        JeeberFeedEmptyView(
          profileName: 'Kamal',
          profileAvatarUrl: 'x',
          acceptOrders: true,
          onAcceptOrdersChanged: (v) => toggled = v,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('jeeber-home-accept-orders-switch')));
    await tester.pump();
    expect(toggled, isFalse);
  });

  testWidgets('renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      _host(
        const JeeberFeedEmptyView(profileName: 'Kamal', profileAvatarUrl: 'x'),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final dir = Directionality.of(
      tester.element(find.byType(JeeberFeedEmptyView)),
    );
    expect(dir, TextDirection.rtl);
    expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
    expect(find.text('قبول الطلبات'), findsOneWidget);
  });
}
