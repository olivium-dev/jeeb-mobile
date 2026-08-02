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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/auth/social_collision_sheet_preview_test.dart
// ===========================================================================
//
// [SocialCollisionSheet] takes no arguments and reads no cubit — its whole
// content is three fixed l10n strings — so there are no *data* states to seed
// and nothing here goes near a repository, a cubit or the network. What varies,
// and what actually breaks, is the ENVIRONMENT the block prompt has to survive:
//
// * the phone-width baseline the copy was written against,
// * the narrowest supported phone (320dp), where the headline takes a third
//   line and pushes everything under it down,
// * 200% text — this sheet is nothing but copy, so it is the first surface to
//   run out of vertical room,
// * and the sheet as `showSocialCollisionSheet` really presents it: pushed onto
//   a navigator, bottom-anchored under a scrim, over a home-indicator inset.
//
// Only the last one goes through the production entry point; the other three
// build the body directly, which is what makes them cheap to re-render while
// tuning copy.
//
// The Arabic rendering is not decoration here. The [Column] is
// `crossAxisAlignment: start`, so the icon, the headline and the body must all
// move to the trailing edge together — a single hardcoded
// `EdgeInsets.only(left:)` anywhere in this tree would show up as one of the
// three staying put. (Both locales measure 332dp tall at 390dp wide, so a
// height difference between the two cards is a wrapping bug, not translation.)
//
// The states mirror `test/social_collision_sheet_test.dart`, which asserts the
// EN and AR copy; these previews exist so the *visual* half of that contract is
// reviewable without booting the app and failing a social sign-in.

/// Canvas box for the body at phone width. The measured body is 332dp tall in
/// both EN and AR, and it is bottom-anchored, so the slack sits above it and
/// reads like the screen the sheet slides up over.
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
/// mainstream device.
///
/// Public because the render test pins the 200% measurement against it.
const double socialCollisionSheetPhoneWindow = 780;

/// Label on the stand-in page the sheet is presented over.
///
/// Public because the render test pins it: it is the one string that tells the
/// presented preview apart from the three that build the body directly.
const String socialCollisionSheetHostLabel = 'Registration screen';

/// Bottom inset of a phone with a home indicator. The presented preview injects
/// it so the sheet's own [SafeArea] has something to clear.
const double _socialCollisionSheetHomeIndicator = 34;

/// The sheet body alone, squeezed to [width].
///
/// Applied through a bottom-anchored [Align] so the preview reads the way the
/// real sheet does — content hugging the bottom edge — instead of as a card
/// floating at the top of the box.
Widget _socialCollisionSheetHosted({required double width}) => Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(width: width, child: const SocialCollisionSheet()),
    );

/// The body at [textScale], laid out at its NATURAL height inside a
/// phone-sized window that clips it.
///
/// The clipping is the whole point. This sheet has no scroll fallback — it is a
/// `Column(mainAxisSize: min)`, and `isScrollControlled: true` only raises the
/// route's height ceiling, it does not make the content scroll — so copy taller
/// than the screen is simply not there on a device. Laying out through an
/// [OverflowBox] and clipping reproduces that, instead of painting
/// yellow-and-black overflow stripes over the very thing under review.
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
    // mounted navigator to push onto — the same sequencing the sibling
    // `SocialSignInSection` previews use.
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
///
/// The local [Navigator] is what makes it safe in a canvas: the sheet is a
/// `showModalBottomSheet` and needs a navigator to push onto, and a preview
/// must not assume the canvas supplies one it may mutate. The [MediaQuery]
/// override adds the home-indicator inset that a modern phone reports —
/// `showModalBottomSheet` only strips the TOP padding, so the bottom inset is
/// the sheet's own [SafeArea] to deal with.
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
///
/// The baseline every other state is read against, and the only state with
/// `matrix: true` — this widget is *nothing but* copy, so the AR card (does the
/// icon/title/body block mirror as one?) and the 200% card (how much of the
/// screen do three sentences take?) are the whole review.
///
/// Expect the 200% card of this matrix to overflow its box. That is the
/// widget, not the preview: the sheet measures 840dp at 200%, which is taller
/// than the phone screen it is presented on. [socialCollisionSheetLargeText]
/// shows the same thing clipped the way a device clips it.
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
///
/// 40dp of padding leaves a 280dp text column, and the headline goes from two
/// lines (56dp at 390dp) to three (84dp). It is worth its own state because the
/// headline is a bare `titleLarge` with no `maxLines`: it wraps silently, and
/// every element under it moves down — 380dp of content against 332dp at phone
/// width, on the smallest screen in the fleet.
@JeebPreview(
  group: 'auth',
  name: 'Narrowest phone · 320dp',
  size: _socialCollisionSheetNarrowBox,
)
Widget socialCollisionSheetNarrowPhone() =>
    _socialCollisionSheetHosted(width: 320);

/// The accessibility ceiling, shown inside a phone-sized window: 200% text.
///
/// The measured sheet is 840dp tall here — 60dp MORE than the 780dp a 390×844
/// phone can give a full-height modal sheet, and more still once the
/// home-indicator inset in [socialCollisionSheetPresented] is taken off. The
/// window clips exactly as the device does, so what this preview shows is the
/// real outcome: "Got it" sits below the bottom edge, and a user at 200% text
/// has no visible way to dismiss the block except dragging the sheet down.
///
/// The title alone takes four lines (224dp) at this scale, which is where most
/// of the growth comes from — it is the string to shorten first.
///
/// `matrix` is deliberately OFF here: the matrix's own 200% card would scale an
/// already-scaled subtree and render at 400%.
@JeebPreview(
  group: 'auth',
  name: 'Text at 200% · phone window',
  size: _socialCollisionSheetScreenBox,
)
Widget socialCollisionSheetLargeText() => _socialCollisionSheetInPhoneWindow(2);

/// The sheet as users actually meet it: pushed by `showSocialCollisionSheet`
/// over the registration screen, under the scrim, with a home-indicator inset
/// below it.
///
/// This is the only preview that exercises the production entry point, so it is
/// the one that covers the parts the body alone cannot show — the rounded top
/// edge, the scrim colour over a real page, and whether the dismiss CTA clears
/// the home indicator. The CTA is live: tapping it in the canvas pops the sheet
/// and leaves the stand-in page behind, which is exactly what
/// `SocialSignInSection` awaits before re-arming its buttons (JM-019).
@JeebPreview(
  group: 'auth',
  name: 'Presented over the sign-in screen',
  size: _socialCollisionSheetScreenBox,
)
Widget socialCollisionSheetPresented() => _socialCollisionSheetInModalRoute();
