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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_photo_upload_card_preview_test.dart
// ===========================================================================
//
// The card takes no parameters, so everything it draws comes from three
// ambient inputs: `DmOnboardingState.photo` on the ambient [DmOnboardingCubit],
// the [BoxConstraints] the photo step hands it, and the colour scheme. The
// previews below vary exactly those.
//
// Network-free by construction, not merely by the guard in [jeebPreviewHost]:
// the cubit is a [_DmOnboardingPhotoUploadCardCubit] parked on a fixed state,
// its picker is the in-memory [StubPhotoPickerService] and its gateway is a
// local no-op. Nothing here can reach Dio.
//
// **About the captions.** The card renders no text at all — it is an icon or a
// bitmap — so `find.text` has nothing of the widget's own to bind to, and a
// render test could otherwise pass while all six states drew the same box.
// Each preview therefore carries a one-line caption naming the state, useful
// in the canvas (six unlabelled grey rectangles are indistinguishable) and
// used by the test only to address a state. The assertions that actually prove
// the states differ — measured box, which branch rendered, and *which* photo —
// live in
// `test/previews/jeeber_onboarding/dm_onboarding_photo_upload_card_preview_test.dart`.
//
// Three things these previews surface in the widget rather than in the
// previews: see [dmOnboardingPhotoUploadCardLandscapePhoto] (BoxFit.cover
// crops over half the frame away, centre-aligned),
// [dmOnboardingPhotoUploadCardLowResPhoto] (nothing gates the resolution of an
// accepted capture) and [dmOnboardingPhotoUploadCardBoundedHeight] (bound the
// height and the drop area stops being a drop area).

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

// ---------------------------------------------------------------------------
// Fixture photos
// ---------------------------------------------------------------------------
//
// Real, decodable PNGs rather than the repeated-byte payloads the widget tests
// use. `StubPhotoPickerService` hands out `Uint8List(n)..fillRange(0, n, 0x42)`
// blobs, which are fine for a test that only asks "is state.photo set" but
// would render as a decode failure in the canvas — and this card has no
// `errorBuilder`, so that failure is invisible until you look at the console.
//
// Each is a flat-banded image chosen so the crop is legible at a glance:
// vertical bands show what `BoxFit.cover` throws away horizontally, the frame
// on the portrait one shows when nothing is cropped at all.
//
// These three (and the two geometry helpers at the end of the section) are the
// only public names below the banner: the render test binds to them by
// identity, so they cannot be private.

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
// Inert cubit
// ---------------------------------------------------------------------------

/// Declared because [DmOnboardingGateway] declares it. Deliberately empty
/// rather than network-backed — nothing on the photo step calls `submit`
/// anyway (only the service-area step does).
class _DmOnboardingPhotoUploadCardGateway implements DmOnboardingGateway {
  @override
  Future<void> submit(DmOnboardingSubmission submission) async {}
}

/// A [DmOnboardingCubit] parked on a fixed state.
///
/// The picker is seeded with the same decodable fixtures the previews use, so
/// *tapping* the card in the canvas — which opens the real OMDS source sheet
/// and calls `pickFromCamera`/`pickFromGallery` — lands on a photo you can
/// actually see, instead of the undecodable synthetic blob the stub returns by
/// default. Both fixtures are far under the 2 MB ceiling, so
/// `HalvingPhotoCompressor` passes them through untouched.
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
// Hosting
// ---------------------------------------------------------------------------

/// Renders [child] above a caption naming the state under review.
///
/// The caption is preview scaffolding — see the section doc. Deliberately tiny
/// and single-line so the 200%-text rendering of the matrix still shows the
/// card rather than a wall of label.
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

/// The production host, reproduced: the photo step's gutter-inset content
/// column on a [deviceWidth]-wide device.
///
/// Copied from `_PhotoStepContent` + `DmOnboardingStepLayout` rather than by
/// importing the step, so this stays a preview of the card and not of the step.
/// Two details are load-bearing and are the reason it is copied rather than
/// approximated: the column is `CrossAxisAlignment.start` (so the card's width
/// constraint is LOOSE, not tight) and its host is a `SingleChildScrollView`
/// (so the height is UNBOUNDED). Both change what `AspectRatio` does.
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
// Previews
// ---------------------------------------------------------------------------

/// The state every Jeeber sees first: no photo picked yet.
///
/// 342 × 427.5 of near-empty surface (`surfaceContainerLow`) with a hairline
/// `outlineVariant` border and a 32pt `Icons.add` in the middle. The whole
/// affordance — "this is tappable, put a photo here" — rests on that border and
/// that icon, and the border does not carry it: measured against the page it is
/// 1.29:1 in light and 1.98:1 in dark, both under the 3:1 WCAG 1.4.11 asks of a
/// component boundary. The **EN light** rendering is the one to look at, not the
/// dark one — light is the worse of the two here, which is the reverse of the
/// usual habit.
///
/// Note also that the localized hint ("Tap to add a photo") is a
/// [Semantics] label only. A sighted user is never told what the box is for.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Empty · phone (390pt)',
  size: _dmOnboardingPhotoUploadCardPhoneBox,
)
Widget dmOnboardingPhotoUploadCardEmpty() =>
    _dmOnboardingPhotoUploadCardHosted('Empty · 342pt content column');

/// The same empty card on the narrowest supported device.
///
/// The card shrinks with the column (272 × 340) but the plus icon does NOT —
/// `Sizes.twoXLarge` is an absolute 32pt. The affordance therefore grows
/// *relatively* stronger as the screen gets smaller, which is the harmless
/// direction; the harmful direction is the 200% rendering of the matrix, where
/// the icon still measures 32pt while every label around it has doubled.
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

/// Filled with a photo whose ratio matches the card's: nothing is cropped.
///
/// This is the sign-off state — the 4:5 portrait the Figma drop area was cut
/// for. The fixture carries a full-bleed frame precisely so it is obvious that
/// all four edges survive; compare with the landscape state below, where the
/// frame's left and right sides are gone.
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

/// Filled from a landscape capture — the common case, and a lossy one.
///
/// `Image.memory(photo.bytes, fit: BoxFit.cover)` passes no `alignment`, so it
/// centres. Covering a 4:5 box with a 16:9 source means scaling to the HEIGHT:
/// the source is drawn 760pt wide inside a 342pt card and 55% of the frame is
/// discarded, 27.5% off each side. In the canvas the outer bands of the fixture
/// simply are not there.
///
/// For a "clear photo of you" that is not a cosmetic loss — a Jeeber standing
/// off-centre in a sideways shot is cropped out of their own identity photo,
/// with no crop UI and no way to tell from the card that anything was removed.
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

/// Filled from a 24 × 30 thumbnail.
///
/// Correct ratio, ~14× under the size it is drawn at. Nothing in the pick path
/// looks at pixel dimensions — [PhotoCompressor] has a BYTE ceiling and no
/// floor of any kind — so a gallery thumbnail is accepted as readily as a
/// camera capture and is then upscaled into a 342pt card.
///
/// Worth a preview because the card is the only place a Jeeber could notice,
/// and it says nothing: no resolution warning, no "retake", just a blurry
/// block. The reviewer on the far end sees the same 24 × 30 of detail.
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

/// The state that breaks: a host that bounds the card's height.
///
/// Today's step puts the card in a `SingleChildScrollView`, so the height is
/// unbounded and the width wins. Bound the height instead — an `Expanded`
/// without a scroll view, a landscape viewport, a future "confirm your photo"
/// sheet — and `AspectRatio` resolves from the height: the drop area collapses
/// to 144 × 180, 42% of the content width, and (because the step's column is
/// `CrossAxisAlignment.start`) sits hard against the leading edge rather than
/// centring. The photo's crop changes with it.
///
/// The widget defends its ratio and gives up its purpose: a 144pt sliver is not
/// a drop area, and nothing about it says so — no overflow stripe, no
/// exception. Included because it is the cheapest possible mistake for the next
/// person to embed this card, and a picture of it costs one preview.
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
/// a magic number.
double dmOnboardingPhotoUploadCardHeightFor(double width) =>
    width / _dmOnboardingPhotoUploadCardRatio;

/// The content width the photo step gives the card on a [deviceWidth] device.
/// Exposed for the same reason.
double dmOnboardingPhotoUploadCardContentWidth(double deviceWidth) =>
    _dmOnboardingPhotoUploadCardColumnWidth(deviceWidth);
