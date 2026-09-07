import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../dev_flags.dart';
import '../../diagnostics/diag.dart';
import '../../network/app_failure.dart';
import '../../network/network_reachability_signals.dart';
import '../../theme/jeeb_color_roles.dart';
import 'app_failure_copy.dart';

/// The Material default, kept explicit because [SnackBar.persist] is derived
/// from `action != null` and would otherwise make every retryable snack eternal.
const Duration kJeebSnackDuration = Duration(seconds: 4);

/// Long enough to read the line and reach Retry; still bounded (F6).
const Duration kJeebSnackActionDuration = Duration(seconds: 8);

/// Development proof builds may stretch the lifetime; product defaults stay put.
Duration get jeebSnackActionDuration =>
    kDevAffordancesAllowed && kDevSnackActionMsOverride > 0
    ? const Duration(milliseconds: kDevSnackActionMsOverride)
    : kJeebSnackActionDuration;

final Expando<_SnackLifetime> _currentSnacks = Expando<_SnackLifetime>();

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
  final Duration life =
      duration ?? (hasAction ? jeebSnackActionDuration : kJeebSnackDuration);
  _currentSnacks[messenger]?.cancel();
  messenger.clearSnackBars();
  final lifetime = _SnackLifetime(messenger, clearOnReconnect, () {
    Diag.event('snack_shown', <String, Object?>{
      'identifier': identifier,
      'hasAction': hasAction,
      'clearOnReconnect': clearOnReconnect,
      'durationMs': life.inMilliseconds,
    });
  });
  _currentSnacks[messenger] = lifetime;
  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: background,
          // Flutter derives `persist` from `action != null`, and a persisting
          // snack is never timed out at all (scaffold.dart 617-624).
          persist: false,
          duration: life,
          content: _SnackContent(
            lifetime: lifetime,
            child: Semantics(
              identifier: identifier,
              liveRegion: true,
              container: true,
              child: Text(
                text,
                style: (base ?? const TextStyle()).copyWith(color: ink),
              ),
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
                  onPressed: () {
                    lifetime.cancel();
                    onAction();
                  },
                ),
        ),
      );
  lifetime.controller = controller;
  unawaited(
    controller.closed.then((SnackBarClosedReason reason) {
      lifetime.cancel();
      final shownAt = lifetime.shownAt;
      if (shownAt == null) return;
      Diag.event('snack_closed', <String, Object?>{
        'identifier': identifier,
        'reason': lifetime.retiredByReconnect ? 'reconnect' : reason.name,
        'elapsedMs': DateTime.now().difference(shownAt).inMilliseconds,
      });
    }),
  );
}

class _SnackLifetime {
  _SnackLifetime(this.messenger, this.clearOnReconnect, this.onShown);

  final ScaffoldMessengerState messenger;
  final bool clearOnReconnect;
  final VoidCallback onShown;
  DateTime? shownAt;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;
  StreamSubscription<void>? _reconnected;
  Animation<double>? _animation;
  int _mounts = 0;
  bool _cancelled = false;
  bool retiredByReconnect = false;

  void attach(Animation<double>? animation) {
    _mounts++;
    _animation = animation;
    if (shownAt == null) {
      shownAt = DateTime.now();
      onShown();
    }
    if (_cancelled || !clearOnReconnect || _reconnected != null) return;
    _reconnected = NetworkReachabilitySignals.instance.stream.listen((void _) {
      if (_cancelled || !messenger.mounted) return;
      final status = _animation?.status;
      // An exit already in flight keeps its original timeout/action/hide cause.
      if (status == AnimationStatus.reverse ||
          status == AnimationStatus.dismissed) {
        cancel();
        return;
      }
      retiredByReconnect = true;
      cancel();
      controller.close();
    });
  }

  void detach() {
    if (--_mounts == 0) cancel();
  }

  void cancel() {
    _cancelled = true;
    unawaited(_reconnected?.cancel());
    _reconnected = null;
    if (identical(_currentSnacks[messenger], this)) {
      _currentSnacks[messenger] = null;
    }
  }
}

// A messenger can disappear without completing controller.closed.
// Tie its reconnect subscription to the displayed content as well.
class _SnackContent extends StatefulWidget {
  const _SnackContent({required this.lifetime, required this.child});

  final _SnackLifetime lifetime;
  final Widget child;

  @override
  State<_SnackContent> createState() => _SnackContentState();
}

class _SnackContentState extends State<_SnackContent> {
  @override
  void initState() {
    super.initState();
    widget.lifetime.attach(
      context.findAncestorWidgetOfExactType<SnackBar>()?.animation,
    );
  }

  @override
  void dispose() {
    widget.lifetime.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
