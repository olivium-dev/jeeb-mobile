import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

/// 409 email_collision: second method BLOCKED. Sheet explains account exists.
Future<void> showSocialCollisionSheet(BuildContext context) {
  final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
        alpha: UIConstants.opacityHigh,
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: OmdsBorderRadius.topXLarge,
    ),
    builder: (sheetContext) => const SocialCollisionSheet(),
  );
}

class SocialCollisionSheet extends StatelessWidget {
  const SocialCollisionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'social_collision_sheet',
      container: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: Spacing.twoXLarge,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                l10n.registrationSocialCollisionTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.registrationSocialCollisionBody,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.large),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  identifier: 'social_collision_sheet_dismiss_cta',
                  button: true,
                  container: true,
                  child: OMDSOutlinedButton(
                    key: const Key('registration.socialCollisionDismiss'),
                    text: l10n.registrationSocialCollisionDismiss,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Canvas box for the body at phone width. The measured body is 332dp tall in
/// both EN and AR, and it is bottom-anchored, so the slack sits above it and
const Size _socialCollisionSheetBox = Size(390, 420);

/// Canvas box for the 320dp rendering — 380dp of measured content.
const Size _socialCollisionSheetNarrowBox = Size(320, 440);

/// Canvas box for a whole phone screen: the presented preview and the 200%
/// window are both read against a device, not against a card.
const Size _socialCollisionSheetScreenBox = Size(
  390,
  socialCollisionSheetPhoneWindow,
);

/// Usable height of a 390×844 phone once the status bar is gone — i.e. the
/// tallest a `showModalBottomSheet(isScrollControlled: true)` can ever be on a
const double socialCollisionSheetPhoneWindow = 780;

/// Label on the stand-in page the sheet is presented over.
/// Public because the render test pins it: it is the one string that tells the
const String socialCollisionSheetHostLabel = 'Registration screen';

/// Bottom inset of a phone with a home indicator. The presented preview injects
/// it so the sheet's own [SafeArea] has something to clear.
const double _socialCollisionSheetHomeIndicator = 34;

/// The sheet body alone, squeezed to [width].
/// Applied through a bottom-anchored [Align] so the preview reads the way the
Widget _socialCollisionSheetHosted({required double width}) => Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(width: width, child: const SocialCollisionSheet()),
    );

/// The body at [textScale], laid out at its NATURAL height inside a
/// phone-sized window that clips it.
Widget _socialCollisionSheetInPhoneWindow(double textScale) {
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: const ClipRect(
        child: SizedBox(
          width: 390,
          height: socialCollisionSheetPhoneWindow,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SocialCollisionSheet(),
          ),
        ),
      ),
    ),
  );
}

/// Stand-in for the registration screen, which shows the sheet on its first
/// frame the way `SocialSignInSection`'s listener does on a 409.
class _SocialCollisionSheetPresenter extends StatefulWidget {
  const _SocialCollisionSheetPresenter();

  @override
  State<_SocialCollisionSheetPresenter> createState() =>
      _SocialCollisionSheetPresenterState();
}

class _SocialCollisionSheetPresenterState
    extends State<_SocialCollisionSheetPresenter> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because `showSocialCollisionSheet` pushes a route and needs a
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSocialCollisionSheet(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          socialCollisionSheetHostLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// The production presentation path, self-contained.
/// The local [Navigator] is what makes it safe in a canvas: the sheet is a
Widget _socialCollisionSheetInModalRoute() {
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(
          bottom: _socialCollisionSheetHomeIndicator,
        ),
        viewPadding: const EdgeInsets.only(
          bottom: _socialCollisionSheetHomeIndicator,
        ),
      ),
      child: Navigator(
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const _SocialCollisionSheetPresenter(),
        ),
      ),
    ),
  );
}

/// The block prompt as designed: phone width, English, light.
/// The baseline every other state is read against, and the only state with
@JeebPreview(
  group: 'auth',
  name: 'Block prompt · phone width',
  size: _socialCollisionSheetBox,
  matrix: true,
)
Widget socialCollisionSheetDefault() =>
    _socialCollisionSheetHosted(width: 390);

/// The narrowest phone the app supports (320dp — iPhone SE 1st gen and the
/// small Android bucket).
@JeebPreview(
  group: 'auth',
  name: 'Narrowest phone · 320dp',
  size: _socialCollisionSheetNarrowBox,
)
Widget socialCollisionSheetNarrowPhone() =>
    _socialCollisionSheetHosted(width: 320);

/// The accessibility ceiling, shown inside a phone-sized window: 200% text.
/// The measured sheet is 840dp tall here — 60dp MORE than the 780dp a 390×844
@JeebPreview(
  group: 'auth',
  name: 'Text at 200% · phone window',
  size: _socialCollisionSheetScreenBox,
)
Widget socialCollisionSheetLargeText() => _socialCollisionSheetInPhoneWindow(2);

/// The sheet as users actually meet it: pushed by `showSocialCollisionSheet`
/// over the registration screen, under the scrim, with a home-indicator inset
@JeebPreview(
  group: 'auth',
  name: 'Presented over the sign-in screen',
  size: _socialCollisionSheetScreenBox,
)
Widget socialCollisionSheetPresented() => _socialCollisionSheetInModalRoute();
