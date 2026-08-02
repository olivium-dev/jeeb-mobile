// Render tests for the AccountStatusScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all five previews are the same screen behind the same "Account
// unavailable" app bar, differing only in the fake repository they are
// constructed with. A suite that asserted "the app bar rendered" would pass
// with every preview wired to the same fake.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/account_status_screen_fixtures.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';

import '../preview_test_harness.dart';

/// The failed branch's copy — one string for all three typed failures.
const String _loadError =
    "Couldn't load your account status. Check your connection and try again.";

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview whose surface actually settles. `Loading · cold entry` gets
  // its own group below: it holds a `CircularProgressIndicator`, whose
  // controller repeats forever, so `pumpAndSettle` never returns.
  testPreviewsRender(
    'AccountStatusScreen',
    const <String, Widget Function()>{
      'Suspended · no server reason': accountStatusScreenSuspendedNoReason,
      'Locked · server reason': accountStatusScreenLockedServerReason,
      'Locked · long server reason': accountStatusScreenLongServerReason,
      'Error · status read failed': accountStatusScreenLoadFailed,
    },
    expectedText: const <String, String>{
      // The suspended banner. The reason line would NOT do: it is the localized
      // default here, and every other loaded state replaces it with server text.
      'Suspended · no server reason': 'Your account is suspended',
      // The server reason, not the banner — `Your account is locked` is shared
      // with the long-reason preview.
      'Locked · server reason': accountStatusScreenSecurityHoldReason,
      'Locked · long server reason': accountStatusScreenLongReasonText,
      'Error · status read failed': _loadError,
    },
  );

  // `OmdsLoadingState` renders a `CircularProgressIndicator`, whose controller
  // `repeat()`s forever, so `pumpAndSettle` — which `pumpPreview` calls — times
  // out on it. This group makes the same three assertions the shared suite does
  // (builds in EN, builds in AR, renders its OWN state) with fixed pumps.
  group('AccountStatusScreen previews · Loading · cold entry', () {
    Future<void> pumpSpinning(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(accountStatusScreenLoading, locale));
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(); // let the cubit's first emit land
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold entry · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSpinning(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold entry renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSpinning(tester);

      // The spinner is up...
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and neither settled surface is. That combination is true of no other
      // preview in this file.
      expect(find.bySemanticsIdentifier('account_status_banner'), findsNothing);
      expect(find.text(_loadError), findsNothing);
      // The finding this preview exists for: the loading surface carries NO
      // copy at all (`OmdsLoadingState.message` is left null), so a blocked user
      // gets a title saying the account is unavailable and nothing else.
      expect(find.byType(Text), findsOneWidget); // the app bar title, alone
      expect(find.text('Account unavailable'), findsOneWidget);
    });
  });

  // The shared suite pumps at the tester's default 800x600 surface, where this
  // screen has 410 pt of width it does not have on a phone. These pump each
  // preview at the box its `@JeebPreview(size:)` declares, which is the only way
  // the declared size stays honest — and at the text scales the canvas matrix
  // renders, which is where the screen actually breaks.
  group('AccountStatusScreen previews · at the declared canvas box', () {
    /// A real device rather than the test default: [Size] in logical pixels at
    /// dpr 1, so `physicalSize` is the box the preview declares.
    Future<void> pumpAtBox(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    const Map<String, Widget Function()> settled = <String, Widget Function()>{
      'Suspended · no server reason': accountStatusScreenSuspendedNoReason,
      'Locked · server reason': accountStatusScreenLockedServerReason,
      'Locked · long server reason': accountStatusScreenLongServerReason,
      'Error · status read failed': accountStatusScreenLoadFailed,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry in settled.entries) {
        testWidgets('${entry.key} · ${locale.languageCode} · 390x844', (
          WidgetTester tester,
        ) async {
          await pumpAtBox(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    // The reference phone holds the three short states at the accessibility
    // ceiling, which is worth pinning as the control for everything below: the
    // body has no scroll fallback, so what follows is not "large text breaks
    // this screen" but "large text breaks it as soon as the viewport shrinks or
    // the server writes a sentence".
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in <String, Widget Function()>{
        'Suspended · no server reason': accountStatusScreenSuspendedNoReason,
        'Locked · server reason': accountStatusScreenLockedServerReason,
        'Error · status read failed': accountStatusScreenLoadFailed,
      }.entries) {
        testWidgets(
          '${entry.key} fits a 390x844 phone at 200% text · '
          '${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              entry.value,
              locale: locale,
              textScale: 2.0,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    // KNOWN DEFECTS, pinned deliberately — see the table in the section header
    // of `account_status_screen.dart`.
    //
    // `_BlockedBody` is a `SafeArea` → `Padding` → `Column` with
    // `mainAxisAlignment: center` and NO scroll fallback, so the column simply
    // grows past the viewport. What goes past the fold is the bottom of the
    // stack: the support CTA and the sign-out CTA, which are the only two exits
    // from a screen `AccountStatusGate` will not let the user leave. The
    // semantics nodes survive — `findsOneWidget` still passes on both ids — so
    // the overflow error is the only signal there is.
    //
    // These assert the CURRENT behaviour. When the body is made scrollable they
    // fail; that is the signal to delete them, not to shrink the fixtures.

    /// Every overflow below is a bottom overflow of the blocked body.
    void expectBottomOverflow(WidgetTester tester) {
      final Object? exception = tester.takeException();
      expect(exception, isFlutterError);
      expect(exception.toString(), contains('overflowed by'));
      expect(exception.toString(), contains('on the bottom'));
    }

    // The plainest rendering this screen has: a suspended account with NO
    // server text at all, so both lines are the app's own localized copy. On
    // the narrowest supported device it is already over the edge at 150%.
    testWidgets(
      'KNOWN: the localized-copy-only state overflows a 320x568 device at '
      '150% text',
      (WidgetTester tester) async {
        await pumpAtBox(
          tester,
          accountStatusScreenSuspendedNoReason,
          textScale: 1.5,
          size: const Size(320, 568),
        );

        expectBottomOverflow(tester);
      },
    );

    // A paragraph-length `statusReason` does not need a large text scale at
    // all: it overflows a compact device at 100%, and the reference phone at
    // 150%.
    testWidgets(
      'KNOWN: a paragraph-length server reason overflows a 320x568 device at '
      '100% text',
      (WidgetTester tester) async {
        await pumpAtBox(
          tester,
          accountStatusScreenLongServerReason,
          size: const Size(320, 568),
        );

        expectBottomOverflow(tester);
      },
    );

    testWidgets(
      'KNOWN: the same reason overflows the 390x844 reference phone at 150% '
      'text',
      (WidgetTester tester) async {
        await pumpAtBox(
          tester,
          accountStatusScreenLongServerReason,
          textScale: 1.5,
        );

        expectBottomOverflow(tester);
      },
    );

    // Not this screen's own `Column` — `OmdsErrorState` centres its icon,
    // message and retry in a `Column(mainAxisSize: min)` with no scroll either,
    // and the failed branch hands it the longest of the two error strings.
    testWidgets(
      'KNOWN: the failed branch overflows a 320x568 device at 200% text',
      (WidgetTester tester) async {
        await pumpAtBox(
          tester,
          accountStatusScreenLoadFailed,
          textScale: 2.0,
          size: const Size(320, 568),
        );

        expectBottomOverflow(tester);
      },
    );

    // The controls. At 100% every state is clean on both devices except the
    // paragraph reason on the compact one, so the assertions above are about
    // the viewport and the text scale rather than about the fixtures being
    // contrived.
    for (final Size size in const <Size>[Size(390, 844), Size(320, 568)]) {
      testWidgets(
        'the localized-copy-only state is clean at 100% on '
        '${size.width.round()}x${size.height.round()}',
        (WidgetTester tester) async {
          await pumpAtBox(
            tester,
            accountStatusScreenSuspendedNoReason,
            size: size,
          );

          expect(tester.takeException(), isNull);
          expect(
            find.bySemanticsIdentifier('account_status_support_cta'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsIdentifier('account_status_signout_cta'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('the paragraph reason is clean at 100% on a phone', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(tester, accountStatusScreenLongServerReason);

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsIdentifier('account_status_support_cta'),
        findsOneWidget,
      );
    });
  });

  group('AccountStatusScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // — `_AccountStatusScreenHost` → `Router` → `AccountStatusScreen` —
    // differing only in the repository handed to it, so pumping a second
    // preview into the same tester would reuse the first preview's element and
    // with it the first preview's cubit.

    testWidgets('the loaded previews show the JM-066 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, accountStatusScreenSuspendedNoReason);

      for (final String id in const <String>[
        'account_status_root',
        'account_status_banner',
        'account_status_reason',
        'account_status_support_cta',
        'account_status_signout_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget);
      }
    });

    testWidgets('the two blocked values differ by glyph as well as by copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, accountStatusScreenLockedServerReason);

      expect(find.text('Your account is locked'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
    });

    testWidgets('a server reason REPLACES the localized default', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, accountStatusScreenLockedServerReason);

      expect(find.text(accountStatusScreenSecurityHoldReason), findsOneWidget);
      expect(
        find.textContaining('Your account has been locked for security'),
        findsNothing,
      );
    });

    // The finding this preview exists for. The gate blocks every tab while the
    // account is blocked, and both exits are built inside the `loaded` branch —
    // so a failed status read strands the user on a Retry-only surface. With
    // `AccountStatusFailure.unauthorized` that Retry re-runs a call that cannot
    // succeed, and the copy still blames the connection.
    testWidgets(
      'Error · status read failed renders its own state: a Retry and NO exits',
      (WidgetTester tester) async {
        await pumpPreview(tester, accountStatusScreenLoadFailed);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('account_status_support_cta'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('account_status_signout_cta'),
          findsNothing,
        );
        expect(find.bySemanticsIdentifier('account_status_banner'), findsNothing);
      },
    );

    testWidgets('an unauthorized read is pixel-identical to an offline one', (
      WidgetTester tester,
    ) async {
      // The control for the "one error string" note in the section header: a
      // second error preview would add no information, and this is the cheapest
      // honest way to say so.
      await pumpPreview(tester, accountStatusScreenLoadFailed);
      expect(find.text(_loadError), findsOneWidget);

      await tester.pumpWidget(
        previewCanvas(
          () => const _UnauthorizedHost(),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_loadError), findsOneWidget);
    });

    testWidgets('the support CTA reaches support-ticket', (
      WidgetTester tester,
    ) async {
      // Proves the preview host is honest to tap in: the screen's
      // `goNamed('support-ticket')` needs a Router, and a preview without one
      // would throw here instead of navigating.
      await pumpPreview(tester, accountStatusScreenSuspendedNoReason);

      await tester.tap(
        find.bySemanticsIdentifier('account_status_support_cta'),
      );
      await tester.pumpAndSettle();

      expect(find.text('support-ticket (JM-063)'), findsOneWidget);
    });

    testWidgets('the sign-out CTA raises the logout/delete confirm sheet', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, accountStatusScreenSuspendedNoReason);

      await tester.tap(
        find.bySemanticsIdentifier('account_status_signout_cta'),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('logout_delete_sheet'), findsOneWidget);
      // Opening it is inert — the sheet's `_terminator` is `late`, so no
      // `DioAccountSessionTerminator` is built until a confirm CTA fires.
      expect(tester.takeException(), isNull);
    });
  });
}

/// The unauthorized twin of `accountStatusScreenLoadFailed`, built here rather
/// than as a sixth preview: it renders the same pixels, so it belongs in the
/// assertion that says so and not in the canvas.
class _UnauthorizedHost extends StatelessWidget {
  const _UnauthorizedHost();

  @override
  Widget build(BuildContext context) => const AccountStatusScreen(
        repository: AccountStatusScreenFailingRepository(
          failure: AccountStatusFailure.unauthorized,
        ),
      );
}

