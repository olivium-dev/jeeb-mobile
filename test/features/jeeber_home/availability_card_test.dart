// sprint-009 §G2 — the compact M3 availability card that replaced the legacy
// 168-px glowing green disc.
//
// Proves:
//   1. Offline state: Switch OFF, neutral status chip, "You're offline" copy.
//   2. Online state: Switch ON, chip + switch colors resolve from the THEME's
//      semantic success role (`JeebColorRoles`) — never a raw hex green.
//   3. The corrected copy: "You're online — receiving requests" (jeebers
//      RECEIVE requests and MAKE offers), en + ar.
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
    status: AvailabilityStatus(
      state: state,
      activeDeliveryCount: deliveries,
    ),
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
    home: Scaffold(body: child),
  );
}

void main() {
  group('AvailabilityCard — states and copy (G2)', () {
    testWidgets('offline: switch OFF, neutral chip, "You\'re offline" copy',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AvailabilityCard(
            view: _viewState(AvailabilityState.offline),
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchWidget =
          tester.widget<Switch>(find.byKey(AvailabilityCard.toggleKey));
      expect(switchWidget.value, isFalse);

      final context = tester.element(find.byKey(AvailabilityCard.rootKey));
      final scheme = Theme.of(context).colorScheme;
      final chip =
          tester.widget<OmdsChip>(find.byKey(AvailabilityCard.statusChipKey));
      expect(chip.label, 'Offline');
      expect(chip.selectedColor, scheme.surfaceContainerHighest,
          reason: 'Offline chip must use the neutral surface role.');

      expect(find.text("You're offline"), findsOneWidget);
      // Idle hint + deliveries line are online-only.
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets(
        'online: switch ON, chip + track colors come from the THEME success '
        'role (no raw hex), corrected copy + idle hint render', (tester) async {
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

      final switchWidget =
          tester.widget<Switch>(find.byKey(AvailabilityCard.toggleKey));
      expect(switchWidget.value, isTrue);
      expect(switchWidget.activeTrackColor, roles.success,
          reason: 'Online track color must resolve from the semantic success '
              'role of the active theme — not a hex literal.');

      final chip =
          tester.widget<OmdsChip>(find.byKey(AvailabilityCard.statusChipKey));
      expect(chip.label, 'Online');
      expect(chip.selectedColor, roles.successContainer);
      expect(chip.selectedTextColor, roles.onSuccessContainer);
      // The legacy disc's raw green must be gone from the resolved colors.
      expect(chip.selectedColor, isNot(const Color(0xFF22C55E)));
      expect(switchWidget.activeTrackColor, isNot(const Color(0xFF22C55E)));

      // G2 copy fix: jeebers RECEIVE requests (they MAKE offers).
      expect(find.text("You're online — receiving requests"), findsOneWidget);
      expect(find.text('2 active deliveries'), findsOneWidget);
      expect(find.text('Auto-offline after 8 h idle'), findsOneWidget);
    });

    testWidgets('arabic copy: online status says تستقبل الطلبات (requests)',
        (tester) async {
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
      expect(find.text('متصل'), findsWidgets); // chip label
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
      expect(find.byKey(AvailabilityCard.toggleKey), findsNothing,
          reason: 'No tappable switch while the PUT is in-flight.');
      expect(find.text('Updating…'), findsOneWidget);
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
    testWidgets('renders inside JeeberFeedTabView when the feed has requests',
        (tester) async {
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
