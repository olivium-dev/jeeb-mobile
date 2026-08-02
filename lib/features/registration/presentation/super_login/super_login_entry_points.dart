import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import 'super_login_picker.dart';
import 'super_login_sheet.dart';

/// Debug-only entry points; kDebugMode-gated, dead-code-eliminated from release.
bool superLoginBlockedByMissingPasscode(BuildContext context) {
  if (!kDebugMode || AppConfig.superAdminPassCode.isNotEmpty) return false;
  // EXEMPT: OMDS exports no standalone snackbar; ScaffoldMessenger is approved pattern.
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

Future<void> openSuperLogin(
  BuildContext context, {
  required Future<void> Function() onAuthenticated,
}) async {
  if (superLoginBlockedByMissingPasscode(context)) return;
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
