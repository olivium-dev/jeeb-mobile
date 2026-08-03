import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

/// Board gutter + block rhythm (redesign-2026-08 §4.3): 24px sides, 16px above
/// the first block. No bottom padding — the residual space below the note is
/// real emptiness (R1), not a slot to fill.
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.large,
  Spacing.xLarge,
  0,
);

/// Graceful fallback rendered when `/request-summary` is reached without a
/// `RequestDraft` (e.g. a cold deep-link). Replaces a raw scaffold that carried
/// hardcoded English copy, so the AR build no longer leaks English here.
///
/// redesign-2026-08: re-skinned onto the Jeeb kit to stop reading as a
/// different product from `RequestSummaryScreen`, the surface it stands in for.
/// The Material [OMDSAppBar] became the in-body [JeebTopBar.back] that screen
/// already uses; the centred [OmdsErrorState] — a 64px `colorScheme.error`
/// glyph on a state that is empty, not failed, and the only red on a screen
/// where the accent is rationed — became a top-aligned [JeebInfoNote.muted] in
/// the 24px gutter, sitting where the request ticket would have been. Same
/// flow, same copy, same glyph, same guarded back (both bars default to
/// `maybePop`); nothing added, nothing removed.
class RequestSummaryUnavailableScreen extends StatelessWidget {
  const RequestSummaryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          identifier: 'request_summary_unavailable_root',
          // Both flags, or this node swallows the bar's own identifier.
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebTopBar.back(
                title: l10n.requestSummaryUnavailableTitle,
                // Deliberately NOT `request_summary_back`: that id belongs to
                // the populated screen, and the two never coexist but do share
                // a route.
                identifier: 'request_summary_unavailable_back',
              ),
              // Scrolls only so 200% text scale cannot overflow the fixed
              // column; at 1.0x everything below the note stays plain white.
              Expanded(
                child: SingleChildScrollView(
                  padding: _kBodyPadding,
                  child: JeebInfoNote.muted(
                    // FROZEN key — the pre-redesign hook for this state.
                    key: const Key('request-summary-unavailable-state'),
                    icon: Icons.inbox_outlined,
                    text: l10n.requestSummaryUnavailableBody,
                    identifier: 'request_summary_unavailable_note',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
