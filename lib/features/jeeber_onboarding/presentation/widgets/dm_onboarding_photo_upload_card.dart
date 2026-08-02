import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../../photo_attachment/domain/photo_attachment.dart';
import '../../domain/dm_onboarding_gateway.dart';

class DmOnboardingPhotoUploadCard extends StatelessWidget {
  const DmOnboardingPhotoUploadCard({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-card');

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

/// Phone width the onboarding wizard is designed against (Figma 56591:5323).
const double _dmOnboardingPhotoUploadCardPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _dmOnboardingPhotoUploadCardCompactPhoneWidth = 320;

/// The card's own 4:5 ratio, restated here so a preview can name the box it
/// produces without reaching into the widget.
const double _dmOnboardingPhotoUploadCardRatio = 4 / 5;

/// The width the photo step actually gives the card: the device width less the
/// wizard's shared gutters (`DmOnboardingStepLayout`'s `Spacing.xLarge` pair).
double _dmOnboardingPhotoUploadCardColumnWidth(double deviceWidth) =>
    deviceWidth - 2 * Spacing.xLarge;

/// Canvas box for a full-width card: 427.5pt of card plus the caption.
const Size _dmOnboardingPhotoUploadCardPhoneBox = Size(390, 480);

/// Canvas box for the compact-device rendering — the card is only 340pt tall.
const Size _dmOnboardingPhotoUploadCardCompactBox = Size(320, 390);

/// Canvas box for the height-bounded host, sized to the 180pt bound it imposes.
const Size _dmOnboardingPhotoUploadCardBoundedBox = Size(390, 240);

/// 80×100 — a 4:5 portrait, the exact ratio the card is cut for.
final Uint8List dmOnboardingPhotoUploadCardPortraitBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAFAAAABkCAIAAACemCBBAAAA4UlEQVR42u3csQ0CQQwE'
  'wC+HIqiE6ogpgpiEIoi/AyI6APRnn/7tkbaBCW/XuuX9PLfKAgxcGPx4rSUDDAwMDAwM'
  '3A283q/fUwT80zlBPg+8QZthngHeTM1gp4NDtIHmXHCgNsqcCA7XhpiBg8BJ2nFzCjhV'
  'O2gGBt6hdsQMDAwMDAwMDAx8HLDHA3A9cLvGQ4nXA9yul+64PHTcljquh0334Y4XAI5a'
  'gIGBgYGB/wOfLreSAQYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYG3gvY'
  '78PAwIfLB4OvkLb3HerSAAAAAElFTkSuQmCC',
);

/// 160×90 — a 16:9 landscape, five wide vertical bands. What a Jeeber gets by
/// holding the phone sideways, which most people do.
final Uint8List dmOnboardingPhotoUploadCardLandscapeBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAKAAAABaCAIAAACwpMoFAAAA/klEQVR42u3RMRGAMBAA'
  'wdj4JiKoaSjABg0ikBMlyEADJQ09Kr5IZmdOwW2JqBq4YgFg9Qx8r0tqb5tS+54zta3t'
  'qc3HlRpgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBg'
  'wIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYM'
  'GDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwIAB'
  'AwYMGDBgwIABAwYMGDBgwIABAwYMGDBgwL0DR1QNHGDA6rkfzCIYCzHPp1sAAAAASUVO'
  'RK5CYII=',
);

/// 24×30 — a 4:5 thumbnail. Correct ratio, ~14× under the width it is drawn at.
final Uint8List dmOnboardingPhotoUploadCardLowResBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABgAAAAeCAIAAAC5TEmyAAAAMElEQVR42mO45upIEH04'
  'YUMQMYwaNGrQqEEj1SCbnhOE0YI8gmjUoFGDRg0aqQYBAMbeVcUBkVWwAAAAAElFTkSu'
  'QmCC',
);

/// Wraps [bytes] the way the cubit does after a successful pick, including the
/// monotonic id shape (`dm-onboarding-photo-<n>`) it generates.
PhotoAttachment _dmOnboardingPhotoUploadCardCapture(
  Uint8List bytes,
  PhotoSource source,
) =>
    PhotoAttachment(
      id: 'dm-onboarding-photo-0',
      bytes: bytes,
      originalSizeBytes: 2 * 1024 * 1024,
      source: source,
    );

// ---------------------------------------------------------------------------

/// Declared because [DmOnboardingGateway] declares it. Deliberately empty
/// rather than network-backed — nothing on the photo step calls `submit`
/// anyway (only the service-area step does).
class _DmOnboardingPhotoUploadCardGateway implements DmOnboardingGateway {
  @override
  Future<void> submit(DmOnboardingSubmission submission) async {}
}

class _DmOnboardingPhotoUploadCardCubit extends DmOnboardingCubit {
  _DmOnboardingPhotoUploadCardCubit(PhotoAttachment? photo)
      : super(
          pickerService: StubPhotoPickerService(
            cameraPayload: dmOnboardingPhotoUploadCardPortraitBytes,
            galleryPayload: dmOnboardingPhotoUploadCardLandscapeBytes,
          ),
          gateway: _DmOnboardingPhotoUploadCardGateway(),
        ) {
    if (photo != null) emit(state.copyWith(photo: photo));
  }
}

// ---------------------------------------------------------------------------

Widget _dmOnboardingPhotoUploadCardMeasured(String caption, Widget child) =>
    Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

Widget _dmOnboardingPhotoUploadCardStepGeometry(
  double deviceWidth, {
  double? boundedHeight,
}) {
  Widget card = const DmOnboardingPhotoUploadCard();
  if (boundedHeight != null) {
    card = SizedBox(height: boundedHeight, child: card);
  }
  return SizedBox(
    width: _dmOnboardingPhotoUploadCardColumnWidth(deviceWidth),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[card],
    ),
  );
}

Widget _dmOnboardingPhotoUploadCardHosted(
  String caption, {
  PhotoAttachment? photo,
  double deviceWidth = _dmOnboardingPhotoUploadCardPhoneWidth,
  double? boundedHeight,
}) =>
    BlocProvider<DmOnboardingCubit>(
      create: (_) => _DmOnboardingPhotoUploadCardCubit(photo),
      child: _dmOnboardingPhotoUploadCardMeasured(
        caption,
        _dmOnboardingPhotoUploadCardStepGeometry(
          deviceWidth,
          boundedHeight: boundedHeight,
        ),
      ),
    );

// ---------------------------------------------------------------------------

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Empty · phone (390pt)',
  size: _dmOnboardingPhotoUploadCardPhoneBox,
)
Widget dmOnboardingPhotoUploadCardEmpty() =>
    _dmOnboardingPhotoUploadCardHosted('Empty · 342pt content column');

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Empty · compact device (320pt)',
  size: _dmOnboardingPhotoUploadCardCompactBox,
)
Widget dmOnboardingPhotoUploadCardCompactDevice() =>
    _dmOnboardingPhotoUploadCardHosted(
      'Empty · 272pt content column',
      deviceWidth: _dmOnboardingPhotoUploadCardCompactPhoneWidth,
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Filled · portrait 4:5',
  size: _dmOnboardingPhotoUploadCardPhoneBox,
)
Widget dmOnboardingPhotoUploadCardPortraitPhoto() =>
    _dmOnboardingPhotoUploadCardHosted(
      'Filled · 80x100 source, no crop',
      photo: _dmOnboardingPhotoUploadCardCapture(
        dmOnboardingPhotoUploadCardPortraitBytes,
        PhotoSource.camera,
      ),
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Filled · landscape 16:9',
  size: _dmOnboardingPhotoUploadCardPhoneBox,
)
Widget dmOnboardingPhotoUploadCardLandscapePhoto() =>
    _dmOnboardingPhotoUploadCardHosted(
      'Filled · 160x90 source, 55% cropped',
      photo: _dmOnboardingPhotoUploadCardCapture(
        dmOnboardingPhotoUploadCardLandscapeBytes,
        PhotoSource.gallery,
      ),
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Filled · low-resolution capture',
  size: _dmOnboardingPhotoUploadCardPhoneBox,
)
Widget dmOnboardingPhotoUploadCardLowResPhoto() =>
    _dmOnboardingPhotoUploadCardHosted(
      'Filled · 24x30 source, upscaled 14x',
      photo: _dmOnboardingPhotoUploadCardCapture(
        dmOnboardingPhotoUploadCardLowResBytes,
        PhotoSource.gallery,
      ),
    );

@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Filled · height-bounded host',
  size: _dmOnboardingPhotoUploadCardBoundedBox,
)
Widget dmOnboardingPhotoUploadCardBoundedHeight() =>
    _dmOnboardingPhotoUploadCardHosted(
      'Bounded 180pt height · card collapses',
      photo: _dmOnboardingPhotoUploadCardCapture(
        dmOnboardingPhotoUploadCardPortraitBytes,
        PhotoSource.camera,
      ),
      boundedHeight: 180,
    );

/// The height the card takes for a given [width], per its own 4:5 ratio.
/// Exposed so the render test states its geometry as arithmetic rather than as
double dmOnboardingPhotoUploadCardHeightFor(double width) =>
    width / _dmOnboardingPhotoUploadCardRatio;

/// The content width the photo step gives the card on a [deviceWidth] device.
/// Exposed for the same reason.
double dmOnboardingPhotoUploadCardContentWidth(double deviceWidth) =>
    _dmOnboardingPhotoUploadCardColumnWidth(deviceWidth);
