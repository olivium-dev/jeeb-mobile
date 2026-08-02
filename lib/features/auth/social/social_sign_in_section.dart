import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_auth_cubit.dart';
import 'social_auth_error.dart';
import 'social_auth_state.dart';
import 'social_collision_sheet.dart';
import 'social_provider.dart';
import 'social_sign_in_button.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import 'social_auth_service.dart';
import 'social_auth_token.dart';
import 'social_auth_token_store.dart';

/// Renders the social sign-in row at the top of the registration screen:
/// [Apple button (iOS-only)] [Google button].
///
/// The "— or —" divider is owned by the registration screen layout
/// (`_PhoneEntryBody._OrDivider`, keyed `registration.orDivider`), NOT here —
/// rendering one in each place produced the duplicate divider QA flagged (D4).
///
/// Reads the [SocialAuthCubit] from the surrounding context. Surfaces
/// errors as a snackbar; lets the caller decide what to do on success
/// via [onAuthenticated].
class SocialSignInSection extends StatelessWidget {
  const SocialSignInSection({super.key, this.onAuthenticated});

  /// Invoked once the cubit reaches [SocialAuthStatus.authenticated]. The
  /// session is already persisted by the time this fires.
  final ValueChanged<SocialAuthState>? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SocialAuthCubit, SocialAuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) async {
        if (state.status == SocialAuthStatus.failed && state.error != null) {
          final message = _errorCopy(state.error!, l10n);
          // EXEMPT(omds-snackbar): OMDS ships `showOmdsErrorSnackbar` for
          // display but does not expose a hide-current helper. We dedupe
          // back-to-back failures here before delegating to OMDS for the
          // actual presentation. Tracked under JEEB-58.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showOmdsErrorSnackbar(context, message: message);
          context.read<SocialAuthCubit>().clearError();
        }
        if (state.status == SocialAuthStatus.collision) {
          // D22 (JM-019): the gateway returned 409 email_collision — the social
          // email is already registered another way. Block the second method
          // with an explicit prompt (identity linking is user-management's,
          // GR-2), then reset so the buttons are tappable and the sheet does
          // not re-fire on the next rebuild.
          final cubit = context.read<SocialAuthCubit>();
          await showSocialCollisionSheet(context);
          cubit.acknowledgeCollision();
        }
        if (state.status == SocialAuthStatus.authenticated) {
          onAuthenticated?.call(state);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SocialAuthCubit>();
        final showApple = SocialSignInButton.isAppleAvailable();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showApple) ...[
              SocialSignInButton(
                key: const Key('registration.appleSignIn'),
                // Maestro/JM-018 selector for the shared social button on the
                // auth entry screen (60_W0_TEST_PLAN §2.1, jm-018-social-login).
                identifier: 'login_social_apple',
                provider: SocialProvider.apple,
                isBusy: state.isBusyFor(SocialProvider.apple),
                isEnabled: !state.isBusy,
                onTap: () => cubit.signInWith(SocialProvider.apple),
              ),
              const SizedBox(height: Spacing.small),
            ],
            SocialSignInButton(
              key: const Key('registration.googleSignIn'),
              // Maestro/JM-018 selector for the shared social button on the
              // auth entry screen (60_W0_TEST_PLAN §2.1, jm-018-social-login).
              identifier: 'login_social_google',
              provider: SocialProvider.google,
              isBusy: state.isBusyFor(SocialProvider.google),
              isEnabled: !state.isBusy,
              onTap: () => cubit.signInWith(SocialProvider.google),
            ),
          ],
        );
      },
    );
  }
}

String _errorCopy(SocialAuthError error, AppLocalizations l10n) {
  switch (error) {
    case SocialAuthError.network:
      return l10n.registrationSocialErrorNetwork;
    case SocialAuthError.invalidToken:
      return l10n.registrationSocialErrorInvalidToken;
    case SocialAuthError.accountDisabled:
      return l10n.registrationSocialErrorAccountDisabled;
    case SocialAuthError.collision:
    case SocialAuthError.cancelled:
    case SocialAuthError.unknown:
      return l10n.registrationSocialErrorGeneric;
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/auth/social_sign_in_section_preview_test.dart
// ===========================================================================
//
// Widget previews for [SocialSignInSection] — run with
// `flutter widget-preview start`.
//
// The section is a `BlocConsumer<SocialAuthCubit, SocialAuthState>`, so every
// state below is driven the way the registration screen drives it: an ambient
// [SocialAuthCubit] over inert collaborators.
// `_SocialSignInSectionCannedResultService` never touches a native SDK or Dio,
// and `_SocialSignInSectionNoopTokenStore` never touches the Keychain, so these
// previews are network- and secure-storage-free by construction — not just by
// the guard in [jeebPreviewHost].
//
// Two shapes of preview live here, because this widget has two halves:
//
// * **Seeded** (`_socialSignInSectionSeeded`) — the `builder` half. A private
//   subclass emits the designed state from its constructor, i.e. BEFORE the
//   `BlocConsumer` subscribes, so the `listener` deliberately does NOT fire.
//   Those previews are the pure button-row renderings.
// * **Live** (`_socialSignInSectionLiveOutcome`) — the `listener` half. A real
//   [SocialAuthCubit] runs its real `signInWith` over a canned result on the
//   first frame, so the D22 collision sheet and the error snackbar are
//   presented through the production code path rather than hand-placed. That is
//   the only way to see them: a seeded `failed`/`collision` state renders
//   *identically to idle*, because this section has no inline error affordance
//   of its own.
//
// The states mirror `test/social_auth_cubit_test.dart` and
// `test/social_collision_sheet_test.dart`; the previews exist so the visual
// half of that contract (RTL mirroring, 200% text, and the busy/disabled
// treatment) is reviewable without booting the app and signing in.
//
// NOTE: [SocialSignInButton.isAppleAvailable] reads `dart:io`'s `Platform`
// directly and takes no seam, so the Apple button is present in every preview
// below whenever the canvas host is iOS/macOS and absent otherwise. The
// Android rendering (Google alone) is not reachable from here.

/// The canvas box for the button row: phone width, two 48dp pills plus the
/// 12dp gap and a little slack for the 200% rendering.
const Size _socialSignInSectionRowBox = Size(390, 160);

// ─────────────────────────────────────────────────────────────────────────────
// Inert collaborators. Neither reaches the network, a native SDK, or the
// Keychain — `signIn` returns a canned result and the store forgets everything.
// ─────────────────────────────────────────────────────────────────────────────

class _SocialSignInSectionCannedResultService implements SocialAuthService {
  const _SocialSignInSectionCannedResultService(this.result);

  final SocialAuthResult result;

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async => result;

  @override
  Future<void> signOut() async {}
}

class _SocialSignInSectionNoopTokenStore implements SocialAuthTokenStore {
  const _SocialSignInSectionNoopTokenStore();

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
/// snackbar/sheet fires — see `_socialSignInSectionLiveOutcome` for those.
class _SocialSignInSectionSeededCubit extends SocialAuthCubit {
  _SocialSignInSectionSeededCubit(SocialAuthState seed)
      : super(
          service: const _SocialSignInSectionCannedResultService(
            SocialAuthFailure(SocialAuthError.cancelled),
          ),
          tokenStore: const _SocialSignInSectionNoopTokenStore(),
        ) {
    emit(seed);
  }
}

Widget _socialSignInSectionSeeded(SocialAuthState state) =>
    BlocProvider<SocialAuthCubit>(
      create: (_) => _SocialSignInSectionSeededCubit(state),
      child: const SocialSignInSection(),
    );

class _SocialSignInSectionSignInOnMount extends StatefulWidget {
  const _SocialSignInSectionSignInOnMount({required this.outcome});

  final SocialAuthResult outcome;

  @override
  State<_SocialSignInSectionSignInOnMount> createState() =>
      _SocialSignInSectionSignInOnMountState();
}

class _SocialSignInSectionSignInOnMountState
    extends State<_SocialSignInSectionSignInOnMount> {
  late final SocialAuthCubit _cubit = SocialAuthCubit(
    service: _SocialSignInSectionCannedResultService(widget.outcome),
    tokenStore: const _SocialSignInSectionNoopTokenStore(),
  );

  @override
  void initState() {
    super.initState();
    // Post-frame, because the listener pushes a route / a snackbar and needs a
    // mounted host to push onto — the same sequencing the other sheet previews
    // use (`ConfirmDeliveryActionSheet`).
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

/// Runs the production `signInWith` over [outcome] on the first frame.
///
/// The local [Navigator] is what makes this self-contained: the collision sheet
/// is a `showModalBottomSheet` and needs a navigator to push onto, and a
/// preview must not assume the canvas supplies one it may safely mutate. The
/// local [ScaffoldMessenger] does the same job for the error snackbar, which
/// the section shows through `ScaffoldMessenger.of(context)`.
Widget _socialSignInSectionLiveOutcome(SocialAuthResult outcome) => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _SocialSignInSectionSignInOnMount(outcome: outcome),
      ),
    );

/// Cold entry: nothing in flight, both providers offered.
///
/// The baseline every other state is read against — and the one where the
/// AR RTL rendering matters most, because each pill is
/// `[glyph][centred label][fixed 24dp spacer]` and only the mirrored pass shows
/// whether that trailing spacer swaps sides with the glyph.
@JeebPreview(
  group: 'auth',
  name: 'Idle · both providers',
  size: _socialSignInSectionRowBox,
)
Widget socialSignInSectionIdle() =>
    _socialSignInSectionSeeded(const SocialAuthState());

/// Google tapped: its native sheet is open / the `/v1/auth/social` exchange is
/// in flight.
///
/// Two things to review here. The busy pill replaces its whole label with a
/// single `…` — the button keeps its 48dp box but loses every readable word.
/// And the Apple pill next to it is passed `isEnabled: false`, which the
/// section honours by swapping in a no-op `onTap`: the only *visible* evidence
/// that the second provider is blocked is… none. It renders at full contrast.
@JeebPreview(
  group: 'auth',
  name: 'Google in flight',
  size: _socialSignInSectionRowBox,
)
Widget socialSignInSectionGoogleInFlight() => _socialSignInSectionSeeded(
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
@JeebPreview(
  group: 'auth',
  name: 'Apple in flight',
  size: _socialSignInSectionRowBox,
)
Widget socialSignInSectionAppleInFlight() => _socialSignInSectionSeeded(
      const SocialAuthState(
        status: SocialAuthStatus.inProgress,
        activeProvider: SocialProvider.apple,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// The listener half: outcomes that are presented, not rendered.
// ─────────────────────────────────────────────────────────────────────────────

/// D22 / JM-019: the gateway answered `409 email_collision`, so the section
/// presents the block-second-method sheet instead of an error.
///
/// Pushed through the real listener, so this is also the regression guard for
/// the re-arm bug the sheet was written around: dismissing it calls
/// `acknowledgeCollision`, which drops the cubit back to idle so the buttons
/// are tappable again and the sheet does not re-fire on the next rebuild. Tap
/// the dismiss CTA in the canvas and the row underneath must come back live.
@JeebPreview(
  group: 'auth',
  name: 'Collision · block sheet',
  size: Size(390, 640),
)
Widget socialSignInSectionCollisionSheet() => _socialSignInSectionLiveOutcome(
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
@JeebPreview(
  group: 'auth',
  name: 'Network error · snackbar',
  size: Size(390, 320),
)
Widget socialSignInSectionNetworkErrorSnackbar() =>
    _socialSignInSectionLiveOutcome(
      const SocialAuthFailure(SocialAuthError.network),
    );
