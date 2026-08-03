import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

/// Graceful terminal screen for `/jeeber/requests/:id` when the request can
/// no longer be worked: it was cancelled, expired, or matched to another
/// jeeber (an ACCEPTED request assigned to THIS jeeber is redirected to the
/// active-delivery screen by [JeeberRequestDetailLoader] before this screen
/// is ever reached).
///
/// sprint-009 scenario matrix #8: the original sanity-build stub hard-coded
/// English copy ("Request unavailable" / "Back"), bypassing l10n/RTL, and gave
/// no forward affordance. Rebuilt on [OmdsEmptyState] with localized copy and
/// a "Browse other requests" CTA (the [onBack] edge → the request feed), so a
/// cold push tap on a dead request lands somewhere useful instead of a
/// dead-end.
class JeeberRequestUnavailableScreen extends StatelessWidget {
  const JeeberRequestUnavailableScreen({
    super.key,
    required this.requestId,
    required this.onBack,
  });

  final String requestId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          identifier: 'jeeber_request_unavailable',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The leading circle resolves to the SAME edge the CTA already
              // owns (back to the feed) — this terminal screen never had a
              // pop-able parent to return to.
              JeebTopBar.back(
                title: l10n.requestUnavailableTitle,
                identifier: 'jeeber_request_unavailable_back',
                onLeadingPressed: onBack,
              ),
              // R1: top-aligned, not vertically centred — the residual space
              // below the message is deliberate emptiness.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.large,
                    Spacing.xLarge,
                    Spacing.xLarge,
                  ),
                  child: OmdsEmptyState(
                    key: const Key('jeeber-request-unavailable-state'),
                    icon: Icons.inbox_outlined,
                    title: l10n.requestUnavailableTitle,
                    subtitle: l10n.requestNoLongerAvailable(requestId),
                  ),
                ),
              ),
              JeebCtaFooter.single(
                child: JeebCtaButton.primary(
                  key: const Key('jeeber-request-unavailable-back-cta'),
                  label: l10n.requestUnavailableBrowseCta,
                  onTap: onBack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
