import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../network/app_failure.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';
import 'app_failure_copy.dart';
import 'jeeb_cta_button.dart';
import 'jeeb_empty_state.dart';

/// The ONE way a failure owns a screen body: [failureCopy] on the error rung,
/// no Retry the user cannot win, and `<screen>_retry_cta`/`_exit_cta` derived.
class JeebFailureBlock extends StatelessWidget {
  const JeebFailureBlock({
    super.key,
    required this.failure,
    required this.identifier,
    this.onRetry,
    this.onExit,
    this.exitLabel,
    this.variant = JeebEmptyStateVariant.parcel,
    this.headlineOverride,
    this.bodyOverride,
    this.secondaryAction,
    this.retryIdentifier,
    this.exitIdentifier,
  }) : compact = false,
       assert(identifier.length > 0, 'A failure nobody can find is untestable'),
       assert(
         retryIdentifier == null || retryIdentifier.length > 0,
         'An empty CTA identifier is an unfindable node — pass null instead.',
       ),
       assert(
         exitIdentifier == null || exitIdentifier.length > 0,
         'An empty CTA identifier is an unfindable node — pass null instead.',
       );

  /// The inline density — a failure inside a card or a form section, not one
  /// that owns the screen.
  const JeebFailureBlock.compact({
    super.key,
    required this.failure,
    required this.identifier,
    this.onRetry,
    this.onExit,
    this.exitLabel,
    this.variant = JeebEmptyStateVariant.parcel,
    this.headlineOverride,
    this.bodyOverride,
    this.secondaryAction,
    this.retryIdentifier,
    this.exitIdentifier,
  }) : compact = true,
       assert(identifier.length > 0, 'A failure nobody can find is untestable'),
       assert(
         retryIdentifier == null || retryIdentifier.length > 0,
         'An empty CTA identifier is an unfindable node — pass null instead.',
       ),
       assert(
         exitIdentifier == null || exitIdentifier.length > 0,
         'An empty CTA identifier is an unfindable node — pass null instead.',
       );

  /// The classified failure. Its `cause` is never rendered.
  final AppFailure failure;

  /// `<screen>_error`.
  final String identifier;

  /// Retries the read. Ignored when the failure is not retryable.
  final VoidCallback? onRetry;

  /// The way out when retrying cannot help — sign in, go back, contact
  /// support. Rendered as the primary pill.
  final VoidCallback? onExit;

  /// Overrides the exit label; defaults to the copy family's action.
  final String? exitLabel;

  /// Illustration; follows the subject of the screen.
  final JeebEmptyStateVariant variant;

  /// Replaces the copy family's title — for a per-`typeSuffix` line.
  final String? headlineOverride;

  /// Replaces the copy family's body — for a per-`typeSuffix` line.
  final String? bodyOverride;

  /// A quieter act under the CTA.
  final Widget? secondaryAction;

  /// Overrides the derived `<screen>_retry_cta` — for a screen whose retry id
  /// was already bound by an existing test or a shared list row.
  final String? retryIdentifier;

  /// Overrides the derived `<screen>_exit_cta`.
  final String? exitIdentifier;

  /// True for [JeebFailureBlock.compact].
  final bool compact;

  /// `<screen>` — [identifier] with its `_error` suffix removed.
  String get screenId => identifier.endsWith('_error')
      ? identifier.substring(0, identifier.length - '_error'.length)
      : identifier;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FailureCopy copy = failureCopy(l10n, failure);
    final bool canRetry = copy.retryable && onRetry != null;

    final Widget? action = canRetry
        ? JeebCtaButton.outline(
            label: copy.action,
            leadingIcon: Icons.refresh,
            expand: false,
            identifier: retryIdentifier ?? '${screenId}_retry_cta',
            onTap: onRetry,
          )
        : onExit == null
        ? null
        : JeebCtaButton.primary(
            label: exitLabel ?? copy.action,
            expand: false,
            identifier: exitIdentifier ?? '${screenId}_exit_cta',
            onTap: onExit,
          );

    if (compact) {
      return JeebEmptyState.compact(
        headline: headlineOverride ?? copy.title,
        body: bodyOverride ?? copy.body,
        variant: variant,
        reason: JeebEmptyStateReason.failed,
        identifier: identifier,
        headlineIdentifier: '${screenId}_error_headline',
        bodyIdentifier: '${screenId}_error_body',
        action: action,
        secondaryAction: secondaryAction,
      );
    }
    return JeebEmptyState(
      headline: headlineOverride ?? copy.title,
      body: bodyOverride ?? copy.body,
      variant: variant,
      reason: JeebEmptyStateReason.failed,
      identifier: identifier,
      headlineIdentifier: '${screenId}_error_headline',
      bodyIdentifier: '${screenId}_error_body',
      action: action,
      secondaryAction: secondaryAction,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// Phone box tall enough for the illustration, both lines and a CTA.
const Size _jeebFailureBlockBox = Size(390, 620);

/// Shorter box for the inline density.
const Size _jeebFailureBlockCompactBox = Size(390, 420);

/// Hosts [child] under a caption naming the failure kind under review.
Widget _jeebFailureBlockHosted(String caption, Widget child) =>
    SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Text(caption), child],
      ),
    );

/// The commonest failure, and the one whose copy is allowed to blame the
/// connection.
@JeebPreview(
  group: 'core',
  name: 'Network (retry)',
  size: _jeebFailureBlockBox,
  matrix: true,
)
Widget jeebFailureBlockNetwork() => _jeebFailureBlockHosted(
  'Network (retry)',
  JeebFailureBlock(
    failure: const NetworkFailure(offline: true),
    identifier: 'preview_error',
    onRetry: () {},
  ),
);

/// Transport exists or is unknown, but the destination cannot be reached.
@JeebPreview(
  group: 'core',
  name: 'Unreachable host (retry)',
  size: _jeebFailureBlockBox,
  matrix: true,
)
Widget jeebFailureBlockUnreachable() => _jeebFailureBlockHosted(
  'Unreachable host (retry)',
  JeebFailureBlock(
    failure: const NetworkFailure(reason: NetworkFailureReason.hostLookup),
    identifier: 'preview_error',
    onRetry: () {},
  ),
);

/// 5xx: retryable, but the copy must not say "server".
@JeebPreview(group: 'core', name: 'Server 500 (retry)', size: _jeebFailureBlockBox)
Widget jeebFailureBlockServer() => _jeebFailureBlockHosted(
  'Server 500 (retry)',
  JeebFailureBlock(
    failure: const ServerFailure(status: 500),
    identifier: 'preview_error',
    onRetry: () {},
  ),
);

/// The unrecoverable case: an expired session gets a sign-in exit, never a
/// Retry that cannot win.
@JeebPreview(
  group: 'core',
  name: 'Session expired (exit)',
  size: _jeebFailureBlockBox,
)
Widget jeebFailureBlockSessionExpired() => _jeebFailureBlockHosted(
  'Session expired (exit)',
  JeebFailureBlock(
    failure: const UnauthorizedFailure(),
    identifier: 'preview_error',
    onRetry: () {},
    onExit: () {},
  ),
);

/// 404 with no exit wired: no CTA at all beats a dead one.
@JeebPreview(group: 'core', name: 'Not found (no CTA)', size: _jeebFailureBlockBox)
Widget jeebFailureBlockNotFound() => _jeebFailureBlockHosted(
  'Not found (no CTA)',
  const JeebFailureBlock(
    failure: NotFoundFailure(),
    identifier: 'preview_error',
  ),
);

/// 429 carrying `Retry-After` — the plural set renders the countdown.
@JeebPreview(group: 'core', name: 'Rate limited (30s)', size: _jeebFailureBlockBox)
Widget jeebFailureBlockRateLimited() => _jeebFailureBlockHosted(
  'Rate limited (30s)',
  JeebFailureBlock(
    failure: const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
    identifier: 'preview_error',
    onRetry: () {},
  ),
);

/// The inline density, for a failure inside a card.
@JeebPreview(
  group: 'core',
  name: 'Compact (inline)',
  size: _jeebFailureBlockCompactBox,
)
Widget jeebFailureBlockCompact() => _jeebFailureBlockHosted(
  'Compact (inline)',
  JeebFailureBlock.compact(
    failure: const TimeoutFailure(phase: DioExceptionType.receiveTimeout),
    identifier: 'preview_error',
    onRetry: () {},
  ),
);
