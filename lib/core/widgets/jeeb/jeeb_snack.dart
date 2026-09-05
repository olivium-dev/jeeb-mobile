import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../network/app_failure.dart';
import '../../theme/jeeb_color_roles.dart';
import 'app_failure_copy.dart';

/// The ONE transient failure surface: replaces `showOmdsErrorSnackbar` (2.79:1,
/// an AA failure) with the errorContainer pair, and is the only one with Retry.
void showJeebErrorSnack(
  BuildContext context, {
  required String identifier,
  AppFailure? failure,
  String? message,
  String? retryLabel,
  VoidCallback? onRetry,
  Duration? duration,
}) {
  assert(
    (failure == null) != (message == null),
    'Pass exactly one of failure or message.',
  );
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final String text = message ?? failureCopy(l10n, failure!).body;

  _show(
    context,
    identifier: identifier,
    text: text,
    // Explicit: the SnackBarTheme hard-codes surfaceHigh/ink, which carries no
    // failure signal at all.
    background: scheme.errorContainer,
    ink: scheme.onErrorContainer,
    actionLabel: onRetry == null ? null : (retryLabel ?? l10n.actionRetry),
    onAction: onRetry,
    duration: duration,
  );
}

/// The neutral notice — the themed surface, no role colour.
void showJeebSnack(
  BuildContext context, {
  required String message,
  required String identifier,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  _show(
    context,
    identifier: identifier,
    text: message,
    background: scheme.surfaceContainerHigh,
    ink: scheme.onSurface,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

/// The success notice — the semantic success pair, never raw `Colors.green`.
void showJeebSuccessSnack(
  BuildContext context, {
  required String message,
  required String identifier,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final JeebRoles roles = context.jeebRoles;
  _show(
    context,
    identifier: identifier,
    text: message,
    background: roles.successContainer,
    ink: roles.onSuccessContainer,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

void _show(
  BuildContext context, {
  required String identifier,
  required String text,
  required Color background,
  required Color ink,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final TextStyle? base = Theme.of(context).snackBarTheme.contentTextStyle;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        duration: duration ?? const Duration(seconds: 4),
        content: Semantics(
          identifier: identifier,
          liveRegion: true,
          container: true,
          child: Text(
            text,
            style: (base ?? const TextStyle()).copyWith(color: ink),
          ),
        ),
        action: actionLabel == null || onAction == null
            ? null
            // SnackBar.action is typed SnackBarAction, so it cannot carry a
            // Semantics identifier; the key is the findable handle instead.
            : SnackBarAction(
                key: Key('${identifier}_retry_cta'),
                label: actionLabel,
                textColor: ink,
                onPressed: onAction,
              ),
      ),
    );
}
