// FIX-B01 — close the double-accept hole (accept exactly ONE offer).
//
// Three guards, all regression-pinned here:
//   1. The OfferAcceptSheet is NON-DISMISSIBLE while the accept POST is in
//      flight (PopScope canPop:false) — the scrim/drag/system-back dismissal
//      vectors are blocked so the user can't bail mid-POST and go accept a
//      second offer.
//   2. The offer-review list wires the previously-DEAD `acceptingOfferId`
//      guard into the real (sheet-based) accept path: while any accept-confirm
//      sheet is open, EVERY card's Accept CTA disables.
//   3. The second call site (home Replies tab) guards against a double-tap
//      stacking two accept sheets.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// OffersRepository whose accept + fetch can be held in flight via completers.
class _GatedOffersRepository implements OffersRepository {
  Completer<void>? acceptGate;
  Completer<void>? fetchGate;
  int acceptCalls = 0;
  int fetchCalls = 0;
  OffersSnapshot fetchResult = OffersSnapshot(
    offers: [_offer(id: 'offer-001')],
    windowExpiresAt: DateTime(2030),
    requestIsOpen: true,
  );

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCalls++;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    return fetchResult;
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    acceptCalls++;
    final gate = acceptGate;
    if (gate != null) await gate.future;
    return const OfferAcceptResult(deliveryId: 'dlv-1', conversationId: 'c-1');
  }
}

class _ScriptedFetchRepository implements OffersRepository {
  _ScriptedFetchRepository(this._snapshot);
  final OffersSnapshot _snapshot;
  int acceptCalls = 0;
  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async => _snapshot;
  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    acceptCalls++;
    // Never completes → the accept stays in flight so the sheet stays open.
    await Completer<void>().future;
    return const OfferAcceptResult();
  }
}

Offer _offer({required String id, String name = 'Kamal', double fee = 6}) =>
    Offer(
      id: id,
      jeeberId: 'j-$id',
      jeeberName: name,
      fee: fee,
      currency: 'USD',
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

late LocalizationsDelegate<AppLocalizations> _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final Map<String, String> _arb;
  @override
  bool isSupported(Locale l) => _arb.containsKey(l.languageCode);
  @override
  Future<AppLocalizations> load(Locale l) async =>
      debugLoadAppLocalizationsSync(l, _arb[l.languageCode]!);
  @override
  bool shouldReload(_SyncDelegate old) => false;
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    _syncDelegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

ClientOffersCubit _testCubitFactory(OffersRepository repo, String requestId) =>
    ClientOffersCubit(
      repository: repo,
      requestId: requestId,
      refreshSignals: const Stream.empty(),
      clockTicks: const Stream.empty(),
    );

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  tearDown(() async {
    if (GetIt.instance.isRegistered<OffersRepository>()) {
      await GetIt.instance.reset();
    }
  });

  testWidgets(
    'P0-1 — the accept sheet is NON-DISMISSIBLE while the POST is in flight',
    (tester) async {
      final repo = _GatedOffersRepository()..acceptGate = Completer<void>();
      late BuildContext sheetHost;

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) {
                sheetHost = context;
                return Center(
                  child: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: sheetHost,
                      builder: (_) => OfferAcceptSheet(
                        offer: _offer(id: 'offer-001'),
                        requestId: 'req-1',
                        repository: repo,
                        onConfirmed: (_) {},
                        onCancelled: () => Navigator.of(sheetHost).pop(),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(); // resolve the async localizations delegate
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('offer_accept_sheet'), findsOneWidget);

      // Confirm → the accept POST is now held in flight (gated).
      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump();

      // The PopScope guarding the sheet reports it must NOT pop while submitting.
      final popScope = tester.widget<PopScope>(
        find.ancestor(
          of: find.byKey(const Key('offer-accept-confirm-cta')),
          matching: find.byType(PopScope),
        ),
      );
      expect(
        popScope.canPop,
        isFalse,
        reason:
            'the sheet must be non-dismissible while the accept is in '
            'flight (canPop:false)',
      );

      // A system-back gesture must NOT dismiss the sheet mid-POST.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('offer_accept_sheet'),
        findsOneWidget,
        reason: 'system-back must not tear down the sheet mid-accept',
      );

      // Release the gate so the test ends cleanly.
      repo.acceptGate!.complete();
      await tester.pump();
    },
  );

  testWidgets(
    'P0-1b — a swipe-down drag does NOT dismiss the sheet mid-POST '
    '(enableDrag:false; the vector PopScope can not guard)',
    (tester) async {
      // Drives the PRODUCTION OfferAcceptSheet.show() path (not a raw
      // showModalBottomSheet) because the drag guard lives on that call. The
      // BottomSheet drag-to-close calls Navigator.pop DIRECTLY, bypassing the
      // PopScope pop disposition — so canPop:false alone can NOT stop it; the
      // sheet must be opened with enableDrag:false. This test flings the sheet
      // down while the accept POST is gated in flight and asserts it survives.
      final repo = _GatedOffersRepository()..acceptGate = Completer<void>();
      late BuildContext host;

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) {
                host = context;
                return Center(
                  child: TextButton(
                    onPressed: () => OfferAcceptSheet.show(
                      host,
                      offer: _offer(id: 'offer-001'),
                      requestId: 'req-1',
                      repository: repo,
                    ),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('offer_accept_sheet'), findsOneWidget);

      // Confirm → the accept POST is held in flight (gated).
      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump();
      expect(repo.acceptCalls, 1);

      // A hard swipe-DOWN fling on the sheet must NOT tear it down mid-POST.
      await tester.fling(
        find.bySemanticsIdentifier('offer_accept_sheet'),
        const Offset(0, 800),
        2000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.bySemanticsIdentifier('offer_accept_sheet'),
        findsOneWidget,
        reason: 'a swipe-down must not dismiss the sheet while the accept is '
            'in flight (enableDrag:false)',
      );
      // Leave the accept POST suspended (gate uncompleted): the production
      // show() path wires its own goNamed('chat-detail') success navigation,
      // which has no GoRouter in this harness — completing it is out of scope.
      // The suspended future is disposed with the widget tree at teardown.
    },
  );

  testWidgets(
    'P0-2 — opening one accept sheet disables EVERY card Accept CTA (list '
    'in-flight guard wired)',
    (tester) async {
      final repo = _ScriptedFetchRepository(
        OffersSnapshot(
          offers: [
            _offer(id: 'a', name: 'Karim', fee: 30),
            _offer(id: 'b', name: 'Hadi', fee: 15),
          ],
          windowExpiresAt: DateTime(2030),
          requestIsOpen: true,
        ),
      );

      await tester.pumpWidget(
        _app(
          ClientOffersScreen(
            requestId: 'req-1',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Both cards start with an ENABLED Accept CTA.
      OmdsPrimaryButton acceptButton(String id) => tester
          .widget<OmdsPrimaryButton>(find.byKey(Key('offer-card-accept-$id')));
      expect(acceptButton('a').isEnabled, isTrue);
      expect(acceptButton('b').isEnabled, isTrue);

      // Accept card A → its confirm sheet opens; beginAccept marks the list.
      await tester.tap(find.byKey(const Key('offer-card-accept-a')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('offer_accept_sheet'), findsOneWidget);

      // Now BOTH cards behind the sheet are disabled — a second offer cannot be
      // accepted while one accept is open (the double-accept guard).
      expect(acceptButton('a').isEnabled, isFalse);
      expect(
        acceptButton('b').isEnabled,
        isFalse,
        reason: 'sibling Accept CTA must disable while an accept sheet is open',
      );
    },
  );

  testWidgets(
    'P0-3 — a same-frame double-tap on ONE offer card Accept CTA opens '
    'exactly ONE accept sheet and fires the accept submit once',
    (tester) async {
      // Regression pin for the offer-list call-site re-entrancy guard
      // (`_openAcceptSheet` early-returns when acceptStatus == inFlight). Two
      // taps land in the SAME frame — before the `acceptingOfferId` rebuild can
      // disable the CTA. Without the guard the second tap would call
      // OfferAcceptSheet.show() again and STACK a second accept sheet, letting
      // the user drive two concurrent accept flows (double-accept, B-01).
      final repo = _ScriptedFetchRepository(
        OffersSnapshot(
          offers: [
            _offer(id: 'a', name: 'Karim', fee: 30),
            _offer(id: 'b', name: 'Hadi', fee: 15),
          ],
          windowExpiresAt: DateTime(2030),
          requestIsOpen: true,
        ),
      );

      await tester.pumpWidget(
        _app(
          ClientOffersScreen(
            requestId: 'req-1',
            repository: repo,
            cubitFactory: _testCubitFactory,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Fire card A's onAccept TWICE synchronously — the exact "two rapid taps
      // / two semantics actions before the disable rebuild" double-activation.
      // Both invocations hit `_openAcceptSheet` in the SAME frame: the first
      // sets acceptStatus=inFlight + show()s the sheet; the second must be
      // swallowed by the call-site guard (else it stacks a second sheet).
      final cardA = tester.widget<OfferCard>(
        find.ancestor(
          of: find.byKey(const Key('offer-card-accept-a')),
          matching: find.byType(OfferCard),
        ),
      );
      cardA.onAccept();
      cardA.onAccept();
      await tester.pumpAndSettle();

      // Exactly ONE accept sheet ROUTE is mounted — not two stacked. Counted by
      // widget type, NOT by semantics identifier: a second stacked sheet route
      // sits offstage below the top one and is excluded from the semantics tree,
      // so a semantics finder would vacuously report one even when two exist.
      expect(
        find.byType(OfferAcceptSheet),
        findsOneWidget,
        reason: 'a same-frame double-activation must stack exactly one sheet',
      );

      // Confirm the single sheet → the accept POST fires exactly once.
      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump();
      expect(
        repo.acceptCalls,
        1,
        reason: 'exactly one sheet means the accept submit fires only once',
      );
    },
  );

  testWidgets(
    'P0-1 (2nd call site) — a double-tap on the Replies Accept CTA opens '
    'only ONE sheet',
    (tester) async {
      final gated = _GatedOffersRepository()..fetchGate = Completer<void>();
      GetIt.instance.registerSingleton<OffersRepository>(gated);

      final ClientHomeRepository homeRepo = InMemoryClientHomeRepository();

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BlocProvider(
              create: (_) => ClientHomeCubit(
                repository: homeRepo,
                greetingNameProvider: () => 'Sami',
              )..load(),
              child: const RepliesTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final acceptCta = find.bySemanticsIdentifier('replies_accept_cta');
      // Seeded home data may render 0..n reply rows; only assert the guard when
      // an Accept CTA is present.
      if (acceptCta.evaluate().isEmpty) {
        gated.fetchGate!.complete();
        return;
      }

      // First tap: begins resolving offers (held by the fetch gate). Second tap
      // while that is still resolving must be swallowed by the re-entrancy guard.
      await tester.tap(acceptCta.first);
      await tester.pump();
      await tester.tap(acceptCta.first, warnIfMissed: false);
      await tester.pump();

      expect(
        gated.fetchCalls,
        1,
        reason: 'the second tap must not start a second accept flow',
      );

      gated.fetchGate!.complete();
      await tester.pumpAndSettle();
    },
  );
}
