// Jeeber Dashboard availability hierarchy regression proof.
//
// Proves:
//   1. Offline state: the navy strip with Switch OFF + status copy.
//   2. Online state: the SAME navy strip (redesign-2026-08: one shape for every
//      state), with the semantic success role (`JeebColorRoles`) driving the
//      on-track and no delivery-count/idle supporting lines.
//   3. The compact copy says "You're online — receiving requests", en + ar.
//   4. Toggling forwards to the cubit wiring (onToggle) and the in-flight
//      frame swaps the switch for the legacy-keyed spinner (tap-blocked).
//   5. §SW-23 persistence: the card also renders in the FEED state
//      (JeeberFeedTabView with a non-empty feed) — availability never
//      disappears exactly when the Jeeber is busy.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

AvailabilityViewState _viewState(
  AvailabilityState state, {
  int deliveries = 0,
  bool inFlight = false,
}) {
  return AvailabilityViewState(
    loadPhase: AvailabilityLoadPhase.ready,
    status: AvailabilityStatus(state: state, activeDeliveryCount: deliveries),
    isToggleInFlight: inFlight,
  );
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
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
    // E3's illustration loops ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion, which is also the capture rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}

class _ExpandedOnlineCopyDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _ExpandedOnlineCopyDelegate(this.onlineCopy);

  final String onlineCopy;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale, {
        'availabilityStatusOnline': onlineCopy,
        'availabilityIndicatorSemanticOnline': onlineCopy,
      });

  @override
  bool shouldReload(_ExpandedOnlineCopyDelegate old) =>
      onlineCopy != old.onlineCopy;
}

const String _expandedOnlineCopy =
    'You are online and receiving delivery requests from nearby customers '
    'across your whole service area right now';

Widget _contractHost({TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      _ExpandedOnlineCopyDelegate(_expandedOnlineCopy),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: AvailabilityCard(
        view: _viewState(AvailabilityState.online),
        onToggle: _noop,
      ),
    ),
  );
}

void _noop() {}

/// The fill the online strip paints (the lit skin is a `DecoratedBox`, not the
/// navy kit card).
Color? _stripFill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(AvailabilityCard.rootKey),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void _expectOnlineCopyWithinTwoLineBudget(WidgetTester tester) {
  final textFinder = find.text(_expandedOnlineCopy);
  final text = tester.widget<Text>(textFinder);
  final context = tester.element(textFinder);
  final defaults = DefaultTextStyle.of(context);
  final effectiveStyle = defaults.style.merge(text.style);
  final linePainter = TextPainter(
    text: TextSpan(text: 'M', style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final twoLineHeight = linePainter.preferredLineHeight * 2;
  linePainter.dispose();

  expect(
    tester.getSize(textFinder).height,
    lessThanOrEqualTo(twoLineHeight),
    reason: 'Expanded online copy must render within two text lines.',
  );
  expect(defaults.maxLines, 2);
  expect(defaults.overflow, TextOverflow.ellipsis);
}

void main() {
  group('AvailabilityCard — state-aware density', () {
    testWidgets('offline: navy strip, switch OFF, offline copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.offline),
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(
        find.byKey(AvailabilityCard.toggleKey),
      );
      expect(switchWidget.value, isFalse);
      expect(find.byType(JeebNavySurfaceCard), findsOneWidget);

      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets('online: the navy strip uses the success role and omits '
        'supporting availability lines', (tester) async {
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.online, deliveries: 2),
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(AvailabilityCard.rootKey));
      final roles = Theme.of(context).extension<JeebColorRoles>()!;

      final switchWidget = tester.widget<Switch>(
        find.byKey(AvailabilityCard.toggleKey),
      );
      expect(switchWidget.value, isTrue);
      expect(
        switchWidget.activeTrackColor,
        roles.success,
        reason:
            'Online track color must resolve from the semantic success '
            'role of the active theme.',
      );

      expect(find.text("You're online — receiving requests"), findsOneWidget);
      expect(find.text('2 active deliveries'), findsNothing);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
      // MIDNIGHT R16: "the availability card glows green when online" — the
      // geometry is the offline strip's, the SKIN is success-tinted glass.
      expect(find.byType(JeebNavySurfaceCard), findsNothing);
      expect(_stripFill(tester), roles.success.withValues(alpha: 0.14));
      expect(
        tester.getSize(find.byKey(AvailabilityCard.rootKey)).height,
        lessThanOrEqualTo(Sizes.sevenXLarge),
        reason: 'Online availability must remain a one-row dashboard control.',
      );
    });

    testWidgets('arabic copy: online status says تستقبل الطلبات (requests)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.online),
            onToggle: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنت متصل — تستقبل الطلبات'), findsOneWidget);
      expect(find.byType(JeebNavySurfaceCard), findsNothing);
      expect(
        tester.getSize(find.byKey(AvailabilityCard.rootKey)).height,
        lessThanOrEqualTo(Sizes.sevenXLarge),
      );
    });

    testWidgets('online copy stays within two lines on a 320dp surface', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_contractHost());
      await tester.pumpAndSettle();

      _expectOnlineCopyWithinTwoLineBudget(tester);
    });

    testWidgets('online copy stays within two lines at 200% text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _contractHost(textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();

      _expectOnlineCopyWithinTwoLineBudget(tester);
    });

    testWidgets('tapping the switch forwards to onToggle; in-flight swaps the '
        'switch for the tap-blocking spinner', (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.offline),
            onToggle: () => toggles++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AvailabilityCard.toggleKey));
      await tester.pump();
      expect(toggles, 1);

      // In-flight frame: spinner (legacy key) replaces the switch entirely.
      // (pump, not pumpAndSettle — the loading indicator animates forever.)
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.offline, inFlight: true),
            onToggle: () => toggles++,
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(AvailabilityCard.spinnerKey), findsOneWidget);
      expect(
        find.byKey(AvailabilityCard.toggleKey),
        findsNothing,
        reason: 'No tappable switch while the PUT is in-flight.',
      );
      expect(find.text('Updating…'), findsOneWidget);
      expect(
        find.byType(JeebNavySurfaceCard),
        findsOneWidget,
        reason: 'The strip does not change shape while the PUT is in flight.',
      );
    });

    testWidgets('switch exposes toggle semantics for TalkBack', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.online),
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('availability_switch'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsIdentifier('availability_switch'),
      );
      expect(node.label, isNotEmpty);
      handle.dispose();
    });
  });

  group('AvailabilityCard — §SW-23 persistence in the feed state', () {
    testWidgets('renders inside JeeberFeedTabView when the feed has requests', (
      tester,
    ) async {
      final ticker = StreamController<DateTime>.broadcast();
      addTearDown(ticker.close);
      final avCubit = AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(
          initial: AvailabilityStatus.initial.copyWith(
            state: AvailabilityState.online,
          ),
        ),
        tickerFactory: () => ticker.stream,
      );
      addTearDown(avCubit.close);
      final feedCubit = RequestFeedCubit(
        repository: SeededRequestFeedRepository([
          DeliveryRequest(
            id: 'req-1',
            pickup: const RequestLocation(
              label: 'Pickup',
              latitude: 33.8,
              longitude: 35.5,
            ),
            dropoff: const RequestLocation(
              label: 'Dropoff',
              latitude: 33.9,
              longitude: 35.6,
            ),
            tier: JeeberRequestTier.flash,
            estimatedDistanceKm: 1.2,
            potentialEarnings: 5.0,
            currency: 'USD',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
            feedStatus: JeeberFeedItemStatus.incoming,
          ),
        ]),
      );
      addTearDown(feedCubit.close);

      await avCubit.load();
      await tester.pumpWidget(
        _host(
          MultiBlocProvider(
            providers: [
              BlocProvider<AvailabilityCubit>.value(value: avCubit),
              BlocProvider<RequestFeedCubit>.value(value: feedCubit),
            ],
            child: const JeeberFeedTabView(),
          ),
        ),
      );
      await tester.pump();
      await feedCubit.refresh();
      await tester.pumpAndSettle();

      // The feed list is live (non-empty state)…
      expect(find.byKey(JeeberFeedTabView.listKey), findsOneWidget);
      // …and the availability card is STILL on the dashboard (G2: the old
      // disc disappeared entirely in this state).
      expect(find.byKey(AvailabilityCard.rootKey), findsOneWidget);
      expect(find.byKey(AvailabilityCard.toggleKey), findsOneWidget);
    });
  });
}
