import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Profile avatar with initial fallback.
///
/// Lifted out of [ProfileEditScreen] so the avatar stays inside the
/// 20-line-function ceiling required by the OMDS lint rules. When [photoUrl]
/// is null we fall back to the first character of [name] (or `?` if the
/// user has not set a name yet) rendered on a circular OMDS card.
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
            // JEBV4-13: a locally-picked avatar (profile-edit "Change avatar")
            // is stored as an absolute on-device path — render it from the
            // file; OmdsCachedImage is network-only.
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
