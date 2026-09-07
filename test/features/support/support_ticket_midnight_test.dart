// MIDNIGHT M3-30 — per-element assertions for the support-ticket restyle.
// Nearest tile is R22 settings (no board render for this screen); the three
// non-form phases take the empty family, as the sibling M3-02 escalate does.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/support/application/support_cubit.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Token sheet §1/§2, spelled out rather than read off the implementation.
const Color _orange = Color(0xFFD73B00);
const Color _success = Color(0xFF3BB273);

class _CannedRepo implements SupportRepository {
  const _CannedRepo();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      const SupportTicket(id: 'ticket-m3-30', status: 'open');
}

class _PendingRepo implements SupportRepository {
  const _PendingRepo();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      Completer<SupportTicket>().future;
}

class _FailingRepo implements SupportRepository {
  const _FailingRepo();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    throw const SupportRepositoryException(SupportFailure.network, 'fixture');
  }
}

SupportCubit _seeded(SupportRepository repo) => SupportCubit(repo)
  ..setCategory(SupportCategory.delivery)
  ..setBody('My delivery never arrived.');

void main() {
  Widget harness(SupportCubit? cubit) => MaterialApp(
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The empty-family illustrations loop ∞ by design; reduce motion is
    // what lets `pumpAndSettle` reach a rest frame.
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: SupportTicketScreen(cubit: cubit),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, SupportCubit? cubit) async {
    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();
  }

  group('field', () {
    testWidgets('mounts R22\'s content field: topEnd glow, no wash, still', (
      tester,
    ) async {
      await pump(tester, _seeded(const _CannedRepo()));

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares no periwinkle wash, and the tile is board-still.
      expect(field.washPlacement, isNull);
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the scaffold is transparent so the field is what paints', (
      tester,
    ) async {
      await pump(tester, _seeded(const _CannedRepo()));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);
    });
  });

  group('submitting', () {
    testWidgets('is the empty family at loading status, not an OMDS spinner', (
      tester,
    ) async {
      final cubit = _seeded(const _PendingRepo());
      unawaited(cubit.submit());
      await pump(tester, cubit);

      final state = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.status, JeebEmptyStateStatus.loading);
      expect(state.variant, JeebEmptyStateVariant.radar);
      // E2's ring discs are jeebers; a support ticket has none to name.
      expect(state.medallions, isEmpty);
      expect(find.bySemanticsIdentifier('support_submitting'), findsOneWidget);
      // `OmdsLoadingState` defaults its spinner to `colorScheme.primary`,
      // which IS #D73B00 under Midnight.
      expect(find.byType(OmdsLoadingState), findsNothing);
    });
  });

  group('error', () {
    testWidgets('is the empty family at error status, ids intact', (
      tester,
    ) async {
      final cubit = _seeded(const _FailingRepo());
      await cubit.submit();
      await pump(tester, cubit);

      final state = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
      expect(state.reason, JeebEmptyStateReason.failed);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);
      expect(find.bySemanticsIdentifier('support_retry_cta'), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
    });
  });

  group('confirmation', () {
    testWidgets('the settled mark takes the success role, never primary', (
      tester,
    ) async {
      final cubit = _seeded(const _CannedRepo());
      await cubit.submit();
      await pump(tester, cubit);

      expect(find.bySemanticsIdentifier('support_success'), findsOneWidget);
      final mark = tester.widget<Icon>(
        find.descendant(
          of: find.bySemanticsIdentifier('support_success'),
          matching: find.byIcon(Icons.check_circle),
        ),
      );
      expect(mark.color, _success);
      expect(mark.color, isNot(_orange));
      expect(mark.color, isNot(AppTheme.midnight().colorScheme.primary));
    });
  });
}
