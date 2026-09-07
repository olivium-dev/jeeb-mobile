import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_snack.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../../support/midnight_test_harness.dart';
import 'jeeb_failure_test_harness.dart';

void _copy(String actual, String expected, Locale locale) {
  expect(actual, expected);
  if (locale.languageCode == 'ar') {
    expect(RegExp(r'[A-Za-z]{3,}|[\u0660-\u0669]').hasMatch(actual), isFalse);
  }
}

String _actionTooltip(WidgetTester tester, Finder container) {
  final tooltips = <String>[];
  tester.getSemantics(container).visitChildren((node) {
    tooltips.add(node.getSemanticsData().tooltip);
    return true;
  });
  expect(tooltips, hasLength(1));
  return tooltips.single;
}

void _before(WidgetTester tester, Finder first, Finder second, Locale locale) {
  final firstX = tester.getCenter(first).dx;
  final secondX = tester.getCenter(second).dx;
  expect(
    firstX,
    locale.languageCode == 'ar' ? lessThan(secondX) : greaterThan(secondX),
  );
}

void main() {
  tearDown(NetworkReachabilitySignals.debugReset);

  for (final locale in kFailureLocales) {
    testWidgets(
      'failure Retry is centred and its leading icon mirrors · ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          wrapMidnight(
            JeebFailureBlock(
              identifier: 'rtl_error',
              failure: const TimeoutFailure(
                phase: DioExceptionType.receiveTimeout,
              ),
              onRetry: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final block = find.byType(JeebFailureBlock);
        final l10n = AppLocalizations.of(tester.element(block));
        expect(
          Directionality.of(tester.element(block)),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        final retry = find.bySemanticsIdentifier('rtl_retry_cta');
        expect(
          tester.getCenter(retry).dx,
          closeTo(tester.getSize(find.byType(Scaffold)).width / 2, 8),
        );
        final icon = find.descendant(
          of: retry,
          matching: find.byIcon(Icons.refresh),
        );
        final label = find.descendant(
          of: retry,
          matching: find.text(l10n.actionRetry),
        );
        _before(tester, label, icon, locale);
        _copy(
          tester
              .getSemantics(find.bySemanticsIdentifier('rtl_error_headline'))
              .label,
          l10n.errorTimeoutTitle,
          locale,
        );
        _copy(
          tester
              .getSemantics(find.bySemanticsIdentifier('rtl_error_body'))
              .label,
          l10n.errorTimeoutBody,
          locale,
        );
        _copy(tester.widget<Text>(label).data!, l10n.actionRetry, locale);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'refresh note Dismiss trails Retry in the locale direction · ${locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          wrapMidnight(
            JeebRefreshFailedNote(
              identifier: 'rtl_refresh_failed',
              failure: const NetworkFailure(offline: true),
              onRetry: () {},
              onDismiss: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(JeebRefreshFailedNote)),
        );
        final retry = find.bySemanticsIdentifier(
          'rtl_refresh_failed_retry_cta',
        );
        final dismiss = find.bySemanticsIdentifier(
          'rtl_refresh_failed_dismiss_cta',
        );
        _before(tester, dismiss, retry, locale);
        _copy(
          tester
              .getSemantics(find.bySemanticsIdentifier('rtl_refresh_failed'))
              .label,
          l10n.errorNetworkBody,
          locale,
        );
        _copy(
          _actionTooltip(tester, retry),
          l10n.actionRetry,
          locale,
        );
        _copy(
          _actionTooltip(tester, dismiss),
          l10n.actionDismiss,
          locale,
        );
      },
    );

    testWidgets(
      'snack Retry mirrors relative to the actual copy · ${locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          wrapMidnight(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showJeebErrorSnack(
                  context,
                  identifier: 'rtl_snack',
                  failure: const NetworkFailure(offline: true),
                  onRetry: () {},
                ),
                child: const Text('fire'),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('fire'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(SnackBar)));
        final retry = find.byKey(const Key('rtl_snack_retry_cta'));
        final content = find.bySemanticsIdentifier('rtl_snack');
        _before(tester, retry, content, locale);
        _copy(
          tester.getSemantics(content).label,
          l10n.errorNetworkBody,
          locale,
        );
        _copy(
          tester.widget<SnackBarAction>(retry).label,
          l10n.actionRetry,
          locale,
        );
      },
    );

    testWidgets(
      'offline banner Dismiss mirrors relative to cloud icon · ${locale.languageCode}',
      (tester) async {
        final cubit = OfflineCubit()..setOffline();
        addTearDown(cubit.close);
        await tester.pumpWidget(
          wrapMidnight(
            BlocProvider.value(value: cubit, child: const OfflineBanner()),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(OfflineBanner)),
        );
        final dismiss = find.bySemanticsIdentifier(
          'offline_banner_dismiss_cta',
        );
        _before(tester, dismiss, find.byIcon(Icons.cloud_off), locale);
        _copy(
          tester
              .getSemantics(find.bySemanticsIdentifier('offline_banner'))
              .label,
          l10n.offlineBannerMessage,
          locale,
        );
        _copy(tester.getSemantics(dismiss).label, l10n.commonDismiss, locale);
      },
    );
  }
}
