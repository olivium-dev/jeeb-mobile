import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/network/app_failure.dart';
import '../../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// F44 — the pinned order strip's failure stand-in. A vanished strip reads as
/// an order that never had one, and silently costs the user price and status.
class OrderChatSummaryUnavailableStrip extends StatelessWidget {
  const OrderChatSummaryUnavailableStrip({
    super.key,
    required this.failure,
    this.onRetry,
    this.identifier = 'order_chat_summary_unavailable',
    this.retryIdentifier = 'order_chat_summary_retry',
  });

  /// The classified failure. Its `cause` is never rendered.
  final AppFailure failure;

  /// Re-reads the summary. Null renders the notice with no CTA rather than an
  /// inert button.
  final VoidCallback? onRetry;

  final String identifier;

  final String retryIdentifier;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FailureCopy copy = failureCopy(l10n, failure);
    // Only a retryable failure gets a Retry the user can win.
    final bool canRetry = copy.retryable && onRetry != null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.xSmall,
        Spacing.medium,
        Spacing.xSmall,
      ),
      child: Semantics(
        identifier: identifier,
        container: true,
        liveRegion: true,
        explicitChildNodes: true,
        child: JeebInfoNote.error(
          icon: Icons.receipt_long_outlined,
          text: l10n.orderChatSummaryUnavailableBody,
          trailing: canRetry
              ? JeebCtaButton.text(
                  label: l10n.orderChatSummaryRetry,
                  expand: false,
                  identifier: retryIdentifier,
                  onTap: onRetry,
                )
              : null,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED: preview canvas + preview tests only.

/// Phone width, with headroom for the EN 200% text-scale wrap.
const Size _orderChatSummaryUnavailableStripBox = Size(390, 220);

Widget _orderChatSummaryUnavailableStripHosted(
  AppFailure failure, {
  bool retry = true,
}) =>
    OrderChatSummaryUnavailableStrip(
      failure: failure,
      onRetry: retry ? () {} : null,
    );

/// The commonest case: the summary read timed out, and reloading can win.
@JeebPreview(
  group: 'chat',
  name: 'Summary unavailable · retry',
  size: _orderChatSummaryUnavailableStripBox,
  matrix: true,
)
Widget orderChatSummaryUnavailableStripRetryable() =>
    _orderChatSummaryUnavailableStripHosted(
      const ServerFailure(status: 503),
    );

/// Offline: same strip, same CTA — the copy family is what changes.
@JeebPreview(
  group: 'chat',
  name: 'Summary unavailable · offline',
  size: _orderChatSummaryUnavailableStripBox,
)
Widget orderChatSummaryUnavailableStripOffline() =>
    _orderChatSummaryUnavailableStripHosted(
      const NetworkFailure(offline: true),
    );

/// Unrecoverable (403): no CTA at all beats a Retry the user cannot win.
@JeebPreview(
  group: 'chat',
  name: 'Summary unavailable · no retry',
  size: _orderChatSummaryUnavailableStripBox,
)
Widget orderChatSummaryUnavailableStripUnrecoverable() =>
    _orderChatSummaryUnavailableStripHosted(
      const ForbiddenFailure(),
      retry: false,
    );
