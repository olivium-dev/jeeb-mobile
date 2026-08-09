import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'client_home_typed_hint.dart';

/// MIDNIGHT R1's create surface: prompt, Arabic tagline and the single-line
/// capsule body that carries the frozen create id.
///
/// E1 re-homes `_request_empty_state_new_order_button` onto that same body
/// ([firstRequest]) — the empty tile draws no separate CTA button (doc-13
/// Pattern D).
///
/// [showPrompt] and [showCapsule] split it in two: the scroll body mounts the
/// prompt half, the screen pins the capsule half into the mic's thumb band.
class ClientHomeRequestHero extends StatelessWidget {
  const ClientHomeRequestHero({
    super.key,
    this.onCreateRequest,
    this.showPrompt = true,
    this.showCapsule = true,
    this.firstRequest = false,
  });

  /// Board capsule: text side 18. The 48dp interactive floor supplies the
  /// vertical air, so the padding adds none of its own.
  static const EdgeInsetsGeometry _capsulePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 18, vertical: 0);

  /// Above this effective title size the trailing chevron is dropped so the
  /// row cannot overflow at large accessibility text scales.
  static const double _chevronHideThreshold = 27;

  /// Gap under the prompt headline (board `margin:6px 0 0`).
  static const double _taglineGap = 6;

  /// Same device-clock split the greeting eyebrow uses.
  static const int _afternoonHour = 12;
  static const int _eveningHour = 17;

  /// Runs the host shell's create-request flow. Null leaves the body inert —
  /// the honest rendering of a host that has not wired one.
  final VoidCallback? onCreateRequest;

  /// Draws the "What do you need tonight?" prompt + Arabic tagline. False on
  /// the pinned half, which is capsule-only.
  final bool showPrompt;

  /// Draws the create capsule and the frozen ids it carries. False in the
  /// scroll body, which keeps the prompt only.
  final bool showCapsule;

  /// Re-homes the empty state's frozen CTA identifier onto the capsule body.
  final bool firstRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final titleSize =
        context.jeebText.titleProminent.fontSize ?? _chevronHideThreshold;
    final showChevron =
        MediaQuery.textScalerOf(context).scale(titleSize) <=
        _chevronHideThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPrompt) ...[
          Text(
            _prompt(l10n),
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
          if (showCapsule) const SizedBox(height: Spacing.medium),
        ],
        if (showCapsule)
          // Blur-free: pinned over a scrolling backdrop a BackdropFilter never
          // leaves the scene, so §4's emphasis fill + border carry it instead.
          JeebGlassCard(
            radius: JeebRadii.capsule,
            padding: _capsulePadding,
            emphasis: true,
            // Pinned over live cards, a 10% fill let "View offers" read
            // straight through the capsule; the base makes it a real surface.
            baseColor: colorScheme.surface,
            // Pinned over the nav gap, floatNav's 20dp drop would smear onto
            // the pill nav underneath.
            shadow: JeebShadows.overlay,
            child: _createBody(context, l10n, semantic, showChevron),
          ),
      ],
    );
  }

  Widget _createBody(
    BuildContext context,
    AppLocalizations l10n,
    JeebSemanticColors semantic,
    bool showChevron,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = firstRequest
        ? l10n.homeCapsuleFirstRequestTitle
        : l10n.homeCreateOrderCta;
    final titleStyle = context.jeebText.titleProminent.copyWith(
      color: colorScheme.onSurface,
    );
    Widget body = Semantics(
      // FROZEN id — jm-023:154, jm-024:45/96, flows 08/13/14/15 and
      // client_home_429_tolerant_test.dart:196 all target it.
      identifier: 'orders_create_request_button',
      button: true,
      // Label-in-name: the STABLE wording, not the rotating hint under it —
      // Voice Control cannot say a run that has already been deleted.
      label: title,
      onTap: onCreateRequest,
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCreateRequest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Row(
            children: [
              Expanded(
                // The wrapper already carries `title` as its label; leaving the
                // run a node of its own reads the same words twice — and the
                // hint rotates, so it is never the accessible name.
                child: ExcludeSemantics(
                  child: firstRequest
                      ? Text(
                          title,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : ClientHomeTypedHint(
                          examples: _hintExamples(l10n),
                          restLabel: title,
                          style: titleStyle,
                          caretColor: context.jeebRoles.accent,
                        ),
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: Spacing.xSmall),
                ExcludeSemantics(
                  child: Icon(
                    DirectionalIcons.disclosureIos(context),
                    size: 14,
                    color: semantic.mutedText,
                  ),
                ),
              ],
            ],
          ),
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

  /// What a customer can actually ask for, in their own words — the answer the
  /// static "Type it" never gave.
  List<String> _hintExamples(AppLocalizations l10n) => <String>[
    l10n.homeCreateHintExample1,
    l10n.homeCreateHintExample2,
    l10n.homeCreateHintExample3,
    l10n.homeCreateHintExample4,
    l10n.homeCreateHintExample5,
    l10n.homeCreateHintExample6,
    l10n.homeCreateHintExample7,
  ];

  /// Time-of-day prompt off the DEVICE clock, like the greeting eyebrow.
  String _prompt(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < _afternoonHour) return l10n.homeHeroPromptMorning;
    if (hour < _eveningHour) return l10n.homeHeroPromptAfternoon;
    return l10n.homeHeroPromptEvening;
  }
}
