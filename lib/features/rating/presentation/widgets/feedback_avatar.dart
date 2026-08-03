import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../l10n/app_localizations.dart';

/// Large circular avatar of the person being rated (Figma 56614:20132).
///
/// redesign-24: composes the kit [JeebAvatar.hero] (Ø74 disc + the Ø26 corner
/// mark) so this legacy `/feedback` terminal reads as the same screen family as
/// `MutualRatingScreen`, which draws the identical hero. The badge is a
/// COMPLETION mark, never "verified" — on the jeeber leg the ratee is a
/// customer with no KYC.
///
/// Falls back to the ratee's initial when no avatar URL is available so it
/// renders deterministically on the dev seam / in tests without a network
/// fetch — [JeebAvatar.initialFrom] normalises a full name to that letter.
class FeedbackAvatar extends StatelessWidget {
  const FeedbackAvatar({super.key, required this.name, this.avatarUrl});

  static const Key rootKey = Key('feedback_ratee_avatar');

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    // The kit avatar is deliberately given no identifier/semanticLabel of its
    // own: this wrapper is the frozen node, and a second one would double it.
    return Semantics(
      identifier: 'feedback_ratee_avatar',
      image: true,
      label: name.isEmpty ? AppLocalizations.of(context).feedbackScreenTitle : name,
      child: Center(
        key: rootKey,
        child: JeebAvatar.hero(
          initial: name,
          imageUrl: avatarUrl,
          badge: JeebAvatarBadge.completed,
        ),
      ),
    );
  }
}
