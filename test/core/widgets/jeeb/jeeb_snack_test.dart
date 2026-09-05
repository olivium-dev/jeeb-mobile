// The three transient surfaces collapse into these three functions. The
// contrast pair, the identifier and the Retry action are the whole point:
// `showOmdsErrorSnackbar` shipped 2.79:1 ink, no id and no way to retry.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_snack.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'jeeb_failure_test_harness.dart';

/// The AA floor for body copy on a coloured slab.
const double _kAaFloor = 4.5;

double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

/// A button that fires [onTap] with the tapped element's own context, which is
/// how every real call site reaches `ScaffoldMessenger`.
Widget _trigger(void Function(BuildContext context) onTap) => Builder(
  builder: (BuildContext context) => TextButton(
    onPressed: () => onTap(context),
    child: const Text('fire'),
  ),
);

Future<void> _fire(
  WidgetTester tester,
  void Function(BuildContext) onTap, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(wrapMidnight(_trigger(onTap), locale: locale));
  await tester.tap(find.text('fire'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

SnackBar _snack(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

Color _ink(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)).first,
    )
    .style!
    .color!;

void main() {
  group('showJeebErrorSnack', () {
    testWidgets('paints the errorContainer pair, not the themed surface', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'profile_edit_error_snack',
          failure: const NetworkFailure(),
        ),
      );

      final ColorScheme scheme = AppTheme.midnight().colorScheme;
      expect(_snack(tester).backgroundColor, scheme.errorContainer);
      expect(_ink(tester), scheme.onErrorContainer);
      expect(
        _snack(tester).backgroundColor,
        isNot(AppTheme.midnight().snackBarTheme.backgroundColor),
        reason: 'the theme hard-codes surfaceHigh, which carries no failure '
            'signal at all',
      );
    });

    testWidgets('the pair clears AA — the old red/#EDEFFC pair was 2.79:1', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'profile_edit_error_snack',
          message: 'Could not save.',
        ),
      );

      expect(
        _contrast(_ink(tester), _snack(tester).backgroundColor!),
        greaterThanOrEqualTo(_kAaFloor),
      );
    });

    testWidgets('carries an identifier and announces itself', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_error_snack',
          failure: const ServerFailure(status: 500),
        ),
      );

      expect(
        find.bySemanticsIdentifier('order_history_error_snack'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('order_history_error_snack'),
            )
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });

    testWidgets('a failure resolves through the copy family, in both locales', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in kFailureLocales) {
        await _fire(
          tester,
          (BuildContext c) => showJeebErrorSnack(
            c,
            identifier: 'order_history_error_snack',
            failure: const NetworkFailure(offline: true),
          ),
          locale: locale,
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(SnackBar)),
        );
        expect(
          find.text(failureCopy(l10n, const NetworkFailure()).body),
          findsOneWidget,
        );
      }
    });

    testWidgets('onRetry becomes a SnackBarAction labelled actionRetry', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_error_snack',
          failure: const ServerFailure(status: 500),
          onRetry: () => retries++,
        ),
      );

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(SnackBar)),
      );
      expect(find.widgetWithText(SnackBarAction, l10n.actionRetry), findsOneWidget);
      expect(
        find.byKey(const Key('order_history_error_snack_retry_cta')),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.actionRetry));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('no onRetry means no action — never a dead button', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_error_snack',
          message: 'Could not save.',
        ),
      );

      expect(_snack(tester).action, isNull);
    });

    testWidgets('passing neither failure nor message is rejected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapMidnight(
          _trigger(
            (BuildContext c) =>
                showJeebErrorSnack(c, identifier: 'x_error_snack'),
          ),
        ),
      );
      await tester.tap(find.text('fire'));
      await tester.pump();

      expect(tester.takeException(), isAssertionError);
    });
  });

  group('showJeebSnack and showJeebSuccessSnack', () {
    testWidgets('the neutral snack takes the surface pair, no role colour', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebSnack(
          c,
          message: 'Copied',
          identifier: 'support_copy_snack',
        ),
      );

      final ColorScheme scheme = AppTheme.midnight().colorScheme;
      expect(_snack(tester).backgroundColor, scheme.surfaceContainerHigh);
      expect(_snack(tester).backgroundColor, isNot(scheme.errorContainer));
      expect(find.bySemanticsIdentifier('support_copy_snack'), findsOneWidget);
    });

    testWidgets('the success snack takes the semantic pair, never raw green', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebSuccessSnack(
          c,
          message: 'Offer sent',
          identifier: 'offer_sent_snack',
        ),
      );

      final JeebRoles roles = JeebRolesX(
        tester.element(find.byType(SnackBar)),
      ).jeebRoles;
      expect(_snack(tester).backgroundColor, roles.successContainer);
      expect(_ink(tester), roles.onSuccessContainer);
      expect(_snack(tester).backgroundColor, isNot(Colors.green));
      expect(
        _contrast(_ink(tester), _snack(tester).backgroundColor!),
        greaterThanOrEqualTo(_kAaFloor),
      );
    });

    testWidgets('an action fires and is labelled by the caller', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _fire(
        tester,
        (BuildContext c) => showJeebSnack(
          c,
          message: 'Saved',
          identifier: 'settings_saved_snack',
          actionLabel: 'Undo',
          onAction: () => taps++,
        ),
      );

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('duration', () {
    testWidgets('defaults to the Material four seconds', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebSnack(
          c,
          message: 'Saved',
          identifier: 'settings_saved_snack',
        ),
      );

      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 4),
      );
    });

    testWidgets('a caller-supplied duration wins on every helper', (
      WidgetTester tester,
    ) async {
      const Duration long = Duration(seconds: 8);

      await _fire(
        tester,
        (BuildContext c) => showJeebSnack(
          c,
          message: 'Saved',
          identifier: 'settings_saved_snack',
          duration: long,
        ),
      );
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, long);

      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'settings_error_snack',
          failure: const NetworkFailure(),
          duration: long,
        ),
      );
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, long);

      await _fire(
        tester,
        (BuildContext c) => showJeebSuccessSnack(
          c,
          message: 'Done',
          identifier: 'settings_success_snack',
          duration: long,
        ),
      );
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, long);
    });
  });

  testWidgets('a second snack replaces the first rather than queueing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapMidnight(
        _trigger(
          (BuildContext c) {
            showJeebSnack(c, message: 'first', identifier: 'a_snack');
            showJeebErrorSnack(
              c,
              identifier: 'b_snack',
              message: 'second',
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });
}
