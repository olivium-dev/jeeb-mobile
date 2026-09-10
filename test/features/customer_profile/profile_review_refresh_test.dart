import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';
import 'package:jeeb_mobile/core/session/profile_review_refresh_scope.dart';
import 'package:jeeb_mobile/core/session/reviews_refresh_signals.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/features/customer_profile/application/customer_profile_cubit.dart';
import 'package:jeeb_mobile/features/customer_profile/application/customer_profile_state.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _Delegate extends LocalizationsDelegate<AppLocalizations> {
  final arb = File('lib/l10n/app_en.arb').readAsStringSync();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, arb);
  @override
  bool shouldReload(_Delegate old) => false;
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.midnight(),
  localizationsDelegates: [
    _Delegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

class _Profile implements CustomerProfileRepository {
  int calls = 0;
  int count = 0;
  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    calls++;
    return CustomerProfileViewData(
      userId: 'actor-a',
      name: 'Test actor',
      ratingCount: count,
    );
  }
}

class _Pending implements CustomerProfileRepository {
  final reads = <Completer<CustomerProfileViewData>>[];
  @override
  Future<CustomerProfileViewData> fetchProfile() {
    final read = Completer<CustomerProfileViewData>();
    reads.add(read);
    return read.future;
  }
}

void main() {
  testWidgets(
    'hidden profile does not read; first rater sees reveal on refocus without push',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      final repo = _Profile();
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, shown, child) =>
                TabVisibility(isVisible: shown, child: child!),
            child: CustomerProfileScreen(
              data: const CustomerProfileViewData(),
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(repo.calls, 0);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('No reviews yet'), findsOneWidget);
      // First submission leaves the revealed received count at zero.
      expect(repo.count, 0);
      visible.value = false;
      await tester.pump();
      repo.count = 1; // Other party submits; server now reveals, with no push.
      await tester.pump(const Duration(minutes: 2));
      expect(repo.calls, 1, reason: 'no hidden polling');
      visible.value = true;
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('1 Reviews'), findsOneWidget);
      await tester
          .widget<JeebPullToRefresh>(find.byType(JeebPullToRefresh))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        repo.calls,
        3,
        reason: 'explicit pull is available and does not echo',
      );
    },
  );

  testWidgets(
    'visibility, resume and targeted invalidations coalesce with no hidden reads',
    (tester) async {
      final visible = ValueNotifier(false);
      final changes = StreamController<void>.broadcast(sync: true);
      final reviews = StreamController<ReviewsRefreshEvent>.broadcast(
        sync: true,
      );
      final auth = StreamController<AuthLossReason>.broadcast(sync: true);
      addTearDown(visible.dispose);
      addTearDown(changes.close);
      addTearDown(reviews.close);
      addTearDown(auth.close);
      final reads = <Completer<void>>[];
      var ended = 0;
      final source = Object();
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, shown, child) =>
                TabVisibility(isVisible: shown, child: child!),
            child: ProfileReviewRefreshScope(
              source: source,
              rateeId: () => 'actor-a',
              profileChanges: changes.stream,
              reviewChanges: reviews.stream,
              authLoss: auth.stream,
              onSessionEnded: () => ended++,
              onRefresh: () {
                final read = Completer<void>();
                reads.add(read);
                return read.future;
              },
              child: const SizedBox(),
            ),
          ),
        ),
      );
      changes.add(null);
      changes.add(null);
      await tester.pump();
      expect(reads, isEmpty);
      visible.value = true;
      await tester.pump();
      expect(reads.length, 1);
      changes.add(null);
      changes.add(null);
      reads[0].complete();
      await tester.pump();
      await tester.pump();
      expect(
        reads.length,
        2,
        reason: 'one trailing read for a mid-flight burst',
      );
      reads[1].complete();
      await tester.pump();
      reviews.add(const ReviewsRefreshEvent(rateeId: 'other'));
      reviews.add(ReviewsRefreshEvent(rateeId: 'actor-a', source: source));
      await tester.pump();
      expect(
        reads.length,
        2,
        reason: 'unrelated subject and own refresh ignored',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      changes.add(null);
      await tester.pump();
      expect(reads.length, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      changes.add(null);
      await tester.pump();
      expect(reads.length, 3);
      reads[2].complete();
      await tester.pump();
      auth.add(AuthLossReason.signedOut);
      changes.add(null);
      await tester.pump();
      expect(ended, 1);
      expect(reads.length, 3, reason: 'ended session cannot restart reads');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pushed route suppresses signals and returning revalidates once',
    (tester) async {
      final repo = _Profile();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: AppTheme.midnight(),
          localizationsDelegates: [
            _Delegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: CustomerProfileScreen(
            data: const CustomerProfileViewData(),
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      unawaited(
        key.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.count = 1;
      ReviewsRefreshSignals.instance.signalChanged(rateeId: 'actor-a');
      await tester.pump();
      expect(repo.calls, 1);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('1 Reviews'), findsOneWidget);
    },
  );

  test(
    'newer self-profile refresh wins, and disposal drops late results',
    () async {
      final repo = _Pending();
      final cubit = CustomerProfileCubit(
        seed: const CustomerProfileViewData(),
        repository: repo,
      );
      final first = cubit.load();
      await Future<void>.delayed(Duration.zero);
      final second = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      repo.reads[1].complete(
        const CustomerProfileViewData(name: 'Current', ratingCount: 1),
      );
      await second;
      repo.reads[0].complete(
        const CustomerProfileViewData(name: 'Stale', ratingCount: 0),
      );
      await first;
      expect(cubit.state.data.ratingCount, 1);
      final third = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repo.reads[2].completeError(StateError('late failure'));
      await third;
    },
  );

  test(
    'account transition or auth loss cannot apply prior account data',
    () async {
      final repo = _Pending();
      var account = 'actor-a';
      final cubit = CustomerProfileCubit(
        seed: const CustomerProfileViewData(
          userId: 'actor-a',
          name: 'Previous',
        ),
        repository: repo,
        accountId: () async => account,
      );
      final read = cubit.load();
      await Future<void>.delayed(Duration.zero);
      account = 'actor-b';
      repo.reads.single.complete(
        const CustomerProfileViewData(
          userId: 'actor-a',
          name: 'Previous',
          ratingCount: 8,
        ),
      );
      await read;
      expect(cubit.state.data.isBlank, isTrue);
      expect(cubit.state.status, CustomerProfileStatus.failed);
      await cubit.refresh();
      expect(repo.reads.length, 1);
      await cubit.close();

      final next = CustomerProfileCubit(
        seed: const CustomerProfileViewData(),
        repository: repo,
      );
      final pending = next.load();
      await Future<void>.delayed(Duration.zero);
      next.endSession();
      repo.reads.last.complete(
        const CustomerProfileViewData(name: 'Must not return'),
      );
      await pending;
      expect(next.state.data.isBlank, isTrue);
      await next.close();
    },
  );
}
