import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
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
/// MIDNIGHT (M3-14): a re-skin, not a promotion — this is still a STUB and
/// deliberately stays one. Nothing that looks like a balance, a top-up or a
/// payment method was added; the screen says the same four sentences it always
/// did, and it still has ONE state (no network call ⇒ no loading/empty/error).
/// The board never drew it; it is DERIVED from R4 (`04-r4-wallet.png`) because
/// this is the surface the wallet chip reaches instead of R4's hub, carrying the
/// treatment `wallet_hub_screen.dart` already ships: the same two radials on the
/// same anchors (ORANGE glow top-start, PERIWINKLE wash end-side at mid-height)
/// and `animateDecor: false`.
///
/// Three pass-1 assumptions were false under Midnight and are corrected here:
/// the `h1` headline and the mark's glyph were both `colorScheme.primary`,
/// which IS `#D73B00` — a screen with no money act spending the orange budget
/// twice — and the body's "brown ink on white" reasoning describes a palette
/// §10 retired.
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
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Semantics(
      identifier: 'customer_wallet_stub',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          washPlacement: JeebFieldWashPlacement.endMid,
          animateDecor: false,
          child: SafeArea(
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
                // column; at 1.0x everything below the note stays field.
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
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: Spacing.small),
                        Text(
                          l10n.customerWalletStubBody,
                          style: context.jeebText.body.copyWith(
                            color: semantic.inkSoft,
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
                // The residual space above the footer stays field. `primary` is
                // periwinkle (theme ruling 3) — this screen has no money act.
                JeebCtaFooter.single(
                  child: Semantics(
                    identifier: 'customer_wallet_stub_done',
                    button: true,
                    container: true,
                    child: JeebCtaButton.primary(
                      label: l10n.customerWalletStubDoneCta,
                      onTap: () => _back(context),
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

/// The screen's state mark: a cash glyph in a glass disc — the kit's own disc
/// rung (`glassFillEmphasis` + 1px `glassBorder` + `onSurface` glyph, R19's fee
/// disc). Decoration only, and deliberately NOT a balance hero: a hero states a
/// number, and this screen has none to state.
class _CashMark extends StatelessWidget {
  const _CashMark();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Align(
      // Directional: the board's bands are start-aligned, never centred.
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: Sizes.fiveXLarge,
        height: Sizes.fiveXLarge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: semantic.glassFillEmphasis,
          border: Border.all(color: semantic.glassBorder),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.payments,
          size: Sizes.xLarge,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
