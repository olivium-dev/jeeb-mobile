import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.diameter = Sizes.tenXLarge,
  });

  final String? name;
  final String? photoUrl;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = _initial(name);
    final placeholder = _InitialBubble(
      letter: letter,
      diameter: diameter,
      background: colorScheme.primaryContainer,
      foreground: colorScheme.onPrimaryContainer,
    );
    if (photoUrl == null || photoUrl!.isEmpty) {
      return placeholder;
    }
    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: _isLocalPath(photoUrl!)
            ? Image.file(
                File(photoUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            : OmdsCachedImage(
                url: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  static bool _isLocalPath(String value) =>
      value.startsWith('/') || value.startsWith('file://');

  static String _initial(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}

class _InitialBubble extends StatelessWidget {
  const _InitialBubble({
    required this.letter,
    required this.diameter,
    required this.background,
    required this.foreground,
  });

  final String letter;
  final double diameter;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Snug around the 96 dp circle, with vertical room for what the initial takes
/// at 200% text — an overflow stripe in the canvas is then a real regression,
const Size _profileAvatarBox = Size(200, 180);

/// One specimen. Mirrors the sole call site,
/// `lib/features/settings/presentation/screens/profile_edit_screen.dart:202`
Widget _profileAvatarHosted(String? name, {String? photoUrl}) =>
    ProfileAvatar(name: name, photoUrl: photoUrl);

/// The state nearly every profile is in.
/// `UserProfile.photoUrl` is null until the user runs the JEBV4-13 "Change
@JeebPreview(
  group: 'settings',
  name: 'Named, no photo',
  size: _profileAvatarBox,
)
Widget profileAvatarNamed() => _profileAvatarHosted('Sami');

/// Cold start for an OTP-only signup: no name, no photo.
/// `SettingsCubit` seeds `UserProfile.name` as null for a phone-only account
@JeebPreview(group: 'settings', name: 'No name yet', size: _profileAvatarBox)
Widget profileAvatarNoName() => _profileAvatarHosted(null);

/// An Arabic name — the majority case for this app.
/// Two things this state proves that no Latin fixture can. `toUpperCase()` is a
@JeebPreview(group: 'settings', name: 'Arabic name', size: _profileAvatarBox)
Widget profileAvatarArabicName() => _profileAvatarHosted('ليلى حداد');

/// A phone-only account as `getMe` returns it (sprint-009 §T5).
/// Jeeb mints `jeeb-<hash>` display names for OTP-only signups, and this widget
@JeebPreview(
  group: 'settings',
  name: 'Phone-only synthetic handle',
  size: _profileAvatarBox,
)
Widget profileAvatarSyntheticHandle() =>
    _profileAvatarHosted('jeeb-e1a35ea8a520');

/// `photoUrl: ''` — what a JSON payload sends for "no photo", as distinct from
/// omitting the field.
@JeebPreview(
  group: 'settings',
  name: 'Empty photo URL',
  size: _profileAvatarBox,
)
Widget profileAvatarEmptyPhotoUrl() =>
    _profileAvatarHosted('Zeina Karam', photoUrl: '');

/// JEBV4-13, one reinstall later: a stored local path whose file is gone.
/// `AppDirProfilePhotoStore` writes the avatar into the app documents directory
@JeebPreview(
  group: 'settings',
  name: 'Stale local photo path',
  size: _profileAvatarBox,
)
Widget profileAvatarStaleLocalPath() => _profileAvatarHosted(
      'Karim Aoun',
      photoUrl: '/var/mobile/Containers/Data/Application/'
          '8B4E9F2A-1C3D-4E5F-9A7B-2D6C8E0F1A3B/Documents/'
          'profile_avatar_1754136000000.jpg',
    );
