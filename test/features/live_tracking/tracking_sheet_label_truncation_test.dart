// D-W4 — the tracking sheet clipped its own labels at 1.0x on an A336B:
// "Door code — share onl…" (the note squeezed by the inflexible code strip) and
// "Report no-…" (the leading half of the 50/50 split footer).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

/// The A336B, in dp — the handset the wave-2 frames were shot on.
const Size kA336B = Size(412, 915);

class _MockRepo extends Mock implements LiveTrackingRepository {}

class _MemoryStore implements HandoverCodeStore {
  _MemoryStore([Map<String, String>? seed]) : rows = {...?seed};

  final Map<String, String> rows;

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    rows[deliveryId] = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => rows[deliveryId];

  @override
  Future<void> clear({required String deliveryId}) async {
    rows.remove(deliveryId);
  }
}

Widget _harness(LiveTrackingCubit cubit, double textScale) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: BlocProvider<LiveTrackingCubit>.value(
      value: cubit,
      child: const LiveTrackingScreen(
        deliveryId: 'DLV-770001',
        useLiveMap: false,
      ),
    ),
  ),
);

/// True when the paragraph had to ellipsize — the actual on-screen "…".
bool _truncated(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

Future<LiveTrackingCubit> _pump(WidgetTester tester, double textScale) async {
  final repo = _MockRepo();
  when(
    () => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')),
  ).thenAnswer(
    (_) async => DeliveryTrackingInfo.fromDeliveryJson('DLV-770001', {
      'id': 'DLV-770001',
      'status': 'InTransit',
    }),
  );
  final cubit = LiveTrackingCubit(
    repository: repo,
    deliveryId: 'DLV-770001',
    refreshSignals: const Stream<void>.empty(),
    handoverCodeStore: _MemoryStore({'DLV-770001': '1234'}),
  );

  await tester.pumpWidget(_harness(cubit, textScale));
  await tester.pump();
  await tester.pump();
  return cubit;
}

void main() {
  setUpAll(loadInterTestFont);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = kA336B;
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  for (final scale in const [1.0, 1.3]) {
    testWidgets('D-W4 — the door-code note is not clipped at ${scale}x', (
      tester,
    ) async {
      final cubit = await _pump(tester, scale);

      final label = find.text('Door code — share only at handoff');
      expect(label, findsOneWidget);
      expect(
        _truncated(tester, label),
        isFalse,
        reason: 'the note wraps to a second line instead of ellipsizing',
      );
      await cubit.close();
    });

    testWidgets('D-W4 — the split action CTAs are not clipped at ${scale}x', (
      tester,
    ) async {
      final cubit = await _pump(tester, scale);

      for (final label in const ['Report no-show', 'Open dispute']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        expect(
          _truncated(tester, finder),
          isFalse,
          reason: '$label must scale down, never ellipsize',
        );
      }
      await cubit.close();
    });
  }
}
