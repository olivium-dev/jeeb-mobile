// M3-22 per-element Midnight assertions for AccountStatusScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator accepts 5% pixel diff, so a token re-point on the title ink or a
// 19px glyph is invisible to them. Every ruling this row landed is read back
// off the widget here instead.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRepository implements AccountStatusRepository {
  const _FakeRepository(this._info);

  final AccountStatusInfo _info;

  @override
  Future<AccountStatusInfo> fetchStatus() async => _info;
}

/// A read that never lands, holding the screen on the loading branch.
class _PendingRepository implements AccountStatusRepository {
  const _PendingRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() =>
      Completer<AccountStatusInfo>().future;
}

class _FailingRepository implements AccountStatusRepository {
  const _FailingRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      throw const AccountStatusRepositoryException(AccountStatusFailure.network);
}

Widget _harness(AccountStatusRepository repo) {
  final router = GoRouter(
    initialLocation: '/account-status',
    routes: [
      GoRoute(
        path: '/account-status',
        builder: (context, state) => AccountStatusScreen(repository: repo),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

const AccountStatusInfo _suspended = AccountStatusInfo(
  value: AccountStatusValue.suspended,
);

void main() {
  Future<void> pump(WidgetTester tester, AccountStatusRepository repo) async {
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
  }

  testWidgets('field is content + orange glow topEnd, no wash, still',
      (tester) async {
    await pump(tester, const _FakeRepository(_suspended));

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    // R22/R23 both declare zero periwinkle: the wash is a different LAYER, not
    // a mirrored glow.
    expect(field.washPlacement, isNull);
    // M3 rows ship with no motion beyond what kit widgets bring.
    expect(field.animateDecor, isFalse);
  });

  testWidgets('screen title is onSurface ink, never the accent', (tester) async {
    await pump(tester, const _FakeRepository(_suspended));

    final title = tester.widget<Text>(find.text('Account unavailable'));
    expect(title.style!.color, JeebMidnight.ink);
    // Under Midnight `colorScheme.primary` IS #D73B00 — a title inked from it
    // is an orange-budget leak, which is exactly what this screen shipped.
    expect(title.style!.color, isNot(JeebMidnight.orange));
  });

  testWidgets('blocked panel glyph is danger-SOFT, not full-strength error',
      (tester) async {
    await pump(tester, const _FakeRepository(_suspended));

    final panel = tester.widget<JeebInfoNote>(
      find.descendant(
        of: find.bySemanticsIdentifier('account_status_banner'),
        matching: find.byType(JeebInfoNote),
      ),
    );
    expect(panel.tone, JeebInfoNoteTone.error);
    expect(panel.iconColor, JeebMidnight.dangerSoft);
    expect(panel.iconColor, isNot(JeebMidnight.danger));
    // Stacked form (R23 `tpl 1368`), so the kit's 13/16 padding and Ø19 glyph
    // apply rather than the 12/16 strip.
    expect(panel.isStacked, isTrue);
  });

  testWidgets('reason sits on R23 glass strip at the body ramp', (tester) async {
    await pump(
      tester,
      const _FakeRepository(
        AccountStatusInfo(
          value: AccountStatusValue.locked,
          reason: 'Security hold pending identity re-verification.',
        ),
      ),
    );

    final strip = tester.widget<JeebInfoNote>(
      find.descendant(
        of: find.bySemanticsIdentifier('account_status_reason'),
        matching: find.byType(JeebInfoNote),
      ),
    );
    expect(strip.tone, JeebInfoNoteTone.muted);
    expect(strip.isStacked, isFalse);
    expect(strip.icon, isNull);

    final reason = tester.widget<Text>(
      find.text('Security hold pending identity re-verification.'),
    );
    // `label:` is what keeps this line on the 14.5 body ramp instead of the
    // strip's 12.5 bodySmall default.
    expect(reason.style!.fontSize, 14.5);
    expect(reason.style!.color, JeebMidnight.inkMuted);

    // The glyph is composed INSIDE the label so it top-aligns: the kit centres
    // its own leading slot, which floats mid-paragraph on a long server reason.
    final row = tester.widget<Row>(
      find.ancestor(
        of: find.byIcon(Icons.info_outline),
        matching: find.byType(Row),
      ).first,
    );
    expect(row.crossAxisAlignment, CrossAxisAlignment.start);
  });

  testWidgets('exits spend zero orange: periwinkle support + glass sign out',
      (tester) async {
    await pump(tester, const _FakeRepository(_suspended));

    final support = tester.widget<JeebCtaButton>(
      find.descendant(
        of: find.bySemanticsIdentifier('account_status_support_cta'),
        matching: find.byType(JeebCtaButton),
      ),
    );
    expect(support.variant, JeebCtaVariant.primary);
    expect(support.variant, isNot(JeebCtaVariant.accent));

    // R22 draws sign-out on calm glass and reserves the dim red for Delete
    // account, which lives inside the confirm sheet this opens.
    final signOut = tester.widget<JeebCtaButton>(
      find.descendant(
        of: find.bySemanticsIdentifier('account_status_signout_cta'),
        matching: find.byType(JeebCtaButton),
      ),
    );
    expect(signOut.variant, JeebCtaVariant.outline);
    expect(signOut.variant, isNot(JeebCtaVariant.danger));
  });

  testWidgets('loading is the radar with no invented identities',
      (tester) async {
    await pump(tester, const _PendingRepository());

    final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(block.variant, JeebEmptyStateVariant.radar);
    expect(block.status, JeebEmptyStateStatus.loading);
    expect(block.medallions, isEmpty);
    // The CTA is withheld while loading (kit ruling 1), so nothing on this
    // frame can be tapped into a dead end.
    expect(find.byType(JeebCtaButton), findsNothing);
  });

  testWidgets('failed read is the radar, danger-tinted, with a glass retry',
      (tester) async {
    await pump(tester, const _FailingRepository());

    final block = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(block.variant, JeebEmptyStateVariant.radar);
    expect(block.status, JeebEmptyStateStatus.error);
    // E2 draws jeebers in range; there is no second party on this surface.
    expect(block.medallions, isEmpty);

    final retry = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
    expect(retry.variant, JeebCtaVariant.outline);
  });
}
