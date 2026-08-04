import 'package:flutter/material.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';

/// The one illustration every §2.7 state in the KYC funnel draws.
///
/// `radar` because every KYC wait is a wait on the REVIEWER — the canonical
/// "waiting on someone else" — and it is the only variant that draws no
/// microphone, which a document-verification funnel must not show. `street`
/// (`kyc_rejected`'s choice) is deliberately not reused: that tile is the
/// jeeber parked at a terminal verdict, not a read in flight.
const JeebEmptyStateVariant kycStateVariant = JeebEmptyStateVariant.radar;

/// The three things the funnel actually handles, so the ring is about
/// DOCUMENTS rather than radar's default jeeber initials.
const List<JeebEmptyMedallion> kycStateMedallions = <JeebEmptyMedallion>[
  JeebEmptyMedallion(icon: Icons.badge_outlined),
  JeebEmptyMedallion(icon: Icons.face_outlined),
  JeebEmptyMedallion(icon: Icons.description_outlined),
];

/// Replaces radar's solid-orange BROADCAST core on any KYC state that draws the
/// LIT tile: nothing broadcasts in a verification queue, and that Ø58 disc is
/// the largest unbudgeted orange fill on the screen. Same glass treatment
/// `_SavedAddressStateMark` uses. Loading and error states do not need it — the
/// skeleton paints no core and the error tint IS §2.7's danger form.
class KycStateMark extends StatelessWidget {
  const KycStateMark({super.key});

  static const double _glyphSize = 26;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: semantic.glassFillEmphasis,
        border: Border.fromBorderSide(
          BorderSide(color: semantic.glassBorderStrong),
        ),
      ),
      child: Icon(
        Icons.verified_user_outlined,
        size: _glyphSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
