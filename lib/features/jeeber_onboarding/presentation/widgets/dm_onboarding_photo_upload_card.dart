import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// The large tappable photo drop-area (Figma 56591:5334/5335/5336).
///
/// Empty state: the kit's outlined card (white fill, 1.5px warm-brown stroke,
/// no shadow — outline-over-shadow) holding the board's navy capture tile over
/// the "tap to add" line. Filled state: the chosen photo previews edge-to-edge
/// inside the same card geometry. Tapping opens the camera/gallery sheet. Sized
/// by aspect ratio so it shrinks on small screens without a fixed height.
class DmOnboardingPhotoUploadCard extends StatelessWidget {
  const DmOnboardingPhotoUploadCard({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-card');

  /// 4:5 portrait card matching the Figma 392x507 drop area.
  static const double _aspectRatio = 4 / 5;

  /// The board's document-card radius (screen 22 `tpl 1308`).
  static const double _cardRadius = 18;

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
        child: JeebOutlinedCard(
          radius: _cardRadius,
          // The preview fills the card; the 1.5px stroke is border-box
          // corrected by the kit, so the photo sits just inside the outline.
          padding: EdgeInsetsDirectional.zero,
          onTap: () => _openPicker(context, l10n),
          child: const _CardContent(),
        ),
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

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.photo != curr.photo,
      builder: (context, state) {
        final photo = state.photo;
        if (photo == null) return const _UploadPrompt();
        return Image.memory(photo.bytes, fit: BoxFit.cover);
      },
    );
  }
}

/// The empty drop-area mark: the board's navy capture tile (screen 22's
/// document thumbnail vocabulary) over the localized tap hint.
class _UploadPrompt extends StatelessWidget {
  const _UploadPrompt();

  /// Matches the board's Ø64 document thumbnail.
  static const double _tileSize = Sizes.sixXLarge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: OmdsBorderRadius.medium,
            ),
            child: SizedBox.square(
              dimension: _tileSize,
              child: Center(
                child: Icon(
                  Icons.photo_camera,
                  size: Sizes.xLarge,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.small),
          // The enclosing `dm_onboarding_photo_upload_area` node already
          // announces this exact string as its label — showing it must not
          // make it read twice.
          ExcludeSemantics(
            child: Text(
              l10n.dmOnboardingPhotoUploadHint,
              textAlign: TextAlign.center,
              style: context.jeebText.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
