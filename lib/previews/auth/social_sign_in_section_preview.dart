/// Widget previews for [SocialSignInSection] — run with
/// `flutter widget-preview start`.
///
/// The section is a `BlocConsumer<SocialAuthCubit, SocialAuthState>`, so every
/// state below is driven the way the registration screen drives it: an ambient
/// [SocialAuthCubit] over inert collaborators. `_CannedResultService` never
/// touches a native SDK or Dio, and `_NoopTokenStore` never touches the
/// Keychain, so these previews are network- and secure-storage-free by
/// construction — not just by the guard in [jeebPreviewHost].
///
/// Two shapes of preview live here, because this widget has two halves:
///
/// * **Seeded** (`_seeded`) — the `builder` half. A private subclass emits the
///   designed state from its constructor, i.e. BEFORE the `BlocConsumer`
///   subscribes, so the `listener` deliberately does NOT fire. Those previews
///   are the pure button-row renderings.
/// * **Live** (`_liveOutcome`) — the `listener` half. A real [SocialAuthCubit]
///   runs its real `signInWith` over a canned result on the first frame, so the
///   D22 collision sheet and the error snackbar are presented through the
///   production code path rather than hand-placed. That is the only way to see
///   them: a seeded `failed`/`collision` state renders *identically to idle*,
///   because this section has no inline error affordance of its own.
///
/// The states mirror `test/social_auth_cubit_test.dart` and
/// `test/social_collision_sheet_test.dart`; the previews exist so the visual
/// half of that contract (RTL mirroring, 200% text, and the busy/disabled
/// treatment) is reviewable without booting the app and signing in.
///
/// NOTE: [SocialSignInButton.isAppleAvailable] reads `dart:io`'s `Platform`
/// directly and takes no seam, so the Apple button is present in every preview
/// below whenever the canvas host is iOS/macOS and absent otherwise. The
/// Android rendering (Google alone) is not reachable from here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/social/social_auth_cubit.dart';
import '../../features/auth/social/social_auth_error.dart';
import '../../features/auth/social/social_auth_service.dart';
import '../../features/auth/social/social_auth_state.dart';
import '../../features/auth/social/social_auth_token.dart';
import '../../features/auth/social/social_auth_token_store.dart';
import '../../features/auth/social/social_provider.dart';
import '../../features/auth/social/social_sign_in_section.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for the button row: phone width, two 48dp pills plus the
/// 12dp gap and a little slack for the 200% rendering.
const Size _rowBox = Size(390, 160);

// ─────────────────────────────────────────────────────────────────────────────
// Inert collaborators. Neither reaches the network, a native SDK, or the
// Keychain — `signIn` returns a canned result and the store forgets everything.
// ─────────────────────────────────────────────────────────────────────────────

class _CannedResultService implements SocialAuthService {
  const _CannedResultService(this.result);

  final SocialAuthResult result;

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async => result;

  @override
  Future<void> signOut() async {}
}

class _NoopTokenStore implements SocialAuthTokenStore {
  const _NoopTokenStore();

  @override
  Future<void> save(SocialAuthSession session) async {}

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

/// The real cubit over inert collaborators, parked on [seed].
///
/// [SocialAuthCubit] exposes no seed seam, and `inProgress` is otherwise
/// reachable only while a native sheet is open, so emitting once from the
/// constructor is the whole implementation. Nothing is overridden: tapping a
/// button in the canvas still runs the production `signInWith`.
///
/// Emitting here happens before the `BlocConsumer` subscribes, so the seeded
/// state is the *initial* state as far as the listener is concerned and no
/// snackbar/sheet fires — see `_liveOutcome` for those.
class _SeededSocialAuthCubit extends SocialAuthCubit {
  _SeededSocialAuthCubit(SocialAuthState seed)
      : super(
          service: const _CannedResultService(
            SocialAuthFailure(SocialAuthError.cancelled),
          ),
          tokenStore: const _NoopTokenStore(),
        ) {
    emit(seed);
  }
}

Widget _seeded(SocialAuthState state) => BlocProvider<SocialAuthCubit>(
      create: (_) => _SeededSocialAuthCubit(state),
      child: const SocialSignInSection(),
    );

/// Cold entry: nothing in flight, both providers offered.
///
/// The baseline every other state is read against — and the one where the
/// AR RTL rendering matters most, because each pill is
/// `[glyph][centred label][fixed 24dp spacer]` and only the mirrored pass shows
/// whether that trailing spacer swaps sides with the glyph.
@JeebPreview(group: 'auth', name: 'Idle · both providers', size: _rowBox)
Widget socialSignInSectionIdle() => _seeded(const SocialAuthState());

/// Google tapped: its native sheet is open / the `/v1/auth/social` exchange is
/// in flight.
///
/// Two things to review here. The busy pill replaces its whole label with a
/// single `…` — the button keeps its 48dp box but loses every readable word.
/// And the Apple pill next to it is passed `isEnabled: false`, which the
/// section honours by swapping in a no-op `onTap`: the only *visible* evidence
/// that the second provider is blocked is… none. It renders at full contrast.
@JeebPreview(group: 'auth', name: 'Google in flight', size: _rowBox)
Widget socialSignInSectionGoogleInFlight() => _seeded(
      const SocialAuthState(
        status: SocialAuthStatus.inProgress,
        activeProvider: SocialProvider.google,
      ),
    );

/// The mirror image: Apple's sheet is open, so Apple collapses to `…` and
/// Google is the blocked-but-full-contrast one.
///
/// Worth its own preview because the two pills are NOT symmetric — Apple's
/// glyph is a 22dp `Icons.apple` while Google's is a 20dp coloured disc, so
/// the busy swap moves a different amount of ink on each row.
@JeebPreview(group: 'auth', name: 'Apple in flight', size: _rowBox)
Widget socialSignInSectionAppleInFlight() => _seeded(
      const SocialAuthState(
        status: SocialAuthStatus.inProgress,
        activeProvider: SocialProvider.apple,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// The listener half: outcomes that are presented, not rendered.
// ─────────────────────────────────────────────────────────────────────────────

/// Runs the production `signInWith` over [outcome] on the first frame.
///
/// The local [Navigator] is what makes this self-contained: the collision sheet
/// is a `showModalBottomSheet` and needs a navigator to push onto, and a
/// preview must not assume the canvas supplies one it may safely mutate. The
/// local [ScaffoldMessenger] does the same job for the error snackbar, which
/// the section shows through `ScaffoldMessenger.of(context)`.
Widget _liveOutcome(SocialAuthResult outcome) => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _SignInOnMount(outcome: outcome),
      ),
    );

class _SignInOnMount extends StatefulWidget {
  const _SignInOnMount({required this.outcome});

  final SocialAuthResult outcome;

  @override
  State<_SignInOnMount> createState() => _SignInOnMountState();
}

class _SignInOnMountState extends State<_SignInOnMount> {
  late final SocialAuthCubit _cubit = SocialAuthCubit(
    service: _CannedResultService(widget.outcome),
    tokenStore: const _NoopTokenStore(),
  );

  @override
  void initState() {
    super.initState();
    // Post-frame, because the listener pushes a route / a snackbar and needs a
    // mounted host to push onto — the same sequencing the other sheet previews
    // use (`confirm_delivery_action_sheet_preview.dart`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.signInWith(SocialProvider.google);
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
        child: Scaffold(
          body: SafeArea(
            child: BlocProvider<SocialAuthCubit>.value(
              value: _cubit,
              child: const SocialSignInSection(),
            ),
          ),
        ),
      );
}

/// D22 / JM-019: the gateway answered `409 email_collision`, so the section
/// presents the block-second-method sheet instead of an error.
///
/// Pushed through the real listener, so this is also the regression guard for
/// the re-arm bug the sheet was written around: dismissing it calls
/// `acknowledgeCollision`, which drops the cubit back to idle so the buttons
/// are tappable again and the sheet does not re-fire on the next rebuild. Tap
/// the dismiss CTA in the canvas and the row underneath must come back live.
@JeebPreview(group: 'auth', name: 'Collision · block sheet', size: Size(390, 640))
Widget socialSignInSectionCollisionSheet() => _liveOutcome(
      const SocialAuthFailure(SocialAuthError.collision),
    );

/// The only visual an error ever gets: a transient snackbar over the row.
///
/// `registrationSocialErrorNetwork` is the longest of the four error strings,
/// which makes this the one to read at 200% text and in Arabic — the floating
/// snackbar is a single unbounded `Text`, so if any error copy is going to
/// clip, it is this one.
///
/// The row itself is back to idle by the time the snackbar lands (the listener
/// calls `clearError()`), which is the point: there is nothing persistent left
/// behind once the snackbar times out.
@JeebPreview(group: 'auth', name: 'Network error · snackbar', size: Size(390, 320))
Widget socialSignInSectionNetworkErrorSnackbar() => _liveOutcome(
      const SocialAuthFailure(SocialAuthError.network),
    );
