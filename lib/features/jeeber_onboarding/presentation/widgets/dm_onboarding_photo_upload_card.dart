import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../kyc/presentation/widgets/kyc_capture_tile.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// The large tappable photo drop-area (Figma 56591:5334/5335/5336).
///
/// MIDNIGHT (R23 carry): empty = rest glass card holding the board's DASHED
/// drop zone — no fill, the stroke carries the shape. It used to paint a solid
/// Ø64 `colorScheme.primary` slab, which under Midnight is a brand-orange block
/// on a non-CTA. Filled = the chosen photo edge-to-edge in the same geometry.
class DmOnboardingPhotoUploadCard extends StatelessWidget {
  const DmOnboardingPhotoUploadCard({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-card');

  /// 4:5 portrait card matching the Figma 392x507 drop area.
  static const double _aspectRatio = 4 / 5;

  /// The board's document-card radius (screen 22 `tpl 1308`) = [JeebRadii.lg].
  static const double _cardRadius = JeebRadii.lg;

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
        return Image.memory(
          photo.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Stub / test payloads aren't real JPEGs; fall back to the drop-zone
          // mark rather than letting the whole card throw (R23 carry).
          errorBuilder: (_, _, _) => const _UploadPrompt(),
        );
      },
    );
  }
}

/// The empty drop-area mark: R23's dashed capture zone over the localized tap
/// hint. The board's drop zone has NO fill — the dashed stroke is the shape.
class _UploadPrompt extends StatelessWidget {
  const _UploadPrompt();

  /// Matches the board's Ø64 document thumbnail.
  static const double _tileSize = Sizes.sixXLarge;

  /// R23's measured drop-zone stroke: 1.5px dashed, white ~21%.
  static const double _strokeWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: _tileSize,
            child: CustomPaint(
              painter: KycDashedBorderPainter(
                color: semantic.glassBorderVivid,
                radius: JeebRadii.md,
                strokeWidth: _strokeWidth,
              ),
              child: Center(
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: Sizes.xLarge,
                  color: theme.colorScheme.onSurface,
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
              // The live coaching line measures `inkSoft` on R23; `mutedText`
              // is reserved for the dimmed/locked rung.
              style: context.jeebText.bodySmall.copyWith(
                color: semantic.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
