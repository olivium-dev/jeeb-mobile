import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_register_prompt_screen_fixtures.dart';

class DeliveryRegisterPromptScreen extends StatelessWidget {
  const DeliveryRegisterPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_register_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.offerKycGateTitle,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(
              Icons.delivery_dining_outlined,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.offerKycGateHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.offerKycGateBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'delivery_register_prompt_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.gateStartKycCta,
                onTap: () => context.goNamed('jeeber-onboarding'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'delivery_register_prompt_back',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Text(l10n.gateBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _deliveryRegisterPromptScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _deliveryRegisterPromptScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _deliveryRegisterPromptScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window, on one of two stacks —
/// see the fixture.
Widget _deliveryRegisterPromptScreenHosted(
  DeliveryRegisterPromptScreenWindow window, {
  bool poppable = false,
}) =>
    DeliveryRegisterPromptScreenPreviewHost(
      window: window,
      poppable: poppable,
      screen: const DeliveryRegisterPromptScreen(),
    );

/// The reference reading, and the production stack: an ordinary phone, no
/// system chrome, default text, nothing underneath to pop.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Phone 390 × 844',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
  matrix: true,
)
Widget deliveryRegisterPromptScreenPhone() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
/// Still fits — the icon, headline and one-sentence body leave room for both
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Compact 320 × 568',
  size: _deliveryRegisterPromptScreenCompactCanvas,
)
Widget deliveryRegisterPromptScreenCompact() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
/// The app bar handles the top inset correctly — the viewport starts 59 + 56 pt
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _deliveryRegisterPromptScreenNotchedCanvas,
)
Widget deliveryRegisterPromptScreenNotched() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.notched,
    );

/// The accessibility ceiling on an ORDINARY phone — the same window the matrix
/// above renders as its third card, pinned here so the render suite asserts it.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Phone · 200% text',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
)
Widget deliveryRegisterPromptScreenLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
/// It holds together — no overflow, nothing clipped, in either locale; the
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Compact · 200% text',
  size: _deliveryRegisterPromptScreenCompactCanvas,
)
Widget deliveryRegisterPromptScreenCompactLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.compactLargeText,
    );

/// The one combination where the missing bottom inset is visible rather than
/// latent: a device with a home indicator, and content long enough to scroll.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Notched · 200% text',
  size: _deliveryRegisterPromptScreenNotchedCanvas,
)
Widget deliveryRegisterPromptScreenNotchedLargeText() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.notchedLargeText,
    );

/// The same phone as the reference reading, with the offer-KYC gate underneath
/// it — the stack no shipped caller actually produces.
@JeebPreview(
  group: 'offer_kyc_gate',
  name: 'Pushed from the gate',
  size: _deliveryRegisterPromptScreenPhoneCanvas,
)
Widget deliveryRegisterPromptScreenPushed() =>
    _deliveryRegisterPromptScreenHosted(
      DeliveryRegisterPromptScreenWindows.phonePushed,
      poppable: true,
    );
