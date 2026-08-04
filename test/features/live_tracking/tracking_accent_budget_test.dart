// M6 orange-budget lane — live tracking's two sanctioned accents and the L10
// map cover. The Show-OTP link and the at-door CTA are the only orange this
// screen spends; the map must never flash Google's light default under them.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/map/jeeb_map_style.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

DeliveryTrackingInfo _fromStatus(String status) =>
    DeliveryTrackingInfo.fromDeliveryJson(
      'DLV-770001',
      <String, dynamic>{'id': 'DLV-770001', 'status': status},
    );

Widget _harness(LiveTrackingCubit cubit) => MaterialApp(
      theme: AppTheme.midnight(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlocProvider<LiveTrackingCubit>.value(
        value: cubit,
        child: const LiveTrackingScreen(
          deliveryId: 'DLV-770001',
          useLiveMap: false,
        ),
      ),
    );

Future<LiveTrackingCubit> _pumpStatus(
  WidgetTester tester,
  String status,
) async {
  final repo = _MockRepo();
  when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
      .thenAnswer((_) async => _fromStatus(status));
  final cubit = LiveTrackingCubit(
    repository: repo,
    deliveryId: 'DLV-770001',
    refreshSignals: const Stream<void>.empty(),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(_harness(cubit));
  await tester.pump();
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets(
    'the Show-OTP link is the sanctioned accent, spelled as a role',
    (tester) async {
      await _pumpStatus(tester, 'InTransit');

      final Finder link = find.byKey(const Key('tracking.codeRowValue'));
      expect(link, findsOneWidget);

      final BuildContext context = tester.element(link);
      final Text label = tester.widget<Text>(link);
      // §4.1's orange text affordance — the ONE sanctioned orange link. This
      // pins it to the ROLE, so a future `scheme.primary` regrind still reads
      // as a deliberate accent rather than a leak.
      expect(
        label.style?.color?.toARGB32(),
        context.jeebRoles.accent.toARGB32(),
      );
    },
  );

  group('L10 · the map never flashes Google\'s light default', () {
    setUp(JeebMapStyle.debugReset);
    tearDown(JeebMapStyle.debugReset);

    testWidgets('an unsettled style is held behind a page-navy cover',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: TrackingGoogleMap(info: _fromStatus('InTransit')),
        ),
      );

      // First frame: the bundle read has not landed, so the cover is up.
      final Finder cover = find.byKey(trackingMapStyleCoverKey);
      expect(cover, findsOneWidget);
      final ColoredBox box = tester.widget<ColoredBox>(
        find.descendant(of: cover, matching: find.byType(ColoredBox)),
      );
      expect(
        box.color.toARGB32(),
        AppTheme.midnight().colorScheme.surfaceContainerLowest.toARGB32(),
      );
      // …and it is inert, so it cannot swallow a pan.
      expect(
        find.descendant(of: cover, matching: find.byType(IgnorePointer)),
        findsOneWidget,
      );
    });

    // NOT ASSERTED HERE — the lift. `TrackingGoogleMap` mounts the real
    // `GoogleMap` platform view (M0-9: "unmockable"), and with it in the tree
    // the `rootBundle` read never settles under `flutter test`, so no amount of
    // pumping flips `_styleSettled`. The lift path is character-for-character
    // the one `GoogleMapCaptureView` already ships, and IS pinned there by
    // `m6_settings_auth_location_receipt_test.dart`'s "the first mount covers
    // the map until the style settles". Re-check on device at M7.
  });
}
