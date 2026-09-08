// ES-15/ESC-08: the three evidence rungs render ONLY behind a repository that
// actually serves a preview, so an "empty evidence" line can never be a lie.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _NoPreviewRepo implements EscalateRepository {
  const _NoPreviewRepo();

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      EscalateEvidence.empty;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async => const EscalateResult(caseId: 'dispute-1', status: 'open');
}

class _PreviewRepo extends _NoPreviewRepo
    implements EscalateEvidencePreviewRepository {
  const _PreviewRepo({this.evidence, this.throws = false});

  final EscalateEvidence? evidence;
  final bool throws;

  @override
  Future<EscalateEvidence> previewEvidence({required String deliveryId}) async {
    if (throws) throw Exception('preview down');
    return evidence ?? EscalateEvidence.empty;
  }
}

void main() {
  final delegates =
      (wrapForTest(const SizedBox()) as MaterialApp).localizationsDelegates!;

  Widget build(EscalateRepository repo, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: delegates,
        home: BlocProvider<EscalateCubit>(
          create: (_) =>
              EscalateCubit(repository: repo, deliveryId: 'dlv-1')
                ..loadEvidence(),
          child: const EscalateScreen(),
        ),
      );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] an empty preview draws the empty rung only', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(build(const _PreviewRepo(), locale: locale));
      await tester.pumpAndSettle();

      expect(byId('dispute_evidence_empty'), findsOneWidget);
      expect(byId('dispute_evidence_error'), findsNothing);
      expect(byId('dispute_evidence_loading'), findsNothing);
      expect(byId('dispute_auto_attach_note'), findsNothing);
    });

    testWidgets('[$tag] a failed preview draws the error rung, never empty', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        build(const _PreviewRepo(throws: true), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(byId('dispute_evidence_error'), findsOneWidget);
      expect(byId('dispute_evidence_empty'), findsNothing);
      expect(byId('dispute_auto_attach_note'), findsNothing);
    });
  }

  testWidgets('a repository with no preview endpoint draws none of the three', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(build(const _NoPreviewRepo()));
    await tester.pumpAndSettle();

    expect(byId('dispute_evidence_loading'), findsNothing);
    expect(byId('dispute_evidence_empty'), findsNothing);
    expect(byId('dispute_evidence_error'), findsNothing);
    // No evidence read means no authority to claim it was attached.
    expect(byId('dispute_auto_attach_note'), findsNothing);
  });

  testWidgets('a resolved preview with content draws no empty rung', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      build(
        const _PreviewRepo(
          evidence: EscalateEvidence(
            chatSnapshotUrl: 'https://cdn.test/conv.html',
            chatMessageCount: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId('dispute_evidence_empty'), findsNothing);
    expect(byId('dispute_evidence_error'), findsNothing);
    expect(byId('dispute_auto_attach_note'), findsOneWidget);
  });
}
