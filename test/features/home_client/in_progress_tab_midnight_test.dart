// M4 — the In Progress tab's empty + error arms on the §2.7 pattern family,
// and the Pending reconnect banner's typography. Per-element, no goldens.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';

import '../../support/sync_app_localizations.dart';

/// Cold load throws — the only route to [ClientHomeStatus.failed] (the cubit
/// swallows a failed *refresh* once it holds data).
class _FailingRepo implements ClientHomeRepository {
  const _FailingRepo();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw StateError('midnight fixture: cold in-progress load failed');
}

Widget _harness({required ClientHomeRepository repo, Widget? child}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [SyncAppLocalizationsDelegate()],
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4).
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider(
        create: (_) => ClientHomeCubit(
          repository: repo,
          greetingNameProvider: () => 'Sami',
        )..load(),
        child: child ?? const InProgressTab(),
      ),
    ),
  );
}

JeebEmptyState _stateAt(WidgetTester tester, Key key) =>
    tester.widget<JeebEmptyState>(find.byKey(key));

void main() {
  group('InProgressTab · M4 §2.7 empty arm', () {
    testWidgets('is a JeebEmptyState, not the OMDS block', (tester) async {
      await tester.pumpWidget(
        _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
      );
      await tester.pumpAndSettle();

      // The frozen key is re-homed onto the kit block itself.
      expect(
        find.byKey(const Key('in-progress-empty')),
        findsOneWidget,
      );
      expect(_stateAt(tester, const Key('in-progress-empty')),
          isA<JeebEmptyState>());
      // The stock Material glyph the OMDS block drew is gone.
      expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
    });

    testWidgets('draws E4 parcel at rest — the subject is the absent delivery',
        (tester) async {
      await tester.pumpWidget(
        _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
      );
      await tester.pumpAndSettle();

      final block = _stateAt(tester, const Key('in-progress-empty'));
      expect(block.variant, JeebEmptyStateVariant.parcel);
      expect(block.status, JeebEmptyStateStatus.empty);
      // NOT the Pending tab's E1: the two tabs must not draw the same tile.
      expect(block.variant, isNot(JeebEmptyStateVariant.e1));
    });

    testWidgets('carries the tab copy and the Maestro identifiers',
        (tester) async {
      await tester.pumpWidget(
        _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
      );
      await tester.pumpAndSettle();

      final block = _stateAt(tester, const Key('in-progress-empty'));
      expect(block.headline, 'What do you need?');
      expect(block.body, 'No active deliveries yet.');
      expect(block.identifier, 'in_progress_empty_state');
      expect(block.headlineIdentifier, 'in_progress_empty_title');
      expect(block.bodyIdentifier, 'in_progress_empty_body');
    });

    testWidgets('its CTA is a wired JeebCtaButton, not OMDS button chrome',
        (tester) async {
      await tester.pumpWidget(
        _harness(repo: InMemoryClientHomeRepository(latency: Duration.zero)),
      );
      await tester.pumpAndSettle();

      final cta = find.byType(JeebCtaButton);
      expect(cta, findsOneWidget);
      final JeebCtaButton button = tester.widget<JeebCtaButton>(cta);
      expect(button.identifier, 'in_progress_create_cta');
      expect(button.onTap, isNotNull);
      expect(find.text('Create your first request'), findsOneWidget);
      // No Material button chrome survives from the OMDS block.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('InProgressTab · M4 §2.7 error arm', () {
    testWidgets('is a danger-tinted JeebEmptyState on the SAME parcel tile',
        (tester) async {
      await tester.pumpWidget(_harness(repo: const _FailingRepo()));
      await tester.pumpAndSettle();

      final JeebFailureBlock block = tester.widget<JeebFailureBlock>(
        find.byKey(const Key('in-progress-error')),
      );
      // Same subject as the empty arm — the tile must not change identity.
      expect(block.variant, JeebEmptyStateVariant.parcel);
      expect(block.headlineOverride, "Couldn't load your deliveries in progress");
      expect(block.identifier, 'in_progress_error_state');
      // COPY-04: the body is the copy family's, not "Tap to retry" over a
      // Retry button.
      expect(block.bodyOverride, isNull);
      expect(find.text('We couldn\'t complete that. Try again.'), findsOneWidget);
      // The OMDS block's stock cloud glyph is gone.
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('its retry CTA is a JeebCtaButton carrying the M4 identifier',
        (tester) async {
      await tester.pumpWidget(_harness(repo: const _FailingRepo()));
      await tester.pumpAndSettle();

      final cta = find.byType(JeebCtaButton);
      expect(cta, findsOneWidget);
      final JeebCtaButton button = tester.widget<JeebCtaButton>(cta);
      expect(button.identifier, 'in_progress_retry_cta');
      expect(button.onTap, isNotNull);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('PendingReconnectBanner · M4 typography', () {
    testWidgets('the label inks Jeeb caption, not Material labelSmall',
        (tester) async {
      late JeebTextStyles text;
      late JeebRoles roles;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [SyncAppLocalizationsDelegate()],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                text = context.jeebText;
                roles = context.jeebRoles;
                return const PendingReconnectBanner(visible: true);
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(
        find.byKey(const Key('pending-reconnect-label')),
      );
      final TextStyle style = label.style!;
      expect(style.fontSize, text.caption.fontSize);
      expect(style.fontWeight, text.caption.fontWeight);
      expect(style.fontFamily, jeebFontFamily);
      expect(style.color, roles.onWarningContainer);
      // Material's labelSmall is 11/w500 — the residue this row carried.
      expect(style.fontSize, isNot(11.0));
      expect(style.fontWeight, isNot(FontWeight.w500));
    });
  });
}
