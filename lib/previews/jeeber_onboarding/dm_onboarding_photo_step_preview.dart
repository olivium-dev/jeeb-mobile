/// Widget previews for [DmOnboardingPhotoStep] — run with
/// `flutter widget-preview start`.
///
/// The step takes no constructor arguments. Everything it can put on screen is
/// a function of one ambient [DmOnboardingCubit]: `state.hasPhoto` gates the
/// Continue CTA, and `state.photo` decides whether the drop-area card shows the
/// "+" affordance or a preview of the chosen image. So every preview below is a
/// SEEDED cubit plus a host box.
///
/// **Network-free by construction.** [DmOnboardingCubit] has no `seed:`
/// constructor, so [_SeededDmOnboardingCubit] passes it two inert
/// collaborators — a picker that always reports `cancelled` (no camera, no
/// gallery, no permission prompt) and the in-memory [FakeDmOnboardingGateway] —
/// then emits the state under review. Neither collaborator can reach the wire;
/// the guard in [jeebPreviewHost] is a net, not the plan. Photo bytes are two
/// tiny PNGs inlined below, so nothing is read from disk either.
///
/// **About the captions.** The step's copy is fixed: every state renders the
/// same title, the same subtitle and the same "Continue". `find.text` therefore
/// cannot tell two of these previews apart, and a render test bound only to
/// widget output would pass even if all six previews were the same state. Each
/// preview carries a one-line caption naming the state instead — useful in the
/// canvas, and used by the test only to *address* a state. What proves the
/// states differ is measured in
/// `test/previews/jeeber_onboarding/dm_onboarding_photo_step_preview_test.dart`:
/// the CTA's enabled flag, the card's contents, and the card's box.
///
/// **The box matters.** In production the step is the `Expanded` child of the
/// wizard's column (`dm_onboarding_screen.dart`), i.e. phone width and whatever
/// height is left under the app bar and the progress header. [DmOnboardingStepLayout]
/// hard-requires that bounded height — its `Column` puts the scrollable content
/// in an `Expanded` above a bottom-pinned CTA — so each preview pins its own
/// `SizedBox`. Pinning rather than inheriting is deliberate: the canvas honours
/// [JeebPreview.size], but the render tests pump onto a fixed 800 × 600
/// surface, so a 320pt state that only asked for a 320pt canvas would be
/// rendered at 800pt under test and quietly become the same state as the 390pt
/// one.
///
/// Five things these previews surface, all in the widgets rather than in the
/// previews — see the notes on the individual states, and the measurements in
/// the test:
///
///  * the drop-area keeps announcing **"Tap to add a photo"** after a photo has
///    been chosen, so a screen-reader user is never told the required photo is
///    on file (`DmOnboardingPhotoUploadCard` builds its `Semantics` label
///    outside the `BlocBuilder` that swaps the content);
///  * the disabled Continue is conveyed **only** by a 60%-alpha fill —
///    `OmdsLoadingButton` renders a `GestureDetector` with a null callback, and
///    the wrapping `Semantics(button: true)` never sets `enabled: false`, so
///    the blocked first step is invisible to assistive tech and unexplained on
///    screen (no "a photo is required" copy anywhere in the step);
///  * the drop-area's own boundary is below the 3:1 WCAG 1.4.11 asks of the
///    edge that identifies a control: `outlineVariant` on `surface` measures
///    **1.29:1** in light and 1.98:1 in dark, over a `surfaceContainerLow` fill
///    that is 1.06:1 from the page. The single biggest tap target on the screen
///    is marked only by the "+" glyph inside it;
///  * the header subtitle inks with `onSecondaryContainer` — the light-indigo
///    emphasis tint — which on the white scaffold measures **3.76:1**, under
///    AA's 4.5:1 for 14pt text. Light mode only; dark is 14.29:1;
///  * a landscape photo is centre-cropped to 4:5 by `BoxFit.cover` with no
///    reframe control, which on a selfie taken sideways can crop the face out.
///
/// What the matrix cleared: the AR rendering genuinely mirrors (the header's
/// wrapped lines end at the trailing edge, not merely translate), and at 200%
/// text every state lengthens its scroll instead of overflowing — the CTA is a
/// fixed 48pt box either way, with the doubled label filling 40 of those 48.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_step.dart';
import '../../features/photo_attachment/domain/photo_attachment.dart';
import '../../features/photo_attachment/domain/photo_picker_service.dart';
import '../harness/jeeb_preview.dart';

/// A typical phone — the width the Figma step (56591:5323) is drawn against.
const double _phoneWidth = 390;

/// The narrowest device the app still has to survive (iPhone SE 1st gen).
const double _compactWidth = 320;

/// The height the step really gets on a 390 × 844 phone is ~650pt (844 minus
/// status bar, app bar, progress header and the bottom inset). 520 keeps the
/// box plus its caption inside the 600pt-tall surface the render tests pump
/// onto even at the matrix's 200% text scale, so the number is honest in both
/// the canvas and CI. It is short of 650 on purpose: the content already has to
/// scroll here, which is the pressure worth looking at.
const double _stepHeight = 520;

/// A viewport too short for the 4:5 drop-area: the content must scroll while
/// the CTA stays pinned. Reachable in the wild on a small phone at large text,
/// and on any phone in landscape.
const double _shortStepHeight = 320;

/// Canvas boxes. Each leaves room under the pinned step for its caption, at
/// the 200% text rendering of the matrix as well as at 100%.
const Size _phoneBox = Size(_phoneWidth, 600);
const Size _compactBox = Size(360, 600);
const Size _shortBox = Size(_phoneWidth, 400);

/// A 48 × 60 portrait PNG standing in for a selfie: the aspect ratio the card
/// is designed for, so `BoxFit.cover` has nothing to crop.
const String _portraitPngBase64 =
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
const String _widePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAAAoCAIAAAC6iKlyAAAAgElEQVR42u3QIQ2AQAAF0CuF'
    'O4NgI8GRgBoIClCFDARgKDrgiECHrxBvewleuYc+9mxd7D3HWNvnWF2v2DIdsSJatGjRokWL'
    'Fi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokWLFi1atGjRokX/'
    'L/oD4EESoyV7juMAAAAASUVORK5CYII=';

/// The two fixture payloads, decoded once.
final Uint8List portraitPhotoBytes = base64Decode(_portraitPngBase64);
final Uint8List widePhotoBytes = base64Decode(_widePngBase64);

/// A picker that can never produce a photo and never touches the platform.
///
/// `cancelled` is the one failure [DmOnboardingCubit] swallows silently, so
/// tapping the drop-area in the canvas opens the OMDS source sheet, dismisses,
/// and leaves the seeded state exactly as the preview declared it.
class _InertPhotoPicker implements PhotoPickerService {
  const _InertPhotoPicker();

  @override
  Future<RawPhoto> pickFromCamera() async =>
      throw const PhotoPickException(PhotoPickFailure.cancelled);

  @override
  Future<RawPhoto> pickFromGallery() async =>
      throw const PhotoPickException(PhotoPickFailure.cancelled);
}

/// The real cubit over inert collaborators, parked on [seed].
///
/// The production cubit only accepts an `initialStep`, so a photo (or a
/// one-shot error) can only be put in place by emitting it. Emitting once from
/// the constructor is the whole implementation — nothing here overrides the
/// step transitions, so the canvas Continue still runs the real `next()`.
class _SeededDmOnboardingCubit extends DmOnboardingCubit {
  _SeededDmOnboardingCubit(DmOnboardingState seed)
    : super(
        pickerService: const _InertPhotoPicker(),
        gateway: FakeDmOnboardingGateway(),
      ) {
    emit(seed);
  }
}

PhotoAttachment _attachment(Uint8List bytes) => PhotoAttachment(
  id: 'dm-onboarding-photo-0',
  bytes: bytes,
  originalSizeBytes: bytes.length * 4,
  source: PhotoSource.camera,
);

/// Hosts the step in a pinned box under [caption].
///
/// The `ValueKey` on the provider is load-bearing for the render tests: two of
/// these trees differ only in the cubit's seed, so without a distinguishing key
/// Flutter would reuse the `BlocProvider` element across pumps in one test and
/// never re-run `create`, leaving the previous state on screen.
Widget _hosted(
  String caption,
  DmOnboardingState seed, {
  double width = _phoneWidth,
  double height = _stepHeight,
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
            create: (_) => _SeededDmOnboardingCubit(seed),
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
///
/// The state to look hardest at, because it is the one that BLOCKS. The step
/// never says why Continue does nothing — the heading claims a clear photo is
/// wanted, but there is no "required" marker, no helper text under the CTA and
/// no error until the user taps a button that cannot respond. All the dimmed
/// button carries is `primary` at 60% alpha; see the library doc.
@JeebPreview(group: 'jeeber_onboarding', name: 'Empty (no photo)', size: _phoneBox)
Widget dmOnboardingPhotoStepEmpty() =>
    _hosted('Empty: no photo yet — Continue inert', const DmOnboardingState());

/// The unblocked state: a portrait photo is on file, so `hasPhoto` flips and
/// Continue lights up and chains photo → address.
///
/// The drop-area swaps its "+" for the image at the SAME 4:5 geometry, which is
/// the only feedback the step gives. Note what does not change: the semantics
/// label is still "Tap to add a photo" (library doc), and there is no "replace"
/// or "remove" affordance — tapping the image silently reopens the source
/// sheet.
@JeebPreview(group: 'jeeber_onboarding', name: 'Photo chosen', size: _phoneBox)
Widget dmOnboardingPhotoStepWithPhoto() => _hosted(
  'Photo chosen: Continue enabled',
  DmOnboardingState(photo: _attachment(portraitPhotoBytes)),
);

/// A landscape photo in a portrait hole.
///
/// `Image.memory(..., fit: BoxFit.cover)` inside the 4:5 card scales a 3:1
/// image to the card's width-equivalent and crops the overflow equally top and
/// bottom — here it keeps roughly the middle third of the six bands. On a real
/// phone held sideways that is the difference between a face and a shoulder,
/// and the step offers no crop, no rotate and no zoom to recover from it.
@JeebPreview(group: 'jeeber_onboarding', name: 'Wide photo (cropped)', size: _phoneBox)
Widget dmOnboardingPhotoStepWidePhoto() => _hosted(
  'Wide photo: 3:1 cropped to 4:5',
  DmOnboardingState(photo: _attachment(widePhotoBytes)),
);

/// The same empty step on the narrowest supported device.
///
/// The card is width-driven (`AspectRatio` 4:5 inside 24pt gutters), so it
/// shrinks from 342 × 427.5 to 272 × 340 — the header and CTA do not, which is
/// what makes this the tightest EN 200% text rendering of the set.
@JeebPreview(group: 'jeeber_onboarding', name: 'Compact 320', size: _compactBox)
Widget dmOnboardingPhotoStepCompact() => _hosted(
  'Compact 320pt device',
  const DmOnboardingState(),
  width: _compactWidth,
);

/// A viewport shorter than the content: heading + subtitle + a 427pt card do
/// not fit in the 256pt left above the CTA.
///
/// This is the state that proves the CTA is genuinely pinned rather than merely
/// last: `DmOnboardingStepLayout` puts the content in an `Expanded`
/// `SingleChildScrollView`, so the overflow becomes scroll rather than a
/// `RenderFlex` stripe, and Continue stays reachable without scrolling to it.
/// Reachable on a small phone at large text, or in landscape.
@JeebPreview(group: 'jeeber_onboarding', name: 'Short viewport (scrolls)', size: _shortBox)
Widget dmOnboardingPhotoStepShortViewport() => _hosted(
  'Short viewport: content scrolls, CTA pinned',
  const DmOnboardingState(),
  height: _shortStepHeight,
);

/// After a failed pick: the user opened the camera, permission was denied, and
/// [DmOnboardingError.photoPickFailed] is sitting in the state.
///
/// The step renders IDENTICALLY to [dmOnboardingPhotoStepEmpty] — that is the
/// point of previewing it. The only surface for this error is a SnackBar owned
/// by the host screen (`_onError`, JEBV4-13 P1-5), which is acknowledged
/// immediately and then gone; the drop-area itself keeps no trace, offers no
/// retry, and cannot explain why the last tap produced nothing. If a future
/// change gives the card an inline error state, this preview is where it shows
/// up.
@JeebPreview(group: 'jeeber_onboarding', name: 'Photo pick failed', size: _phoneBox)
Widget dmOnboardingPhotoStepPickFailed() => _hosted(
  'Pick failed: step shows nothing',
  const DmOnboardingState(error: DmOnboardingError.photoPickFailed),
);
