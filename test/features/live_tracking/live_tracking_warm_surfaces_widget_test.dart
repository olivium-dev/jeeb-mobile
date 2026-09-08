// UX-09/UX-11/NET-05 — the three tracking surfaces the cubit tests proved but
// nothing ever RENDERED: the cold loading rung, the warm refresh strip and the
// position-stream notice.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const DeliveryTrackingInfo _info = DeliveryTrackingInfo(
  deliveryId: 'DLV-1',
  currentStage: TrackingStage.inTransit,
  stageTimestamps: <TrackingStage, DateTime>{},
  requestId: 'REQ-1',
);

/// Reads once, then refuses — the warm-failure lane.
class _WarmFailingRepository implements LiveTrackingRepository {
  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    reads++;
    if (reads == 1) return _info;
    throw const LiveTrackingException(LiveTrackingErrorKind.network);
  }
}

/// Never answers — the cold loading rung.
class _PendingRepository implements LiveTrackingRepository {
  const _PendingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) => Completer<DeliveryTrackingInfo>().future;
}

class _StaticRepository implements LiveTrackingRepository {
  const _StaticRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async => _info;
}

/// The channel the gateway rejected: `streamUnavailable`, not "no news".
class _RefusingChannel
    implements CourierPositionChannel, CourierPositionChannelOutcome {
  const _RefusingChannel();

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;

  @override
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  }) async =>
      const CourierPositionOpenResult.failed(
        CourierPositionOpenFailure.authRejected,
      );
}

LiveTrackingCubit _cubit(
  LiveTrackingRepository repository, {
  CourierPositionChannel? channel,
}) =>
    LiveTrackingCubit(
      repository: repository,
      deliveryId: 'DLV-1',
      refreshSignals: const Stream<void>.empty(),
      positionChannel: channel,
    );

Widget _harness(LiveTrackingCubit cubit, Locale locale) => wrapForTest(
      BlocProvider<LiveTrackingCubit>.value(
        value: cubit,
        child: const LiveTrackingScreen(deliveryId: 'DLV-1', useLiveMap: false),
      ),
      locale: locale,
    );

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('[$tag] the cold read renders tracking_loading',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      final LiveTrackingCubit cubit = _cubit(const _PendingRepository());
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pump();

      expect(find.bySemanticsIdentifier('tracking_loading'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_error_state'), findsNothing);
    });

    testWidgets('[$tag] a warm failure renders tracking_refresh_failed over '
        'the rows, and dismiss clears it', (WidgetTester tester) async {
      useReduceMotion(tester);
      final LiveTrackingCubit cubit = _cubit(_WarmFailingRepository());
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('tracking_refresh_failed'), findsNothing);

      await cubit.refreshNow();
      await tester.pumpAndSettle();

      // The rows stayed: the error rung never took the screen.
      expect(find.bySemanticsIdentifier('tracking_error_state'), findsNothing);
      expect(
        find.bySemanticsIdentifier('tracking_refresh_failed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('tracking_refresh_failed_retry_cta'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier('tracking_refresh_failed_dismiss_cta'),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier('tracking_refresh_failed'), findsNothing);
    });

    testWidgets('[$tag] a rejected position channel renders '
        'tracking_stream_unavailable', (WidgetTester tester) async {
      useReduceMotion(tester);
      final LiveTrackingCubit cubit = _cubit(
        const _StaticRepository(),
        channel: const _RefusingChannel(),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();

      expect(cubit.state.streamUnavailable, isTrue);
      expect(
        find.bySemanticsIdentifier('tracking_stream_unavailable'),
        findsOneWidget,
      );
    });
  }
}
