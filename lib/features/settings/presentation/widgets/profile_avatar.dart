import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_avatar.dart';

/// Profile avatar with initial fallback.
///
/// redesign-2026-08: this now **wraps** the kit's [JeebAvatar] instead of
/// hand-rolling a disc — the navy fill, the white initial and the size ramp
/// all come from the kit, so the hero here matches the Ø50 disc the settings
/// identity card draws one screen up.
///
/// What it adds is the one case the kit cannot serve: a locally-picked photo.
/// JEBV4-13 stores the avatar chosen on this screen as an absolute on-device
/// path, and [JeebAvatar] composes `OmdsProfileAvatar`, whose image path is
/// network-only (`OmdsCachedImage`). Remote and absent photos are delegated
/// straight through.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.diameter = JeebAvatar.heroDiameter,
  });

  final String? name;
  final String? photoUrl;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl;
    if (photo == null || photo.isEmpty || !_isLocalPath(photo)) {
      return JeebAvatar(
        initial: name ?? '',
        diameter: diameter,
        imageUrl: photo,
      );
    }
    final placeholder = JeebAvatar(initial: name ?? '', diameter: diameter);
    return ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: Image.file(
          File(photo),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }

  static bool _isLocalPath(String value) =>
      value.startsWith('/') || value.startsWith('file://');
}
