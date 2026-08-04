import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/request_summary_cubit.dart';

/// The 20px broadcast glyph on the CTA (`dc-tpl 624`).
const double _ctaIconSize = 20;

/// Docked broadcast CTA plus the free-to-cancel reassurance line.
///
/// Sits below the scroll area, never inside it: the board's lower half is
/// deliberately empty and the CTA must stay reachable at every text scale.
/// MIDNIGHT: the tile's caption names this "the lone solid-orange act", so the
/// pill spends the orange budget and carries `JeebShadows.ctaOrange`.
class BroadcastFooter extends StatelessWidget {
  const BroadcastFooter({required this.isSubmitting, super.key});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.midnight())
            .mutedText;

    return JeebCtaFooter.single(
      spacing: Spacing.small,
      below: Text(
        l10n.requestSummaryCancelNote,
        textAlign: TextAlign.center,
        style: context.jeebText.bodySmall.copyWith(color: mutedInk),
      ),
      // The id and the Key are frozen contracts (Maestro + the route test), so
      // they are re-homed verbatim onto the new CTA rather than regenerated.
      child: Semantics(
        identifier: 'request_summary_submit',
        button: true,
        child: JeebCtaButton.accent(
          key: const Key('request_summary.submit'),
          label: l10n.requestSummaryBroadcastCta,
          // Board draws this pill's label at w700; the shared `button` rung
          // is w600.
          labelStyle: context.jeebText.button.copyWith(
            fontWeight: FontWeight.w700,
          ),
          leadingIcon: Icons.wifi_tethering,
          iconSize: _ctaIconSize,
          height: JeebCtaButton.primaryHeightTall,
          isLoading: isSubmitting,
          onTap: () => context.read<RequestSummaryCubit>().submit(),
        ),
      ),
    );
  }
}
