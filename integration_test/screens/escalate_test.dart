// Isolated native UI test — EscalateScreen (dispute-open-evidence, JM-060).
// The screen owns its own Scaffold but expects an EscalateCubit above it (the
// route provides it), so we seed a cubit off an in-memory repository and pump
// the screen under a BlocProvider.value. Navigation edges (goNamed on submit
// success / support link) fire only on tap, so no router is needed for these
// static shots.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';

import '../support/screen_harness.dart';

/// In-memory EscalateRepository (mirrors the widget test's _FakeRepo): resolves
/// auto-attached evidence, and optionally fails submit to drive the error view.
class _FakeRepo implements EscalateRepository {
  const _FakeRepo({this.failWith});
  final EscalateErrorKind? failWith;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      const EscalateEvidence(
        chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
        chatMessageCount: 3,
        timeline: [
          EscalateTimelineEntry(status: 'Ordered'),
          EscalateTimelineEntry(status: 'Picked'),
          EscalateTimelineEntry(status: 'InTransit'),
        ],
      );

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'dispute-999', status: 'open');
  }
}

Widget _screenWith(EscalateCubit cubit) => BlocProvider<EscalateCubit>.value(
      value: cubit,
      child: const EscalateScreen(),
    );

EscalateCubit _cubit({EscalateReason? reason, EscalateErrorKind? failWith}) {
  final cubit = EscalateCubit(
    repository: _FakeRepo(failWith: failWith),
    deliveryId: 'dlv-1',
  );
  if (reason != null) cubit.setReason(reason);
  return cubit;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('escalate: input form, reason selected (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screenWith(_cubit(reason: EscalateReason.damaged)),
      'escalate__form',
    );
  });

  testWidgets('escalate: server error state (en)', (tester) async {
    final cubit = _cubit(
      reason: EscalateReason.noShow,
      failWith: EscalateErrorKind.server,
    );
    // Seed the error phase before pumping (submit sets phase=error, no nav).
    await cubit.submit();
    await pumpAndShoot(tester, binding, _screenWith(cubit), 'escalate__error');
  });

  testWidgets('escalate: input form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screenWith(_cubit(reason: EscalateReason.fraud)),
      'escalate__ar',
      locale: const Locale('ar'),
    );
  });
}
