import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/layout/bottom_inset.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_cubit.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_sheet.dart';

import '../../support/sync_app_localizations.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

class _FakeSuperLoginService implements SuperLoginService {
  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      const SuperLoginFailure(SuperLoginError.unknown);
}

/// Simulated soft-button navigation bar inset (3-button nav is 
const double _kNavBarInsetDp = 48;

void main() {
  group('BottomInsetX.sheetBottomInset', () {
    Future<double> resolveInset(
      WidgetTester tester, {
      required double keyboardDp,
      required double navBarDp,
    }) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding =
          FakeViewPadding(bottom: navBarDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: navBarDp * dpr);
      addTearDown(tester.view.reset);

      late double captured;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            viewInsets: EdgeInsets.only(bottom: keyboardDp),
          ),
          child: Builder(
            builder: (context) {
              captured = context.sheetBottomInset;
              return const SizedBox();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('sums keyboard inset and nav-bar inset', (tester) async {
      final inset = await resolveInset(
        tester,
        keyboardDp: 300,
        navBarDp: _kNavBarInsetDp,
      );
      expect(inset, 300 + _kNavBarInsetDp);
    });

    testWidgets('nav-bar inset is reserved when the keyboard is closed',
        (tester) async {
      final inset = await resolveInset(
        tester,
        keyboardDp: 0,
        navBarDp: _kNavBarInsetDp,
      );
      expect(inset, _kNavBarInsetDp);
    });

    testWidgets('is zero only with no keyboard and no nav bar (gesture nav off)',
        (tester) async {
      final inset = await resolveInset(tester, keyboardDp: 0, navBarDp: 0);
      expect(inset, 0);
    });
  });

  group('Super-login sheet bottom inset (edge-to-edge)', () {
    late _FakeSuperLoginService service;
    late _MockAuthTokenStore tokenStore;

    setUp(() {
      service = _FakeSuperLoginService();
      tokenStore = _MockAuthTokenStore();
    });

    Widget host(SuperLoginCubit cubit) => wrapForTest(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showSuperLoginSheet(context, cubit: cubit),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

    testWidgets(
        'submit button clears the soft-button nav bar inset',
        (tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding =
          FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      addTearDown(tester.view.reset);

      final cubit = SuperLoginCubit(service: service, tokenStore: tokenStore);
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final submitRect =
          tester.getRect(find.byKey(const Key('superLogin.submit')));

      final gapBelowButton = screenHeight - submitRect.bottom;
      expect(
        gapBelowButton,
        greaterThanOrEqualTo(_kNavBarInsetDp),
        reason: 'Submit CTA must clear the $_kNavBarInsetDp dp nav-bar inset; '
            'gap was $gapBelowButton',
      );
    });
  });
}
