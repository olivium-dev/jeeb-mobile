// M3-05 — per-element assertions for the MIDNIGHT order-summary screen.
//
// Goldens tolerate 5% pixel diff, so every ruling below is read off the widget
// (colour, radius, geometry, variant) rather than off a picture.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_footer.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/order_summary/application/order_summary_cubit.dart';
import 'package:jeeb_mobile/features/order_summary/application/order_summary_state.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const OrderSummary _kSummary = OrderSummary(
  deliveryId: 'DEL-2044',
  requestId: 'REQ-2044',
  conversationId: 'CONV-2044',
  price: 14.5,
  currency: 'USD',
  jeeberName: 'Rami Chidiac',
  tier: 'express',
  jeeberRating: 4.8,
  jeeberRatingCount: 214,
  etaMinutes: 12,
  itemSummary: 'Pharmacy pickup',
);

class _Repo implements OrderSummaryRepository {
  _Repo({this.summary, this.failure});

  final OrderSummary? summary;
  final OrderSummaryFailure? failure;
  int calls = 0;

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async {
    calls++;
    final OrderSummaryFailure? f = failure;
    if (f != null) throw OrderSummaryRepositoryException(f);
    return summary!;
  }
}

class _StalledRepo implements OrderSummaryRepository {
  @override
  Future<OrderSummary> fetchSummary(String deliveryId) =>
      Completer<OrderSummary>().future;
}

Widget _harnessWithCubit(
  OrderSummaryCubit Function(OrderSummaryRepository, String) factory, {
  Locale locale = const Locale('en'),
}) =>
    _harness(_Repo(summary: _kSummary), locale: locale, cubitFactory: factory);

Widget _harness(
  OrderSummaryRepository repo, {
  Locale locale = const Locale('en'),
  OrderSummaryCubit Function(OrderSummaryRepository, String)? cubitFactory,
}) {
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
    // JeebEmptyState's illustration loops forever by design, so every mount
    // runs at the reduce-motion rest frame (M0-4 ruling).
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: OrderSummaryScreen(
      deliveryId: 'DEL-2044',
      repository: repo,
      cubitFactory: cubitFactory,
    ),
  );
}

/// The decoration actually painted by [of]'s nearest [DecoratedBox].
BoxDecoration _paintedBox(WidgetTester tester, Finder of) {
  final Finder box = find.descendant(
    of: of,
    matching: find.byType(DecoratedBox),
  );
  return tester.widget<DecoratedBox>(box.first).decoration as BoxDecoration;
}

void main() {
  group('M3-05 · field + surface rungs (derived from R12)', () {
    testWidgets('mounts the content field, still, at the topEnd default',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      final JeebMidnightField field =
          tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
      expect(field.variant, JeebFieldVariant.content);
      expect(field.animateDecor, isFalse);
      // R12 is a top-end bloom tile and declares no periwinkle wash.
      expect(field.glowPlacement, isNull);
      expect(field.washPlacement, isNull);
    });

    testWidgets('the ticket paints R12\'s xl slab at the strong glass rung',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      final BoxDecoration decoration =
          _paintedBox(tester, find.byType(JeebOutlinedCard));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(JeebRadii.xl),
        reason: 'token sheet §5: 20 is off the ladder; R12 measures 22.',
      );
      expect(
        (decoration.border! as Border).top.color,
        JeebMidnight.glassBorderStrong,
        reason: 'R12 slab stroke is white .15 → the §4 strong rung.',
      );
    });
  });

  group('M3-05 · money emphasis', () {
    // The ramp carries the emphasis; the ink does NOT. A read-only recap spends
    // no accent (M3 ruling: `primary` on a non-CTA is a defect signature).
    testWidgets('the price run is the 22/w800 token in onSurface ink',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      final Text price = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_price'),
          matching: find.textContaining('14.50'),
        ),
      );
      expect(price.style!.fontSize, 22);
      expect(price.style!.fontWeight, FontWeight.w800);
      expect(price.style!.letterSpacing, -0.5);
      expect(price.style!.color, JeebMidnight.ink);
      expect(price.style!.color, isNot(JeebMidnight.orange));
    });

    testWidgets('the item value sits a rung BELOW the price, at R12\'s 14.5/700',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      final Text value = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_item'),
          matching: find.text('Pharmacy pickup'),
        ),
      );
      expect(value.style!.fontSize, 14.5);
      expect(value.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('the review count is parenthesised ONCE',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      expect(find.text('(214)'), findsOneWidget);
      expect(find.text('((214))'), findsNothing);
    });
  });

  group('M3-05 · CTA treatment', () {
    testWidgets('Track is the lone accent act and Open chat stays glass',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      final JeebCtaButton track = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_track'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      final JeebCtaButton chat = tester.widget<JeebCtaButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_open_chat'),
          matching: find.byType(JeebCtaButton),
        ),
      );
      expect(track.variant, JeebCtaVariant.accent);
      expect(chat.variant, JeebCtaVariant.outline);
      // R12's docked pill is 58; the glass twin matches so they share a baseline.
      expect(track.height, JeebCtaButton.primaryHeightTall);
      expect(chat.height, JeebCtaButton.primaryHeightTall);

      // Read the painted fill, not just the enum.
      expect(
        _paintedBox(
          tester,
          find.bySemanticsIdentifier('order_summary_track'),
        ).color,
        JeebMidnight.orange,
      );
    });

    testWidgets('the CTA pair is DOCKED — outside the scroll area',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      expect(
        find.ancestor(
          of: find.bySemanticsIdentifier('order_summary_track'),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
        reason: 'R12 docks its act below the scroll area.',
      );
      final JeebCtaFooter footer =
          tester.widget<JeebCtaFooter>(find.byType(JeebCtaFooter));
      expect(footer.padding, JeebCtaFooter.docked);
      expect(footer.form, JeebCtaFooterForm.split);
    });
  });

  group('M3-05 · the empty / loading / error family', () {
    testWidgets('cold read draws the parcel skeleton',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_StalledRepo()));
      await tester.pump();

      final JeebEmptyState state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.status, JeebEmptyStateStatus.loading);
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.identifier, 'order_summary_loading');
      expect(find.byType(JeebCtaFooter), findsNothing);
    });

    testWidgets('a 404 is the ERROR rung with an EXIT, never an inert Retry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(_Repo(failure: OrderSummaryFailure.notFound)),
      );
      await tester.pump();

      final JeebEmptyState state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.identifier, 'order_summary_error');
      expect(find.bySemanticsIdentifier('order_summary_retry_cta'),
          findsNothing);
      // R6: an unrecoverable kind gets a way onward, never a dead block.
      expect(find.bySemanticsIdentifier('order_summary_exit_cta'),
          findsOneWidget);
    });

    testWidgets('a loaded-but-absent summary still owns order_summary_empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _harnessWithCubit(
          (OrderSummaryRepository repo, String id) =>
              OrderSummaryCubit(repository: repo, deliveryId: id)
                ..emit(const OrderSummaryState(
                  status: OrderSummaryStatus.loaded,
                )),
        ),
      );
      await tester.pump();

      final JeebEmptyState state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.effectiveStatus, JeebEmptyStateStatus.empty);
      expect(state.identifier, 'order_summary_empty');
    });

    testWidgets('a warm refresh failure renders order_summary_refresh_failed '
        'over the rows', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harnessWithCubit(
          (OrderSummaryRepository repo, String id) =>
              OrderSummaryCubit(repository: repo, deliveryId: id)
                ..emit(const OrderSummaryState(
                  status: OrderSummaryStatus.loaded,
                  summary: _kSummary,
                  refreshError: OrderSummaryFailure.network,
                )),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('order_summary_error'), findsNothing);
      expect(
        find.bySemanticsIdentifier('order_summary_refresh_failed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_summary_refresh_failed_retry_cta'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier('order_summary_refresh_failed_dismiss_cta'),
      );
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('order_summary_refresh_failed'),
        findsNothing,
      );
    });

    testWidgets('a transport failure is the ERROR rung and refetches on Retry',
        (WidgetTester tester) async {
      final _Repo repo = _Repo(failure: OrderSummaryFailure.network);
      await tester.pumpWidget(_harness(repo));
      await tester.pump();

      final JeebEmptyState state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.identifier, 'order_summary_error');
      expect(
        state.body,
        'You appear to be offline. Check your connection and try again.',
      );

      expect(repo.calls, 1);
      // UX-31: the CTA now calls `retry()` — `load()` early-returned unless
      // the status was `initial`, so the old CTA could never re-read.
      await tester.tap(find.bySemanticsIdentifier('order_summary_retry_cta'));
      await tester.pump();
      expect(repo.calls, 2);
    });
  });

  group('M3-05 · identifiers survive the restyle', () {
    testWidgets('the root node does not swallow its children',
        (WidgetTester tester) async {
      await tester.pumpWidget(_harness(_Repo(summary: _kSummary)));
      await tester.pump();

      for (final String id in const <String>[
        'order_summary_root',
        'order_summary_back',
        'order_summary_pinned',
        'order_summary_jeeber_name',
        'order_summary_tier',
        'order_summary_eta',
        'order_summary_item',
        'order_summary_price',
        'order_summary_cash_label',
        'order_summary_open_chat',
        'order_summary_track',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('renders RTL without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(_Repo(summary: _kSummary), locale: const Locale('ar')),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsOneWidget);
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });
  });
}

