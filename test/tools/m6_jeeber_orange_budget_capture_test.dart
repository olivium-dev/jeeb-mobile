// MIDNIGHT · M6 capture for the three jeeber surfaces this lane re-inked.
//
// The elements themselves had no live producer: the R16-tint pair was captured
// by a one-off the wave-C fixup lane deleted, and no catalog state renders a
// `RequestCard` at all (the glow-anchor wave logged that gap).
//
//   flutter test test/tools/m6_jeeber_orange_budget_capture_test.dart \
//     --update-goldens
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/chat/domain/accepted_conversation.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);

class _StaticActiveRepo implements ActiveDeliveriesRepository {
  const _StaticActiveRepo(this.result);

  final List<ActiveDeliverySummary> result;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => result;
}

class _CannedAcceptedRepo implements AcceptedConversationsRepository {
  const _CannedAcceptedRepo(this.result);

  final List<AcceptedConversation> result;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => result;
}

const _deliveries = <ActiveDeliverySummary>[
  ActiveDeliverySummary(
    id: 'd0',
    status: JeeberDeliveryStatus.ordered,
    conversationId: 'conv-0',
    title: 'Pharmacy run',
    dropoffAddress: 'Achrafieh',
  ),
  ActiveDeliverySummary(
    id: 'd1',
    status: JeeberDeliveryStatus.inTransit,
    conversationId: 'conv-1',
    title: 'Grocery run',
    dropoffAddress: 'Mar Mikhael',
  ),
];

const _accepted = <AcceptedConversation>[
  AcceptedConversation(
    conversationId: 'conv-0',
    requestId: 'd0',
    title: 'Pharmacy run',
    destinationLabel: 'Achrafieh',
  ),
];

const _request = DeliveryRequest(
  id: 'r-1',
  pickup: RequestLocation(label: 'Hamra, Beirut', latitude: 0, longitude: 0),
  dropoff: RequestLocation(label: 'Achrafieh, Beirut', latitude: 0, longitude: 0),
  tier: JeeberRequestTier.standard,
  estimatedDistanceKm: 3.4,
  potentialEarnings: 8.5,
  currency: 'USD',
  expiresAt: null,
);

void _capture(String path, WidgetBuilder builder) {
  testWidgets('capture $path', (WidgetTester tester) async {
    tester.view.physicalSize = _kCanvas;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    useReduceMotion(tester);

    await tester.pumpWidget(
      OmdsColorTokensProvider(
        tokens: jeebMidnightOmdsTokens,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withCaptureTestFonts(AppTheme.midnight()),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object?>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(child: builder(context)),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/redesign-midnight/captures/M6/$path.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void main() {
  setUpAll(loadCatalogCaptureFonts);

  // Two deliveries so the disclosure summary row renders alongside the cards —
  // the row whose title was the third leak.
  _capture('jeeber_active_deliveries/shell-injected-banner-expanded', (_) {
    final cubit = ActiveDeliveriesCubit(
      repository: const _StaticActiveRepo(_deliveries),
    )..start();
    addTearDown(cubit.close);
    return BlocProvider<ActiveDeliveriesCubit>.value(
      value: cubit,
      child: ActiveDeliveriesBanner(
        onOpenChat: (_) {},
        onManageDelivery: (_) {},
      ),
    );
  });

  _capture(
    'jeeber_home/fallback-active-delivery-card',
    (_) => const JeeberActiveDeliveriesBanner(
      repository: _CannedAcceptedRepo(_accepted),
    ),
  );

  _capture(
    'jeeber_request_feed/request-card-idle',
    (_) => RequestCard(
      request: _request,
      actionStatus: RequestActionStatus.idle,
      secondsRemaining: 42,
      onAccept: () {},
      onDecline: () {},
    ),
  );
}
