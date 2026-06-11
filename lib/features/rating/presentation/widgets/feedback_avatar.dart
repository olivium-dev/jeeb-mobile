import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Large circular avatar of the person being rated (Figma 56614:20132).
///
/// Falls back to the ratee's initial when no avatar URL is available so it
/// renders deterministically on the dev seam / in tests without a network
/// fetch.
class FeedbackAvatar extends StatelessWidget {
  const FeedbackAvatar({super.key, required this.name, this.avatarUrl});

  static const Key rootKey = Key('feedback_ratee_avatar');

  final String name;
  final String? avatarUrl;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'feedback_ratee_avatar',
      image: true,
      label: name.isEmpty ? AppLocalizations.of(context).feedbackScreenTitle : name,
      child: Center(
        key: rootKey,
        child: OmdsProfileAvatar(
          initial: _initial,
          profilePicUrl: avatarUrl,
          size: Sizes.tenXLarge,
        ),
      ),
    );
  }
}
