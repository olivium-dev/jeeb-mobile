import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';
import 'dm_onboarding_photo_upload_card.dart';
import 'dm_onboarding_step_header.dart';
import 'dm_onboarding_step_layout.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/domain/photo_attachment.dart';
import '../../../photo_attachment/domain/photo_picker_service.dart';
import '../../domain/dm_onboarding_gateway.dart';

class DmOnboardingPhotoStep extends StatelessWidget {
  const DmOnboardingPhotoStep({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-step');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.hasPhoto != curr.hasPhoto,
      builder: (context, state) => DmOnboardingStepLayout(
        key: rootKey,
        continueIdentifier: 'dm_onboarding_continue',
        enabled: state.hasPhoto,
        content: _PhotoStepContent(l10n: l10n),
      ),
    );
  }
}

class _PhotoStepContent extends StatelessWidget {
  const _PhotoStepContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingPhotoUploadTitle,
          subtitle: l10n.dmOnboardingPhotoUploadSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        const DmOnboardingPhotoUploadCard(),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A typical phone — the width the Figma step (56591:5323) is drawn against.
const double _dmOnboardingPhotoStepPhoneWidth = 390;

/// The narrowest device the app still has to survive (iPhone SE 1st gen).
const double _dmOnboardingPhotoStepCompactWidth = 320;

/// The height the step really gets on a 390 × 844 phone is ~650pt (844 minus
/// status bar, app bar, progress header and the bottom inset). 520 keeps the
const double _dmOnboardingPhotoStepHeight = 520;

/// A viewport too short for the 4:5 drop-area: the content must scroll while
/// the CTA stays pinned. Reachable in the wild on a small phone at large text,
const double _dmOnboardingPhotoStepShortHeight = 320;

/// Canvas boxes. Each leaves room under the pinned step for its caption, at
/// the 200% text rendering of the matrix as well as at 100%.
const Size _dmOnboardingPhotoStepPhoneBox =
    Size(_dmOnboardingPhotoStepPhoneWidth, 600);
const Size _dmOnboardingPhotoStepCompactBox = Size(360, 600);
const Size _dmOnboardingPhotoStepShortBox =
    Size(_dmOnboardingPhotoStepPhoneWidth, 400);

/// A 48 × 60 portrait PNG standing in for a selfie: the aspect ratio the card
/// is designed for, so `BoxFit.cover` has nothing to crop.
const String _dmOnboardingPhotoStepPortraitPng =
    'iVBORw0KGgoAAAANSUhEUgAAADAAAAA8CAIAAACvoq6rAAABkklEQVR42s3O6SoEABiF4XM5'
    'kiRJkn0nSZJ9l30nMQ3GvszYprFNY88WEYmIiIiI5Cpchls4fb9OPf/fF0Ex/VIQHOuQgpB4'
    'pxSEJg5IQVjykBSEp7qkICJ9RAoiM0elICprXAqisyd4fy8HNnwCMTlTPPMQn0Bc7jTPPMQn'
    'kJDn5pmH+ASS8j088xCfQErBHM88xCeQVjjPMw/xCWQUL/LMQ3wCWaVennmITyC73MczD/EJ'
    '5FQu8cxDfAK51Ss88xCfQF7tGs88xCeQX+fnmYf4BArqAzzzEJ9AUeM6zzzEJ1DSvMkzD/EJ'
    'lLVu8cxDfAIV7Ts88xCfQFXnLs88xCdQ073HMw/xCdT17PPMQ3wCDb2HUtDUdyQFLY5jKWhz'
    'nkhBx+CpFHS5zqSgZ/hcCnpHL6Sgb/xSChyTV1LgnL6WgkH3jRS4Zm+lYGT+TgrGFu6lYML7'
    'IAVTvkcpmFl+kgLP6rMUzPlfpGAh8CoF3vU3KfBtvkvB8vaHFKzufkqBf+9LCgIH31KwcfQj'
    'BdvHv1L+ATemXGIEvn1mAAAAAElFTkSuQmCC';

/// A 120 × 40 landscape PNG in six vertical bands, so what `BoxFit.cover`
/// throws away is countable rather than a matter of opinion.
const String _dmOnboardingPhotoStepWidePng =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAAAoCAIAAAC6iKlyAAAAgElEQVR42u3QIQ2AQAAF0CuF'
    'O4NgI8GRgBoIClCFDARgKDrgiECHrxBvewleuYc+9mxd7D3HWNvnWF2v2DIdsSJatGjRokWL'
    'Fi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokX/'
    'L/oD4EESoyV7juMAAAAASUVORK5CYII=';

/// The two fixture payloads, decoded once.
final Uint8List _dmOnboardingPhotoStepPortraitBytes =
    base64Decode(_dmOnboardingPhotoStepPortraitPng);
final Uint8List _dmOnboardingPhotoStepWideBytes =
    base64Decode(_dmOnboardingPhotoStepWidePng);

/// A picker that can never produce a photo and never touches the platform.
/// `cancelled` is the one failure [DmOnboardingCubit] swallows silently, so
/// tapping the drop-area in the canvas opens the OMDS source sheet, dismisses,
class _DmOnboardingPhotoStepInertPicker implements PhotoPickerService {
  const _DmOnboardingPhotoStepInertPicker();

  @override
  Future<RawPhoto> pickFromCamera() async =>
      throw const PhotoPickException(PhotoPickFailure.cancelled);

  @override
  Future<RawPhoto> pickFromGallery() async =>
      throw const PhotoPickException(PhotoPickFailure.cancelled);
}

/// The real cubit over inert collaborators, parked on the seeded state.
/// The production cubit only accepts an `initialStep`, so a photo (or a
/// one-shot error) can only be put in place by emitting it. Emitting once from
class _DmOnboardingPhotoStepCubit extends DmOnboardingCubit {
  _DmOnboardingPhotoStepCubit(DmOnboardingState seed)
    : super(
        pickerService: const _DmOnboardingPhotoStepInertPicker(),
        gateway: FakeDmOnboardingGateway(),
      ) {
    emit(seed);
  }
}

PhotoAttachment _dmOnboardingPhotoStepAttachment(Uint8List bytes) =>
    PhotoAttachment(
      id: 'dm-onboarding-photo-0',
      bytes: bytes,
      originalSizeBytes: bytes.length * 4,
      source: PhotoSource.camera,
    );

/// Hosts the step in a pinned box under [caption].
/// The `ValueKey` on the provider is load-bearing for the render tests: two of
Widget _dmOnboardingPhotoStepHosted(
  String caption,
  DmOnboardingState seed, {
  double width = _dmOnboardingPhotoStepPhoneWidth,
  double height = _dmOnboardingPhotoStepHeight,
}) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: width,
          height: height,
          child: BlocProvider<DmOnboardingCubit>(
            key: ValueKey<String>(caption),
            create: (_) => _DmOnboardingPhotoStepCubit(seed),
            child: const DmOnboardingPhotoStep(),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

/// Cold entry: the first thing a would-be Jeeber sees after tapping "Become a
/// Jeeber". No photo, so `hasPhoto` is false and Continue is inert.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Empty (no photo)',
  size: _dmOnboardingPhotoStepPhoneBox,
)
Widget dmOnboardingPhotoStepEmpty() => _dmOnboardingPhotoStepHosted(
  'Empty: no photo yet — Continue inert',
  const DmOnboardingState(),
);

/// The unblocked state: a portrait photo is on file, so `hasPhoto` flips and
/// Continue lights up and chains photo → address.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Photo chosen',
  size: _dmOnboardingPhotoStepPhoneBox,
)
Widget dmOnboardingPhotoStepWithPhoto() => _dmOnboardingPhotoStepHosted(
  'Photo chosen: Continue enabled',
  DmOnboardingState(
    photo: _dmOnboardingPhotoStepAttachment(
      _dmOnboardingPhotoStepPortraitBytes,
    ),
  ),
);

/// A landscape photo in a portrait hole.
/// `Image.memory(..., fit: BoxFit.cover)` inside the 4:5 card scales a 3:1
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Wide photo (cropped)',
  size: _dmOnboardingPhotoStepPhoneBox,
)
Widget dmOnboardingPhotoStepWidePhoto() => _dmOnboardingPhotoStepHosted(
  'Wide photo: 3:1 cropped to 4:5',
  DmOnboardingState(
    photo: _dmOnboardingPhotoStepAttachment(_dmOnboardingPhotoStepWideBytes),
  ),
);

/// The same empty step on the narrowest supported device.
/// The card is width-driven (`AspectRatio` 4:5 inside 24pt gutters), so it
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Compact 320',
  size: _dmOnboardingPhotoStepCompactBox,
)
Widget dmOnboardingPhotoStepCompact() => _dmOnboardingPhotoStepHosted(
  'Compact 320pt device',
  const DmOnboardingState(),
  width: _dmOnboardingPhotoStepCompactWidth,
);

/// A viewport shorter than the content: heading + subtitle + a 427pt card do
/// not fit in the 256pt left above the CTA.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Short viewport (scrolls)',
  size: _dmOnboardingPhotoStepShortBox,
)
Widget dmOnboardingPhotoStepShortViewport() => _dmOnboardingPhotoStepHosted(
  'Short viewport: content scrolls, CTA pinned',
  const DmOnboardingState(),
  height: _dmOnboardingPhotoStepShortHeight,
);

/// After a failed pick: the user opened the camera, permission was denied, and
/// [DmOnboardingError.photoPickFailed] is sitting in the state.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Photo pick failed',
  size: _dmOnboardingPhotoStepPhoneBox,
)
Widget dmOnboardingPhotoStepPickFailed() => _dmOnboardingPhotoStepHosted(
  'Pick failed: step shows nothing',
  const DmOnboardingState(error: DmOnboardingError.photoPickFailed),
);
