// The three transient surfaces collapse into these three functions. The
// contrast pair, the identifier and the Retry action are the whole point:
// `showOmdsErrorSnackbar` shipped 2.79:1 ink, no id and no way to retry.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
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
  builder: (BuildContext context) =>
      TextButton(onPressed: () => onTap(context), child: const Text('fire')),
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
      find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
          .first,
    )
    .style!
    .color!;

List<Map<String, dynamic>> _diagEvents(List<String> lines, String name) => lines
    .map(
      (line) =>
          jsonDecode(line.substring(Diag.prefix.length + 1))
              as Map<String, dynamic>,
    )
    .where((record) => record['t'] == 'evt' && record['name'] == name)
    .map((record) => record['data'] as Map<String, dynamic>)
    .toList();

class _ObservedReachabilitySignals extends NetworkReachabilitySignals {
  final events = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get stream => events.stream;

  void reconnect() => events.add(null);

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

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
        reason:
            'the theme hard-codes surfaceHigh, which carries no failure '
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
          find.text(
            failureCopy(l10n, const NetworkFailure(offline: true)).body,
          ),
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
      expect(
        find.widgetWithText(SnackBarAction, l10n.actionRetry),
        findsOneWidget,
      );
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
        _trigger((BuildContext c) {
          showJeebSnack(c, message: 'first', identifier: 'a_snack');
          showJeebErrorSnack(c, identifier: 'b_snack', message: 'second');
        }),
      ),
    );
    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  group('F6 · the close cause is observable', () {
    late _ObservedReachabilitySignals bus;
    late List<String> lines;
    const identifier = 'order_history_refresh_failed_snack';

    setUp(() {
      bus = _ObservedReachabilitySignals();
      NetworkReachabilitySignals.instance = bus;
      lines = <String>[];
      Diag.enabledOverride = true;
      Diag.sink = lines.add;
    });

    tearDown(() async {
      await NetworkReachabilitySignals.debugReset();
      Diag.resetForTest();
    });

    for (final locale in kFailureLocales) {
      testWidgets(
        'shown metadata and reconnect cause · ${locale.languageCode}',
        (tester) async {
          await _fire(
            tester,
            (c) => showJeebErrorSnack(
              c,
              identifier: identifier,
              failure: const NetworkFailure(offline: true),
              onRetry: () {},
            ),
            locale: locale,
          );
          expect(_diagEvents(lines, 'snack_shown'), <Map<String, Object?>>[
            <String, Object?>{
              'identifier': identifier,
              'hasAction': true,
              'clearOnReconnect': true,
              'durationMs': jeebSnackActionDuration.inMilliseconds,
            },
          ]);
          expect(bus.events.hasListener, isTrue);
          bus.reconnect();
          bus.reconnect();
          await tester.pumpAndSettle();
          expect(find.bySemanticsIdentifier(identifier), findsNothing);
          final closed = _diagEvents(lines, 'snack_closed');
          expect(closed, hasLength(1));
          expect(closed.single['reason'], 'reconnect');
          expect(closed.single['elapsedMs'], isNonNegative);
          expect(bus.events.hasListener, isFalse);
        },
      );

      testWidgets(
        'natural expiry remains timeout during reconnect · ${locale.languageCode}',
        (tester) async {
          await _fire(
            tester,
            (c) => showJeebErrorSnack(
              c,
              identifier: identifier,
              failure: const NetworkFailure(offline: true),
              onRetry: () {},
            ),
            locale: locale,
          );
          await tester.pump(jeebSnackActionDuration);
          bus.reconnect();
          await tester.pumpAndSettle();
          expect(
            _diagEvents(lines, 'snack_closed').single['reason'],
            'timeout',
          );
          expect(find.bySemanticsIdentifier(identifier), findsNothing);
          expect(bus.events.hasListener, isFalse);
        },
      );

      testWidgets(
        'Retry keeps action cause even if callback reconnects · ${locale.languageCode}',
        (tester) async {
          int retries = 0;
          await _fire(
            tester,
            (c) => showJeebErrorSnack(
              c,
              identifier: identifier,
              failure: const NetworkFailure(offline: true),
              onRetry: () {
                retries++;
                bus.reconnect();
              },
            ),
            locale: locale,
          );
          await tester.tap(find.byKey(const Key('${identifier}_retry_cta')));
          await tester.pumpAndSettle();
          expect(retries, 1);
          expect(_diagEvents(lines, 'snack_closed').single['reason'], 'action');
          expect(bus.events.hasListener, isFalse);
        },
      );

      testWidgets(
        '500 survives reconnect without a close event · ${locale.languageCode}',
        (tester) async {
          await _fire(
            tester,
            (c) => showJeebErrorSnack(
              c,
              identifier: identifier,
              failure: const ServerFailure(status: 500),
              onRetry: () {},
            ),
            locale: locale,
          );
          expect(
            _diagEvents(lines, 'snack_shown').single['clearOnReconnect'],
            isFalse,
          );
          bus.reconnect();
          await tester.pumpAndSettle();
          expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
          expect(_diagEvents(lines, 'snack_closed'), isEmpty);
          expect(bus.events.hasListener, isFalse);
        },
      );

      testWidgets(
        'host lookup uses unreachable copy and reconnect cause · ${locale.languageCode}',
        (tester) async {
          await _fire(
            tester,
            (c) => showJeebErrorSnack(
              c,
              identifier: identifier,
              failure: const NetworkFailure(
                reason: NetworkFailureReason.hostLookup,
              ),
              onRetry: () {},
            ),
            locale: locale,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(SnackBar)),
          );
          expect(find.text(l10n.errorUnreachableBody), findsOneWidget);
          expect(
            _diagEvents(lines, 'snack_shown').single['clearOnReconnect'],
            isTrue,
          );
          bus.reconnect();
          await tester.pumpAndSettle();
          expect(
            _diagEvents(lines, 'snack_closed').single['reason'],
            'reconnect',
          );
          expect(find.bySemanticsIdentifier(identifier), findsNothing);
        },
      );
    }

    testWidgets('an explicit action duration wins on every helper', (
      tester,
    ) async {
      const duration = Duration(seconds: 2);
      final helpers = <void Function(BuildContext)>[
        (c) => showJeebErrorSnack(
          c,
          identifier: identifier,
          failure: const NetworkFailure(),
          onRetry: () {},
          duration: duration,
        ),
        (c) => showJeebSnack(
          c,
          identifier: identifier,
          message: 'Saved',
          actionLabel: 'Undo',
          onAction: () {},
          duration: duration,
        ),
        (c) => showJeebSuccessSnack(
          c,
          identifier: identifier,
          message: 'Saved',
          actionLabel: 'Undo',
          onAction: () {},
          duration: duration,
        ),
      ];
      for (final helper in helpers) {
        await _fire(tester, helper);
        expect(_snack(tester).duration, duration);
        expect(_diagEvents(lines, 'snack_shown').last['durationMs'], 2000);
        await tester.pump(duration);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
      'replacement during exit preserves hide cause and replacement',
      (tester) async {
        late BuildContext context;
        await _fire(tester, (c) {
          context = c;
          showJeebErrorSnack(
            c,
            identifier: identifier,
            failure: const NetworkFailure(),
            onRetry: () {},
          );
        });
        showJeebSuccessSnack(
          context,
          identifier: 'offer_sent_snack',
          message: 'Offer sent',
        );
        bus.reconnect();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsIdentifier('offer_sent_snack'), findsOneWidget);
        expect(_diagEvents(lines, 'snack_closed').single['reason'], 'hide');
        expect(bus.events.hasListener, isFalse);
      },
    );

    testWidgets('discarded queued snack is never reported as shown or closed', (
      tester,
    ) async {
      late BuildContext context;
      await _fire(tester, (c) {
        context = c;
        showJeebSnack(c, identifier: 'first_snack', message: 'First');
      });
      showJeebSnack(
        context,
        identifier: 'discarded_snack',
        message: 'Discarded',
      );
      showJeebSnack(context, identifier: 'latest_snack', message: 'Latest');
      await tester.pumpAndSettle();
      expect(find.text('Discarded'), findsNothing);
      expect(find.text('Latest'), findsOneWidget);
      expect(_diagEvents(lines, 'snack_shown').map((e) => e['identifier']), [
        'first_snack',
        'latest_snack',
      ]);
      expect(_diagEvents(lines, 'snack_closed').map((e) => e['identifier']), [
        'first_snack',
      ]);
      await tester.pump(kJeebSnackDuration);
      await tester.pumpAndSettle();
      expect(_diagEvents(lines, 'snack_closed').map((e) => e['identifier']), [
        'first_snack',
        'latest_snack',
      ]);
    });

    testWidgets('a queued replacement never closes the previous controller', (
      tester,
    ) async {
      late BuildContext context;
      await _fire(tester, (c) {
        context = c;
        showJeebSnack(c, identifier: 'first_snack', message: 'First');
      });
      showJeebErrorSnack(
        context,
        identifier: identifier,
        failure: const NetworkFailure(),
        onRetry: () {},
      );
      bus.reconnect();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
      bus.reconnect();
      await tester.pumpAndSettle();
      expect(_diagEvents(lines, 'snack_closed').last['reason'], 'reconnect');
    });

    testWidgets(
      'messenger disposal cancels the subscription without a fake close',
      (tester) async {
        await _fire(
          tester,
          (c) => showJeebErrorSnack(
            c,
            identifier: identifier,
            failure: const NetworkFailure(),
            onRetry: () {},
          ),
        );
        expect(bus.events.hasListener, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(bus.events.hasListener, isFalse);
        bus.reconnect();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_diagEvents(lines, 'snack_closed'), isEmpty);
      },
    );
  });

  group('F6 · a snack has a bounded life', () {
    late NetworkReachabilitySignals bus;

    setUp(() {
      bus = NetworkReachabilitySignals(minInterval: Duration.zero);
      NetworkReachabilitySignals.instance = bus;
    });

    tearDown(NetworkReachabilitySignals.debugReset);

    /// The offline -> online edge: the first observation is only a baseline.
    void reconnect() {
      bus
        ..debugObserve(online: false)
        ..debugObserve(online: true);
    }

    testWidgets('a retryable snack never persists — persist is explicit', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_refresh_failed_snack',
          failure: const NetworkFailure(offline: true),
          onRetry: () {},
        ),
      );

      final SnackBar snack = _snack(tester);
      expect(
        snack.persist,
        isFalse,
        reason:
            'SnackBar derives persist from `action != null`, and a '
            'persisting snack is never timed out at all',
      );
      expect(snack.duration, jeebSnackActionDuration);
    });

    testWidgets('and it is gone once that duration elapses', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_refresh_failed_snack',
          failure: const NetworkFailure(offline: true),
          onRetry: () {},
        ),
      );
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(jeebSnackActionDuration);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a plain snack keeps the shorter default', (
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

      expect(_snack(tester).duration, kJeebSnackDuration);
      expect(_snack(tester).persist, isFalse);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the reconnect edge retires a connectivity snack · '
          '${locale.languageCode}', (WidgetTester tester) async {
        await _fire(
          tester,
          (BuildContext c) => showJeebErrorSnack(
            c,
            identifier: 'order_history_refresh_failed_snack',
            failure: const NetworkFailure(offline: true),
            onRetry: () {},
          ),
          locale: locale,
        );
        expect(
          find.bySemanticsIdentifier('order_history_refresh_failed_snack'),
          findsOneWidget,
        );

        reconnect();
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('order_history_refresh_failed_snack'),
          findsNothing,
        );
        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('but leaves a snack that never blamed the connection', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_error_snack',
          failure: const ServerFailure(status: 500),
          onRetry: () {},
        ),
      );

      reconnect();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('and never kills the snack that replaced it', (
      WidgetTester tester,
    ) async {
      await _fire(
        tester,
        (BuildContext c) => showJeebErrorSnack(
          c,
          identifier: 'order_history_refresh_failed_snack',
          failure: const NetworkFailure(offline: true),
          onRetry: () {},
        ),
      );
      await tester.tap(find.text('fire'));
      await tester.pump();

      await _fire(
        tester,
        (BuildContext c) => showJeebSuccessSnack(
          c,
          message: 'Offer sent',
          identifier: 'offer_sent_snack',
        ),
      );

      reconnect();
      await tester.pumpAndSettle();
      expect(find.text('Offer sent'), findsOneWidget);
    });
  });
}
