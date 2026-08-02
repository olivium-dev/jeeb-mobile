import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
