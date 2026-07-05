// Isolated native UI test — CancellationScreen (delivery-cancel, T-MOB-024).
// The screen owns its BlocProvider and resolves a CancellationRepository from
// the `repository` seam, so injecting a scripted fake avoids DI/network. The
// cubit starts in CancellationIdle (no async load, no timers). `context.push`/
// `context.pop` only fire on submit, so the harness's plain MaterialApp is
// enough. The `?role=` param maps to `isJeeber`, which swaps the reason list —
// covered for both roles here.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';

import '../support/screen_harness.dart';

/// Inert repo — a submit is never triggered from the captured idle picker.
class _FakeCancellationRepo implements CancellationRepository {
  const _FakeCancellationRepo();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      const CancellationResult(
        deliveryId: 'DLV-1',
        feeApplied: 0,
        weeklyCount: 1,
      );
}

CancellationScreen _cancellation({required bool isJeeber}) => CancellationScreen(
      deliveryId: 'DLV-1',
      isJeeber: isJeeber,
      repository: const _FakeCancellationRepo(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivery-cancel: client reasons (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _cancellation(isJeeber: false),
      'delivery-cancel__client',
    );
  });

  testWidgets('delivery-cancel: jeeber reasons (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _cancellation(isJeeber: true),
      'delivery-cancel__jeeber',
    );
  });

  testWidgets('delivery-cancel: client reasons (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _cancellation(isJeeber: false),
      'delivery-cancel__ar',
      locale: const Locale('ar'),
    );
  });
}
