// MIDNIGHT M3-08 adoption instruments.
//
// The screen has no board tile; every value below is derived from R21
// (order history) and is read back off the BUILT widget, because the golden
// comparator tolerates 5% pixel diff and is blind to a token re-point.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements NotificationsRepository {
  _Repo(this._items, {this.throws, this.stall = false});

  final List<NotificationItem> _items;
  final NotificationsFailure? throws;
  final bool stall;

  @override
  Future<List<NotificationItem>> fetchNotifications() {
    if (stall) return Completer<List<NotificationItem>>().future;
    final NotificationsFailure? f = throws;
    if (f != null) throw NotificationsRepositoryException(f);
    return Future<List<NotificationItem>>.value(_items);
  }

  @override
  Future<void> markRead(String id) async {}
}

NotificationItem _row(String id, {required bool read}) => NotificationItem(
  id: id,
  kind: NotificationKind.offer,
  title: 'title-$id',
  body: 'body-$id',
  timestamp: '2026-06-18T10:00:00Z',
  read: read,
);

Widget _harness(NotificationsRepository repo) {
  final GoRouter router = GoRouter(
    initialLocation: '/notifications',
    routes: <RouteBase>[
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, _) => NotificationsListScreen(repository: repo),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => const Scaffold()),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    // E4's illustration loops ∞ by design — reduce motion pins the rest frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child ?? const SizedBox.shrink(),
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

Color? _inkOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  Future<void> pump(WidgetTester tester, NotificationsRepository repo) async {
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
  }

  group('field (derived from R21: one PERIWINKLE radial at 12% -6%)', () {
    testWidgets('content variant, wash top-start, orange layer nulled', (
      tester,
    ) async {
      await pump(tester, _Repo(<NotificationItem>[_row('a', read: false)]));

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      expect(field.glowColor, Colors.transparent);
      expect(field.animateDecor, isFalse);
      // The wash is the periwinkle layer and the glow is the orange one —
      // asserting the pair catches the mirrored-layer error directly.
      expect(field.washPlacement!.fx, closeTo(0.12, 0.001));
      expect(field.washPlacement!.fy, closeTo(-0.06, 0.001));
    });
  });

  group('row (derived from R21 tpl 1437: glass 7%, r20→lg, 14/16)', () {
    testWidgets('title ink is onSurface, NOT the accent', (tester) async {
      await pump(tester, _Repo(<NotificationItem>[_row('a', read: false)]));

      final ColorScheme scheme = Theme.of(
        tester.element(find.text('title-a')),
      ).colorScheme;
      final JeebRoles roles = tester.element(find.text('title-a')).jeebRoles;
      expect(_inkOf(tester, 'title-a'), scheme.onSurface);
      expect(_inkOf(tester, 'title-a'), isNot(roles.accent));
      expect(_inkOf(tester, 'title-a'), isNot(scheme.primary));
    });

    testWidgets('meta run is onSurfaceVariant, body is inkSoft', (
      tester,
    ) async {
      await pump(tester, _Repo(<NotificationItem>[_row('a', read: false)]));

      final ColorScheme scheme = Theme.of(
        tester.element(find.text('body-a')),
      ).colorScheme;
      // Eyebrow + relative time = R21's measured `#8A93D8` meta run.
      expect(_inkOf(tester, 'New offer'), scheme.onSurfaceVariant);
      // Payload body = `#B9C0F0` inkSoft, the rung between title and meta.
      expect(_inkOf(tester, 'body-a'), scheme.onSecondaryContainer);
      expect(_inkOf(tester, 'body-a'), isNot(scheme.onSurface));
    });

    testWidgets('card rung: JeebRadii.lg + 14/16 padding', (tester) async {
      await pump(tester, _Repo(<NotificationItem>[_row('a', read: false)]));

      final JeebOutlinedCard card = tester.widget<JeebOutlinedCard>(
        find.byType(JeebOutlinedCard).first,
      );
      expect(card.radius, JeebRadii.lg);
      expect(
        card.padding,
        const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: 14,
        ),
      );
    });

    // TODO(midnight): inherits owner Q-006 — see notification_row.dart.
    testWidgets('a READ row carries R21\'s faded treatment, unread does not', (
      tester,
    ) async {
      await pump(tester, _Repo(<NotificationItem>[_row('r', read: true)]));
      final Finder readFade = find.ancestor(
        of: find.bySemanticsIdentifier('notif_row_r'),
        matching: find.byType(Opacity),
      );
      expect(readFade, findsOneWidget);
      expect(tester.widget<Opacity>(readFade).opacity, 0.65);

      await pump(tester, _Repo(<NotificationItem>[_row('u', read: false)]));
      expect(
        find.ancestor(
          of: find.bySemanticsIdentifier('notif_row_u'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('the unread dot is the accent and is FLAT (no R21 glowDot)', (
      tester,
    ) async {
      await pump(tester, _Repo(<NotificationItem>[_row('a', read: false)]));

      final Finder dot = find.descendant(
        of: find.bySemanticsIdentifier('notif_row_a_unread_badge'),
        matching: find.byType(Container),
      );
      final BoxDecoration decoration =
          tester.widget<Container>(dot).decoration! as BoxDecoration;
      expect(decoration.color, tester.element(dot).jeebRoles.accent);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.boxShadow, isNull);
      expect(tester.getSize(dot), const Size(9, 9));
    });
  });

  group('states (E4 parcel — R21\'s own empty family)', () {
    testWidgets('empty renders the parcel illustration at rest', (
      tester,
    ) async {
      await pump(tester, _Repo(const <NotificationItem>[]));

      final JeebEmptyState empty = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(empty.identifier, 'notifications_empty');
      expect(empty.variant, JeebEmptyStateVariant.parcel);
      expect(empty.status, JeebEmptyStateStatus.empty);
      // No CTA: nothing routes to "make a notification happen".
      expect(empty.action, isNull);
    });

    testWidgets('error is the same illustration, danger-tinted, with a retry', (
      tester,
    ) async {
      await pump(
        tester,
        _Repo(const <NotificationItem>[], throws: NotificationsFailure.network),
      );

      final JeebEmptyState error = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(error.variant, JeebEmptyStateVariant.parcel);
      expect(error.status, JeebEmptyStateStatus.error);
      expect(error.action, isNotNull);
    });

    testWidgets('loading is the same illustration, skeleton, CTA withheld', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_Repo(const <NotificationItem>[], stall: true)),
      );
      await tester.pump();

      final JeebEmptyState loading = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(loading.identifier, 'notifications_loading');
      expect(loading.variant, JeebEmptyStateVariant.parcel);
      expect(loading.status, JeebEmptyStateStatus.loading);
    });

    testWidgets('no OMDS light-theme state chrome survives', (tester) async {
      await pump(tester, _Repo(const <NotificationItem>[]));
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
    });
  });
}
