import 'package:flutter/material.dart';

import '../../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../../features/biometric_auth/domain/biometric_gateway.dart';
import '../../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../../features/masked_call/application/masked_call_cubit.dart';
import '../../../features/masked_call/presentation/masked_call_button.dart';
import '../../../features/mixed_direction/presentation/mixed_direction_text.dart';
import '../../../features/offline_mode/application/offline_cubit.dart';
import '../../../features/offline_mode/presentation/offline_banner.dart';
import '../../../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import '../catalog_models.dart';

/// Batch 11 — the DT-04 mop-up pass: `biometric_auth`, `masked_call`,
/// `mixed_direction`, `offline_mode` (all four SKIPPED or partially skipped
/// across batch_01/05/06/07).
///
/// `biometric_auth` (`BiometricLockScreen`) and `masked_call`
/// (`MaskedCallButton`) and `offline_mode` (`OfflineBanner`) each resolved
/// their cubit off an AMBIENT `BlocProvider` with no local injection seam —
/// batch_01/05/07 skipped them for exactly that reason. This batch adds a
/// MINIMAL, ADDITIVE `cubit` constructor param to all three (defaults to
/// `null`, preserving the exact original ambient-provider behaviour for every
/// existing call site — see `seamsAdded` in the manifest), then renders each
/// via a local `BlocProvider.value` fed by an inline fake, with NO NETWORK.
///
/// `mixed_direction` (`MixedDirectionText`) needed no seam at all — it is a
/// pure, stateless `Text` wrapper with no cubit/repository dependency.
///
/// `background_gps` is correctly NOT present here — it has no
/// `presentation/` folder at all (pure location-capture + upload service, no
/// screen to catalog), consistent with the batch_01 finding.
List<CatalogEntry> get batch11Entries => <CatalogEntry>[
      // ─────────────────────────────────────────────────────────────────────
      // biometric_auth
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'biometric_auth',
        screen: 'BiometricLockScreen',
        states: [
          CatalogState('Locked — idle prompt', _biometricLockedIdle),
          CatalogState('Prompting (dialog in flight)', _biometricPrompting),
          CatalogState(
            'Failed — retry + password fallback',
            _biometricFailed,
          ),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // masked_call
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'masked_call',
        screen: 'MaskedCallButton',
        states: [
          CatalogState('Idle — ready to call', _maskedCallIdle),
          CatalogState('Loading — call in flight', _maskedCallLoading),
          CatalogState('Failed (snackbar shown)', _maskedCallFailed),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // mixed_direction
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'mixed_direction',
        screen: 'MixedDirectionText',
        states: [
          CatalogState('LTR (English)', _mixedDirectionLtr),
          CatalogState('RTL (Arabic)', _mixedDirectionRtl),
          CatalogState(
            'Mixed content (Arabic-led, Latin order id)',
            _mixedDirectionMixed,
          ),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // offline_mode
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'offline_mode',
        screen: 'OfflineBanner',
        states: [
          CatalogState('Offline — banner shown', _offlineBannerOffline),
          CatalogState('Online — hidden (no banner)', _offlineBannerOnline),
        ],
      ),
    ];

// ───────────────────────────────────────────────────────────────────────────
// biometric_auth
// ───────────────────────────────────────────────────────────────────────────

/// Local, no-`SharedPreferences` fake — `implements` the CONCRETE
/// [BiometricPreferenceRepositoryImpl] (Dart classes are implicit
/// interfaces), so the catalog never has to touch a real
/// `SharedPreferences.getInstance()` platform channel just to seed the "user
/// opted in" preference.
class _FakeBiometricPreference implements BiometricPreferenceRepositoryImpl {
  const _FakeBiometricPreference();

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> setEnabled(bool value) async {}
}

/// Local, no-`SharedPreferences` fake — `implements` the CONCRETE
/// [SharedPrefsPinRepository] the same way (see [_FakeBiometricPreference]).
class _FakePinRepository implements SharedPrefsPinRepository {
  const _FakePinRepository();

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<void> setPin(String pin) async {}

  @override
  Future<bool> verifyPin(String pin) async => true;
}

/// Gateway stub for the catalog — [BiometricGateway] is already an abstract
/// interface (unlike the two fakes above), so this is a plain `implements`.
class _FakeBiometricGateway implements BiometricGateway {
  const _FakeBiometricGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

/// Seeds the DESIGNED [BiometricLockState] directly via `emit` (same
/// bypass-the-async-evaluate() pattern as `_TierSelectionErrorCubit` /
/// `_SeededVoiceRecordingCubit` in batch_10): [BiometricLockCubit.evaluate] is
/// async and races the single synchronous `builder` call, so a subclass that
/// emits the exact target state deterministically is the local, no-network
/// way to preview each phase/prompt combination.
class _SeededBiometricLockCubit extends BiometricLockCubit {
  _SeededBiometricLockCubit(BiometricLockState seed)
      : super(
          preference: const _FakeBiometricPreference(),
          gateway: const _FakeBiometricGateway(),
          pinRepository: const _FakePinRepository(),
        ) {
    emit(seed);
  }
}

Widget _biometricLockedIdle(BuildContext _) => BiometricLockScreen(
      cubit: _SeededBiometricLockCubit(
        const BiometricLockState(phase: BiometricLockPhase.locked),
      ),
    );

Widget _biometricPrompting(BuildContext _) => BiometricLockScreen(
      cubit: _SeededBiometricLockCubit(
        const BiometricLockState(
          phase: BiometricLockPhase.locked,
          prompt: BiometricPromptStatus.prompting,
        ),
      ),
    );

Widget _biometricFailed(BuildContext _) => BiometricLockScreen(
      cubit: _SeededBiometricLockCubit(
        const BiometricLockState(
          phase: BiometricLockPhase.locked,
          prompt: BiometricPromptStatus.failed,
        ),
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// masked_call
// ───────────────────────────────────────────────────────────────────────────

/// Seeds a [MaskedCallState] directly via `emit` (same seeded-cubit pattern
/// as biometric_auth above) — `MaskedCallCubit.initiateCall` never actually
/// fails (its `catch` is unreachable given the shipped body), so the only
/// local way to preview the loading/error designed states is a subclass that
/// emits them.
class _SeededMaskedCallCubit extends MaskedCallCubit {
  _SeededMaskedCallCubit(MaskedCallState seed) : super() {
    emit(seed);
  }

  /// Drives a genuine POST-MOUNT transition (loading → failed) so the
  /// screen's real `BlocConsumer` listener fires and shows the designed
  /// error `SnackBar` copy — a pre-seeded initial state alone would not (a
  /// `BlocListener`/`BlocConsumer` listener only fires on transitions after
  /// the widget subscribes, never for the state it was built with).
  void simulateFailure() {
    emit(state.copyWith(isLoading: true));
    emit(
      state.copyWith(
        isLoading: false,
        error: 'Failed to initiate call: network unreachable',
      ),
    );
  }
}

Widget _maskedCallIdle(BuildContext _) =>
    const Center(child: MaskedCallButton(orderId: 'demo-order-1001'));

Widget _maskedCallLoading(BuildContext _) => Center(
      child: MaskedCallButton(
        orderId: 'demo-order-1002',
        cubit: _SeededMaskedCallCubit(const MaskedCallState(isLoading: true)),
      ),
    );

Widget _maskedCallFailed(BuildContext _) => const _MaskedCallErrorPreview();

/// Hosts [MaskedCallButton] with a seeded cubit that fires its failure
/// transition right after the first frame, so the catalog preview shows the
/// REAL designed error `SnackBar` (see [_SeededMaskedCallCubit.simulateFailure])
/// with NO network — mirrors the `_ProhibitedAcknowledgmentPreview`
/// post-frame-callback pattern already used in batch_08.
class _MaskedCallErrorPreview extends StatefulWidget {
  const _MaskedCallErrorPreview();

  @override
  State<_MaskedCallErrorPreview> createState() =>
      _MaskedCallErrorPreviewState();
}

class _MaskedCallErrorPreviewState extends State<_MaskedCallErrorPreview> {
  late final _SeededMaskedCallCubit _cubit =
      _SeededMaskedCallCubit(const MaskedCallState());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.simulateFailure();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: MaskedCallButton(
            orderId: 'demo-order-1003',
            cubit: _cubit,
          ),
        ),
      );
}

// ───────────────────────────────────────────────────────────────────────────
// mixed_direction
// ───────────────────────────────────────────────────────────────────────────

Widget _mixedDirectionLtr(BuildContext _) => const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: MixedDirectionText(
          'Pick up two bags of rice from Al Fanar market.',
        ),
      ),
    );

Widget _mixedDirectionRtl(BuildContext _) => const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: MixedDirectionText(
          'التقط كيسين من الأرز من سوق الفنار وسلمهما في المبنى 12.',
        ),
      ),
    );

Widget _mixedDirectionMixed(BuildContext _) => const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: MixedDirectionText(
          'طلب رقم JEBV4-1042 - التسليم قبل الساعة 5 مساءً',
        ),
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// offline_mode
// ───────────────────────────────────────────────────────────────────────────

Widget _offlineBannerOffline(BuildContext _) => Scaffold(
      body: Column(
        children: [
          OfflineBanner(
            cubit: OfflineCubit()
              ..setOffline()
              ..enqueuePendingSync()
              ..enqueuePendingSync(),
          ),
          const Expanded(child: Center(child: Text('Rest of screen'))),
        ],
      ),
    );

Widget _offlineBannerOnline(BuildContext _) => Scaffold(
      body: Column(
        children: [
          OfflineBanner(cubit: OfflineCubit()),
          const Expanded(
            child: Center(child: Text('Online — no banner above')),
          ),
        ],
      ),
    );
