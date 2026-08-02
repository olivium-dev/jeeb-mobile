import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/customer_wallet_stub_screen_fixtures.dart';

class CustomerWalletStubScreen extends StatelessWidget {
  const CustomerWalletStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'customer_wallet_stub',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.customerWalletStubTitle,
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
              Icons.payments_outlined,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.customerWalletStubHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.customerWalletStubBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.large),
            Container(
              padding: const EdgeInsets.all(Spacing.medium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: OmdsBorderRadius.uiMedium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.local_atm_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.customerWalletStubCodTitle,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: Spacing.twoXSmall),
                        Text(
                          l10n.customerWalletStubCodBody,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xLarge),
            Semantics(
              identifier: 'customer_wallet_stub_done',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.customerWalletStubDoneCta,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
const Size _customerWalletStubScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _customerWalletStubScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _customerWalletStubScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
/// The `const CustomerWalletStubScreen()` is constructed HERE rather than
Widget _customerWalletStubScreenHosted(
  CustomerWalletStubScreenWindow window,
) =>
    CustomerWalletStubScreenPreviewHost(
      window: window,
      screen: const CustomerWalletStubScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text.
/// Everything fits — `maxScrollExtent` is 0, so the body does not scroll and
@JeebPreview(
  group: 'wallet',
  name: 'Phone 390 × 844',
  size: _customerWalletStubScreenPhoneCanvas,
  matrix: true,
)
Widget customerWalletStubScreenPhone() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
/// The CTA is already gone: `customer_wallet_stub_done` is not in the widget
@JeebPreview(
  group: 'wallet',
  name: 'Compact 320 × 568',
  size: _customerWalletStubScreenCompactCanvas,
)
Widget customerWalletStubScreenCompact() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
/// The app bar handles the top inset correctly — the viewport starts 59 + 56 pt
@JeebPreview(
  group: 'wallet',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _customerWalletStubScreenNotchedCanvas,
)
Widget customerWalletStubScreenNotched() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
/// 1210 pt of scroll behind a 788 pt viewport. A user who has doubled their
@JeebPreview(
  group: 'wallet',
  name: 'Phone · 200% text',
  size: _customerWalletStubScreenPhoneCanvas,
)
Widget customerWalletStubScreenLargeText() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
/// 1202 pt of scroll behind a 512 pt viewport — and it holds together. No
@JeebPreview(
  group: 'wallet',
  name: 'Compact · 200% text',
  size: _customerWalletStubScreenCompactCanvas,
)
Widget customerWalletStubScreenCompactLargeText() =>
    _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.compactLargeText,
    );

/// The one combination where the missing bottom inset is visible rather than
/// latent: a device with a home indicator, and content long enough to scroll.
@JeebPreview(
  group: 'wallet',
  name: 'Notched · 200% text',
  size: _customerWalletStubScreenNotchedCanvas,
)
Widget customerWalletStubScreenNotchedLargeText() =>
    _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.notchedLargeText,
    );
