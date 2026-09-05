// JeebFailureBlock is the only sanctioned full-body failure. These lock the
// three things a per-feature reimplementation always gets wrong: an
// unrecoverable failure never gets an inert Retry, the identifier triple is
// derived rather than typed, and the block announces itself.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/app_failure_copy.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../../support/midnight_test_harness.dart';
import 'jeeb_failure_test_harness.dart';

/// Every kind the block can be handed, with an `onRetry` and an `onExit` wired
/// so the CTA choice is the widget's, not the caller's.
const Map<String, AppFailure> _kKinds = <String, AppFailure>{
  'network': NetworkFailure(offline: true),
  'timeout': TimeoutFailure(phase: DioExceptionType.receiveTimeout),
  'server': ServerFailure(status: 500),
  'unavailable': ServerFailure(status: 503),
  'unauthorized': UnauthorizedFailure(),
  'recovering': UnauthorizedFailure(recovering: true),
  'forbidden': ForbiddenFailure(),
  'notFound': NotFoundFailure(),
  'conflict': ConflictFailure(),
  'gone': GoneFailure(),
  'validation': ValidationFailure(),
  'rateLimited': RateLimitedFailure(retryAfter: Duration(seconds: 30)),
  'unknown': UnknownFailure(),
};

/// The kinds whose CTA must be an exit, never a Retry.
const Set<String> _kUnrecoverable = <String>{
  'unauthorized',
  'forbidden',
  'notFound',
  'gone',
};

Future<void> _pump(
  WidgetTester tester,
  Widget block, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(wrapMidnight(block, locale: locale));
  await tester.pumpAndSettle();
}

void main() {
  group('JeebFailureBlock · every kind renders its own copy', () {
    for (final Locale locale in kFailureLocales) {
      for (final MapEntry<String, AppFailure> entry in _kKinds.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await _pump(
            tester,
            JeebFailureBlock(
              failure: entry.value,
              identifier: 'wallet_hub_error',
              onRetry: () {},
              onExit: () {},
            ),
            locale: locale,
          );

          final AppLocalizations l10n = l10nOf(tester, JeebFailureBlock);
          final FailureCopy copy = failureCopy(l10n, entry.value);

          expect(find.bySemanticsIdentifier('wallet_hub_error'), findsOneWidget);
          expect(find.text(copy.title), findsOneWidget);
          expect(find.text(copy.body), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('JeebFailureBlock · the CTA the failure can actually win', () {
    for (final MapEntry<String, AppFailure> entry in _kKinds.entries) {
      testWidgets('${entry.key} offers the right act', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          JeebFailureBlock(
            failure: entry.value,
            identifier: 'wallet_hub_error',
            onRetry: () {},
            onExit: () {},
          ),
        );

        final bool unrecoverable = _kUnrecoverable.contains(entry.key);
        expect(
          find.bySemanticsIdentifier('wallet_hub_retry_cta'),
          unrecoverable ? findsNothing : findsOneWidget,
          reason: unrecoverable
              ? '${entry.key} cannot be retried — a Retry here is a button '
                  'that can never succeed (F14/UX-25/CR-01)'
              : '${entry.key} is retryable and must offer a Retry',
        );
        expect(
          find.bySemanticsIdentifier('wallet_hub_exit_cta'),
          unrecoverable ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('a retryable failure with no onRetry renders no CTA at all', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebFailureBlock(
          failure: NetworkFailure(),
          identifier: 'wallet_hub_error',
        ),
      );

      expect(find.bySemanticsIdentifier('wallet_hub_retry_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_hub_exit_cta'), findsNothing);
    });

    testWidgets('an unrecoverable failure with no onExit renders no CTA', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const JeebFailureBlock(
          failure: UnauthorizedFailure(),
          identifier: 'wallet_hub_error',
          onRetry: _noop,
        ),
      );

      expect(find.bySemanticsIdentifier('wallet_hub_retry_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('wallet_hub_exit_cta'), findsNothing);
    });

    testWidgets('Retry fires onRetry, exit fires onExit', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      int exits = 0;

      await _pump(
        tester,
        JeebFailureBlock(
          failure: const ServerFailure(status: 500),
          identifier: 'wallet_hub_error',
          onRetry: () => retries++,
          onExit: () => exits++,
        ),
      );
      await tester.tap(find.bySemanticsIdentifier('wallet_hub_retry_cta'));
      await tester.pump();
      expect(retries, 1);
      expect(exits, 0);

      await _pump(
        tester,
        JeebFailureBlock(
          failure: const ForbiddenFailure(),
          identifier: 'wallet_hub_error',
          onRetry: () => retries++,
          onExit: () => exits++,
        ),
      );
      await tester.tap(find.bySemanticsIdentifier('wallet_hub_exit_cta'));
      await tester.pump();
      expect(retries, 1);
      expect(exits, 1);
    });

    testWidgets('exitLabel overrides the copy family action', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const GoneFailure(),
          identifier: 'waiting_error',
          onExit: () {},
          exitLabel: 'Create a new request',
        ),
      );

      expect(find.text('Create a new request'), findsOneWidget);
    });
  });

  group('JeebFailureBlock · identifiers and announcement', () {
    testWidgets('the id triple is derived from the one identifier', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'request_feed_error',
          onRetry: () {},
        ),
      );

      expect(find.bySemanticsIdentifier('request_feed_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('request_feed_error_headline'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('request_feed_error_body'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('request_feed_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('an identifier without the _error suffix still derives ids', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'chat_resolution_error_state',
          onRetry: () {},
        ),
      );

      expect(
        find.bySemanticsIdentifier('chat_resolution_error_state_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('the block is a live region, so it is announced', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          onRetry: () {},
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('wallet_hub_error'),
      );
      expect(
        node.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
        reason: 'a failure that arrives silently is a failure a screen reader '
            'user never learns about (EP-21/UX-36)',
      );
      final AppLocalizations l10n = l10nOf(tester, JeebFailureBlock);
      final FailureCopy copy = failureCopy(l10n, const NetworkFailure());
      expect(
        node.getSemanticsData().label,
        '${copy.title}. ${copy.body}',
        reason: 'an announced node with no label of its own reads as silence',
      );
      handle.dispose();
    });
  });

  group('JeebFailureBlock · overrides and density', () {
    testWidgets('headlineOverride and bodyOverride win over the family', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const ConflictFailure(),
          identifier: 'offers_error',
          headlineOverride: 'You already made an offer',
          bodyOverride: 'Open it to change your price.',
          onRetry: () {},
        ),
      );

      expect(find.text('You already made an offer'), findsOneWidget);
      expect(find.text('Open it to change your price.'), findsOneWidget);
    });

    testWidgets('compact renders the inline density, not the board', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock.compact(
          failure: const NetworkFailure(),
          identifier: 'reviews_error',
          onRetry: () {},
        ),
      );

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.compact, isTrue);
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
    });

    testWidgets('a secondaryAction renders under the primary act', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          onRetry: () {},
          secondaryAction: Semantics(
            identifier: 'wallet_hub_support_cta',
            container: true,
            child: const Text('Contact support'),
          ),
        ),
      );

      final Offset retry = tester.getCenter(
        find.bySemanticsIdentifier('wallet_hub_retry_cta'),
      );
      final Offset support = tester.getCenter(
        find.bySemanticsIdentifier('wallet_hub_support_cta'),
      );
      expect(support.dy, greaterThan(retry.dy));
    });
  });

  group('JeebFailureBlock · CTA identifier overrides', () {
    testWidgets('retryIdentifier replaces the derived retry id', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          retryIdentifier: 'wallet_hub_reload_cta',
          onRetry: () {},
        ),
      );

      expect(find.bySemanticsIdentifier('wallet_hub_reload_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('wallet_hub_retry_cta'), findsNothing);
    });

    testWidgets('exitIdentifier replaces the derived exit id', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        JeebFailureBlock(
          failure: const UnauthorizedFailure(),
          identifier: 'wallet_hub_error',
          exitIdentifier: 'wallet_hub_sign_in_cta',
          onRetry: () {},
          onExit: () {},
        ),
      );

      expect(
        find.bySemanticsIdentifier('wallet_hub_sign_in_cta'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('wallet_hub_exit_cta'), findsNothing);
    });

    testWidgets('compact honours both overrides', (WidgetTester tester) async {
      await _pump(
        tester,
        JeebFailureBlock.compact(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          retryIdentifier: 'wallet_hub_reload_cta',
          exitIdentifier: 'wallet_hub_sign_in_cta',
          onRetry: () {},
        ),
      );

      expect(find.bySemanticsIdentifier('wallet_hub_reload_cta'), findsOneWidget);
    });

    test('an empty override identifier is rejected at construction', () {
      expect(
        () => JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          retryIdentifier: '',
        ),
        throwsAssertionError,
      );
      expect(
        () => JeebFailureBlock(
          failure: const NetworkFailure(),
          identifier: 'wallet_hub_error',
          exitIdentifier: '',
        ),
        throwsAssertionError,
      );
    });
  });

  test('an empty identifier is rejected at construction', () {
    expect(
      () => JeebFailureBlock(
        failure: const NetworkFailure(),
        identifier: '',
      ),
      throwsAssertionError,
    );
  });
}

void _noop() {}
