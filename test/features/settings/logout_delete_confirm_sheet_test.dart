// JM-062 — Logout / Delete Account confirm sheet (logout-delete-account).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/settings/domain/account_deletion_policy.dart';
import 'package:jeeb_mobile/features/settings/domain/account_session_terminator.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';

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

/// Records which terminal action ran so the test can assert the session clear
/// without a keystore / Dio. Mirrors the FakeCancelRequestRepository pattern.
class _FakeTerminator implements AccountSessionTerminator {
  int logoutCount = 0;
  int deleteCount = 0;

  @override
  Future<void> logout() async => logoutCount++;

  @override
  Future<void> deleteAccount() async => deleteCount++;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  _syncDelegate = _SyncDelegate({
    'en': File('lib/l10n/app_en.arb').readAsStringSync(),
    'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
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

  // MIDNIGHT M3-23/37 lane: `primary` IS #D73B00, so the grabber was drawing a
  // bright orange bar over a sign-out sheet. Inert chrome takes the .22 rung.
  testWidgets('the drag handle spends no orange budget', (tester) async {
    await tester.pumpWidget(
      _harness(
        LogoutDeleteConfirmSheet(
          mode: LogoutDeleteMode.logout,
          terminator: _FakeTerminator(),
        ),
      ),
    );
    await tester.pump();

    final BuildContext context =
        tester.element(find.byType(LogoutDeleteConfirmSheet));
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>()!;

    final Finder handle = find.byWidgetPredicate((Widget w) {
      if (w is! Container) return false;
      final Decoration? d = w.decoration;
      return d is BoxDecoration && d.borderRadius == OmdsBorderRadius.pill;
    });
    expect(handle, findsOneWidget);
    final BoxDecoration decoration =
        tester.widget<Container>(handle).decoration! as BoxDecoration;

    expect(decoration.color, semantics.glassBorderVivid);
    expect(decoration.color, isNot(scheme.primary));
  });

  group('JM-062 LogoutDeleteConfirmSheet', () {
    testWidgets('AC1 — logout mode surfaces logout_confirm_cta + root + cancel',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.logout,
            terminator: _FakeTerminator(),
          ),
        ),
      );
      await tester.pump();

      for (final id in const [
        'logout_delete_confirm_sheet',
        'logout_confirm_cta',
        'logout_delete_cancel_cta',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: '$id must surface as its own SemanticsNode.',
        );
      }
      // The delete-specific id must NOT be present in logout mode.
      expect(find.bySemanticsIdentifier('delete_confirm_cta'), findsNothing);
    });

    testWidgets('AC1b — delete mode surfaces delete_confirm_cta', (tester) async {
      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.delete,
            terminator: _FakeTerminator(),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('delete_confirm_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('logout_confirm_cta'), findsNothing);
    });

    testWidgets(
        'E20 (JEBV4-215) — delete mode communicates the scheduled-purge SLA',
        (tester) async {
      // Proves the soft-delete + scheduled-purge SLA copy renders from the
      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.delete,
            terminator: _FakeTerminator(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('$kAccountPurgeGraceDays days'),
        findsOneWidget,
        reason: 'delete body must surface the purge grace window (E20 SLA)',
      );
      expect(
        find.textContaining('Sign in again'),
        findsOneWidget,
        reason: 'delete body must state the sign-in-again reversal (E20)',
      );
    });

    testWidgets('AC2 — logout_confirm_cta clears the session + reports completed',
        (tester) async {
      final terminator = _FakeTerminator();
      var completedCount = 0;

      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.logout,
            terminator: terminator,
            onCompleted: () => completedCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('logout_confirm_cta'));
      await tester.pump(); // inFlight
      await tester.pump(); // terminator resolves → onCompleted

      expect(terminator.logoutCount, 1);
      expect(terminator.deleteCount, 0);
      expect(completedCount, 1,
          reason: 'host routes to splash (D5) once session is cleared');
    });

    testWidgets('AC3 — delete_confirm_cta deletes + reports completed',
        (tester) async {
      final terminator = _FakeTerminator();
      var completedCount = 0;

      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.delete,
            terminator: terminator,
            onCompleted: () => completedCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('delete_confirm_cta'));
      await tester.pump();
      await tester.pump();

      expect(terminator.deleteCount, 1);
      expect(terminator.logoutCount, 0);
      expect(completedCount, 1);
    });

    testWidgets('AC4 — cancel dismisses and does NOT clear the session',
        (tester) async {
      final terminator = _FakeTerminator();
      var cancelledCount = 0;
      var completedCount = 0;

      await tester.pumpWidget(
        _harness(
          LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.logout,
            terminator: terminator,
            onCompleted: () => completedCount++,
            onCancelled: () => cancelledCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('logout_delete_cancel_cta'));
      await tester.pump();

      expect(cancelledCount, 1);
      expect(completedCount, 0);
      expect(terminator.logoutCount, 0);
      expect(terminator.deleteCount, 0);
    });
  });
}
