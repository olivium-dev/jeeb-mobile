import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

/// State 1 of the Jeeber home (Figma node 56614:18920 — "Delivery screen,
/// User not registered as delivery man"): the user has not yet completed the
/// delivery-man registration.
///
/// Visual (redesign-2026-08): the shared `JeeberHomeGreeting` band → a centred
/// accent-tinted hero disc → the `h1` headline → a muted subtitle → the docked
/// `JeebCtaFooter` carrying the navy "Register now" pill. The illustration is
/// still a themed placeholder until the branded scooter asset ships through
/// `omds-flutter`; it is now painted from the sanctioned orange tokens
/// (12% tint + 30% ring) instead of an ad-hoc `tertiary` alpha, so the accent
/// stays rationed to the glyph and its halo.
///
/// `onRegister` is wired to the host's delivery-man onboarding route — the home
/// screen itself stays route-agnostic per the existing `onOpenFeedRequest`
/// pattern. Closes the JEEB-66 hardcoded-string debt: all copy is now keyed in
/// `app_en.arb` + `app_ar.arb`.
class JeeberUnregisteredView extends StatelessWidget {
  const JeeberUnregisteredView({
    super.key,
    required this.onRegister,
    this.profileName,
    this.ctaIdentifier,
  });

  static const Key rootKey = Key('jeeber-unregistered-view-root');
  static const Key registerButtonKey =
      Key('jeeber-unregistered-view-register');

  /// Tapped when the Jeeber taps the primary "Register now" CTA.
  final VoidCallback onRegister;

  /// Optional profile display name passed through to the greeting.
  final String? profileName;

  /// JM-036: optional additional Semantics identifier wrapped around the
  /// "Register now" CTA, in addition to the W0 `jeeber_unregistered_register_button`.
  /// The DELIVERY-tab gate (`dashboard_tab.dart`) passes `delivery_register_now_cta`
  /// (65_W2_TEST_PLAN §2) so the JM-036 flow can tap the prompt's CTA by its
  /// coined screen id while screen-19's flow keeps using the widget id. Null
  /// for non-gate callers (e.g. the dev-seam capture path) — the CTA then
  /// carries only the W0 id.
  final String? ctaIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      container: true,
      // explicitChildNodes makes this identified container a NON-merging
      // boundary so the nested `jeeber_unregistered_register_button` (and any
      // other identified descendant) surfaces as its own queryable
      // SemanticsNode instead of being folded into the root. Without it,
      // `container: true` still merges the subtree's semantics into this node
      // and the CTA identifier is swallowed (CAP-3 / same pattern as 8b81dc1
      // fixed for screens 16/17/22/26/27).
      explicitChildNodes: true,
      identifier: 'jeeber_unregistered_root',
      child: SafeArea(
        child: Column(
          children: [
            JeeberHomeGreeting(name: profileName),
            const Expanded(child: _UnregisteredHero()),
            // The footer owns the board's 24px gutters + 32px bottom inset, so
            // no trailing spacer is needed below it.
            _UnregisteredCta(
              onRegister: onRegister,
              extraIdentifier: ctaIdentifier,
            ),
          ],
        ),
      ),
    );
  }
}

/// The upsell hero is the same "Empty ≠ dead" block the rest of the jeeber home
/// draws: E3's night street — the parked scooter waiting to be ridden is
/// literally what this screen is asking the user to become. The CTA stays in
/// the docked footer (its two frozen ids live there), so the block passes none.
class _UnregisteredHero extends StatelessWidget {
  const _UnregisteredHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: JeebEmptyState(
              identifier: 'jeeber_unregistered_empty_state',
              variant: JeebEmptyStateVariant.street,
              headline: l10n.jeeberRegisterTitle,
              body: l10n.jeeberRegisterSubtitle,
              // TODO(midnight): l10n-queued — `jeeberRegisterStreetSemantic`;
              // this key still describes the retired scooter-from-phone glyph.
              semanticLabel: l10n.jeeberRegisterHeroSemantic,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnregisteredCta extends StatelessWidget {
  const _UnregisteredCta({required this.onRegister, this.extraIdentifier});

  final VoidCallback onRegister;

  /// JM-036: when set, the CTA is additionally wrapped in a Semantics node
  /// carrying this identifier (`delivery_register_now_cta`) so the DELIVERY-tab
  /// gate flow can tap the same button by the coined screen id. The inner
  /// `jeeber_unregistered_register_button` node stays queryable because the
  /// root view sets `explicitChildNodes: true`.
  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget cta = Semantics(
      identifier: 'jeeber_unregistered_register_button',
      button: true,
      child: JeebCtaButton.primary(
        key: JeeberUnregisteredView.registerButtonKey,
        label: l10n.jeeberRegisterCta,
        onTap: onRegister,
      ),
    );
    final extraId = extraIdentifier;
    if (extraId != null) {
      cta = Semantics(
        identifier: extraId,
        button: true,
        explicitChildNodes: true,
        child: cta,
      );
    }
    return JeebCtaFooter.single(child: cta);
  }
}
