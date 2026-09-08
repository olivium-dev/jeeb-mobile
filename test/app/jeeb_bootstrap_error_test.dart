// EP-01: a bootstrap failure is the first and only surface the user sees, so
// it must read as product copy, not as a stack trace.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app_restarter.dart';
import 'package:jeeb_mobile/app/bootstrap.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';

import '../support/midnight_test_harness.dart';

/// The shape of a real init failure: a plugin blowing up with a path in it.
const Object _initFailure = FileSystemException(
  'Keystore unavailable at /data/user/0/com.olivium.jeeb/secret.bin',
);

String _en(String key) => kBootstrapFailureStrings['en']![key]!;

String _ar(String key) => kBootstrapFailureStrings['ar']![key]!;

Future<void> _pumpFailedBootstrap(
  WidgetTester tester, {
  bool withRestarter = false,
}) async {
  final Future<BootstrapResult> rejected =
      Future<BootstrapResult>.error(_initFailure);
  rejected.ignore();
  useReduceMotion(tester);
  final Widget host = JeebBootstrap(bootstrapFuture: rejected);
  await tester.pumpWidget(
    withRestarter ? AppRestarter(child: host) : host,
  );
  await tester.pump();
}

JeebFailureBlock _block(WidgetTester tester) =>
    tester.widget<JeebFailureBlock>(find.byType(JeebFailureBlock));

void main() {
  testWidgets('the failure surface is the kit block, not a raw Text', (
    WidgetTester tester,
  ) async {
    await _pumpFailedBootstrap(tester);

    final JeebFailureBlock block = _block(tester);
    expect(block.failure, isA<UnknownFailure>());
    expect(block.headlineOverride, _en('bootstrapFailedTitle'));
    expect(find.text(_en('bootstrapFailedTitle')), findsOneWidget);
    expect(
      tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).reason,
      JeebEmptyStateReason.failed,
    );
  });

  testWidgets('the Arabic device locale gets the Arabic block, RTL', (
    WidgetTester tester,
  ) async {
    DevSeam.debugOverride(const DevSeamConfig(forcedLocale: 'ar'));
    addTearDown(DevSeam.debugReset);

    await _pumpFailedBootstrap(tester);

    expect(find.text(_ar('bootstrapFailedTitle')), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.text(_ar('bootstrapFailedTitle'))),
      ),
      TextDirection.rtl,
    );
  });

  // The bootstrap host does not produce a semantics tree under the test
  // binding (mounting it leaves `debugSemantics` null for every node, even for
  // an unrelated widget pumped afterwards), so the frozen id is asserted on the
  // block itself. Every other surface asserts by `find.bySemanticsIdentifier`.
  testWidgets('the block carries the frozen identifiers', (
    WidgetTester tester,
  ) async {
    await _pumpFailedBootstrap(tester);

    expect(_block(tester).identifier, bootstrapErrorIdentifier);
    expect(_block(tester).retryIdentifier, bootstrapErrorRetryIdentifier);
  });

  testWidgets('the raw error never reaches release copy', (
    WidgetTester tester,
  ) async {
    await _pumpFailedBootstrap(tester);

    // The test binding runs in debug, where the detail is a developer aid; the
    // release branch is the one that must never carry it.
    for (final String tag in kBootstrapFailureStrings.keys) {
      final String body =
          kBootstrapFailureStrings[tag]!['bootstrapFailedBody']!;
      expect(body, isNot(contains(r'$')));
      expect(body, isNot(contains('/data/user/0')));
      expect(body, isNot(contains('FileSystemException')));
    }
    expect(_block(tester).headlineOverride, isNot(contains('Exception')));
    // Debug renders the capped payload as the body; release renders neither
    // it nor an interpolation, which is what the constants above pin.
    expect(_block(tester).bodyOverride, bootstrapErrorDetail(_initFailure));
  });

  testWidgets('no restart host above it means no inert Retry button', (
    WidgetTester tester,
  ) async {
    await _pumpFailedBootstrap(tester);

    // `JeebRoot` only mounts `AppRestarter` in dev-tool builds; without it a
    // Retry CTA would do nothing at all.
    expect(_block(tester).onRetry, isNull);
    expect(find.byType(JeebCtaButton), findsNothing);
    expect(find.text(_en('actionRetry')), findsNothing);
  });

  testWidgets('a restart host above it arms the Retry CTA', (
    WidgetTester tester,
  ) async {
    await _pumpFailedBootstrap(tester, withRestarter: true);

    expect(_block(tester).onRetry, isNotNull);
    expect(find.text(_en('actionRetry')), findsOneWidget);
    expect(
      tester.widget<JeebCtaButton>(find.byType(JeebCtaButton)).identifier,
      bootstrapErrorRetryIdentifier,
    );
  });

  testWidgets('a still-running bootstrap shows no failure surface', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      JeebBootstrap(bootstrapFuture: Completer<BootstrapResult>().future),
    );
    await tester.pump();

    expect(find.byType(JeebFailureBlock), findsNothing);
  });

  test('the inlined last-resort strings still match the ARB', () {
    for (final String tag in kBootstrapFailureStrings.keys) {
      final Map<String, dynamic> arb =
          jsonDecode(File('lib/l10n/app_$tag.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        kBootstrapFailureStrings[tag]!.keys,
        unorderedEquals(kBootstrapFailureKeys),
      );
      for (final String key in kBootstrapFailureKeys) {
        expect(arb[key], kBootstrapFailureStrings[tag]![key], reason: key);
      }
    }
  });
}
