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

import '../../../core/previews/jeeb_preview.dart';
import 'social_auth_service.dart';
import 'social_auth_token.dart';
import 'social_auth_token_store.dart';

class SocialSignInSection extends StatelessWidget {
  const SocialSignInSection({super.key, this.onAuthenticated});

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
          // EXEMPT: OMDS shows error but no hide-current helper; dedupe back-to-back.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showOmdsErrorSnackbar(context, message: message);
          context.read<SocialAuthCubit>().clearError();
        }
        if (state.status == SocialAuthStatus.collision) {
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
// DEV-ONLY, NOT SHIPPED.

/// The canvas box for the button row: phone width, two 48dp pills plus the
/// 12dp gap and a little slack for the 200% rendering.
const Size _socialSignInSectionRowBox = Size(390, 160);

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
/// [SocialAuthCubit] exposes no seed seam, and `inProgress` is otherwise
/// reachable only while a native sheet is open, so emitting once from the
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
/// The local [Navigator] is what makes this self-contained: the collision sheet
Widget _socialSignInSectionLiveOutcome(SocialAuthResult outcome) => Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _SocialSignInSectionSignInOnMount(outcome: outcome),
      ),
    );

/// Cold entry: nothing in flight, both providers offered.
/// The baseline every other state is read against — and the one where the
@JeebPreview(
  group: 'auth',
  name: 'Idle · both providers',
  size: _socialSignInSectionRowBox,
)
Widget socialSignInSectionIdle() =>
    _socialSignInSectionSeeded(const SocialAuthState());

/// Google tapped: its native sheet is open / the `/v1/auth/social` exchange is
/// in flight.
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

/// D22 / JM-019: the gateway answered `409 email_collision`, so the section
/// presents the block-second-method sheet instead of an error.
@JeebPreview(
  group: 'auth',
  name: 'Collision · block sheet',
  size: Size(390, 640),
)
Widget socialSignInSectionCollisionSheet() => _socialSignInSectionLiveOutcome(
      const SocialAuthFailure(SocialAuthError.collision),
    );

/// The only visual an error ever gets: a transient snackbar over the row.
/// `registrationSocialErrorNetwork` is the longest of the four error strings,
@JeebPreview(
  group: 'auth',
  name: 'Network error · snackbar',
  size: Size(390, 320),
)
Widget socialSignInSectionNetworkErrorSnackbar() =>
    _socialSignInSectionLiveOutcome(
      const SocialAuthFailure(SocialAuthError.network),
    );
