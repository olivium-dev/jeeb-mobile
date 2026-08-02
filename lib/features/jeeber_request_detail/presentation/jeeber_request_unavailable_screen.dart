import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/jeeber_request_unavailable_screen_fixtures.dart';

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
      appBar: OMDSAppBar(title: l10n.requestUnavailableTitle),
      body: SafeArea(
        child: Semantics(
          identifier: 'jeeber_request_unavailable',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.large),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OmdsEmptyState(
                    key: const Key('jeeber-request-unavailable-state'),
                    icon: Icons.inbox_outlined,
                    title: l10n.requestUnavailableTitle,
                    subtitle: l10n.requestNoLongerAvailable(requestId),
                  ),
                  const SizedBox(height: Spacing.large),
                  OmdsPrimaryButton(
                    key: const Key('jeeber-request-unavailable-back-cta'),
                    text: l10n.requestUnavailableBrowseCta,
                    onTap: onBack,
                  ),
                ],
              ),
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
int jeeberRequestUnavailableScreenBrowseTaps = 0;

/// Resets [jeeberRequestUnavailableScreenBrowseTaps]; the counter is top-level,
/// so one test's taps would otherwise leak into the next.
void jeeberRequestUnavailableScreenResetTaps() =>
    jeeberRequestUnavailableScreenBrowseTaps = 0;

/// Builds the screen for [fixture] and hands it to the shared host.
/// The `JeeberRequestUnavailableScreen(...)` is constructed HERE rather than
Widget _jeeberRequestUnavailableScreenHosted(
  JeeberRequestUnavailableScreenFixture fixture,
) =>
    JeeberRequestUnavailableScreenPreviewHost(
      fixture: fixture,
      screen: JeeberRequestUnavailableScreen(
        requestId: fixture.requestId,
        onBack: () => jeeberRequestUnavailableScreenBrowseTaps++,
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
