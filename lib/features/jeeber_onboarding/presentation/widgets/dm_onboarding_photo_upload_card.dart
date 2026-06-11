import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// The large tappable photo drop-area (Figma 56591:5334/5335/5336).
///
/// Empty state: near-white card, hairline border, centered plus icon. Filled
/// state: the chosen photo previews inside the same card geometry. Tapping
/// opens the camera/gallery sheet. Sized by aspect ratio so it shrinks on
/// small screens without a fixed height.
class DmOnboardingPhotoUploadCard extends StatelessWidget {
  const DmOnboardingPhotoUploadCard({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-card');

  /// 4:5 portrait card matching the Figma 392x507 drop area.
  static const double _aspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_photo_upload_area',
      button: true,
      label: l10n.dmOnboardingPhotoUploadHint,
      child: AspectRatio(
        key: rootKey,
        aspectRatio: _aspectRatio,
        child: _CardSurface(onTap: () => _openPicker(context, l10n)),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<DmOnboardingCubit>();
    // OMDS exposes generic 'photo'/'video' choice keys with camera/videocam
    // icons; this step repurposes the sheet as a photo-*source* picker, so the
    // two visible option labels are Camera and Gallery (design-spec.md §6,
    // Figma 56591:5334). The returned key is OMDS-internal, never shown:
    //   'photo' (left option, Icons.photo_camera) -> camera capture
    //   'video' (right option, Icons.videocam)    -> gallery pick
    final choice = await OmdsMediaPickerSheet.show(
      context,
      title: l10n.dmOnboardingPhotoUploadTitle,
      subtitle: l10n.dmOnboardingPhotoUploadSubtitle,
      photoLabel: l10n.dmOnboardingPhotoUploadCameraLabel,
      videoLabel: l10n.dmOnboardingPhotoUploadGalleryLabel,
    );
    if (choice == 'photo') {
      await cubit.pickFromCamera();
    } else if (choice == 'video') {
      await cubit.pickFromGallery();
    }
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.large,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: const _CardContent()),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.photo != curr.photo,
      builder: (context, state) {
        final photo = state.photo;
        if (photo == null) return const _UploadPlusIcon();
        return Image.memory(photo.bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _UploadPlusIcon extends StatelessWidget {
  const _UploadPlusIcon();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.add,
        size: Sizes.twoXLarge,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
