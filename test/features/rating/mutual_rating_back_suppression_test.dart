// Run-22 replacement P1 regression guard — hardware BACK on the mandatory
// mutual-rating terminal must NEVER escape to the OS (it exited to the
// launcher, backgrounding the app mid-mandatory-rating).
//
// Root cause: the screen relied on `PopScope(canPop: false)` alone, but it is
// typically reached via `context.goNamed('mutual-rating')` (receipt confirm /
// OTP handover), which REPLACES the navigation stack. As the lone root page
// there is nothing to pop, so `popRoute` never consults PopScope and the BACK
// event propagated to the OS. The fix consumes the system BACK at the
// `BackButtonListener` layer (before the router delegate), at both stack
// positions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRatingRepo implements RatingRepository {
  const _FakeRatingRepo();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      const RatingStatus(
        deliveryId: 'dlv-1',
        revealState: RatingRevealState.pendingTheirs,
      );
}

void main() {
  testWidgets(
    'system BACK on mutual-rating as the LONE ROOT page is consumed — the app '
    'is not backgrounded and the rating stays on screen',
    (tester) async {
      // Reproduce the exact run-22 configuration: the rating terminal reached
      // via `go` — a go_router stack whose LONE ROOT page is mutual-rating.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<MutualRatingCubit>(
              create: (_) => MutualRatingCubit(
                repository: const _FakeRatingRepo(),
                deliveryId: 'dlv-1',
                isClient: true,
              ),
              child: const MutualRatingScreen(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      );
      await tester.pump();
      expect(find.byType(MutualRatingScreen), findsOneWidget);

      // When the framework does NOT consume a system BACK, it invokes
      // `SystemNavigator.pop` on the platform channel — on Android that
      // backgrounds the app (the run-22 launcher-exit symptom). Intercept the
      // platform channel to detect that escape.
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      // Deliver the hardware/system BACK exactly as the engine does.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pump();

      expect(
        platformCalls,
        isNot(contains('SystemNavigator.pop')),
        reason: 'system BACK must be consumed by the mandatory rating '
            'terminal, never escape to the OS',
      );
      expect(find.byType(MutualRatingScreen), findsOneWidget);
    },
  );
}
