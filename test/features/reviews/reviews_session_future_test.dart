// LR-31: the session read is memoised (a future built inside `build` re-fires
// on every rebuild) and a failed read is a failure, not `jeeberId: ''`.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _CountingTokenStore implements AuthTokenStore {
  _CountingTokenStore({this.value, this.throws = false});

  final String? value;
  final bool throws;
  int reads = 0;

  @override
  Future<String?> get userId async {
    reads += 1;
    if (throws) throw StateError('keychain unavailable');
    return value;
  }

  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<bool> get hasToken async => false;
  @override
  Future<void> clear() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}
}

class _EmptyRepository implements ReviewsRepository {
  const _EmptyRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      const ReviewsPage(reviews: <ReviewItem>[], page: 1, totalPages: 1);

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// Rebuilds its child on demand — the LR-31 re-fire condition.
class _Rebuilder extends StatefulWidget {
  const _Rebuilder({super.key, required this.child});

  final Widget child;

  @override
  State<_Rebuilder> createState() => _RebuilderState();
}

class _RebuilderState extends State<_Rebuilder> {
  int _tick = 0;

  void bump() => setState(() => _tick += 1);

  @override
  Widget build(BuildContext context) {
    // The tick only forces a rebuild; the subtree keeps its element, which is
    // exactly the LR-31 condition.
    return SizedBox.expand(child: widget.child);
  }
}

void main() {
  Widget harness(
    AuthTokenStore store,
    GlobalKey<_RebuilderState> key, {
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: _Rebuilder(
      key: key,
      child: ReviewsListScreen(
        repository: const _EmptyRepository(),
        authTokenStore: store,
      ),
    ),
  );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  testWidgets('the session future is created once across three rebuilds', (
    tester,
  ) async {
    useReduceMotion(tester);
    final store = _CountingTokenStore(value: 'jeeber-1');
    final key = GlobalKey<_RebuilderState>();
    await tester.pumpWidget(harness(store, key));
    await tester.pumpAndSettle();

    for (int i = 0; i < 3; i++) {
      key.currentState!.bump();
      await tester.pumpAndSettle();
    }

    expect(store.reads, 1);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('[${locale.languageCode}] a failed session read is a failure, '
        'never jeeberId ""', (tester) async {
      useReduceMotion(tester);
      final store = _CountingTokenStore(throws: true);
      final key = GlobalKey<_RebuilderState>();
      await tester.pumpWidget(harness(store, key, locale: locale));
      await tester.pumpAndSettle();

      expect(byId('reviews_error'), findsOneWidget);
      expect(byId('reviews_retry_cta'), findsOneWidget);
      expect(byId('reviews_empty'), findsNothing);
    });
  }

  testWidgets('the error retry re-reads the session', (tester) async {
    useReduceMotion(tester);
    final store = _CountingTokenStore(throws: true);
    final key = GlobalKey<_RebuilderState>();
    await tester.pumpWidget(harness(store, key));
    await tester.pumpAndSettle();

    expect(store.reads, 1);
    await tester.tap(byId('reviews_retry_cta'));
    await tester.pumpAndSettle();
    expect(store.reads, 2);
  });
}
