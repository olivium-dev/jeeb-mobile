// JM-030 — Cancel Request Confirm sheet (cancel-request-confirm, pre-accept).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/cancel_request/data/fake_cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';
import 'package:omds/omds.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

/// Reads the real ARB and injects the intended `cancelRequest*` keys so the
/// test does not depend on the integrator-owned ARB batch landing first.
String _arbWith(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  json.putIfAbsent(
    'cancelRequestFreeNote',
    () => "It's free to cancel before you accept an offer — nothing will be "
        'charged.',
  );
  return jsonEncode(json);
}

void _loadArbs() {
  _syncDelegate = _SyncDelegate({
    'en': _arbWith('lib/l10n/app_en.arb'),
    'ar': _arbWith('lib/l10n/app_ar.arb'),
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Normally hosted by showModalBottomSheet; mounted directly here so the
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('JM-030 CancelRequestSheet', () {
    testWidgets('AC1 — surfaces every EXACT Semantics identifier (63 §2.10)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: FakeCancelRequestRepository(),
          ),
        ),
      );
      await tester.pump();

      for (final id in const [
        'cancel_request_sheet',
        'cancel_request_free_note',
        'cancel_request_confirm_cta',
        'cancel_request_keep_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must surface as its own SemanticsNode.',
        );
      }
    });

    testWidgets('AC1b — confirm and Keep delivery targets are at least 48dp',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: FakeCancelRequestRepository(),
          ),
        ),
      );
      await tester.pump();

      for (final key in const [
        Key('cancel-request-confirm-cta'),
        Key('cancel-request-keep-cta'),
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(UIConstants.buttonHeight),
          reason: '$key must meet the Android 48dp touch-target minimum',
        );
      }
    });

    testWidgets('AC2 — confirm cancels the request and reports onCancelled',
        (tester) async {
      final repo = FakeCancelRequestRepository();
      var cancelledCount = 0;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: repo,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump(); // inFlight
      await tester.pump(); // succeeded → listener fires

      expect(repo.cancelledRequestIds, ['req-client-001-pending']);
      expect(cancelledCount, 1);
    });

    testWidgets('AC3 — keep dismisses and does NOT cancel', (tester) async {
      final repo = FakeCancelRequestRepository();
      var keptCount = 0;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: repo,
            onKept: () => keptCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('cancel_request_keep_cta'));
      await tester.pump();

      expect(keptCount, 1);
      expect(repo.cancelledRequestIds, isEmpty);
    });

    testWidgets(
        'AC4 — a network failure keeps the sheet open + surfaces the error '
        '(D30); not reported succeeded', (tester) async {
      final repo =
          FakeCancelRequestRepository(failWith: CancelRequestFailure.network);
      var cancelledCount = 0;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: repo,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump(); // inFlight
      await tester.pump(); // failed

      expect(repo.cancelledRequestIds, ['req-client-001-pending']);
      expect(cancelledCount, 0, reason: 'network failure must NOT route home');
      expect(
        find.bySemanticsIdentifier('cancel_request_error'),
        findsOneWidget,
        reason: 'D30 transient error must surface; sheet stays open.',
      );
      // Sheet root remains present (not dismissed).
      expect(find.bySemanticsIdentifier('cancel_request_sheet'), findsOneWidget);
    });

    testWidgets(
        'AC2b (cycle-4 NO-SWALLOW) — an unknown server failure SURFACES and '
        'does NOT pretend success', (tester) async {
      final repo =
          FakeCancelRequestRepository(failWith: CancelRequestFailure.unknown);
      var cancelledCount = 0;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: repo,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump();
      await tester.pump();

      // Regression flip: the old behaviour upgraded soft failures to success
      expect(cancelledCount, 0,
          reason: 'a cancel the server did not confirm must never route home');
      expect(find.bySemanticsIdentifier('cancel_request_error'), findsOneWidget);
      expect(find.bySemanticsIdentifier('cancel_request_sheet'), findsOneWidget,
          reason: 'sheet stays open so the user can retry or keep');
    });

    testWidgets(
        'AC5 — a 409 conflict surfaces the "can no longer be cancelled" copy '
        'and keeps the request', (tester) async {
      final repo =
          FakeCancelRequestRepository(failWith: CancelRequestFailure.conflict);
      var cancelledCount = 0;

      await tester.pumpWidget(
        _harness(
          CancelRequestSheet(
            requestId: 'req-client-001-pending',
            repository: repo,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('cancel_request_confirm_cta'));
      await tester.pump();
      await tester.pump();

      expect(cancelledCount, 0);
      expect(find.bySemanticsIdentifier('cancel_request_error'), findsOneWidget);
      expect(
        find.text('This request can no longer be cancelled.'),
        findsOneWidget,
        reason: '409 must map to the dedicated conflict copy.',
      );
    });
  });
}
