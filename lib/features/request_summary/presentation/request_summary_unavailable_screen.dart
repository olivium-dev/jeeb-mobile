import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

/// Graceful fallback rendered when `/request-summary` is reached without a
/// `RequestDraft` (e.g. a cold deep-link).
class RequestSummaryUnavailableScreen extends StatelessWidget {
  const RequestSummaryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        animateDecor: false,
        child: SafeArea(
          child: Semantics(
            identifier: 'request_summary_unavailable_root',
            // Both flags, or this node swallows the bar's own identifier.
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title-less bar: the empty block's headline is the same
                // string, and the board never prints a screen name twice.
                const JeebTopBar.back(
                  // NOT `request_summary_back`: that id belongs to the
                  // populated screen, which shares this route.
                  identifier: 'request_summary_unavailable_back',
                ),
                // Scrolls only so 200% text scale cannot overflow the fixed
                // column; at 1.0x the block sits centred in the empty field.
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        0,
                        0,
                        0,
                        Spacing.xLarge,
                      ),
                      child: JeebEmptyState(
                        // FROZEN key — the pre-redesign hook for this state.
                        key: const Key('request-summary-unavailable-state'),
                        variant: JeebEmptyStateVariant.parcel,
                        status: JeebEmptyStateStatus.error,
                        // TODO(midnight): l10n-queued requestSummaryUnavailable
                        // Headline — this key is a screen NAME, not an absence.
                        headline: l10n.requestSummaryUnavailableTitle,
                        body: l10n.requestSummaryUnavailableBody,
                        identifier: 'request_summary_unavailable_note',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
