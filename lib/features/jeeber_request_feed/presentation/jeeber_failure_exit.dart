import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../l10n/app_localizations.dart';

/// What `JeebFailureBlock` needs for its exit pill: the act, and the word for
/// it when the copy family's own action word would lie.
typedef JeeberFailureExit = ({VoidCallback? onExit, String? label});

/// R6: an unrecoverable kind gets a way out, never a dead block. Forbidden is
/// the live KYC-pending 403; a vanished row leaves by the back stack.
JeeberFailureExit jeeberFailureExit(
  BuildContext context,
  AppFailure failure,
  AppLocalizations l10n, {
  Future<void> Function()? onReload,
}) {
  if (failure is ForbiddenFailure) {
    return (
      onExit: () => GoRouter.maybeOf(context)?.goNamed('offer-kyc-gate'),
      label: l10n.gateStartKycCta,
    );
  }
  if (failure is NotFoundFailure || failure is GoneFailure) {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      return (onExit: () => router.pop(), label: null);
    }
    // Nothing to pop back to (a tab body): re-reading is the only way out.
    if (onReload != null) {
      return (onExit: () => unawaited(onReload()), label: l10n.actionRetry);
    }
  }
  return (onExit: null, label: null);
}
