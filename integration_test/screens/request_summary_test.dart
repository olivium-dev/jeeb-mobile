// Isolated native UI test — RequestSummaryScreen (request-summary). The screen
// reads its RequestSummaryCubit from the tree (no self-provider) and renders the
// OmdsLoadingState fallback until a draft is present, so we wrap it in a
// BlocProvider.value over a cubit seeded with a RequestDraft. The submission
// service is an inert inline fake (submit fires only on tap; `context.go('/')`
// only on the submit-success edge), so the plain MaterialApp harness is enough.
// Captures the assembled summary card in en + Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';

import '../support/screen_harness.dart';

/// Inert service — the summary is captured before any submit is triggered.
class _NoopSubmissionService implements RequestSubmissionService {
  const _NoopSubmissionService();
  @override
  Future<String> submit(RequestDraft draft) async => 'req-server-1';
}

const _draft = RequestDraft(
  description: 'Bring me 2 kg of tomatoes and a loaf of bread from the souq',
  transcription: 'كيلو بندورة من السوق',
  photoUrls: ['a.jpg', 'b.jpg'],
  tierName: 'Flash',
  pickupAddress: 'Souq, Hamra Street, Beirut',
  dropoffAddress: 'Verdun 732, Beirut',
);

RequestSummaryCubit _cubit() =>
    RequestSummaryCubit(const _NoopSubmissionService())..setDraft(_draft);

Widget _host(RequestSummaryCubit cubit) =>
    BlocProvider<RequestSummaryCubit>.value(
      value: cubit,
      child: const RequestSummaryScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('request-summary: assembled draft (en)', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _host(cubit), 'request-summary__filled');
  });

  testWidgets('request-summary: assembled draft (ar)', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit),
      'request-summary__ar',
      locale: const Locale('ar'),
    );
  });
}
