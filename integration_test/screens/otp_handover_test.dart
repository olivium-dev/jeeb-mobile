// Isolated native UI test — OtpHandoverScreen (otp-handover, T-MOB-018). The
// screen reads its OtpHandoverCubit from the tree (no self-provider), so we wrap
// it in a BlocProvider.value over a cubit driven by an in-memory
// OtpHandoverRepository. The cubit only uses Futures (no timers/streams), so the
// binding has no pending timers. `context.go`/escalate-dialog fire only on tap
// or escalation, so the harness's plain MaterialApp (no router) is enough.
// Covers both `?mode=` legs: the client code display and the Jeeber entry grid.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';

import '../support/screen_harness.dart';

/// Serves a fixed handover code to the client leg (or an SMS-trigger shape when
/// [code] is null) and accepts any Jeeber OTP submit.
class _FakeOtpRepo implements OtpHandoverRepository {
  const _FakeOtpRepo({this.code});
  final String? code;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      OtpFetchResult(code: code, smsTriggered: code == null);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async =>
      const OtpHandoverResult(success: true);
}

OtpHandoverCubit _cubit({required bool isClient, String? code}) =>
    OtpHandoverCubit(
      repository: _FakeOtpRepo(code: code),
      deliveryId: 'DLV-770001',
      isClient: isClient,
    );

Widget _host(OtpHandoverCubit cubit, {required bool isClient}) =>
    BlocProvider<OtpHandoverCubit>.value(
      value: cubit,
      child: OtpHandoverScreen(deliveryId: 'DLV-770001', isClient: isClient),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('otp-handover: client code display (en)', (tester) async {
    final cubit = _cubit(isClient: true, code: '1234');
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit, isClient: true),
      'otp-handover__client',
    );
  });

  testWidgets('otp-handover: jeeber code entry (en)', (tester) async {
    final cubit = _cubit(isClient: false);
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit, isClient: false),
      'otp-handover__jeeber',
    );
  });

  testWidgets('otp-handover: client code display (ar)', (tester) async {
    final cubit = _cubit(isClient: true, code: '1234');
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit, isClient: true),
      'otp-handover__ar',
      locale: const Locale('ar'),
    );
  });
}
