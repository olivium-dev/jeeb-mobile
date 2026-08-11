import 'package:flutter/material.dart';

import '../../../core/formatting/friendly_reference.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_request_unavailable_screen_fixtures.dart';

/// The request-detail route's dead end: a push tap landed on a request that is
/// gone, and the only forward edge is back to the feed.
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
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topStart,
        animateDecor: false,
        child: SafeArea(
          child: Semantics(
            identifier: 'jeeber_request_unavailable',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title-less: the empty block's headline is the same string,
                // and the leading circle resolves to the CTA's own edge.
                JeebTopBar.back(
                  identifier: 'jeeber_request_unavailable_back',
                  onLeadingPressed: onBack,
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: JeebEmptyState(
                        key: const Key('jeeber-request-unavailable-state'),
                        variant: JeebEmptyStateVariant.parcel,
                        status: JeebEmptyStateStatus.error,
                        headline: l10n.requestUnavailableTitle,
                        // sprint-009 §T5: never echo the raw route UUID at the
                        // jeeber — the short ref the detail card renders.
                        body: l10n.requestNoLongerAvailable(
                          friendlyReference(requestId),
                        ),
                      ),
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
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a phone frame plus the fixture's outline and caption.
const Size _jeeberRequestUnavailableScreenPhoneCanvas = Size(402, 888);

/// The same, for the smallest supported display.
const Size _jeeberRequestUnavailableScreenCompactCanvas = Size(332, 612);

/// Taps on the "Browse other requests" CTA.
/// A dead end whose only forward affordance does nothing reviews nothing, and
int _jeeberRequestUnavailableScreenBrowseTaps = 0;

/// Builds the screen for [fixture] and hands it to the shared host.
/// The `JeeberRequestUnavailableScreen(...)` is constructed HERE rather than
Widget _jeeberRequestUnavailableScreenHosted(
  JeeberRequestUnavailableScreenFixture fixture,
) =>
    JeeberRequestUnavailableScreenPreviewHost(
      fixture: fixture,
      screen: JeeberRequestUnavailableScreen(
        requestId: fixture.requestId,
        onBack: () => _jeeberRequestUnavailableScreenBrowseTaps++,
      ),
    );

/// The Screen Catalog's state, framed as a phone: the short, human-sized id,
/// default text, and a page underneath so the app bar has a back arrow.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · short id',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenPhoneShortId() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.phoneShortId,
    );

/// What a cold push tap on a dead request actually produces: the raw 36-character
/// route id in the sentence, and nothing underneath to pop back to.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Cold push tap · raw UUID',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget jeeberRequestUnavailableScreenPushDeadEnd() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.pushDeadEnd,
    );

/// The smallest display the app supports, carrying the id the shipped route
/// hands over.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568',
  size: _jeeberRequestUnavailableScreenCompactCanvas,
)
Widget jeeberRequestUnavailableScreenCompact() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.compact,
    );

/// The accessibility ceiling on an ORDINARY phone — 200% text on 390 x 844.
/// **This card overflows in English, and the stripes you see are real.** The
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Phone · 200% text',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenLargeText() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.phoneLargeText,
    );

/// The worst case the app supports, and one a cold push tap can really produce:
/// the smallest display, the largest text, and a stack with nothing to pop.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact · 200% text',
  size: _jeeberRequestUnavailableScreenCompactCanvas,
)
Widget jeeberRequestUnavailableScreenCompactLargeText() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.compactLargeText,
    );

/// The router's `?? ''` fallback, rendered.
/// `app_router.dart:1284` is `state.pathParameters['id'] ?? ''`, and the id goes
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Blank id',
  size: _jeeberRequestUnavailableScreenPhoneCanvas,
)
Widget jeeberRequestUnavailableScreenBlankId() =>
    _jeeberRequestUnavailableScreenHosted(
      JeeberRequestUnavailableScreenFixtures.blankId,
    );
