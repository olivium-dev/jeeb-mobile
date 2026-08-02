import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/customer_wallet_stub_screen_fixtures.dart';

/// customer-wallet stub (JEBV4-303 / F6 role-bleed).
///
/// The Jeeber wallet-hub ([WalletHubScreen], `/wallet`) is a BIDDING wallet: it
/// calls `/v1/jeeb/wallet`, `/v1/jeeb/wallet/ledger` and `/v1/jeeb/earnings`,
/// and its copy ("Top up to bid", "the customer pays YOU") only makes sense for
/// a jeeber. A pure customer (no active jeeber role) tapping the top-bar wallet
/// chip must NOT land there — it exposed jeeber-only money surfaces and an
/// Earnings-403 dead-end (role-bleed on A33).
///
/// This customer-appropriate stub is what the wallet chip routes a client to
/// instead. It performs NO network calls and explains the product truth: Jeeb is
/// cash-on-delivery, so there is no in-app balance to top up — the customer pays
/// their Jeeber directly in cash when the order arrives (D11, the same cash-only
/// invariant the offer card / receipt already state).
///
/// Semantics ids:
///   `customer_wallet_stub`      — screen root (QA target for the role-gate).
///   `customer_wallet_stub_done` — the "Got it" CTA (back to the shell).
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
          // The chip reaches this via stack-REPLACING `goNamed('customer-wallet')`,
          // so there is usually nothing to pop — fall back to the shell rather
          // than leave an empty Navigator (mirrors the wallet-hub back guard).
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/wallet/customer_wallet_stub_screen_preview_test.dart
// ===========================================================================
//
// [CustomerWalletStubScreen] has NO data axis. It takes nothing but a `key`,
// resolves nothing out of GetIt, builds no cubit and renders six fixed ARB
// strings — its own dartdoc says "It performs NO network calls". There is no
// empty / loading / error to seed and no repository to fake, so the usual
// preview question ("which state?") has to be asked differently here: the only
// inputs this screen has are the ones the WINDOW supplies. How wide, how tall,
// how much of the display the system chrome has already claimed, and how large
// the user has set their text. Those are the six states below.
//
// That also makes it network-free by construction rather than by the guard in
// [jeebPreviewHost]: there is no seam through which a Dio-backed repository
// could be reached even by accident.
//
// Two things about the hosting, both delegated to
// `lib/devtool/catalog/fixtures/customer_wallet_stub_screen_fixtures.dart` so a
// future Screen Catalog entry seeds from the same windows instead of inventing
// a second set (there is no catalog entry for this screen today):
//
// 1. The frame is pinned INSIDE the fixture — a `MediaQuery` override plus a
//    `SizedBox` — rather than left to the canvas [Size]. The canvas honours
//    `size`, but the render tests pump onto a fixed 800 x 600 surface, so a
//    state that merely ASKED for a 320 x 568 canvas would be measured at
//    800 x 600 and all six states would silently become the same widget.
//    Windows that exist for a text scale set one; the rest inherit, so
//    `matrix: true` can still render its own 200% card.
//
// 2. The screen BUILDS without a `Router` — neither `context.canPop()` call
//    happens during `build` — and then throws the moment anyone taps the back
//    button or the CTA in the canvas. The fixture host supplies a real
//    [GoRouter] seeded the way production seeds it: the screen is the only page
//    on the stack (the wallet chip arrives by stack-REPLACING
//    `goNamed('customer-wallet')`), so `canPop()` is false and both exits take
//    the `context.go('/')` fallback onto a shell stand-in.
//
// Note that this screen owns its own `Scaffold` and [jeebPreviewHost] wraps
// every child in one as well, so the canvas shows two nested Scaffolds. The
// inner one is the real surface; the outer contributes a background and a
// `SafeArea` — which is exactly why each window has to RESTORE
// `MediaQuery.padding`, or the notched states would mean nothing.
//
// What these previews surfaced in the screen — details on the states below:
//
//  * **The body has no bottom `SafeArea`, and the `ListView`'s 24 pt bottom
//    padding is smaller than a home indicator.** `app_router.dart` mounts this
//    screen as a bare top-level `GoRoute` — no `ShellRoute`, no `SafeArea` — so
//    the scroll viewport runs to the physical bottom edge of the display
//    (measured: viewport bottom == display bottom in every window). Scrolled to
//    the end, the "Got it" CTA rests `Spacing.xLarge` = 24 pt off that edge,
//    inside a 34 pt home indicator: 10 pt of the app's dismiss button sits under
//    the system gesture bar. This is arithmetic, not a font artifact, and
//    `Notched · 200% text` is the state that shows it.
//  * **The only action on the screen is inside the scroll body, not pinned.**
//    On a 390 x 844 phone at 100% nothing scrolls at all (`maxScrollExtent` 0)
//    and the CTA sits 644 pt down an 844 pt display — the state everybody
//    reviews, and the reason the rest went unnoticed. At 200% text the same
//    phone has 1210 pt of scroll and a 320 x 568 phone has 1202 pt, so the CTA
//    arrives entirely below the fold with no affordance suggesting it exists.
//  * **Below the fold it is not merely invisible, it is not BUILT.** A
//    `ListView` stops building past the viewport + cache extent, so on arrival
//    at 320 x 568 (or at 200% on any phone) `customer_wallet_stub_done` — the
//    id the screen's own dartdoc publishes as the QA target — is absent from
//    the widget tree AND from the semantics tree until the user scrolls. A
//    driver or a screen reader querying it by id finds nothing.
//  * The good news, recorded because it is cheap to lose: NOTHING overflows.
//    All six windows render clean in EN and AR, at 100% and at 200%, with no
//    `RenderFlex overflowed` in any combination — the `Expanded` inside the
//    cash-on-delivery card and the directional `EdgeInsetsDirectional` padding
//    both hold up.

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _customerWalletStubScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _customerWalletStubScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _customerWalletStubScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
///
/// The `const CustomerWalletStubScreen()` is constructed HERE rather than
/// inside the fixture host on purpose: `tool/preview_coverage.dart` credits a
/// section only when it literally builds the widget its previews are named
/// after, and it keeps the fixture library free of a circular import back into
/// this one.
Widget _customerWalletStubScreenHosted(
  CustomerWalletStubScreenWindow window,
) =>
    CustomerWalletStubScreenPreviewHost(
      window: window,
      screen: const CustomerWalletStubScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text.
///
/// Everything fits — `maxScrollExtent` is 0, so the body does not scroll and
/// the CTA sits 644 pt down an 844 pt display. Read the five states below
/// against this one; it is the only window in which this screen is the simple
/// surface it looks like.
///
/// Matrixed because the whole screen is two long paragraphs and a card, and
/// their length is what swings by locale: the AR rendering is 72 pt shorter
/// than the EN one here, and the 200% rendering is where the composition stops
/// fitting at all.
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
///
/// The CTA is already gone: `customer_wallet_stub_done` is not in the widget
/// tree on arrival, because the `ListView` never builds past the viewport plus
/// its cache extent. Nothing marks the screen as scrollable, so the only visible
/// way out is the app-bar back button.
///
/// Treat the exact scroll extent with care — `flutter_test` renders every glyph
/// as a square of the font size, which makes English roughly twice as wide as
/// Inter does, so the 200 pt of overflow measured under test is closer to
/// "fits, with about 50 pt to spare" in the real app. What is NOT a font
/// artifact is how little margin there is: this screen is within one reworded
/// sentence of overflowing a small phone at the default text size.
@JeebPreview(
  group: 'wallet',
  name: 'Compact 320 × 568',
  size: _customerWalletStubScreenCompactCanvas,
)
Widget customerWalletStubScreenCompact() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
///
/// The app bar handles the top inset correctly — the viewport starts 59 + 56 pt
/// down. The bottom is the interesting half: the scroll viewport ends at 852,
/// the physical bottom edge, because `Scaffold` does not `SafeArea` its body and
/// nothing above this screen does either. At 100% the content is short enough
/// that the CTA lands 181 pt clear of the edge and the omission costs nothing.
/// `Notched · 200% text` is the same window with the content long enough to
/// reach the bottom.
@JeebPreview(
  group: 'wallet',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _customerWalletStubScreenNotchedCanvas,
)
Widget customerWalletStubScreenNotched() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
///
/// 1210 pt of scroll behind a 788 pt viewport. A user who has doubled their
/// text size opens the wallet chip and sees an icon, a headline and the top of
/// a paragraph; the "Got it" button that dismisses the screen is three
/// screenfuls down and, again, not built until they get there.
@JeebPreview(
  group: 'wallet',
  name: 'Phone · 200% text',
  size: _customerWalletStubScreenPhoneCanvas,
)
Widget customerWalletStubScreenLargeText() => _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
///
/// 1202 pt of scroll behind a 512 pt viewport — and it holds together. No
/// overflow, no clipped card, no truncated paragraph, in either locale; the
/// composition simply becomes a long scroll. That is the useful reading here:
/// the failure mode of this screen at the ceiling is reachability, not layout.
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
///
/// Scroll to the end. The CTA's bottom edge comes to rest 24 pt off the display
/// edge — the `ListView`'s `Spacing.xLarge` bottom padding — while the home
/// indicator claims 34 pt. The last 10 pt of the button is underneath the system
/// gesture bar, where a swipe goes to the OS rather than to the app.
///
/// The fix is not in this preview: either `SafeArea(bottom: true)` around the
/// body, or `MediaQuery.paddingOf(context).bottom` added to the `ListView`'s
/// bottom padding.
@JeebPreview(
  group: 'wallet',
  name: 'Notched · 200% text',
  size: _customerWalletStubScreenNotchedCanvas,
)
Widget customerWalletStubScreenNotchedLargeText() =>
    _customerWalletStubScreenHosted(
      CustomerWalletStubScreenWindows.notchedLargeText,
    );
