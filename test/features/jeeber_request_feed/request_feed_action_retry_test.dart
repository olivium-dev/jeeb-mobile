// The failed-act snack must retry the act the jeeber TOOK. A declined job that
// comes back as an accept is a safety defect, not a UI slip.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_feed_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _SpyRepository implements RequestFeedRepository {
  _SpyRepository({required this.failure});

  final AppFailure failure;
  int accepts = 0;
  int declines = 0;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async {
    accepts++;
    throw failure;
  }

  @override
  Future<RequestActionOutcome> decline(String id) async {
    declines++;
    throw failure;
  }

  @override
  Future<void> dispose() async {}
}

/// Never `start()`ed: no expiry sweep, no refresh gate, no live timers.
class _SeededFeedCubit extends RequestFeedCubit {
  _SeededFeedCubit(RequestFeedState seed, {required super.repository}) {
    emit(seed);
  }
}

const DeliveryRequest _row = DeliveryRequest(
  id: 'r1',
  pickup: RequestLocation(label: 'Hamra', latitude: 33.89, longitude: 35.48),
  dropoff: RequestLocation(label: 'Achrafieh', latitude: 33.88, longitude: 35.52),
  tier: null,
  estimatedDistanceKm: 2.4,
  potentialEarnings: 12,
  currency: 'USD',
  expiresAt: null,
);

const RequestFeedState _seed = RequestFeedState(
  status: RequestFeedStatus.ready,
  requests: <DeliveryRequest>[_row],
);

Widget _harness(RequestFeedCubit cubit) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: RequestFeedScreen(cubit: cubit),
  );
}

final Finder _snackRetry = find.byKey(
  const Key('request_feed_action_snack_retry_cta'),
);

void main() {
  testWidgets('a failed DECLINE retries the DECLINE, never the accept',
      (tester) async {
    final repo = _SpyRepository(failure: const ServerFailure(status: 500));
    final cubit = _SeededFeedCubit(_seed, repository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await cubit.decline('r1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_snackRetry, findsOneWidget);
    await tester.tap(_snackRetry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.declines, 2);
    expect(repo.accepts, 0, reason: 'a Retry must never change the act');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed ACCEPT still retries the accept', (tester) async {
    final repo = _SpyRepository(failure: const NetworkFailure());
    final cubit = _SeededFeedCubit(_seed, repository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await cubit.accept('r1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(_snackRetry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.accepts, 2);
    expect(repo.declines, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an UNRECOVERABLE act failure offers no Retry at all',
      (tester) async {
    final repo = _SpyRepository(failure: const ForbiddenFailure());
    final cubit = _SeededFeedCubit(_seed, repository: repo);
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit));
    await cubit.decline('r1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.bySemanticsIdentifier('request_feed_action_snack'),
        findsOneWidget);
    expect(_snackRetry, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
