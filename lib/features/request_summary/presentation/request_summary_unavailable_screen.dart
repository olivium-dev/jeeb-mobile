import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

/// Graceful fallback rendered when `/request-summary` is reached without a
/// `RequestDraft` (e.g. a cold deep-link).
///
/// MIDNIGHT: this is the route's EMPTY state, so it ships the `JeebEmptyState`
/// family (master-plan §2.7) on the same `content` field the populated screen
/// mounts — same flow, same copy, same guarded back. The frozen
/// `request-summary-unavailable-state` Key and the three identifiers are
/// re-homed onto the drawn block; the `JeebInfoNote` chrome that only existed to
/// host them is gone.
class RequestSummaryUnavailableScreen extends StatelessWidget {
  const RequestSummaryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
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
                  // Deliberately NOT `request_summary_back`: that id belongs to
                  // the populated screen, and the two never coexist but do share
                  // a route.
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
                        variant: JeebEmptyStateVariant.pocket,
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
