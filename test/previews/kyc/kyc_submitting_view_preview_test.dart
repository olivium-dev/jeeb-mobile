// Render tests for the KycSubmittingView previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// A word on `expectedText`, because this file breaks the house rule that every
// state pins a DISTINCT string: it cannot. [KycSubmittingView] takes no
// arguments and reads nothing off the cubit — its body is a fixed icon,
// `kycSubmittingTitle`, `kycSubmittingBody` and a spinner — so the two strings
// below are the ONLY text any state can render. What tells the states apart is
// the safety net underneath them, so the discrimination the shared harness
// normally does with text is done here in `preview specifics`, against the
// wizard step each state leaves the cubit on. The identical copy is asserted
// deliberately in `renders the SAME frame in every state`: it is the finding,
// not an accident of the fixtures.
//
// The last group is the other thing these previews exposed — the body is an
// unscrollable centred Column, and at 200% text on a real phone the spinner is
// laid out off the bottom of the screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';
import 'package:jeeb_mobile/previews/kyc/kyc_submitting_view_preview.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _title = 'Submitting your documents';
const String _body =
    "Hang tight — we're uploading your ID and selfie. "
    'This usually takes a few seconds.';
const String _titleAr = 'جاري إرسال مستنداتك';
const String _bodyAr =
    'يرجى الانتظار — نقوم برفع الهوية والصورة الشخصية. '
    'عادةً ما يستغرق ذلك بضع ثوانٍ.';

/// The three states that keep an ambient wizard cubit parked on
/// [KycWizardStep.submitting] once the canvas has settled.
const Map<String, Widget Function()> _stuckOnSubmitting =
    <String, Widget Function()>{
  'Probe budget spent · nothing recorded': kycSubmittingViewBudgetSpent,
  'Submit HUNG · status read never answers': kycSubmittingViewHung,
};

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all. Read from the message rather than pinned as an exact
/// constant: the fact under test is "this does not fit on a phone", and an
/// exact pixel count would break on a font metric change without meaning
/// anything.
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// The wizard cubit a preview mounted above the view, read back the way the
/// view itself reads it.
KycWizardCubit _cubitOf(WidgetTester tester) {
  return BlocProvider.of<KycWizardCubit>(
    tester.element(find.byType(KycSubmittingView)),
  );
}

/// Pumps [preview], asserts the full body is there, and returns the headline's
/// rect — then UNMOUNTS, so the next preview in the same test builds a fresh
/// element tree instead of silently reusing this one's cubit.
Future<Rect> _frameOf(WidgetTester tester, Widget Function() preview) async {
  await pumpPreview(tester, preview);

  expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
  expect(find.byKey(KycSubmittingView.titleKey), findsOneWidget);
  expect(find.byKey(KycSubmittingView.spinnerKey), findsOneWidget);
  expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  expect(find.text(_title), findsOneWidget);
  expect(find.text(_body), findsOneWidget);
  expect(find.byType(Text), findsNWidgets(2));

  final Rect rect = tester.getRect(find.byKey(KycSubmittingView.titleKey));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  return rect;
}

/// Pumps a preview into a real phone box at [textScale], the way the canvas
/// renders it, instead of into the 800x600 default test surface. The size is
/// the point: at 800x600 this body has room it never has on a phone.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 700),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycSubmittingView',
    const <String, Widget Function()>{
      'Spinner only · no wizard cubit': kycSubmittingViewDetached,
      'Probe budget spent · nothing recorded': kycSubmittingViewBudgetSpent,
      'Submit HUNG · status read never answers': kycSubmittingViewHung,
      'Safety net fires · server recorded it': kycSubmittingViewSelfHeal,
      'Small phone body (320x480)': kycSubmittingViewSmallPhone,
    },
    // Both strings this widget owns, alternated so a state that stopped
    // rendering either one is caught. They cannot be distinct per state — see
    // the header, and `renders the SAME frame in every state` below.
    expectedText: const <String, String>{
      'Spinner only · no wizard cubit': _title,
      'Probe budget spent · nothing recorded': _body,
      'Submit HUNG · status read never answers': _title,
      'Safety net fires · server recorded it': _body,
      'Small phone body (320x480)': _title,
    },
  );

  group('KycSubmittingView preview specifics', () {
    testWidgets('renders the SAME frame in every state — no submit-hang tell', (
      WidgetTester tester,
    ) async {
      final Map<String, Rect> byState = <String, Rect>{};
      for (final MapEntry<String, Widget Function()> entry
          in const <String, Widget Function()>{
        'Spinner only · no wizard cubit': kycSubmittingViewDetached,
        'Probe budget spent · nothing recorded': kycSubmittingViewBudgetSpent,
        'Submit HUNG · status read never answers': kycSubmittingViewHung,
        'Safety net fires · server recorded it': kycSubmittingViewSelfHeal,
        'Small phone body (320x480)': kycSubmittingViewSmallPhone,
      }.entries) {
        byState[entry.key] = await _frameOf(tester, entry.value);
      }

      expect(
        byState.values.toSet(),
        hasLength(1),
        reason:
            'a healthy submit, a hung one, one whose recovery budget is spent '
            'and one the safety net already rescued all render the same two '
            'strings in the same place: $byState',
      );
    });

    testWidgets('offers the user no control of any kind', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycSubmittingViewBudgetSpent);

      // After the eight-request budget the automatic recovery is over, and
      // there is nothing on screen to retry, cancel or leave with — recovery
      // is entirely off-screen (the submit future, the CDN-upload timeout,
      // KycWizardCubit.onJeeberRoleGranted).
      expect(find.byWidgetPredicate((Widget w) => w is ButtonStyleButton),
          findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });

    for (final MapEntry<String, Widget Function()> entry
        in _stuckOnSubmitting.entries) {
      testWidgets('${entry.key}: the wizard is still on the spinner', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        expect(_cubitOf(tester).state.step, KycWizardStep.submitting);
        expect(find.byKey(KycSubmittingView.spinnerKey), findsOneWidget);
      });
    }

    testWidgets('the safety net advances the wizard off the spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycSubmittingViewSelfHeal);

      // JEBV4-259/271: the server recorded the submission even though the
      // client never saw the 201, so the probe moves the wizard on — this is
      // the self-heal that replaced "force-stop and relaunch".
      final KycWizardCubit cubit = _cubitOf(tester);
      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.pending);
      // A recovered submit must NOT chain to onboarding-funding.
      expect(cubit.state.justSubmitted, isFalse);
      // ...and the view it is mounted in cannot show any of that.
      expect(find.text(_title), findsOneWidget);
    });

    testWidgets('with no wizard cubit in scope the safety net is a no-op', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycSubmittingViewDetached);

      // `context.read<KycWizardCubit?>()` is a nullable read: outside the
      // wizard this view polls nothing and never throws — the spinner is
      // simply terminal.
      expect(tester.takeException(), isNull);
      expect(find.byKey(KycSubmittingView.spinnerKey), findsOneWidget);
    });

    testWidgets('localizes: no English leaks into the AR reading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycSubmittingViewHung, locale: const Locale('ar'));

      expect(find.text(_titleAr), findsOneWidget);
      expect(find.text(_bodyAr), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(find.text(_body), findsNothing);
      final Element title = tester.element(
        find.byKey(KycSubmittingView.titleKey),
      );
      expect(Directionality.of(title), TextDirection.rtl);
    });

    testWidgets('announces the state change as a live region', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, kycSubmittingViewDetached);

      // It IS a live region, so the step change is announced rather than
      // waiting for the user to swipe back to it.
      final Semantics root = tester.widget<Semantics>(
        find.byKey(KycSubmittingView.rootKey),
      );
      expect(root.properties.liveRegion, isTrue);

      // FINDING — the announcement STUTTERS. The container sets its own
      // `label`/`hint` from the same two ARB keys the body already renders as
      // Text, and it neither excludes those descendants
      // (`excludeSemantics: true`) nor makes them explicit child nodes, so
      // their labels are merged into the container's own. The live region
      // therefore announces the headline twice, then the body, then repeats
      // the body as the hint. Pinned exactly: fixing this must fail here
      // rather than leave a stale claim behind.
      final node = tester.getSemantics(find.byKey(KycSubmittingView.rootKey));
      expect(node.label, '$_title\n$_title\n$_body');
      expect(node.hint, _body);

      // Disposed inline, not in a tearDown: the framework verifies handles
      // before tearDowns run.
      handle.dispose();
    });
  });

  // What the previews exposed, held as assertions so it cannot regress
  // unnoticed — and so that FIXING it fails this file loudly rather than
  // leaving a stale claim behind.
  //
  // None of it is visible in the default reading: `testPreviewsRender` pumps
  // into the 800x600 test surface, where the headline fits on one line and the
  // body has ~200 dp of headroom it never has on a phone.
  group('KycSubmittingView layout ceiling (phone-sized boxes)', () {
    testWidgets('nothing scrolls: the body is a bare centred Column', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(tester, kycSubmittingViewDetached, textScale: 1.0);

      expect(tester.takeException(), isNull);
      expect(
        find.byType(Scrollable),
        findsNothing,
        reason:
            'with no scroll view, anything that outgrows the viewport is off '
            'the screen rather than scrolled to',
      );
    });

    testWidgets('fits a 390x700 phone body at 100% text (the control)', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(tester, kycSubmittingViewDetached, textScale: 1.0);

      expect(_overflowPixels(tester.takeException()), 0);
      expect(
        tester.getRect(find.byKey(KycSubmittingView.spinnerKey)).bottom,
        lessThan(700),
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'at 200% text the spinner is off the bottom of a 390x700 phone '
        '(${locale.languageCode})',
        (WidgetTester tester) async {
          await _pumpInPreviewBox(
            tester,
            kycSubmittingViewDetached,
            textScale: 2.0,
            locale: locale,
          );

          // Measured: 84 dp of overflow in EN, 124 dp in AR.
          expect(_overflowPixels(tester.takeException()), greaterThan(0));
          // Not merely clipped decoration: the ONLY indication that anything
          // is still happening is laid out below the phone, and nothing
          // scrolls to it.
          expect(
            tester.getRect(find.byKey(KycSubmittingView.spinnerKey)).top,
            greaterThan(700),
            reason: 'the spinner is the whole message of this screen',
          );
        },
      );
    }

    testWidgets('on a 320 dp phone at 200% text it overflows by 300+ dp', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycSubmittingViewSmallPhone,
        textScale: 2.0,
        box: const Size(320, 480),
      );

      // Measured: 528 dp in EN, 344 dp in AR — the body copy alone is taller
      // than the viewport.
      expect(_overflowPixels(tester.takeException()), greaterThan(300));
      expect(
        tester.getRect(find.byKey(KycSubmittingView.spinnerKey)).top,
        greaterThan(480),
      );
    });
  });
}
