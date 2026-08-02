// Designed states for `OtpHandoverScreen` (T-MOB-018 / sprint-009 G4, the
// at-door handover) — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_08_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/otp_handover/presentation/
//     otp_handover_screen.dart                          the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned a private `_FakeOtpHandoverRepository`, a private
// `_InMemoryHandoverCodeStore` and a private `_driveEscalate` helper. They moved
// here whole when the screen got a preview section, because two copies of the
// same "designed state" drift and the catalog is the one a designer signs off
// against. The catalog's seven states are unchanged, state-for-state and
// label-for-label; what they are built out of now lives here.
//
// Two things changed in the move, neither of them to what the catalog RENDERS:
//
//  * the fake grew two "never completes" axes ([ScriptedOtpHandoverRepository.
//    fetchStalls] / [ScriptedOtpHandoverRepository.submitStalls]), because the
//    catalog's enum-of-flags could not express the two states this screen spends
//    real time in — the customer's cold read and the jeeber's verify POST;
//  * the cubit construction + pre-drive moved behind
//    [OtpHandoverScreenPreviewFixtures.cubit], so both hosts mount the SAME
//    cubit with the same delivery id.
//
// This screen has NO seed seam: `OtpHandoverCubit` takes a repository and starts
// working in its constructor (client mode fetches, jeeber mode emits `ready`).
// So a designed state here is described by what the collaborators answer plus
// the pre-drive, and the real mount path runs exactly as it does in production.
//
// NOTHING here touches the network. Every answer is a const value, a throw, or a
// `Completer` that is never completed — the [CatalogNetworkGuard] both hosts
// install is a net, not the plan. There is no Dio and no GetIt on any path
// below, and the code store is a plain field rather than SharedPreferences, so
// nothing a reviewer taps can persist a handover code into the real app.

import 'dart:async';

import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/handover_code_store.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/domain/otp_handover_result.dart';

/// A fake [OtpHandoverRepository] whose two calls are scripted independently.
///
/// The independence matters: `fetchHandoverCode` is the CUSTOMER's path (the
/// cubit calls it from its constructor) and `submitOtp` is the JEEBER's, and no
/// state uses both. A single "fixture kind" enum would have to name a submit
/// behaviour for a customer state that never submits.
///
/// Both axes have a "never completes" setting, spelled as a [Completer] that is
/// never completed: it holds no timer and no subscription, so a frozen state is
/// stable for as long as the host is open without arming anything a widget test
/// would report as pending.
class ScriptedOtpHandoverRepository implements OtpHandoverRepository {
  const ScriptedOtpHandoverRepository({
    this.fetchResult,
    this.fetchErrorKind,
    this.fetchStalls = false,
    this.submitErrorKind,
    this.submitStalls = false,
  });

  /// What a successful `fetchHandoverCode` answers.
  ///
  /// Defaults to the SMS-trigger reading (`code: null, smsTriggered: true`),
  /// which is what the live gateway's `GET /otp` actually returns — see G4 in
  /// `test/otp_handover_screen_test.dart`. A fixture that forgets to say what it
  /// wants therefore gets the honest production answer, not a code.
  final OtpFetchResult? fetchResult;

  /// When set, `fetchHandoverCode` throws it — the customer's full-screen error.
  final OtpHandoverErrorKind? fetchErrorKind;

  /// When true, `fetchHandoverCode` never resolves and the customer stays on
  /// [OtpHandoverViewMode.loading].
  final bool fetchStalls;

  /// When set, `submitOtp` throws it. [OtpHandoverErrorKind.invalidOtp] is the
  /// one that drives the wrong-code / attempts-hint / escalate ladder.
  final OtpHandoverErrorKind? submitErrorKind;

  /// When true, `submitOtp` never resolves, freezing the jeeber on
  /// [OtpHandoverViewMode.submitting].
  final bool submitStalls;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) {
    if (fetchStalls) return Completer<OtpFetchResult>().future;
    final OtpHandoverErrorKind? kind = fetchErrorKind;
    if (kind != null) {
      return Future<OtpFetchResult>.error(OtpHandoverException(kind));
    }
    return Future<OtpFetchResult>.value(
      fetchResult ?? const OtpFetchResult(smsTriggered: true),
    );
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) {
    if (submitStalls) return Completer<OtpHandoverResult>().future;
    final OtpHandoverErrorKind? kind = submitErrorKind;
    if (kind != null) {
      return Future<OtpHandoverResult>.error(OtpHandoverException(kind));
    }
    return Future<OtpHandoverResult>.value(
      const OtpHandoverResult(success: true),
    );
  }
}

/// In-memory [HandoverCodeStore] — seeded with a code (or empty), mutated in
/// place by the cubit's save/clear calls.
///
/// The production store is SharedPreferences-backed, which is why neither dev
/// surface may use it: a reviewer opening the catalog would write a fixture code
/// into the real app's prefs, where `_loadHandoverCode` reads it BEFORE the
/// gateway on the next real delivery.
class InMemoryHandoverCodeStore implements HandoverCodeStore {
  InMemoryHandoverCodeStore([this._code]);

  String? _code;

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    _code = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => _code;

  @override
  Future<void> clear({required String deliveryId}) async {
    _code = null;
  }
}

/// The designed states of `OtpHandoverScreen`, as collaborators plus the cubit
/// pre-drive that puts the screen in each one.
class OtpHandoverScreenPreviewFixtures {
  const OtpHandoverScreenPreviewFixtures._();

  /// The delivery every state hangs off. Both hosts pass it to the cubit AND to
  /// the screen, which take it separately.
  static const String deliveryId = 'DEL-3091';

  /// The code the customer is shown, and the one the jeeber types to succeed.
  static const String storedCode = '4821';

  /// The four digits reviewed on the 320 pt floor.
  ///
  /// Deliberately the same digits `handoverCodeDisplayNarrowPhone` uses in
  /// `presentation/widgets/handover_code_display.dart`, so the panel's own
  /// narrow-phone preview and this screen's compact state describe one code
  /// rather than two. It differs from [storedCode] only so a render test can
  /// tell the two compact states apart from the phone-width ones.
  static const String compactCode = '9061';

  /// A code the gateway widened past the four digits the UI was designed for.
  ///
  /// Nothing on the customer's path enforces the length — `HandoverCodeDisplay`
  /// renders whatever string arrives — so this is one gateway change away. Only
  /// the JEEBER's submit button carries the contract (`code.length == 4`).
  static const String widenedCode = '481902';

  /// What the jeeber types when they get it wrong. Never [storedCode]: the
  /// scripted repository decides the outcome, but a fixture that typed the right
  /// code into a rejecting repository would read as a lie.
  static const String wrongCode = '0000';

  // ──────────────────────────── the collaborators ──────────────────────────

  /// The reference repository: fetch returns the SMS trigger, submit succeeds.
  static OtpHandoverRepository accepting() =>
      const ScriptedOtpHandoverRepository();

  /// The customer's cold read, still in flight.
  static OtpHandoverRepository stalledFetch() =>
      const ScriptedOtpHandoverRepository(fetchStalls: true);

  /// The customer's cold read failed. Defaults to the transport error, which is
  /// the one the screen maps to its own copy rather than to the generic
  /// fallback.
  static OtpHandoverRepository failingFetch([
    OtpHandoverErrorKind kind = OtpHandoverErrorKind.network,
  ]) => ScriptedOtpHandoverRepository(fetchErrorKind: kind);

  /// The gateway answered with a code — the state a customer reaches only when
  /// the delivery predates the SMS-trigger behaviour, or when the code was
  /// cached locally. Pair it with [codeStore] to reach it without a fetch at
  /// all.
  static OtpHandoverRepository returningCode([String code = storedCode]) =>
      ScriptedOtpHandoverRepository(fetchResult: OtpFetchResult(code: code));

  /// Every verify is rejected as the wrong code — the ladder that ends in the
  /// escalate dialog.
  static OtpHandoverRepository rejectingSubmit() =>
      const ScriptedOtpHandoverRepository(
        submitErrorKind: OtpHandoverErrorKind.invalidOtp,
      );

  /// The verify POST never resolves, so the jeeber stays on
  /// [OtpHandoverViewMode.submitting].
  static OtpHandoverRepository stalledSubmit() =>
      const ScriptedOtpHandoverRepository(submitStalls: true);

  /// A code already on the device. `_loadHandoverCode` reads the store FIRST and
  /// returns without calling the gateway at all when it hits, which is why the
  /// code-ready state needs no fetch fixture.
  static HandoverCodeStore codeStore([String code = storedCode]) =>
      InMemoryHandoverCodeStore(code);

  // ────────────────────────────── the cubit ────────────────────────────────

  /// The cubit both hosts mount above the screen, optionally pre-driven.
  ///
  /// No `retry()` or `resendSms()` here on purpose — the constructor already
  /// starts client mode's fetch and puts jeeber mode in `ready`, so calling one
  /// would double the read and hide the mount path the screen actually ships.
  ///
  /// [drive] is fire-and-forget. It cannot be awaited (a `create:` callback is
  /// synchronous), so every state it produces lands in a microtask AFTER the
  /// first frame — which is also how the screen's own `BlocConsumer` gets to see
  /// the transition, and therefore the only way the escalate dialog can open.
  static OtpHandoverCubit cubit({
    required bool isClient,
    required OtpHandoverRepository repository,
    HandoverCodeStore? codeStore,
    Future<void> Function(OtpHandoverCubit cubit)? drive,
  }) {
    final OtpHandoverCubit cubit = OtpHandoverCubit(
      repository: repository,
      deliveryId: deliveryId,
      isClient: isClient,
      codeStore: codeStore,
    );
    if (drive != null) unawaited(drive(cubit));
    return cubit;
  }

  // ────────────────────────────── the drives ───────────────────────────────

  /// One rejected verify: the inline "Incorrect code" copy plus the attempts
  /// hint at 2 remaining.
  static Future<void> driveWrongCode(OtpHandoverCubit cubit) =>
      cubit.submitOtp(wrongCode);

  /// Three rejected verifies — the AC4 cap. Each is awaited so the cubit's
  /// re-entry guard sees `ready` again before the next call; the third flips
  /// `escalate`, which is what opens the dialog.
  static Future<void> driveToEscalation(OtpHandoverCubit cubit) async {
    for (int i = 0; i < 3; i++) {
      await cubit.submitOtp(wrongCode);
    }
  }

  /// FOUR rejected verifies, each followed by the Cancel the dialog offers.
  ///
  /// `submitOtp` returns early while `escalate` is set, so dismissing is the
  /// only way past the cap — and past it the hint counts DOWN THROUGH ZERO
  /// (`maxAttempts - wrongAttempts` is plain subtraction). This is the state
  /// `otpHandoverScreenPastTheCap` holds still.
  static Future<void> driveBeyondCap(OtpHandoverCubit cubit) async {
    for (int i = 0; i < 4; i++) {
      await cubit.submitOtp(wrongCode);
      cubit.dismissEscalate();
    }
  }

  /// The accepted verify: `success`, and the Done body.
  static Future<void> driveSuccessfulSubmit(OtpHandoverCubit cubit) =>
      cubit.submitOtp(storedCode);
}
