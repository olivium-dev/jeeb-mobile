// MIDNIGHT M3-09 — the single-sided `/orders/:id/feedback` terminal, derived
// from R15 (the sibling mutual-rating tile).
//
// Per-element assertions, NOT goldens: the capture comparator tolerates 5 %
// pixel diff, so a token re-point on a star glyph is invisible to it. Every
// check below reads the colour / geometry / enum off the built widget.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _StalledRepo implements RatingRepository {
  const _StalledRepo();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) =>
      // A Completer, not `Future.delayed` — a pending timer trips the
      // binding's post-test invariants.
      Completer<void>().future;

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) =>
      throw UnimplementedError();
}

/// Records the tags the chip band sent on the wire.
class _RecordingRepo implements RatingRepository {
  List<String>? tags;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    this.tags = tags;
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) =>
      throw UnimplementedError();
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

/// `context.go('/')` needs a router; the stalled repo never gets there.
Widget _wrapRouted(Widget screen) {
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: GoRouter(
      initialLocation: '/f',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('HOME_SHELL')),
        ),
        GoRoute(path: '/f', builder: (_, _) => screen),
      ],
    ),
  );
}

List<Icon> _stars(WidgetTester tester) => tester
    .widgetList<Icon>(
      find.descendant(
        of: find.byType(FeedbackStarInput),
        matching: find.byType(Icon),
      ),
    )
    .toList();

Iterable<RadialGradient> _halos(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(FeedbackStarInput),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((DecoratedBox b) => b.decoration)
    .whereType<BoxDecoration>()
    .map((BoxDecoration d) => d.gradient)
    .whereType<RadialGradient>();

void main() {
  group('field (R15: base wash + one quiet glow low, nothing ticks)', () {
    testWidgets('content variant, bottom glow, decor not animated',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.bottom);
      expect(field.animateDecor, isFalse);
      // R15 declares no periwinkle wash: the wash and the glow are different
      // layers, and several screens shipped mirrored by conflating them.
      expect(field.washPlacement, isNull);
    });
  });

  group('star row', () {
    testWidgets('filled stars are amber, empty stars are white 22 % glass',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            initialStars: 3,
          ),
        ),
      );
      await tester.pump();

      final icons = _stars(tester);
      expect(icons.length, FeedbackStarInput.starCount);
      // The board never draws a hollow star: every glyph is `Icons.star`.
      expect(icons.every((Icon i) => i.icon == Icons.star), isTrue);
      expect(
        icons.take(3).map((Icon i) => i.color),
        everyElement(JeebMidnight.amber),
      );
      expect(
        icons.skip(3).map((Icon i) => i.color),
        everyElement(JeebMidnight.glassBorderVivid),
      );
    });

    testWidgets('one radial-gradient halo per FILLED star, amber @ .32 → 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            initialStars: 4,
          ),
        ),
      );
      await tester.pump();

      final halos = _halos(tester).toList();
      expect(halos.length, 4);
      for (final RadialGradient g in halos) {
        expect(g.colors.first, JeebMidnight.amber.withValues(alpha: 0.32));
        expect(g.colors.last, JeebMidnight.amber.withValues(alpha: 0));
      }
    });

    testWidgets('the halo is a gradient, never a BoxShadow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            initialStars: 5,
          ),
        ),
      );
      await tester.pump();

      // A BoxShadow halo paints nothing on the golden canvas — the measured
      // falloff is the gradient's, and it survives the software renderer.
      final shadowed = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FeedbackStarInput),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox b) => b.decoration)
          .whereType<BoxDecoration>()
          .where((BoxDecoration d) => (d.boxShadow ?? const []).isNotEmpty);
      expect(shadowed, isEmpty);
      expect(_halos(tester).length, 5);
    });

    testWidgets('no halo at all before a score is picked', (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();
      expect(_halos(tester), isEmpty);
    });

    testWidgets('tapping a star lights it and prints the verdict word',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();
      expect(find.text('Great'), findsNothing);

      await tester.tap(find.bySemanticsIdentifier('feedback_star_4'));
      await tester.pump();

      expect(_halos(tester).length, 4);
      expect(find.text('Great'), findsOneWidget);
    });
  });

  group('identity disc', () {
    testWidgets('ratee disc is the glass rung, not an opaque navy one',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();

      final avatar = tester.widget<JeebAvatar>(find.byType(JeebAvatar));
      expect(avatar.fill, JeebAvatarFill.glass);
      expect(avatar.diameter, JeebAvatar.heroDiameter);
      expect(avatar.badge, JeebAvatarBadge.completed);
    });
  });

  group('CTA', () {
    testWidgets('accent (orange) pill, disabled until a star is picked',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();

      JeebCtaButton cta() =>
          tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      expect(cta().variant, JeebCtaVariant.accent);
      expect(cta().isEnabled, isFalse);

      await tester.tap(find.bySemanticsIdentifier('feedback_star_1'));
      await tester.pump();
      expect(cta().isEnabled, isTrue);
    });
  });

  group('what stood out (chip band)', () {
    testWidgets('five taxonomy chips; a tap flips one to selected',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami')),
      );
      await tester.pump();

      expect(find.byType(JeebSelectChip), findsNWidgets(5));
      expect(
        tester
            .widgetList<JeebSelectChip>(find.byType(JeebSelectChip))
            .every((JeebSelectChip c) => c.role == JeebChipRole.inlineAction),
        isTrue,
      );
      expect(find.bySemanticsIdentifier('feedback_tag_punctuality'),
          findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('feedback_tag_punctuality'));
      await tester.pump();
      final selected = tester
          .widgetList<JeebSelectChip>(find.byType(JeebSelectChip))
          .where((JeebSelectChip c) => c.selected);
      expect(selected.length, 1);
    });

    testWidgets('selected chips reach the wire as canonical taxonomy keys',
        (tester) async {
      final repo = _RecordingRepo();
      await tester.pumpWidget(
        _wrapRouted(
          RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            repository: repo,
            initialStars: 5,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('feedback_tag_courtesy'));
      await tester.pump();
      await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
      await tester.pumpAndSettle();

      expect(repo.tags, <String>['courtesy']);
    });
  });

  group('nameless ratee (the empty form of this screen)', () {
    testWidgets('drops the "Rate {name}" line instead of dangling a blank',
        (tester) async {
      await tester.pumpWidget(_wrap(const RatingScreen(deliveryId: 'd-1')));
      await tester.pump();

      expect(find.textContaining('Rate '), findsNothing);
      // The disc and the whole form still stand — only the name line is gone.
      expect(find.byType(JeebAvatar), findsOneWidget);
      expect(find.bySemanticsIdentifier('feedback_star_rating'), findsOneWidget);
      expect(find.bySemanticsIdentifier('rating_root'), findsOneWidget);
    });
  });

  group('submitting', () {
    testWidgets('in-flight draws the empty-state loading member, keeps '
        'rating_root', (tester) async {
      await tester.pumpWidget(
        _wrapRouted(
          const RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            repository: _StalledRepo(),
            initialStars: 4,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
      await tester.pump();

      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(empty.status, JeebEmptyStateStatus.loading);
      expect(empty.compact, isTrue);
      expect(
        find.bySemanticsIdentifier('feedback_submit_loading'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('rating_root'), findsOneWidget);
      expect(find.text('Sending your rating'), findsOneWidget);
    });
  });

  group('rtl', () {
    testWidgets('ar mirrors and keeps every frozen id', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RatingScreen(
            deliveryId: 'd-1',
            rateeName: 'Sami',
            initialStars: 3,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.byType(RatingScreen))),
        TextDirection.rtl,
      );
      for (final String id in <String>[
        'rating_root',
        'feedback_ratee_avatar',
        'feedback_star_rating',
        'feedback_comment_field',
        'rating_submit_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      expect(_halos(tester).length, 3);
    });
  });
}
