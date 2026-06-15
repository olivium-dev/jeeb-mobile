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

/// Simulated soft-button navigation bar inset (3-button nav is ~48dp; this is a
/// representative value that any correct fix must reserve at the bottom). The
/// FlutterView reports insets in PHYSICAL pixels, so multiply by the device
/// pixel ratio when seeding `tester.view`.
const double _kNavBarInsetDp = 48;

void main() {
  group('BottomInsetX.sheetBottomInset', () {
    // Seeds the FlutterView's nav-bar inset (where the helper reads it from —
    // NOT MediaQuery, which a modal route consumes) and injects the keyboard
    // inset via the propagated MediaQuery (which IS preserved inside sheets).
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
      // The exact regression: keyboard closed (viewInsets.bottom == 0) must
      // still reserve the nav-bar inset. The buggy code reserved 0 here, so
      // content rendered flush behind the nav bar.
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
      // Soft-button nav bar reported by the device under edge-to-edge. Seeded on
      // the FlutterView so it survives the modal-sheet route (which strips the
      // MediaQuery padding).
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding =
          FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      addTearDown(tester.view.reset);

      final cubit = SuperLoginCubit(service: service, tokenStore: tokenStore);
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit));
      await tester.tap(find.byKey(const Key('open')));
      // pump() not pumpAndSettle() — OmdsLoadingButton has a live ticker.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final submitRect =
          tester.getRect(find.byKey(const Key('superLogin.submit')));

      // The CTA's bottom edge must sit at least one nav-bar inset above the
      // screen bottom. Pre-fix (viewInsets-only padding) this gap was ~20dp
      // (the sheet's own content padding) and the button rendered behind the
      // soft buttons.
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
