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

/// The phone width every onboarding step is designed against.
const double _dmOnboardingStepHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _dmOnboardingStepHeaderCompactPhoneWidth = 320;

/// Canvas boxes. The header is two stacked lines, so a box only has to be tall
/// enough for the `EN 200% text` rendering of its own state — where the
const Size _dmOnboardingStepHeaderShortCopyBox = Size(390, 300);
const Size _dmOnboardingStepHeaderLongCopyBox = Size(390, 460);
const Size _dmOnboardingStepHeaderCompactBox = Size(320, 460);

/// One ARB lookup, deferred until there is a context to resolve it against.
typedef _DmOnboardingStepHeaderCopy = String Function(AppLocalizations l10n);

/// Hosts the header exactly as `DmOnboardingStepLayout` does: a [width]-wide
/// page with the shared `Spacing.xLarge` gutter, wrapped in the same
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
/// The shortest copy the widget carries in production — a short headline over
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
/// A whole question for a supporting line — the longer of the two shipping
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
/// Reachable two ways, neither exotic: the personal-details step
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Blank subtitle',
  size: _dmOnboardingStepHeaderShortCopyBox,
)
Widget dmOnboardingStepHeaderBlankSubtitle() => _dmOnboardingStepHeaderHosted(
      title: (AppLocalizations l10n) => l10n.dmOnboardingPersonalDetailsTitle,
      subtitle: (AppLocalizations l10n) => '',
    );
