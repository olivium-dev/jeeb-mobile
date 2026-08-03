import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../../l10n/app_localizations.dart';

/// The client home's voice-first create surface (redesign-2026-08 screen 04,
/// design source `04-client-home.html` tpl 166-181).
///
/// A navy r24 card carrying the Ø56 orange mic, the "What do you need?" prompt
/// and a decorative waveform, with an off-canvas accent ring in the top-END
/// corner. It replaces the buried `+` icon button the greeting used to own —
/// the board's "the buried '+' becomes a mic-first create hero". It is still
/// exactly ONE create surface, so the 2026-07-22 single-entry-point directive
/// holds; the retired `client_home_voice_request` identifier is NOT revived.
///
/// Two tap targets, two frozen contracts:
///   * the mic (`client_home_mic_cta`) routes straight to `voice-request`;
///   * the body (`orders_create_request_button` — moved here verbatim from
///     `ClientHomeGreeting._AddRequestButton`) runs the host's create handler,
///     which is what Maestro jm-023/jm-024 and flows 08/13/14/15 tap.
///
/// The subtitle deliberately says "tap", not the board's "Hold to talk":
/// `VoiceRecordingScreen` exposes no auto-start seam, so a hold on THIS screen
/// cannot begin a recording. `onLongPress` still routes, so the gesture is not
/// dead — only the promise is honest.
class ClientHomeRequestHero extends StatelessWidget {
  const ClientHomeRequestHero({super.key, this.onCreateRequest});

  /// Board padding is 18; 16 is the nearest spacing token and lands the card on
  /// the render's measured ~88px height with the Ø56 mic inside.
  static const EdgeInsetsGeometry _cardPadding = EdgeInsetsDirectional.all(
    Spacing.medium,
  );

  /// Above this effective subtitle size the waveform is dropped so the row
  /// cannot overflow at large accessibility text scales. The mic never hides —
  /// it is the screen's primary action.
  static const double _waveformHideThreshold = 20;

  /// Runs the host shell's create-request flow. Null leaves the body inert
  /// (the mic still routes), which is the honest rendering of a host that has
  /// not wired one.
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = (Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light())
        .mutedText;
    final subtitleSize =
        context.jeebText.bodySmall.fontSize ?? _waveformHideThreshold;
    final showWaveform =
        MediaQuery.textScalerOf(context).scale(subtitleSize) <=
        _waveformHideThreshold;

    return JeebNavySurfaceCard(
      radius: OMDSBorderRadius.xl,
      padding: _cardPadding,
      shadow: JeebNavySurfaceCard.noShadow,
      rings: const <JeebNavyRing>[JeebNavyRing.heroTopEnd],
      child: Row(
        children: [
          JeebMicHero(
            size: JeebMicHero.sizeCompact,
            identifier: 'client_home_mic_cta',
            semanticLabel: l10n.homeMicLabel,
            onTap: () => _openVoiceRequest(context),
            // The gesture the board draws still works even though the copy
            // promises a tap: a hold lands on the same recording screen.
            onLongPress: () => _openVoiceRequest(context),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Semantics(
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
                      l10n.homeEmptyTitle,
                      style: context.jeebText.titleProminent.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Spacing.twoXSmall),
                    Text(
                      l10n.homeHeroSubtitle,
                      // Periwinkle is legal HERE and only here on this screen:
                      // 4.55:1 on navy. On white it fails (ruling 3).
                      style: context.jeebText.bodySmall.copyWith(
                        color: mutedText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showWaveform) ...[
            const SizedBox(width: Spacing.small),
            const ExcludeSemantics(child: JeebWaveform.onNavy()),
          ],
        ],
      ),
    );
  }

  /// Both mic gestures land on the same registered route
  /// (`app_router.dart:1059-1060`) — no router change, no invented screen.
  void _openVoiceRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('voice-request');
  }
}
