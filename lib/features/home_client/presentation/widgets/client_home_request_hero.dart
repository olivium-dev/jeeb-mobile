import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../../l10n/app_localizations.dart';

/// MIDNIGHT R1's create surface: the white prompt, the orange Arabic tagline
/// and the frosted voice capsule that carries the Ø56 mic.
///
/// Two tap targets, two frozen contracts:
///   * the mic (`client_home_mic_cta`) routes to `voice-request` on tap AND on
///     hold — the capsule promises both gestures and both work;
///   * the capsule body (`orders_create_request_button`) runs the host's create
///     handler, which is what Maestro jm-023/jm-024 and flows 08/13/14/15 tap.
///
/// E1 re-homes `_request_empty_state_new_order_button` onto that same body
/// ([firstRequest]) — the empty tile draws no separate CTA button, only this
/// capsule, so the identifier follows the affordance instead of keeping a
/// button alive that the board deleted (doc-13 Pattern D).
class ClientHomeRequestHero extends StatelessWidget {
  const ClientHomeRequestHero({
    super.key,
    this.onCreateRequest,
    this.showPrompt = true,
    this.firstRequest = false,
  });

  /// Board capsule: a leading disc inset by 10, text side 18.
  static const EdgeInsetsGeometry _capsulePadding =
      EdgeInsetsDirectional.fromSTEB(10, 10, 18, 10);

  /// Above this effective subtitle size the waveform is dropped so the row
  /// cannot overflow at large accessibility text scales. The mic never hides —
  /// it is the screen's primary action.
  static const double _waveformHideThreshold = 20;

  /// Gap under the prompt headline (board `margin:6px 0 0`).
  static const double _taglineGap = 6;

  /// Runs the host shell's create-request flow. Null leaves the body inert
  /// (the mic still routes), which is the honest rendering of a host that has
  /// not wired one.
  final VoidCallback? onCreateRequest;

  /// Draws the "What do you need tonight?" prompt + Arabic tagline above the
  /// capsule. False on the E1 composition, where the empty block owns the
  /// headline and the capsule sits under it.
  final bool showPrompt;

  /// Re-homes the empty state's frozen CTA identifier onto the capsule body.
  final bool firstRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final subtitleSize =
        context.jeebText.bodySmall.fontSize ?? _waveformHideThreshold;
    final showWaveform =
        MediaQuery.textScalerOf(context).scale(subtitleSize) <=
        _waveformHideThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPrompt) ...[
          Text(
            // TODO(midnight): l10n-queued homeHeroPromptEvening — the tile
            // draws the time-of-day form "What do you need tonight?".
            l10n.homeEmptyTitle,
            style: context.jeebText.h1.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: _taglineGap),
          Text(
            l10n.onboardingTagline,
            style: context.jeebText.titleProminent.copyWith(
              color: context.jeebRoles.accent,
            ),
            // The Arabic run shapes RTL on its own; the tile hangs it on the
            // reading-start edge under the prompt, not on the far edge.
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: Spacing.medium),
        ],
        JeebGlassCapsule(
          radius: JeebRadii.capsule,
          padding: _capsulePadding,
          child: Row(
            children: [
              JeebMicHero(
                size: JeebMicHero.sizeCompact,
                identifier: 'client_home_mic_cta',
                semanticLabel: l10n.homeMicLabel,
                onTap: () => _openVoiceRequest(context),
                onLongPress: () => _openVoiceRequest(context),
              ),
              const SizedBox(width: Spacing.small),
              Expanded(child: _createBody(context, l10n, semantic)),
              if (showWaveform) ...[
                const SizedBox(width: Spacing.small),
                const ExcludeSemantics(child: JeebWaveform.onNavy()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _createBody(
    BuildContext context,
    AppLocalizations l10n,
    JeebSemanticColors semantic,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget body = Semantics(
      // FROZEN id — jm-023:154, jm-024:45/96, flows 08/13/14/15 and
      // client_home_429_tolerant_test.dart:196 all target it.
      identifier: 'orders_create_request_button',
      button: true,
      label: l10n.homeEmptyCta,
      onTap: onCreateRequest,
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCreateRequest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // TODO(midnight): l10n-queued homeCapsuleHoldToTalk — "Hold to
              // talk" (E1: "Hold to talk — Jeeb it").
              l10n.homeMicLabel,
              style: context.jeebText.titleProminent.copyWith(
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Spacing.twoXSmall),
            Text(
              // TODO(midnight): l10n-queued homeCapsuleOrTapToType — "or tap to
              // type" (E1: "or tap to type your first request").
              l10n.homeHeroSubtitle,
              style: context.jeebText.bodySmall.copyWith(
                color: semantic.mutedText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    if (firstRequest) {
      body = Semantics(
        identifier: '_request_empty_state_new_order_button',
        button: true,
        container: true,
        explicitChildNodes: true,
        child: body,
      );
    }
    return body;
  }

  /// Both mic gestures land on the same registered route
  /// (`app_router.dart:1059-1060`) — no router change, no invented screen.
  void _openVoiceRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('voice-request');
  }
}
