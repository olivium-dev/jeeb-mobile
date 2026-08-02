import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Large circular avatar of the person being rated (Figma 56614:20132).
/// Falls back to the ratee's initial when no avatar URL is available so it
/// renders deterministically on the dev seam / in tests without a network
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, and tall enough to frame the 96 dp circle plus the room the
/// initial takes at 200% text — an overflow stripe in the canvas is a real
const Size _feedbackAvatarBox = Size(390, 160);

/// One specimen. Mirrors the call site at
/// `lib/features/rating/presentation/rating_screen.dart:226`
Widget _feedbackAvatarHosted(String name, {String? avatarUrl}) =>
    FeedbackAvatar(name: name, avatarUrl: avatarUrl);

/// The happy path: a named ratee with no photo on file.
/// Renders the uppercased first letter on the primary container fill — 'R' for
@JeebPreview(group: 'rating', name: 'Named ratee', size: _feedbackAvatarBox)
Widget feedbackAvatarNamed() => _feedbackAvatarHosted('Rami Chidiac');

/// The route default, not an edge case.
/// `RatingScreen.rateeName` defaults to `''` and the `/orders/:id/feedback`
@JeebPreview(
  group: 'rating',
  name: 'No name (route default)',
  size: _feedbackAvatarBox,
)
Widget feedbackAvatarNoName() => _feedbackAvatarHosted('');

/// An Arabic ratee name — the majority case for this app.
/// Two things this state proves that the Latin states cannot. `toUpperCase()`
@JeebPreview(group: 'rating', name: 'Arabic name', size: _feedbackAvatarBox)
Widget feedbackAvatarArabicName() => _feedbackAvatarHosted('ليلى حداد');

/// A phone-only account, as `getMe` returns it (sprint-009 §T5).
/// Jeeb mints `jeeb-<hash>` display names for OTP-only signups, and this widget
@JeebPreview(
  group: 'rating',
  name: 'Phone-only synthetic handle',
  size: _feedbackAvatarBox,
)
Widget feedbackAvatarSyntheticHandle() =>
    _feedbackAvatarHosted('jeeb-e1a35ea8a520');

/// TRIPWIRE: a name whose first letter is a multi-code-unit grapheme — here the
/// decomposed (NFD) Arabic 'آ', an alef `ا` carrying a maddah `ٓ`,
@JeebPreview(
  group: 'rating',
  name: 'Decomposed first letter',
  size: _feedbackAvatarBox,
)
Widget feedbackAvatarDecomposedName() => _feedbackAvatarHosted('ا\u0653منة');

/// `avatarUrl: ''` — what the gateway sends for "no photo", as distinct from
/// omitting the field.
@JeebPreview(
  group: 'rating',
  name: 'Empty avatar URL',
  size: _feedbackAvatarBox,
)
Widget feedbackAvatarEmptyUrl() =>
    _feedbackAvatarHosted('Zeina Karam', avatarUrl: '');
