// MIDNIGHT M4 — the three state surfaces of `RequestFeedScreen` (inventory
// rows #30 / #31 / #32).
//
// Goldens are evidence, not gates (5% comparator tolerance), so every ruling
// this row landed is read back off the built widget: variant, status, copy,
// identifier, and the absence of the OMDS state family.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_feed_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Counts reads so the retry CTA can be proven to re-hit the feed.
class _InertRepository implements RequestFeedRepository {
  _InertRepository();

  int reads = 0;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    reads++;
    throw Exception('designed load failure');
  }

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<void> dispose() async {}
}

/// Pinned to ONE designed frame. Never `start()`ed, so the cubit builds neither
/// its expiry sweep nor its refresh gate — the 1Hz timers that would otherwise
/// outlive the test body.
class _SeededFeedCubit extends RequestFeedCubit {
  _SeededFeedCubit(RequestFeedState seed, {required super.repository}) {
    emit(seed);
  }
}

const RequestFeedState _loadingSeed = RequestFeedState(
  status: RequestFeedStatus.loading,
);
const RequestFeedState _errorSeed = RequestFeedState(
  status: RequestFeedStatus.error,
  error: NetworkFailure(offline: true),
);
const RequestFeedState _emptySeed = RequestFeedState(
  status: RequestFeedStatus.ready,
);

Widget _harness(RequestFeedCubit cubit, {Locale locale = const Locale('en')}) {
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
    // The illustrations loop ∞ by design (02-STUDY-NOTES M0-4); reduce motion
    // pins the rest frame, which is also the capture frame.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: RequestFeedScreen(cubit: cubit),
  );
}

/// The view runs a 1Hz countdown ticker cancelled only in `dispose`, so every
/// test unmounts the tree before the pending-timer invariant runs.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

RequestFeedCubit _seated(RequestFeedState seed, {_InertRepository? repository}) {
  final RequestFeedCubit cubit = _SeededFeedCubit(
    seed,
    repository: repository ?? _InertRepository(),
  );
  addTearDown(cubit.close);
  return cubit;
}

JeebEmptyState _block(WidgetTester tester) =>
    tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));

void main() {
  group('M4 · request feed state family', () {
    testWidgets('#30 cold read draws the street SKELETON, no CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_seated(_loadingSeed)));
      await tester.pump();

      final JeebEmptyState block = _block(tester);
      expect(block.status, JeebEmptyStateStatus.loading);
      expect(block.variant, JeebEmptyStateVariant.street);
      expect(block.identifier, 'request_feed_loading_state');
      expect(block.headline, _l10n(tester).requestFeedLoadingHeadline);
      expect(block.action, isNull);

      await _unmount(tester);
    });

    testWidgets(
      '#31 cold failure draws the DANGER block + a retry that re-reads',
      (tester) async {
        final _InertRepository repo = _InertRepository();
        await tester.pumpWidget(
          _harness(_seated(_errorSeed, repository: repo)),
        );
        await tester.pump();

        final JeebEmptyState block = _block(tester);
        final AppLocalizations l10n = _l10n(tester);
        expect(block.reason, JeebEmptyStateReason.failed);
        expect(block.variant, JeebEmptyStateVariant.street);
        expect(block.identifier, 'request_feed_error_state');
        // The kind's copy family, never a flat "check your connection".
        expect(block.headline, l10n.errorNetworkTitle);
        expect(block.body, l10n.errorNetworkBody);
        expect(block.action, isNotNull);
        expect(repo.reads, 0);

        await tester.tap(find.bySemanticsIdentifier('request_feed_retry_cta'));
        await tester.pump();
        expect(repo.reads, 1, reason: 'the retry must re-read the feed');

        await _unmount(tester);
      },
    );

    testWidgets('#32 an empty board draws the LIT street block, both lines', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_seated(_emptySeed)));
      await tester.pump();

      final JeebEmptyState block = _block(tester);
      final AppLocalizations l10n = _l10n(tester);
      expect(block.status, JeebEmptyStateStatus.empty);
      expect(block.variant, JeebEmptyStateVariant.street);
      expect(block.identifier, 'request_feed_empty_state');
      expect(block.headline, l10n.requestFeedEmptyTitle);
      expect(block.body, l10n.requestFeedEmptySubtitle);

      await _unmount(tester);
    });

    testWidgets(
      'the FROZEN requestFeed.empty key survives, still over a scrollable',
      (tester) async {
        await tester.pumpWidget(_harness(_seated(_emptySeed)));
        await tester.pump();

        expect(find.byKey(const Key('requestFeed.empty')), findsOneWidget);
        // OmdsPullToRefresh only fires over a scrollable child.
        expect(
          find.descendant(
            of: find.byKey(const Key('requestFeed.empty')),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );

        await _unmount(tester);
      },
    );

    testWidgets('no OMDS state widget survives on ANY of the three branches', (
      tester,
    ) async {
      for (final RequestFeedState seed in <RequestFeedState>[
        _loadingSeed,
        _errorSeed,
        _emptySeed,
      ]) {
        await tester.pumpWidget(_harness(_seated(seed)));
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w.runtimeType.toString().startsWith('Omds') &&
                w.runtimeType.toString().contains('State'),
          ),
          findsNothing,
          reason: 'branch ${seed.status} still draws an OMDS state widget',
        );
      }

      await _unmount(tester);
    });

    testWidgets('the empty headline is NOT the accent — primary IS #D73B00', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_seated(_emptySeed)));
      await tester.pump();

      final ColorScheme scheme = AppTheme.midnight().colorScheme;
      final Text headline = tester.widget<Text>(
        find.text(_l10n(tester).requestFeedEmptyTitle),
      );
      expect(headline.style?.color, scheme.onSurface);
      expect(headline.style?.color, isNot(scheme.primary));

      await _unmount(tester);
    });

    testWidgets('renders mirrored under Arabic with the block intact', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(_seated(_emptySeed), locale: const Locale('ar')),
      );
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.byType(JeebEmptyState))),
        TextDirection.rtl,
      );
      expect(
        find.bySemanticsIdentifier('request_feed_empty_state'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  });
}
