// F33: a failed `fetchOffers` is NOT "no offers" — it must not navigate the
// customer to a different screen behind their back.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const ClientHomeRequest _reply = ClientHomeRequest(
  id: 'req-1',
  title: 'ORD-7001',
  displayId: 'ORD-7001',
  status: ClientRequestStatus.offersReceived,
  destinationLabel: 'Hamra, Beirut',
  itemsSummary: 'Coffee beans',
  tier: ClientRequestTier.express,
  offerCount: 2,
);

class _SeededHome implements ClientHomeRepository {
  const _SeededHome();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      const ClientHomeSnapshot(replies: <ClientHomeRequest>[_reply]);
}

/// [offers] null means the read throws.
class _ScriptedOffers implements OffersRepository {
  _ScriptedOffers(this.offers);

  final List<Offer>? offers;
  int reads = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    reads++;
    final List<Offer>? rows = offers;
    if (rows == null) throw const NetworkFailure(offline: true);
    return OffersSnapshot(
      offers: rows,
      windowExpiresAt: null,
      requestIsOpen: true,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      OfferAcceptResult.empty;
}

final List<String> _pushed = <String>[];

GoRouter _router(Widget child) => GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
    GoRoute(
      path: '/requests/:id/offers',
      name: 'offer-review',
      builder: (BuildContext context, GoRouterState state) {
        _pushed.add(state.pathParameters['id']!);
        return const Scaffold(body: Text('offer review'));
      },
    ),
  ],
);

Widget _harness(ClientHomeCubit cubit, Locale locale) => MaterialApp.router(
  theme: AppTheme.midnight(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  routerConfig: _router(
    BlocProvider<ClientHomeCubit>.value(value: cubit, child: const RepliesTab()),
  ),
);

Future<ClientHomeCubit> _loaded() async {
  final ClientHomeCubit cubit = ClientHomeCubit(
    repository: const _SeededHome(),
    greetingNameProvider: () => 'Sami',
  );
  await cubit.load();
  return cubit;
}

void main() {
  setUp(() {
    _pushed.clear();
    GetIt.instance.reset();
  });
  tearDown(() => GetIt.instance.reset());

  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: a failed read stays on the tab', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final _ScriptedOffers offers = _ScriptedOffers(null);
      GetIt.instance.registerSingleton<OffersRepository>(offers);
      final ClientHomeCubit cubit = await _loaded();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('replies_accept_cta'));
      await tester.pumpAndSettle();

      expect(offers.reads, 1);
      expect(_pushed, isEmpty, reason: 'a failure must not navigate away');
      expect(
        find.bySemanticsIdentifier('replies_accept_offers_error_snack'),
        findsOneWidget,
      );
    });
  }

  testWidgets('an EMPTY snapshot still routes to offer-review', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    GetIt.instance.registerSingleton<OffersRepository>(
      _ScriptedOffers(const <Offer>[]),
    );
    final ClientHomeCubit cubit = await _loaded();
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('replies_accept_cta'));
    await tester.pumpAndSettle();

    expect(_pushed, <String>['req-1']);
  });
}
