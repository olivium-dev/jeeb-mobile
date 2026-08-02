import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

class DmOnboardingStepHeader extends StatelessWidget {
  const DmOnboardingStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          subtitle,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ],
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
// Render tests: test/previews/jeeber_onboarding/dm_onboarding_step_header_preview_test.dart
// ===========================================================================
//
// The header is pure props: two [String]s in, two [Text]s out. No cubit, no
// repository, no DI graph — so these previews are network-free by
// construction rather than by the guard in [jeebPreviewHost].
//
// That makes the copy the only variable, and the copy is exactly what breaks
// it. Every string it can be handed comes from the ARB, so each state below
// is a real `AppLocalizations` pair (resolved through a [Builder], since a
// preview function has no context of its own) rather than invented text,
// hosted at the gutter its caller uses — `DmOnboardingStepLayout` pads the
// page by [Spacing.xLarge] and its scroll view adds [Spacing.medium] on top.
//
// The ceiling is the text SCALE, not the language: measured in the render
// test, every AR rendering comes out no taller than its EN twin, while the
// `EN 200% text` rendering of the same state is 2.7–4.2x the 1.0 height —
// super-linear, because both lines scale AND both then wrap further.
//
// Two things these previews surface in the widget rather than in themselves,
// both pinned in `test/previews/jeeber_onboarding/dm_onboarding_step_header_preview_test.dart`:
//
// * the subtitle is painted in `onSecondaryContainer` — the periwinkle
//   #777FC0 — on the white `surface`, which measures **3.76:1** and is the
//   pairing `test/core/theme/color_role_contrast_test.dart` keeps a guard
//   against ("the OLD periwinkle-on-white pairing was genuinely failing").
//   See [dmOnboardingStepHeaderPhotoStep].
// * nothing here is a heading to a screen reader — see
//   [dmOnboardingStepHeaderServiceArea].

/// The phone width every onboarding step is designed against.
const double _dmOnboardingStepHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _dmOnboardingStepHeaderCompactPhoneWidth = 320;

/// Canvas boxes. The header is two stacked lines, so a box only has to be tall
/// enough for the `EN 200% text` rendering of its own state — where the
/// headline goes from 24 to 48 logical pixels and both lines wrap further.
/// Heights measured in the render test (under `flutter test`'s wider
/// substitute font, so a device needs slightly less):
///
/// | state                | 1.0    | 200%   |
/// |----------------------|--------|--------|
/// | photo step           |  88 pt | 340 pt |
/// | service area         | 108 pt | 420 pt |
/// | longest copy (KYC)   | 148 pt | 620 pt |
/// | compact device       | 168 pt | 660 pt |
/// | blank subtitle       |  88 pt | 236 pt |
const Size _dmOnboardingStepHeaderShortCopyBox = Size(390, 300);
const Size _dmOnboardingStepHeaderLongCopyBox = Size(390, 460);
const Size _dmOnboardingStepHeaderCompactBox = Size(320, 460);

/// One ARB lookup, deferred until there is a context to resolve it against.
typedef _DmOnboardingStepHeaderCopy = String Function(AppLocalizations l10n);

/// Hosts the header exactly as `DmOnboardingStepLayout` does: a [width]-wide
/// page with the shared `Spacing.xLarge` gutter, wrapped in the same
/// `SingleChildScrollView` (`Spacing.medium` top inset) the layout puts its
/// step content in — and nothing else. No progress bar, no pinned Continue
/// button. What is left is the header's own box, which is what these previews
/// are for.
///
/// The scroll view is not decoration: without it the header's [Column] gets a
/// bounded height and stretches to fill whatever box it is in, which is not
/// what production does and would hide the height these previews are meant to
/// show. With it, the header shrink-wraps its two lines and any shortfall at
/// large text scales is absorbed by scrolling — again, exactly production.
Widget _dmOnboardingStepHeaderHosted({
  required _DmOnboardingStepHeaderCopy title,
  required _DmOnboardingStepHeaderCopy subtitle,
  double width = _dmOnboardingStepHeaderPhoneWidth,
}) =>
    Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xLarge,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
            child: Builder(
              builder: (BuildContext context) {
                final AppLocalizations l10n = AppLocalizations.of(context);
                return DmOnboardingStepHeader(
                  title: title(l10n),
                  subtitle: subtitle(l10n),
                );
              },
            ),
          ),
        ),
      ),
    );

/// Call site 1 of 2 that ships: the photo step (Figma 56591:5331/5332).
///
/// The shortest copy the widget carries in production — a short headline over
/// a three-word supporting line, 88 pt tall at 1.0 — and therefore the reading
/// that hides the most. It is the state to look at for COLOUR, not for layout.
///
/// The subtitle takes `colorScheme.onSecondaryContainer`, which in the light
/// Jeeb palette is the periwinkle #777FC0, and it is painted on the scaffold's
/// white `surface`. That pairing measures 3.76:1 — below the 4.5:1 AA floor
/// for normal-size text, and `titleSmall` (14 px / w500) is normal-size text.
/// It is not a hypothetical: `test/core/theme/color_role_contrast_test.dart`
/// already pins "the OLD periwinkle-on-white pairing was genuinely failing" as
/// the reason every other label role was migrated to `onSurfaceVariant`
/// (#5C4038, 9.35:1 on the same surface). This widget is a surviving caller of
/// the pattern that migration removed.
///
/// The AR RTL dark rendering does NOT share the defect: `onSecondaryContainer`
/// in the seeded dark scheme is a light tone on a dark surface.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Photo step (production copy)',
  size: _dmOnboardingStepHeaderShortCopyBox,
)
Widget dmOnboardingStepHeaderPhotoStep() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.dmOnboardingPhotoUploadTitle,
      subtitle: (AppLocalizations l10n) => l10n.dmOnboardingPhotoUploadSubtitle,
    );

/// Call site 2 of 2 that ships: the service-area step (Figma 56591:5337).
///
/// A whole question for a supporting line — the longer of the two shipping
/// pairs (108 pt against the photo step's 88 at 1.0), and the first to wrap as
/// the text scale rises. It is the state that shows the two [Text]s carry no
/// `maxLines` and no `overflow` between them: they degrade by wrapping, which
/// is right here because the host is a [SingleChildScrollView] — but nothing
/// in the widget enforces it, and a future caller inside a bounded box gets an
/// overflow stripe rather than an ellipsis.
///
/// This is also the state to inspect for SEMANTICS. The class is named
/// `StepHeader` and paints a `headlineSmall` in extra-bold navy, but neither
/// [Text] sets `header: true` (nor does any ancestor), so assistive tech
/// announces two anonymous runs of text and heading-by-heading navigation
/// skips the only thing on the step that says which step it is.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Service area (production copy)',
  size: _dmOnboardingStepHeaderShortCopyBox,
)
Widget dmOnboardingStepHeaderServiceArea() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.dmOnboardingServiceAreaHeading,
      subtitle: (AppLocalizations l10n) => l10n.dmOnboardingServiceAreaSubtitle,
    );

/// The longest plausible copy: the KYC identity step this wizard chains into
/// (JM-040), whose ARB pair is the longest heading + supporting line in the
/// whole onboarding family.
///
/// Nothing invented — `kycIdStepTitle` / `kycIdStepSubtitle` ship today, and
/// the identity step is one Continue tap past the service-area step, so this
/// is the copy the header gets the moment the KYC wizard adopts it.
///
/// This is the height ceiling. Measured in the render test: 148 pt at 1.0 and
/// **620 pt at the 200% text scale** the golden tests already assert for other
/// screens — a 4.2x growth, because both lines scale and both then wrap
/// further. 620 pt is more than the whole scrollable area
/// `DmOnboardingStepLayout` leaves above its pinned Continue button on a
/// 390x844 phone, before the step has drawn any content of its own. It scrolls
/// rather than overflowing (the layout wraps steps in a
/// [SingleChildScrollView]), so this is an ergonomics reading, not a broken
/// one.
///
/// The `Spacing.twoXSmall` gap between the two lines is a raw logical 4 and
/// does NOT follow the text scaler, so at 200% a 48 px headline and a 28 px
/// subtitle still sit 4 pt apart and read as one clump.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Longest copy (KYC identity)',
  size: _dmOnboardingStepHeaderLongCopyBox,
)
Widget dmOnboardingStepHeaderLongestCopy() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.kycIdStepTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycIdStepSubtitle,
    );

/// The same widget on the narrowest supported device: 320 pt less the 48 pt of
/// shared gutter leaves 272 pt of text column, against 342 pt on a 390 pt
/// phone.
///
/// Copy is the KYC selfie step (`kycSelfieStepTitle` / `kycSelfieStepSubtitle`)
/// — the sibling of the state above, so the two narrow states are told apart
/// by what they say and not only by how wide they are.
///
/// 20% less column is paid entirely in extra wrapped lines, and the supporting
/// line pays most of it: measured 168 pt at 1.0 and 660 pt at 200% — the
/// tallest of the five states on the smallest screen. Nothing clips — no
/// `maxLines` and no `overflow` on either [Text] — so the failure mode of a
/// narrow device is a header that pushes the step's real content off screen,
/// not a truncated one.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Compact device (320pt)',
  size: _dmOnboardingStepHeaderCompactBox,
)
Widget dmOnboardingStepHeaderCompactDevice() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.kycSelfieStepTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycSelfieStepSubtitle,
      width: _dmOnboardingStepHeaderCompactPhoneWidth,
    );

/// A step with no supporting line — `subtitle: ''`.
///
/// Reachable two ways, neither exotic: the personal-details step
/// (`dmOnboardingPersonalDetailsTitle`) is the one onboarding step that has a
/// title and no subtitle key today and does not use this header, and any ARB
/// value a translator leaves blank arrives here as an empty string. Both
/// `title` and `subtitle` are `required`, so a caller with nothing to say has
/// no way to say nothing except this.
///
/// The widget has no branch for it: it still builds the [SizedBox] and an
/// empty [Text], so the heading carries 4 pt of dead space plus a full empty
/// line box beneath it, and the semantics tree gains an empty node. Small, and
/// the only reason to look at it is that the fix (`if (subtitle.isEmpty)`) is
/// smaller still.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Blank subtitle',
  size: _dmOnboardingStepHeaderShortCopyBox,
)
Widget dmOnboardingStepHeaderBlankSubtitle() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.dmOnboardingPersonalDetailsTitle,
      subtitle: (AppLocalizations l10n) => '',
    );
