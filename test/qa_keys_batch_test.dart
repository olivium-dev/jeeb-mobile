// QA-KEYS-BATCH (T-MOB-QAKEYS): addressability locks for codex/Maestro.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/otp_at_door_card.dart';

class _MockOtpRepo extends Mock implements OtpHandoverRepository {}

/// Minimal real RatingRepository so the cubit starts in the `inputting` phase
/// (default state) which renders the star/comment/submit input view.
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
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingTheirs,
    );
  }
}

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  setUpAll(_loadArbs);

  // Tall, wide surface so nothing is laid out off-screen / culled.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  // ---- B-4 OTP handover ----------------------------------------------------
  group('B-4 OtpHandoverScreen', () {
    testWidgets(
      'client view surfaces otp_handover_code_display id (+ Key)',
      (tester) async {
        final repo = _MockOtpRepo();
        when(() => repo.fetchHandoverCode(deliveryId: any(named: 'deliveryId')))
            .thenAnswer((_) async => const OtpFetchResult(code: '1234'));
        final cubit = OtpHandoverCubit(
          repository: repo,
          deliveryId: 'DLV-1',
          isClient: true,
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _harness(
            BlocProvider<OtpHandoverCubit>.value(
              value: cubit,
              child: const OtpHandoverScreen(
                deliveryId: 'DLV-1',
                isClient: true,
              ),
            ),
          ),
        );
        // Pump (not pumpAndSettle): the client display never settles cleanly
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('otp_handover_code_display'),
          findsOneWidget,
          reason: 'The client-facing OTP code display must be addressable.',
        );
        expect(find.byKey(const Key('otpHandover.codeDisplay')), findsOneWidget);
      },
    );

    testWidgets(
      'jeeber view surfaces otp_handover_input and otp_handover_submit ids '
      '(+ Keys)',
      (tester) async {
        final repo = _MockOtpRepo();
        final cubit = OtpHandoverCubit(
          repository: repo,
          deliveryId: 'DLV-1',
          isClient: false,
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _harness(
            BlocProvider<OtpHandoverCubit>.value(
              value: cubit,
              child: const OtpHandoverScreen(
                deliveryId: 'DLV-1',
                isClient: false,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('otp_handover_input'),
          findsOneWidget,
          reason: 'The Jeeber OTP entry field must be addressable.',
        );
        expect(
          find.bySemanticsIdentifier('otp_handover_submit'),
          findsOneWidget,
          reason: 'The verify/submit CTA must be addressable.',
        );
        expect(find.byKey(const Key('otpHandover.input')), findsOneWidget);
        expect(find.byKey(const Key('otpHandover.submit')), findsOneWidget);
      },
    );
  });

  // ---- B-5 Mutual rating ---------------------------------------------------
  group('B-5 MutualRatingScreen', () {
    testWidgets(
      'input view surfaces mutual_rating_stars / _comment / _submit ids '
      '(+ Keys)',
      (tester) async {
        final cubit = MutualRatingCubit(
          repository: const _FakeRatingRepo(),
          deliveryId: 'DLV-2',
          isClient: true,
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _harness(
            BlocProvider<MutualRatingCubit>.value(
              value: cubit,
              child: const MutualRatingScreen(),
            ),
          ),
        );
        await tester.pump();

        // JM-034 §2.14 W1 contract ids.
        expect(
          find.bySemanticsIdentifier('rating_root'),
          findsOneWidget,
          reason: 'The screen signature id must surface on the canonical '
              'mutual-rate terminal.',
        );
        expect(
          find.bySemanticsIdentifier('mutual_rating_stars'),
          findsOneWidget,
          reason: 'The star-rating input must be addressable.',
        );
        expect(
          find.bySemanticsIdentifier('mutual_rating_comment'),
          findsOneWidget,
          reason: 'The comment field must be addressable.',
        );
        expect(
          find.bySemanticsIdentifier('rating_submit_cta'),
          findsOneWidget,
          reason: 'The rating submit CTA must be addressable (W1 id).',
        );
        // AC1/D56: no skip/dismiss control on the mandatory path.
        expect(
          find.bySemanticsIdentifier('rating_skip_cta'),
          findsNothing,
          reason: 'The mandatory rating path must expose no skip control.',
        );
        expect(find.byKey(const Key('mutualRating.stars')), findsOneWidget);
        expect(find.byKey(const Key('mutualRating.comment')), findsOneWidget);
        expect(find.byKey(const Key('mutualRating.submit')), findsOneWidget);
      },
    );
  });

  // ---- B-6 Tracking OTP CTA ------------------------------------------------
  group('B-6 OtpAtDoorCard', () {
    testWidgets(
      'surfaces tracking_otp_cta id and Key(tracking.otpCta)',
      (tester) async {
        await tester.pumpWidget(
          _harness(const OtpAtDoorCard(deliveryId: 'DLV-3')),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('tracking_otp_cta'),
          findsOneWidget,
          reason: 'The at-door → OTP CTA must be addressable by uiautomator.',
        );
        expect(find.byKey(const Key('tracking.otpCta')), findsOneWidget);
      },
    );
  });
}
