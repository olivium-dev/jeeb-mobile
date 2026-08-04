// The active-delivery banner exists TWICE: the shell-injected
// [ActiveDeliveriesBanner] a registered jeeber actually sees (dashboard_tab.dart
// :147) and the [JeeberActiveDeliveriesBanner] `??` fallback the unregistered
// path falls through to (jeeber_home_screen.dart:407). The fallback's own doc
// says it is "kept visually identical to the shell-injected banner (W-3)" —
// until now that identity was guarded by a source comment and nothing else, so
// a one-sided token edit split the pair silently.
//
// These tests pin the pair by READING the treatment off each rendered card:
// wave-C ruling 10's `accentTint` rung (orange 12%), the 2px accent frame, the
// radius, and — the actual pair guard — the two treatments compared to each
// other. Goldens cannot do this: the comparator tolerates 5% pixel diff and a
// fill swap on one small row moves far less than that.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/chat/domain/accepted_conversation.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StaticActiveRepo implements ActiveDeliveriesRepository {
  const _StaticActiveRepo(this.result);

  final List<ActiveDeliverySummary> result;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => result;
}

class _CannedAcceptedRepo implements AcceptedConversationsRepository {
  const _CannedAcceptedRepo(this.result);

  final List<AcceptedConversation> result;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => result;
}

const _delivery = ActiveDeliverySummary(
  id: 'd0',
  status: JeeberDeliveryStatus.ordered,
  conversationId: 'conv-0',
  title: 'Pharmacy run',
  dropoffAddress: 'Achrafieh',
);

const _accepted = AcceptedConversation(
  conversationId: 'conv-0',
  requestId: 'd0',
  title: 'Pharmacy run',
  destinationLabel: 'Achrafieh',
);

/// What a rendered active-delivery card actually paints. Read off the widget
/// tree, never declared — a token re-point that does not reach the pixel fails.
typedef _Frame = ({
  JeebAccentFrameFill fill,
  Color surface,
  Color border,
  double borderWidth,
  BorderRadiusGeometry? radius,
});

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

_Frame _frameOf(WidgetTester tester) {
  final card = tester.widget<JeebAccentFrameCard>(
    find.byType(JeebAccentFrameCard).first,
  );
  final decoration =
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(JeebOutlinedCard).first,
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;
  final border = decoration.border! as Border;
  return (
    fill: card.fill,
    surface: decoration.color!,
    border: border.top.color,
    borderWidth: border.top.width,
    radius: decoration.borderRadius,
  );
}

/// The banner a registered jeeber actually sees (shell-injected, W-3).
Future<ActiveDeliveriesCubit> _pumpShellBanner(WidgetTester tester) async {
  final cubit = ActiveDeliveriesCubit(
    repository: const _StaticActiveRepo(<ActiveDeliverySummary>[_delivery]),
  )..start();
  await tester.pumpWidget(
    _host(
      BlocProvider<ActiveDeliveriesCubit>.value(
        value: cubit,
        child: ActiveDeliveriesBanner(
          onOpenChat: (_) {},
          onManageDelivery: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return cubit;
}

/// The `??` fallback, reached only when the jeeber is unregistered.
Future<void> _pumpFallbackBanner(WidgetTester tester) async {
  await tester.pumpWidget(
    _host(
      JeeberActiveDeliveriesBanner(
        repository: const _CannedAcceptedRepo(<AcceptedConversation>[_accepted]),
        onOpenChat: (_) {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  const surface = Size(360, 800);

  group('R16 active-delivery banner takes the accentTint rung', () {
    testWidgets('the shell-injected banner PAINTS orange 12%', (tester) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cubit = await _pumpShellBanner(tester);
      final frame = _frameOf(tester);

      expect(frame.fill, JeebAccentFrameFill.accentTint);
      expect(frame.surface, JeebMidnight.accentTint);
      expect(frame.surface, isNot(JeebMidnight.glassFill));
      expect(frame.surface, isNot(JeebMidnight.accentSelectedFill));
      expect(frame.surface.a, closeTo(0.12, 0.001));

      await cubit.close();
    });

    testWidgets('the `??` fallback PAINTS the same orange 12%', (tester) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpFallbackBanner(tester);
      final frame = _frameOf(tester);

      expect(frame.fill, JeebAccentFrameFill.accentTint);
      expect(frame.surface, JeebMidnight.accentTint);
      expect(frame.surface, isNot(JeebMidnight.glassFill));
      expect(frame.surface, isNot(JeebMidnight.accentSelectedFill));
    });

    testWidgets('the tint stops at the frame — content reads true glass', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cubit = await _pumpShellBanner(tester);
      final inner = Theme.of(
        tester.element(find.byIcon(Icons.two_wheeler)),
      ).extension<JeebSemanticColors>()!;

      expect(inner.glassFill, JeebMidnight.glassFill);
      expect(inner.glassFill, isNot(JeebMidnight.accentTint));

      await cubit.close();
    });

    testWidgets('the frame itself is unchanged: 2px accent, radius lg, no lift',
        (tester) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cubit = await _pumpShellBanner(tester);
      final frame = _frameOf(tester);
      final accent = tester
          .element(find.byType(JeebAccentFrameCard).first)
          .jeebRoles
          .accent;

      expect(frame.border, accent);
      expect(frame.borderWidth, 2);
      expect(frame.radius, BorderRadius.circular(JeebRadii.lg));

      await cubit.close();
    });
  });

  // THE PAIR GUARD. The fallback's doc says it "cannot drift away from the
  // surface the jeeber actually sees"; this is what makes that true. A one-sided
  // edit at either call site fails here even if both sides still analyze.
  testWidgets(
    'both banners resolve the SAME frame treatment (one-sided edits fail)',
    (tester) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cubit = await _pumpShellBanner(tester);
      final shell = _frameOf(tester);
      await cubit.close();

      await _pumpFallbackBanner(tester);
      final fallback = _frameOf(tester);

      expect(
        fallback,
        shell,
        reason:
            'the jeeber_home `??` fallback must stay visually identical to the '
            'shell-injected banner (W-3): same fill rung, same painted surface, '
            'same frame stroke and radius',
      );
      // Equality alone would also hold if BOTH regressed to glass, so the rung
      // the pair agrees on is pinned to the board's measurement too.
      expect(shell.fill, JeebAccentFrameFill.accentTint);
      expect(shell.surface, JeebMidnight.accentTint);
    },
  );
}
