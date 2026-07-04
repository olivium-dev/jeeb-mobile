import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import 'super_login_picker.dart';
import 'super_login_sheet.dart';

/// Debug-only super-login entry points, RELOCATED from the registration screen
/// to the LOGIN screen (P1 owner request: surface super-login on the login
/// screen as the way in, instead of the OTP/credential funnel).
///
/// This file only LIFTS the two link affordances + their open/guard logic out
/// of `registration_screen.dart` so the login screen (the new home) shares one
/// implementation. The actual auth is unchanged — [openSuperLogin] /
/// [openSuperLoginPlus] reuse the existing [showSuperLoginSheet] +
/// [showSuperLoginPicker] (passcode-gated user list → tap → user-id-login).
///
/// SECURITY: every surface here is `kDebugMode`-gated by the host AND by
/// [SuperLoginEntryPoints] itself, so it is dead-code-eliminated from release
/// builds (mirrors the original registration placement, FR-P0-4 / defect D2).

/// Fail-loud guard. The dev super-login surfaces are unusable without a
/// SuperAdmin passcode. With the [AppConfig] debug fallback this is effectively
/// never empty in a dev build — but if a build somehow ships with neither the
/// `--dart-define` nor the fallback, surface an EXPLICIT misconfiguration
/// message instead of letting the user hit a generic gateway "Invalid user id
/// or passcode". Returns `true` when the action was blocked (caller aborts).
bool superLoginBlockedByMissingPasscode(BuildContext context) {
  if (!kDebugMode || AppConfig.superAdminPassCode.isNotEmpty) return false;
  // EXEMPT: OMDS exports no standalone snackbar/toast widget; ScaffoldMessenger
  // is the approved fleet pattern for transient feedback. kDebugMode-only path
  // (never ships).
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        key: const Key('superLogin.missingPasscode'),
        content: const Text(
          'Dev build missing SuperAdmin passcode '
          '(JEEB_SUPERADMIN_PASSCODE). Cannot super-login.',
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  return true;
}

/// Opens the FR-P0-4 credential sheet, PRE-FILLED with the dev SuperAdmin
/// passcode (+ the Nour Demo userId) so the surface is usable without typing.
/// On a server-validated success the sheet pops `true`; the host's
/// [onAuthenticated] then runs (onboarding complete → session refresh → home)
/// using the REAL tokens the sheet persisted, never a client mint.
Future<void> openSuperLogin(
  BuildContext context, {
  required Future<void> Function() onAuthenticated,
}) async {
  if (superLoginBlockedByMissingPasscode(context)) return;
  // Capture the owned SessionCubit from the CALLER's context (the login screen
  // — a modal sheet can't inherit providers above the navigator) so the sheet
  // can drive the shared real-login establishment (refresh → session emits
  // `authenticated` → notifyLogin) on success.
  final session = context.read<SessionCubit?>();
  final signedIn = await showSuperLoginSheet(
    context,
    session: session,
    initialUserId: AppConfig.devSuperLoginUserId,
    initialPasscode: AppConfig.superAdminPassCode,
  );
  if (signedIn != true || !context.mounted) return;
  await onAuthenticated();
}

/// "Super user login plus": first opens the demo-user picker, then opens the
/// SAME credential sheet pre-filled with the chosen user's userId + the single
/// real SuperAdmin passcode. The sheet POSTs this + the tapped userId to the
/// existing user-id-login path for real server validation; the post-success
/// path is identical to [openSuperLogin].
Future<void> openSuperLoginPlus(
  BuildContext context, {
  required Future<void> Function() onAuthenticated,
}) async {
  if (superLoginBlockedByMissingPasscode(context)) return;
  final session = context.read<SessionCubit?>();
  final user = await showSuperLoginPicker(context);
  if (user == null || !context.mounted) return;
  final signedIn = await showSuperLoginSheet(
    context,
    session: session,
    initialUserId: user.userId,
    initialPasscode: AppConfig.superAdminPassCode,
  );
  if (signedIn != true || !context.mounted) return;
  await onAuthenticated();
}

/// The two debug-only super-login affordances, stacked. The host gates with
/// `if (kDebugMode)`; this widget additionally renders nothing in release so the
/// surface can never reach a production user.
class SuperLoginEntryPoints extends StatelessWidget {
  const SuperLoginEntryPoints({
    super.key,
    required this.onSuperLogin,
    required this.onSuperLoginPlus,
  });

  final VoidCallback onSuperLogin;
  final VoidCallback onSuperLoginPlus;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuperLoginLink(onTap: onSuperLogin),
        const SizedBox(height: Spacing.medium),
        _SuperLoginPlusLink(onTap: onSuperLoginPlus),
      ],
    );
  }
}

/// Debug-only "Super User Login" text link that opens the credential sheet.
class _SuperLoginLink extends StatelessWidget {
  const _SuperLoginLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: '_super_login_link',
        button: true,
        label: l10n.superLoginTitle,
        child: GestureDetector(
          key: const Key('login.superLogin'),
          onTap: onTap,
          child: Text(
            l10n.superLoginTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}

/// Debug-only "Super user login plus" text link. Opens a demo-user picker that
/// pre-fills the credential sheet. Rendered next to [_SuperLoginLink].
class _SuperLoginPlusLink extends StatelessWidget {
  const _SuperLoginPlusLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: 'super_login_plus_button',
        button: true,
        label: l10n.superLoginPlusTitle,
        child: GestureDetector(
          key: const Key('login.superLoginPlus'),
          onTap: onTap,
          child: Text(
            l10n.superLoginPlusTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}
