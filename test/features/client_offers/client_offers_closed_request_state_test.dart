import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/offers_fixtures.dart';
import '../../support/scripted_offers_repository.dart';
import '../../support/sync_app_localizations.dart';

/// DEVICE JUDGE F2 (PLAN-P02): tapping a `new offer` notification for the
/// CANCELLED request `defb1f07` opened `offer_review_list_root` showing the
/// "Request closed" chip TOGETHER with the live broadcasting empty state
/// ("Broadcasting to nearby Jeebers…" + "First offers usually land within 4
/// minutes."). A closed request is not broadcasting anything; the screen must
/// render ONE coherent closed state with a real exit.
ClientOffersCubit _testCubitFactory(
  OffersRepository repository,
  String requestId,
) => ClientOffersCubit(
  repository: repository,
  requestId: requestId,
  refreshSignals: const Stream.empty(),
  clockTicks: const Stream.empty(),
);

Widget _harness(OffersRepository repo, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The radar illustration loops forever; reduce motion so pumps settle.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: ClientOffersScreen(
        requestId: 'defb1f07',
        repository: repo,
        cubitFactory: _testCubitFactory,
      ),
    );

OffersSnapshot _closed({
  bool expired = false,
  DateTime? deadline,
  List<Offer> offers = const [],
}) => OffersSnapshot(
  offers: offers,
  windowExpiresAt: deadline,
  requestIsOpen: false,
  requestIsExpired: expired,
);

void main() {
  testWidgets(
    'cancelled request with no offers renders one closed state — no '
    'broadcasting promise, no countdown',
    (tester) async {
      await tester.pumpWidget(
        _harness(ScriptedOffersRepository(snapshots: [_closed()])),
      );
      await tester.pump();
      await tester.pump();

      // The closed rung, with its own identifier grammar.
      expect(
        find.bySemanticsIdentifier('offer_review_closed_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_review_closed_title'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_review_closed_body'),
        findsOneWidget,
      );
      expect(find.text('Request closed'), findsOneWidget);
      expect(
        find.text(
          'This request is no longer taking offers. Nothing was charged.',
        ),
        findsOneWidget,
      );

      // The live waiting rung must be gone — headline, body and its node.
      expect(
        find.bySemanticsIdentifier('offer_review_empty_state'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('offer_review_empty_title'),
        findsNothing,
      );
      expect(find.text('Broadcasting to nearby Jeebers…'), findsNothing);
      expect(
        find.text(
          "First offers usually land within 4 minutes. We'll ping you the "
          'second one does.',
        ),
        findsNothing,
      );

      // No countdown chip and no duplicate "Request closed" note.
      expect(
        find.bySemanticsIdentifier('offer_review_waiting_window_chip'),
        findsNothing,
      );
      expect(
        find.byKey(const Key('offer-request-closed-banner')),
        findsNothing,
        reason: 'the closed block already says it — one coherent state',
      );

      // A real exit, not an inert retry and not the cancel footer.
      expect(find.bySemanticsIdentifier('offer_review_exit_cta'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.byKey(const Key('offer-review-footer')), findsNothing);
      expect(
        find.bySemanticsIdentifier('offer_review_retry_cta'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a server deadline on a closed request draws no countdown chip',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _closed(deadline: DateTime.now().add(const Duration(minutes: 9))),
        ],
      );
      await tester.pumpWidget(_harness(repo));
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('offer_review_closed_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_review_waiting_window_chip'),
        findsNothing,
      );
      expect(find.byKey(const Key('offer-window-timer')), findsNothing);
    },
  );

  testWidgets('an expired request gets its own headline, not the cancelled one',
      (tester) async {
    await tester.pumpWidget(
      _harness(ScriptedOffersRepository(snapshots: [_closed(expired: true)])),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('offer_review_expired_state'),
      findsOneWidget,
    );
    expect(find.text('Offer window expired'), findsOneWidget);
    expect(
      find.text(
        'This request expired before a Jeeber took it. You can create a new '
        'one any time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Request closed'), findsNothing);
    expect(
      find.text('This request is no longer taking offers. Nothing was charged.'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('offer_review_exit_cta'), findsOneWidget);
  });

  testWidgets('AR renders the closed state in Arabic, with no English left',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        ScriptedOffersRepository(snapshots: [_closed()]),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('offer_review_closed_state'),
      findsOneWidget,
    );
    expect(find.text('تم إغلاق الطلب'), findsOneWidget);
    expect(find.text('ما عاد هالطلب ياخد عروض. ما انحسب عليك شي.'), findsOneWidget);
    expect(find.text('العودة إلى الرئيسية'), findsOneWidget);
    expect(find.text('Request closed'), findsNothing);
    expect(find.text('Broadcasting to nearby Jeebers…'), findsNothing);
  });

  testWidgets('an OPEN request keeps the live broadcasting empty state',
      (tester) async {
    final repo = ScriptedOffersRepository(
      snapshots: [
        OffersSnapshot(
          offers: const [],
          windowExpiresAt: DateTime.now().add(const Duration(minutes: 4)),
          requestIsOpen: true,
        ),
      ],
    );
    await tester.pumpWidget(_harness(repo));
    await tester.pump();
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('offer_review_empty_state'),
      findsOneWidget,
    );
    expect(find.text('Broadcasting to nearby Jeebers…'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('offer_review_closed_state'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('offer_review_exit_cta'), findsNothing);
    expect(find.byKey(const Key('offer-review-footer')), findsOneWidget);
  });

  testWidgets(
    'a closed request that still has bids keeps the list and the closed note',
    (tester) async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _closed(offers: [buildOffer(id: 'a', jeeberName: 'Karim', fee: 30)]),
        ],
      );
      await tester.pumpWidget(_harness(repo));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('offer-card-a')), findsOneWidget);
      expect(
        find.byKey(const Key('offer-request-closed-banner')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_review_closed_state'),
        findsNothing,
      );
    },
  );
}
