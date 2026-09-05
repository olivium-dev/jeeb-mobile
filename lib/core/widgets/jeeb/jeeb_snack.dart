import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../network/app_failure.dart';
import '../../network/network_reachability_signals.dart';
import '../../theme/jeeb_color_roles.dart';
import 'app_failure_copy.dart';

/// The Material default, kept explicit because [SnackBar.persist] is derived
/// from `action != null` and would otherwise make every retryable snack eternal.
const Duration kJeebSnackDuration = Duration(seconds: 4);

/// Long enough to read the line and reach Retry; still bounded (F6).
const Duration kJeebSnackActionDuration = Duration(seconds: 8);

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
  bool? clearOnReconnect,
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
    clearOnReconnect:
        clearOnReconnect ??
        (failure != null && failureBlamesConnectivity(failure)),
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
  bool clearOnReconnect = false,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final TextStyle? base = Theme.of(context).snackBarTheme.contentTextStyle;
  final bool hasAction = actionLabel != null && onAction != null;
  messenger.hideCurrentSnackBar();
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: background,
          // Flutter derives `persist` from `action != null`, and a persisting
          // snack is never timed out at all (scaffold.dart 617-624).
          persist: false,
          duration:
              duration ??
              (hasAction ? kJeebSnackActionDuration : kJeebSnackDuration),
          content: Semantics(
            identifier: identifier,
            liveRegion: true,
            container: true,
            child: Text(
              text,
              style: (base ?? const TextStyle()).copyWith(color: ink),
            ),
          ),
          action: !hasAction
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
  if (!clearOnReconnect) return;
  bool settled = false;
  late final StreamSubscription<void> reconnected;
  reconnected = NetworkReachabilitySignals.instance.stream.listen((void _) {
    if (settled) return;
    settled = true;
    // `controller.close()` and not `hideCurrentSnackBar()`: a later snack must
    // survive the reconnect that retires this one.
    controller.close();
  });
  unawaited(
    controller.closed.whenComplete(() {
      settled = true;
      unawaited(reconnected.cancel());
    }),
  );
}
