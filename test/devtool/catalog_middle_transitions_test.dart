import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/catalog_transition_host.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/offer_submission_screen_fixtures.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/presentation/widgets/notification_row.dart';
import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/offers/presentation/widgets/jeeb_money_field.dart';
import 'package:jeeb_mobile/features/reviews/application/reviews_cubit.dart';
import 'package:jeeb_mobile/features/reviews/presentation/widgets/review_row.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

Widget _scenario(String feature, String label) => Builder(
  builder: kScreenCatalog
      .where((entry) => entry.feature == feature)
      .expand((entry) => entry.states)
      .singleWhere((state) => state.label == label)
      .builder,
);

Finder _id(String value) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == value,
);

Future<void> _pump(WidgetTester tester, Widget child, Locale locale) async {
  useReduceMotion(tester);
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    wrapMidnight(child, locale: locale, scrollable: false),
  );
  // 12 frames cover load, mounted action, rejected call and snack animation.
  // Never swallow pumpAndSettle failures or wait for transient feedback to vanish.
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in kFailureLocales) {
    testWidgets(
      'catalog server45s renders and counts down actual resend window ${locale.languageCode}',
      (tester) async {
        await _pump(
          tester,
          _scenario('registration', 'OTP — rate limited (server window 45s)'),
          locale,
        );
        final context = tester.element(find.byType(OtpVerificationScreen));
        final cubit = context.read<RegistrationCubit>();
        final l10n = AppLocalizations.of(context);
        expect(cubit.state.step, RegistrationStep.otp);
        expect(cubit.state.otpError, RegistrationOtpError.rateLimited);
        expect(cubit.state.otpRetryAfterSeconds, 45);
        expect(cubit.state.resendSecondsRemaining, 45);
        expect(
          find.text(l10n.registrationOtpRateLimitedSeconds(45)),
          findsOneWidget,
        );
        Text countdown() => tester.widget<Text>(
          find.byKey(const Key('registration.resendCountdown')),
        );
        expect(countdown().textSpan!.toPlainText(), contains('0:45'));
        expect(
          find.byKey(const Key('registration.lockoutBanner')),
          findsNothing,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(cubit.state.resendSecondsRemaining, 44);
        expect(
          find.text(l10n.registrationOtpRateLimitedSeconds(44)),
          findsOneWidget,
        );
        expect(countdown().textSpan!.toPlainText(), contains('0:44'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    for (final label in ['description_too_short', 'moderation_blocked']) {
      testWidgets(
        'location instruction wraps fully $label ${locale.languageCode}',
        (tester) async {
          await _pump(tester, _scenario('location', label), locale);
          final finder = find.byKey(
            const Key('clientLocation.descriptionErrorCopy'),
          );
          expect(finder, findsOneWidget);
          final copy = tester.widget<Text>(finder);
          expect(copy.maxLines, isNull);
          expect(copy.overflow, isNot(TextOverflow.ellipsis));
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.size.width, lessThanOrEqualTo(440));
          expect(copy.data, isNotEmpty);
        },
      );
    }
    for (final lost in [false, true]) {
      testWidgets(
        'tracking catalog drives ${lost ? 'lost' : 'warm failure'} ${locale.languageCode}',
        (tester) async {
          await _pump(
            tester,
            _scenario(
              'live_tracking',
              lost
                  ? 'Warm — position lost, the map goes stale'
                  : 'Warm — refresh failed over a live snapshot',
            ),
            locale,
          );
          final state = tester
              .element(find.byType(LiveTrackingScreen))
              .read<LiveTrackingCubit>()
              .state;
          expect(state.trackingInfo, isNotNull);
          if (lost) {
            expect(state.trackingInfo!.positionLost, isTrue);
            expect(state.trackingInfo!.positionStale, isTrue);
          } else {
            expect(state.refreshError, isNotNull);
            expect(find.byType(JeebRefreshFailedNote), findsOneWidget);
          }
        },
      );
    }

    for (final label in [
      'Refresh failed over rows (LR-07)',
      'Load-more failed (TEST-16)',
      'Report conflict — already rated (AE-25)',
    ]) {
      testWidgets(
        'reviews catalog really executes $label ${locale.languageCode}',
        (tester) async {
          await _pump(tester, _scenario('reviews', label), locale);
          expect(find.byType(ReviewRow), findsNWidgets(2));
          final context = tester.element(find.byType(ReviewRow).first);
          final state = context.read<ReviewsCubit>().state;
          if (label.startsWith('Refresh')) {
            expect(state.refreshError, isNotNull);
            expect(find.byType(JeebRefreshFailedNote), findsOneWidget);
          } else if (label.startsWith('Load-more')) {
            expect(state.hasMore, isTrue);
            expect(state.loadMoreError, isTrue);
            expect(state.loadMoreFailure, isNotNull);
            expect(_id('reviews_load_more_retry'), findsOneWidget);
          } else {
            expect(
              find.text(AppLocalizations.of(context).reviewsErrorAlreadyRated),
              findsOneWidget,
            );
            expect(_id('reviews_report_error'), findsOneWidget);
          }
        },
      );
    }

    for (final refLess in [false, true]) {
      testWidgets(
        'notification catalog performs ${refLess ? 'ref-less tap' : 'failed PATCH'} ${locale.languageCode}',
        (tester) async {
          await _pump(
            tester,
            _scenario(
              'notifications',
              refLess
                  ? 'Ref-less rows — every tap says it cannot open (NOTIF-04)'
                  : 'Mark-read failed — the flip rolls back (NOTIF-03)',
            ),
            locale,
          );
          final context = tester.element(find.byType(NotificationRow).first);
          if (refLess) {
            expect(_id('notifications_cannot_open'), findsOneWidget);
          } else {
            expect(
              context.read<NotificationsListCubit>().state.items.first.read,
              isFalse,
            );
            expect(_id('notifications_markread_error'), findsOneWidget);
          }
        },
      );
    }

    for (final label in [
      'Photo attached (the CTA is wired now)',
      'Photo permission denied',
      'Photo unavailable',
    ]) {
      testWidgets(
        'photo catalog invokes picker $label ${locale.languageCode}',
        (tester) async {
          await _pump(
            tester,
            _scenario('prohibited_item_report', label),
            locale,
          );
          if (label.startsWith('Photo attached')) {
            expect(_id('prohibited_item_report_photo_chip'), findsOneWidget);
            expect(_id('prohibited_item_report_photo_error'), findsNothing);
          } else {
            expect(_id('prohibited_item_report_photo_chip'), findsNothing);
            expect(_id('prohibited_item_report_photo_error'), findsOneWidget);
          }
        },
      );
    }

    for (final label in [
      'Duplicate offer — withdraw and re-bid',
      'Fee too low — the PRICE slot',
      'ETA invalid — the ETA slot',
      'Note too long — the note slot',
      'Out of range',
      'Same-role violation',
      'Request not open — terminal',
      '402 with figures',
      '402 with an EMPTY body — no fabricated zero',
    ]) {
      testWidgets(
        'offer catalog submits actual form $label ${locale.languageCode}',
        (tester) async {
          await _pump(tester, _scenario('offers', label), locale);
          final screen = tester.widget<OfferSubmissionScreen>(
            find.byType(OfferSubmissionScreen),
          );
          final repository =
              screen.repository! as CatalogObservedOfferRepository;
          final field = tester.widget<JeebMoneyField>(
            find.byType(JeebMoneyField),
          );
          expect(repository.submissions, 1);
          expect(repository.price, label.startsWith('402') ? 125 : 15);
          expect(double.parse(field.controller.text), repository.price);
          expect(repository.eta, 80);
          expect(repository.note, isNotEmpty);
          final cubit = tester
              .element(find.byType(JeebMoneyField))
              .read<OfferFormCubit>();
          expect(cubit.state.mode, isNot(OfferFormMode.idle));
          expect(cubit.state.isSubmitting, isFalse);
          if (label.startsWith('Note too long')) {
            expect(repository.note!.length, kOfferNoteMaxLength);
            expect(cubit.state.noteError, OfferFormState.noteErrorTooLong);
          }
          if (label.startsWith('Request not open')) {
            final button = tester.widget<JeebCtaButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is JeebCtaButton &&
                    w.identifier == 'offer_composer_send_cta',
              ),
            );
            expect(button.isEnabled, isFalse);
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is JeebInfoNote &&
                    w.identifier == 'offer_composer_error_note',
              ),
              findsOneWidget,
            );
          }
          if (label.startsWith('402')) {
            expect(_id('insufficient_balance_sheet'), findsOneWidget);
            expect(
              (screen.walletRepository!
                      as OfferSubmissionFailureWalletRepository)
                  .reads,
              2,
            );
            if (label == '402 with figures') {
              expect(_id('insufficient_balance_needed_amount'), findsOneWidget);
              expect(
                _id('insufficient_balance_available_amount'),
                findsOneWidget,
              );
            } else {
              expect(_id('insufficient_balance_needed_amount'), findsNothing);
              expect(
                _id('insufficient_balance_available_amount'),
                findsNothing,
              );
            }
          }
        },
      );
    }
  }

  testWidgets(
    'catalog driver executes a newly selected scenario in reused host',
    (tester) async {
      var first = 0;
      var second = 0;
      Widget host(bool next) => Directionality(
        textDirection: TextDirection.ltr,
        child: CatalogTransitionHost(
          steps: [
            (root) {
              if (next) {
                second++;
              } else {
                first++;
              }
              return true;
            },
          ],
          child: Text(next ? 'second scenario' : 'first scenario'),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(first, 1);
      expect(second, 0);
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(first, 1);
      expect(second, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog driver fails explicitly when a required action is absent',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CatalogTransitionHost(
            steps: [(root) => false],
            child: const SizedBox(),
          ),
        ),
      );
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(tester.takeException(), isA<StateError>());
    },
  );
}
