import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/users/scenario_users_page.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../../support/midnight_test_harness.dart';
import 'jeeb_failure_test_harness.dart';

const _loading = 'devtool_scenario_users_roster_loading';
const _empty = 'devtool_scenario_users_roster_empty';

class _PendingRosterClient extends DevGatewayClient {
  _PendingRosterClient(this.result) : super(dio: Dio());

  final Future<List<DevUser>> result;

  @override
  Future<List<DevUser>> listUsers({int skip = 0, int limit = 100}) => result;
}

Widget _sameShapeRoster(Future<List<DevUser>> result) =>
    FutureBuilder<List<DevUser>>(
      future: result,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return JeebEmptyState.compact(
            identifier: _loading,
            status: JeebEmptyStateStatus.loading,
            reason: JeebEmptyStateReason.loading,
            variant: JeebEmptyStateVariant.balcony,
            headline: l10n.scenarioUsersRosterLoadingHeadline,
          );
        }
        return JeebEmptyState.compact(
          identifier: _empty,
          reason: JeebEmptyStateReason.nothingYet,
          variant: JeebEmptyStateVariant.balcony,
          headline: l10n.scenarioUsersEmpty,
        );
      },
    );

Finder _block(String identifier) => find.byWidgetPredicate(
  (widget) => widget is JeebEmptyState && widget.identifier == identifier,
);

void main() {
  for (final locale in kFailureLocales) {
    for (final actualPage in <bool>[false, true]) {
      testWidgets(
        'B2-10 ${locale.languageCode} ${actualPage ? 'real page' : 'same shape'} updates an unkeyed retained semantics node',
        (tester) async {
          useReduceMotion(tester);
          final semantics = tester.ensureSemantics();
          tester.view.physicalSize = const Size(1200, 2400);
          tester.view.devicePixelRatio = 1;
          try {
            final result = Completer<List<DevUser>>();
            final child = actualPage
                ? ScenarioUsersPage(client: _PendingRosterClient(result.future))
                : _sameShapeRoster(result.future);
            await tester.pumpWidget(
              wrapMidnight(child, locale: locale, scrollable: false),
            );
            await tester.pump();
            tester.binding.rootPipelineOwner.flushSemantics();
            expect(find.bySemanticsIdentifier(_loading), findsOneWidget);
            final beforeElement = tester.element(_block(_loading));
            final before = tester.getSemantics(
              find.bySemanticsIdentifier(_loading),
            );
            final nodeId = before.id;
            expect(before.getSemanticsData().identifier, _loading);
            expect((beforeElement.widget as JeebEmptyState).key, isNull);

            result.complete(const <DevUser>[]);
            await tester.pump();
            await tester.pump();
            tester.binding.rootPipelineOwner.flushSemantics();
            expect(find.bySemanticsIdentifier(_loading), findsNothing);
            expect(find.bySemanticsIdentifier(_empty), findsOneWidget);
            expect(tester.element(_block(_empty)), same(beforeElement));
            final after = tester.getSemantics(
              find.bySemanticsIdentifier(_empty),
            );
            expect(after.id, nodeId);
            expect(after.getSemanticsData().identifier, _empty);
            final l10n = AppLocalizations.of(tester.element(_block(_empty)));
            expect(find.text(l10n.scenarioUsersEmpty), findsOneWidget);
            debugPrint(
              'B2-10 ${locale.languageCode} actualPage=$actualPage '
              'sameElement=true sameNode=$nodeId identifier=${after.getSemanticsData().identifier}',
            );
          } finally {
            semantics.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }

    testWidgets(
      'B2-20 ${locale.languageCode} unreachable announcement preserves distinct copy once',
      (tester) async {
        useReduceMotion(tester);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            wrapMidnight(
              JeebFailureBlock(
                failure: const NetworkFailure(offline: false),
                identifier: 'unreachable_error',
                onRetry: () {},
              ),
              locale: locale,
            ),
          );
          await tester.pump();
          tester.binding.rootPipelineOwner.flushSemantics();
          final l10n = l10nOf(tester, JeebFailureBlock);
          final title = l10n.errorUnreachableTitle;
          final body = l10n.errorUnreachableBody;
          final data = tester
              .getSemantics(find.bySemanticsIdentifier('unreachable_error'))
              .getSemanticsData();
          debugPrint(
            'B2-20 ${locale.languageCode} title=$title body=$body label=${data.label}',
          );
          expect(data.flagsCollection.isLiveRegion, isTrue);
          expect(body.startsWith('$title. '), locale.languageCode == 'ar');
          expect(
            data.label,
            locale.languageCode == 'ar' ? body : '$title. $body',
          );
          expect(
            RegExp(RegExp.escape(title)).allMatches(data.label),
            hasLength(1),
          );
          expect(find.text(title), findsOneWidget);
          expect(find.text(body), findsOneWidget);
          for (final part in ['headline', 'body']) {
            expect(
              find.bySemanticsIdentifier('unreachable_error_$part'),
              findsOneWidget,
            );
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    for (final compact in [false, true]) {
      testWidgets(
        'announcement ${locale.languageCode} compact=$compact exact duplicates and overrides',
        (tester) async {
          useReduceMotion(tester);
          final semantics = tester.ensureSemantics();
          try {
            final title = locale.languageCode == 'ar'
                ? 'تعذّر الوصول'
                : 'Unavailable';
            for (final sample
                in <
                  ({String? body, String? override, bool? live, String label})
                >[
                  (body: title, override: null, live: null, label: title),
                  (
                    body: '$title. Details',
                    override: null,
                    live: null,
                    label: '$title. Details',
                  ),
                  (
                    body: '$title now. Details',
                    override: null,
                    live: null,
                    label: '$title. $title now. Details',
                  ),
                  (
                    body: 'Details. $title',
                    override: null,
                    live: null,
                    label: '$title. Details. $title',
                  ),
                  (body: null, override: null, live: null, label: title),
                  (
                    body: title,
                    override: 'Explicit',
                    live: null,
                    label: 'Explicit',
                  ),
                  (body: title, override: '', live: null, label: ''),
                  (body: title, override: null, live: false, label: ''),
                  (
                    body: title,
                    override: 'Explicit',
                    live: false,
                    label: 'Explicit',
                  ),
                ]) {
              final child = compact
                  ? JeebEmptyState.compact(
                      headline: title,
                      body: sample.body,
                      identifier: 'sample_error',
                      headlineIdentifier: 'sample_headline',
                      bodyIdentifier: 'sample_body',
                      reason: JeebEmptyStateReason.failed,
                      semanticLabel: sample.override,
                      liveRegion: sample.live,
                    )
                  : JeebEmptyState(
                      headline: title,
                      body: sample.body,
                      identifier: 'sample_error',
                      headlineIdentifier: 'sample_headline',
                      bodyIdentifier: 'sample_body',
                      reason: JeebEmptyStateReason.failed,
                      semanticLabel: sample.override,
                      liveRegion: sample.live,
                    );
              await tester.pumpWidget(wrapMidnight(child, locale: locale));
              await tester.pump();
              tester.binding.rootPipelineOwner.flushSemantics();
              final data = tester
                  .getSemantics(find.bySemanticsIdentifier('sample_error'))
                  .getSemanticsData();
              expect(data.label, sample.label);
              expect(
                data.flagsCollection.isLiveRegion,
                sample.live ?? true,
              );
              expect(
                find.bySemanticsIdentifier('sample_headline'),
                findsOneWidget,
              );
              expect(
                find.bySemanticsIdentifier('sample_body'),
                sample.body == null ? findsNothing : findsOneWidget,
              );
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
