import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';

/// The board gutter (24) with 16 above the first block; the docked
/// [JeebCtaFooter] owns the bottom edge, so the body keeps only enough bottom
/// inset to clear it when the copy scrolls (200% text scale, long AR copy).
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.medium,
);

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
///
/// Redesign-2026-08: a re-skin onto the Jeeb kit, not a promotion — this is
/// still a STUB and deliberately stays one. Nothing that looks like a balance,
/// a top-up or a payment method was added; the screen says the same four
/// sentences it always did. What changed is the language it says them in: the
/// Material [OMDSAppBar] became the in-body [JeebTopBar] its wallet neighbours
/// use, the centred Ø64 raw glyph + centred type became the house start-aligned
/// tonal state mark over a navy `h1` headline and brown body (the
/// `kyc_rejected_screen.dart` idiom — the board's bands are start-aligned and
/// its glyphs live inside a disc or a note, never loose), the hand-rolled grey
/// panel became [JeebInfoNote.muted], and the "Got it" CTA docks over real
/// white emptiness (R1) instead of floating at the end of the scroll.
class CustomerWalletStubScreen extends StatelessWidget {
  const CustomerWalletStubScreen({super.key});

  /// The single exit, shared by the top bar's leading circle and the CTA.
  ///
  /// The chip reaches this via stack-REPLACING `goNamed('customer-wallet')`, so
  /// there is usually nothing to pop — fall back to the shell rather than leave
  /// an empty Navigator (mirrors the wallet-hub back guard).
  static void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'customer_wallet_stub',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebTopBar(
                // New interactive element -> `<screen>_<element>`; the CTA's
                // `customer_wallet_stub_done` id is untouched.
                identifier: 'customer_wallet_stub_back',
                title: l10n.customerWalletStubTitle,
                leadingTooltip:
                    MaterialLocalizations.of(context).backButtonTooltip,
                onLeadingPressed: () => _back(context),
              ),
              // Scrolls only so 200% text scale cannot overflow the fixed
              // column; at 1.0x everything below the note stays plain white.
              Expanded(
                child: SingleChildScrollView(
                  padding: _kBodyPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CashMark(),
                      const SizedBox(height: Spacing.large),
                      Text(
                        l10n.customerWalletStubHeadline,
                        style: context.jeebText.h1.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.customerWalletStubBody,
                        // Brown is the board's secondary ink; periwinkle is
                        // forbidden as body text on white (§4.1).
                        style: context.jeebText.body.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Spacing.large),
                      // The cash-on-delivery explainer — the kit's stacked
                      // muted note (title + body), the same panel the hub uses
                      // for its KYC banner.
                      JeebInfoNote.muted(
                        // Filled glyph (R10).
                        icon: Icons.local_atm,
                        title: l10n.customerWalletStubCodTitle,
                        text: l10n.customerWalletStubCodBody,
                      ),
                    ],
                  ),
                ),
              ),
              // R1: the residual space above the footer stays plain white.
              JeebCtaFooter.single(
                child: Semantics(
                  identifier: 'customer_wallet_stub_done',
                  button: true,
                  container: true,
                  child: JeebCtaButton(
                    label: l10n.customerWalletStubDoneCta,
                    onTap: () => _back(context),
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

/// The screen's state mark: a cash glyph in a tonal disc. Decoration only — not
/// a tappable affordance, and deliberately NOT a navy hero card: a hero states
/// a number, and this screen has none to state.
class _CashMark extends StatelessWidget {
  const _CashMark();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      // Directional: the board's bands are start-aligned, never centred.
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: Sizes.fiveXLarge,
        height: Sizes.fiveXLarge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.payments,
          size: Sizes.xLarge,
          color: scheme.primary,
        ),
      ),
    );
  }
}
