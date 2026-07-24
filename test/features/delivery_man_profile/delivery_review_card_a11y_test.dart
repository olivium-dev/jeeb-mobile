import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/sync_app_localizations.dart';

const _anonymousReview = DeliveryReviewData(
  id: 'anonymous',
  reviewerName: '   ',
  rating: 4,
  body: 'Great delivery.',
  daysAgo: 2,
  reviewerAvatarUrl: 'https://example.com/private-avatar.png',
);

Widget _harness({Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(
      body: DeliveryReviewCard(review: _anonymousReview, index: 0),
    ),
  );
}

void main() {
  testWidgets('blank reviewer uses localized label and neutral avatar', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    expect(find.text('Jeeb customer'), findsOneWidget);
    expect(find.text('?'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OmdsProfileAvatar &&
            widget.initial == 'J' &&
            widget.profilePicUrl == null,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'blank reviewer label is localized in Arabic without question mark',
    (tester) async {
      await tester.pumpWidget(_harness(locale: const Locale('ar')));

      expect(find.text('عميل جيب'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    },
  );

  testWidgets('visual star score has an exact localized semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness());

    expect(find.bySemanticsLabel('4 of 5 stars'), findsOneWidget);
    handle.dispose();
  });
}
