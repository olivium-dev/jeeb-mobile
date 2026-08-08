import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../features/support/domain/support_contact.dart';
import '../../../l10n/app_localizations.dart';
import '../application/whatsapp_top_up_launcher.dart';

/// The board gutter (24) with 16 above the first block; the docked
/// [JeebCtaFooter] owns the bottom edge, so the list keeps only enough bottom
/// inset to clear it when the content scrolls (200% text scale, long AR copy).
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.medium,
);

/// wallet-charge-info (JM-054). Static, NO-payment instructional screen
/// (D92/D93): the Jeeber charges the wallet at an authorized store, gives a
/// phone number / ID, pays cash, the balance auto-updates, and the 10% platform
/// fee per accepted offer comes from that pre-charged balance — there is NO
/// in-app payment, NO card input, NO amount field, NO store directory. The
/// three forbidden affordances (`charge_info_card_input`,
/// `charge_info_amount_field`, `charge_info_store_directory`) are intentionally
/// absent and `assertNotVisible` in the JM-054 Maestro flow; do NOT add any
/// payment/amount widget here.
///
/// This screen makes NO network call (JM-054 AC: "No network call. Mock: —").
///
/// It is the honest target of every "+ Top up" CTA across the app: wallet-hub
/// `wallet_topup_cta` (JM-053), onboarding-funding `funding_topup_cta` (JM-041),
/// kyc-pending `kyc_status_topup_cta` (JM-042), insufficient-balance
/// `insufficient_topup_cta` (JM-046). When reached standalone the back CTA
/// returns to wallet-hub; when pushed from one of those callers it pops back to
/// the caller (canPop) — the JM-054 flow asserts back → `wallet_available_balance`.
///
/// Identifier contract: 65_W2_TEST_PLAN §2/§4 JM-054. Every id below is exact.
///
/// MIDNIGHT (M3-13): a re-skin, not a rewrite — same route, same blocks in the
/// same order, same copy, every frozen identifier unmoved, and still zero
/// payment affordances. The board never drew this screen; it is DERIVED from
/// R4 (`04-r4-wallet.png`), the hub whose `+ Top up` CTA is the only way here,
/// carrying the treatment `wallet_hub_screen.dart` already ships: the same two
/// radials on the same anchors (ORANGE glow top-start, PERIWINKLE wash end-side
/// at mid-height), `animateDecor: false` (03-MOTION-NOTES §R4 records zero
/// animated elements), an in-body [JeebTopBar], a 24px gutter, the three
/// numbered rows in ONE outlined card whose kit dividers carry the sequence,
/// the two caveats as [JeebInfoNote.muted] panels, and the exit docked.
///
/// This screen has ONE state: it makes no network call, so there is no loading,
/// empty or error branch to draw.
///
/// R4's caption is explicit that the money ACT ("Top up") is the only solid
/// orange element on the wallet. This screen's only CTA is a navigation exit, so
/// it spends none — and the three numbered badges, which were filled
/// `colorScheme.primary` (which under Midnight IS `#D73B00`), are now the kit's
/// glass disc rung.
class WalletChargeInfoScreen extends StatelessWidget {
  const WalletChargeInfoScreen({
    super.key,
    this.whatsAppLauncher,
    this.accountPhoneProvider,
    this.supportWhatsAppNumberE164 = kSupportWhatsAppNumberE164,
  });

  /// F2 — injected `url_launcher` seam (mirrors `mapsUrlBuilder`); wired at
  /// the route builder, null in bare construction (existing widget tests).
  final WhatsAppLauncher? whatsAppLauncher;

  /// F2 — lazy local read of the cached account phone (`settings.profile.v1`);
  /// must never become a network fetch — this screen makes NO network call.
  final Future<String?> Function()? accountPhoneProvider;

  /// F2 release gate: defaults to [kSupportWhatsAppNumberE164] (empty = CTA
  /// hidden); overridable only so tests can render the populated state.
  final String supportWhatsAppNumberE164;

  /// The single exit this screen owns, shared by the top bar's leading circle
  /// and the body CTA so the two can never disagree.
  ///
  /// EDGE: wallet-charge-info → wallet-hub (21_NAV_PLAN §C JM-054). Standalone
  /// launch has nothing to pop → `goNamed('wallet')`; when pushed by a +Top up
  /// caller (funding / kyc-pending / insufficient) it pops back to that caller.
  /// Never pops the last page (an empty Navigator → black surface).
  static void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.goNamed('wallet');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'charge_info_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // R4's two radials, carried from the hub — separate layers, separate
        // anchors, neither animated.
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          washPlacement: JeebFieldWashPlacement.endMid,
          animateDecor: false,
          // The header is an in-body row, not a Material app bar — the shape the
          // hub, the activity list and the transaction detail all moved to, so
          // this screen carries the board's 24px gutter instead of a centred M3
          // title.
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              JeebTopBar(
                // New interactive element -> `<screen>_<element>`. The in-body
                // `charge_info_back_cta` below keeps its own id untouched (the
                // `kyc_rejected_back` / `kyc_rejected_back_cta` precedent).
                identifier: 'charge_info_back',
                title: l10n.chargeInfoTitle,
                leadingTooltip:
                    MaterialLocalizations.of(context).backButtonTooltip,
                // Mirror the body `charge_info_back_cta` destination contract:
                // pop to the caller when pushed (+Top up flows), else go to
                // wallet-hub when launched standalone.
                onLeadingPressed: () => _back(context),
              ),
              Expanded(
                child: ListView(
                  padding: _kBodyPadding,
                  children: [
                    // ── The numbered, ordered instruction steps (D92/D93
                    //    charge-at-store flow) as one outlined card: the kit's
                    //    1px inset dividers read as the sequence, and an
                    //    outlined card needs no shadow (R7/R12).
                    JeebOutlinedCard.grouped(
                      children: [
                        _Step(
                          index: 1,
                          id: 'charge_info_store_step',
                          text: l10n.chargeInfoStoreStep,
                        ),
                        _Step(
                          index: 2,
                          id: 'charge_info_identity_step',
                          text: l10n.chargeInfoIdentityStep,
                        ),
                        _Step(
                          index: 3,
                          id: 'charge_info_pay_cash_step',
                          text: l10n.chargeInfoPayCashStep,
                        ),
                      ],
                    ),

                    const SizedBox(height: Spacing.medium),

                    // ── Note 1 — balance auto-updates, no in-app payment
                    //    (D92/D93). The frozen id keeps its own wrapper; the
                    //    kit note is the panel inside it.
                    Semantics(
                      identifier: 'charge_info_auto_update_note',
                      container: true,
                      child: JeebInfoNote.muted(
                        // Filled glyphs only (R10).
                        icon: Icons.sync,
                        text: l10n.chargeInfoAutoUpdateNote,
                      ),
                    ),

                    const SizedBox(height: Spacing.xSmall),

                    // ── Note 2 — the 10% PLATFORM FEE (never "commission",
                    //    D41/D44) comes from the pre-charged balance (D1
                    //    reserve-per-offer). Copy unchanged.
                    Semantics(
                      identifier: 'charge_info_fee_note',
                      container: true,
                      child: JeebInfoNote.muted(
                        icon: Icons.percent,
                        text: l10n.chargeInfoFeeNote,
                      ),
                    ),

                    // F2 — second top-up path; release-gated: an empty number
                    // (the shipped default) hides the block entirely.
                    if (supportWhatsAppNumberE164.isNotEmpty) ...[
                      const SizedBox(height: Spacing.xSmall),
                      _WhatsAppSupportCta(
                        supportPhoneE164: supportWhatsAppNumberE164,
                        whatsAppLauncher: whatsAppLauncher,
                        accountPhoneProvider: accountPhoneProvider,
                      ),
                    ],
                  ],
                ),
              ),

              // ── The residual space above the footer stays field — the one
              //    exit docks, in the position every screen in this journey
              //    puts it. `primary` is periwinkle (theme ruling 3): the exit
              //    is navigation, not the money act R4 rations orange to.
              JeebCtaFooter.single(
                child: Semantics(
                  identifier: 'charge_info_back_cta',
                  button: true,
                  container: true,
                  child: JeebCtaButton.primary(
                    label: l10n.chargeInfoBackCta,
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

/// A single ordered instruction step: a numbered glass badge + the step copy,
/// sized to sit inside a [JeebOutlinedCard.grouped] ([JeebListRow]'s own 14/16
/// padding and 12 gap, so a step row keeps the same rhythm as every other row
/// in a grouped card across the redesign).
///
/// The kit ships no numbered badge, so this is a screen-local mark on the kit's
/// own glass-disc rung (`glassFillEmphasis` + 1px `glassBorder` + `onSurface`
/// ink — R19's fee disc). It was a solid `colorScheme.primary` disc, which pass
/// 1 read as navy and Midnight renders `#D73B00`: three orange discs on a screen
/// whose only act is "Back to wallet".
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.id, required this.text});

  final int index;
  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors glass =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Semantics(
      identifier: id,
      container: true,
      child: Padding(
        padding: JeebListRow.defaultPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Numbered badge.
            Container(
              width: Sizes.xLarge,
              height: Sizes.xLarge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: glass.glassFillEmphasis,
                border: Border.all(color: glass.glassBorder),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: context.jeebText.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Padding(
                // Nudges the first line onto the badge's optical centre.
                padding: const EdgeInsetsDirectional.only(
                  top: Spacing.twoXSmall,
                ),
                child: Text(
                  text,
                  style: context.jeebText.body.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// F2 — WhatsApp note+link (`charge_info_whatsapp_note`/`_cta`); a failed
/// hand-off shows a copyable-number fallback, never a dead tap.
class _WhatsAppSupportCta extends StatelessWidget {
  const _WhatsAppSupportCta({
    required this.supportPhoneE164,
    required this.whatsAppLauncher,
    required this.accountPhoneProvider,
  });

  final String supportPhoneE164;
  final WhatsAppLauncher? whatsAppLauncher;
  final Future<String?> Function()? accountPhoneProvider;

  Future<void> _onLink(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    String? userPhone;
    try {
      userPhone = await (accountPhoneProvider ?? (() async => null))();
    } catch (_) {
      userPhone = null;
    }
    final Uri uri = WhatsAppTopUpLink.build(
      supportPhoneE164: supportPhoneE164,
      baseMessage: l10n.chargeInfoWhatsAppMessage,
      accountPhoneSentence: (userPhone == null || userPhone.isEmpty)
          ? null
          : l10n.chargeInfoWhatsAppMessagePhoneSentence(userPhone),
    );
    bool launched;
    try {
      launched = await (whatsAppLauncher ?? (_) async => false)(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      _showFallback(context, l10n);
    }
  }

  void _showFallback(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.chargeInfoWhatsAppFallbackMessage(supportPhoneE164),
        ),
        action: SnackBarAction(
          label: l10n.chargeInfoWhatsAppCopyAction,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: supportPhoneE164));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chargeInfoWhatsAppNumberCopied)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebInfoNote.accent(
      // Filled glyph only (R10) — chat_bubble_outline is forbidden.
      icon: Icons.chat_bubble,
      text: l10n.chargeInfoWhatsAppNote,
      linkLabel: l10n.chargeInfoWhatsAppCta,
      onLink: () => _onLink(context),
      identifier: 'charge_info_whatsapp_note',
      linkIdentifier: 'charge_info_whatsapp_cta',
    );
  }
}
