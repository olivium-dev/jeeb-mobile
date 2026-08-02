import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import 'super_login_picker.dart';
import 'super_login_sheet.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Debug-only entry points; kDebugMode-gated, dead-code-eliminated from release.
bool superLoginBlockedByMissingPasscode(BuildContext context) {
  if (!kDebugMode || AppConfig.superAdminPassCode.isNotEmpty) return false;
  // EXEMPT: OMDS exports no standalone snackbar; ScaffoldMessenger is approved pattern.
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        key: const Key('superLogin.missingPasscode'),
        content: const Text(
          'Dev build missing SuperAdmin passcode '
          '(JEEB_SUPERADMIN_PASSCODE). Cannot super-login.',
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  return true;
}

Future<void> openSuperLogin(
  BuildContext context, {
  required Future<void> Function() onAuthenticated,
}) async {
  if (superLoginBlockedByMissingPasscode(context)) return;
  final session = context.read<SessionCubit?>();
  final signedIn = await showSuperLoginSheet(
    context,
    session: session,
    initialUserId: AppConfig.devSuperLoginUserId,
    initialPasscode: AppConfig.superAdminPassCode,
  );
  if (signedIn != true || !context.mounted) return;
  await onAuthenticated();
}

Future<void> openSuperLoginPlus(
  BuildContext context, {
  required Future<void> Function() onAuthenticated,
}) async {
  if (superLoginBlockedByMissingPasscode(context)) return;
  final session = context.read<SessionCubit?>();
  final user = await showSuperLoginPicker(context);
  if (user == null || !context.mounted) return;
  final signedIn = await showSuperLoginSheet(
    context,
    session: session,
    initialUserId: user.userId,
    initialPasscode: AppConfig.superAdminPassCode,
  );
  if (signedIn != true || !context.mounted) return;
  await onAuthenticated();
}

class SuperLoginEntryPoints extends StatelessWidget {
  const SuperLoginEntryPoints({
    super.key,
    required this.onSuperLogin,
    required this.onSuperLoginPlus,
  });

  final VoidCallback onSuperLogin;
  final VoidCallback onSuperLoginPlus;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuperLoginLink(onTap: onSuperLogin),
        const SizedBox(height: Spacing.medium),
        _SuperLoginPlusLink(onTap: onSuperLoginPlus),
      ],
    );
  }
}

class _SuperLoginLink extends StatelessWidget {
  const _SuperLoginLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: '_super_login_link',
        button: true,
        label: l10n.superLoginTitle,
        child: GestureDetector(
          key: const Key('login.superLogin'),
          onTap: onTap,
          child: Text(
            l10n.superLoginTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}

class _SuperLoginPlusLink extends StatelessWidget {
  const _SuperLoginPlusLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        identifier: 'super_login_plus_button',
        button: true,
        label: l10n.superLoginPlusTitle,
        child: GestureDetector(
          key: const Key('login.superLoginPlus'),
          onTap: onTap,
          child: Text(
            l10n.superLoginPlusTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary
                      .withValues(alpha: UIConstants.opacityMedium),
                  decoration: TextDecoration.underline,
                ),
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
// Render tests: test/previews/registration/super_login_entry_points_preview_test.dart
// ===========================================================================
//
// [SuperLoginEntryPoints] takes two callbacks and nothing else. It has no
// cubit, no repository, no future and no asset load — it renders two localized
// strings in a `Column`, so "empty / loading / error" do not exist here and
// these previews are network-free because there is nothing to fetch, not merely
// because [jeebPreviewHost] guards the wire.
//
// Its states are therefore HOST states: the width the login screen gives it,
// the ambient text scale, the reading direction, and the chrome around it. Each
// preview below pins one of those, because the widget itself pins none of them.
//
// Two branches deliberately have NO preview:
//
//  * **the release branch.** `build` returns `SizedBox.shrink()` when
//    `!kDebugMode` (FR-P0-4 / defect D2). The canvas and `flutter test` are both
//    debug builds, so every card below shows the debug branch; the release state
//    is the absence of the widget and cannot be drawn.
//  * **the missing-passcode snackbar.** [superLoginBlockedByMissingPasscode]
//    only fires when `AppConfig.superAdminPassCode` is empty, and that getter
//    falls back to a committed dev constant whenever `kDebugMode` — so in every
//    context a preview can run, the guard returns false. Reaching it would need
//    a seam this file does not have, and the preview rules forbid adding one.
//
// **About the captions.** The widget renders the SAME two strings in every
// state — its content is a function of the locale, not of any input — so
// `find.text` on the widget's own output cannot tell one preview from another.
// Each preview therefore carries a one-line caption naming the state, used by
// the render test only to *address* a state. The assertions that prove the
// states differ are measured in
// `test/previews/registration/super_login_entry_points_preview_test.dart`: the
// hit-box height, the gap between the two links, and the laid-out link centre.
//
// Two things these previews surface, both in the widget rather than in the
// previews — see the notes on the individual states:
//
//  * each link's hit area is its `Text` box (a bare [GestureDetector] with no
//    padding and no minimum), roughly 16pt tall against the 48pt WCAG 2.5.5 /
//    Material minimum — see [superLoginEntryPointsTapTargets];
//  * the `Spacing.medium` separator between the two links is a fixed
//    [SizedBox], so at 200% text the labels double and the gap does not —
//    compare [superLoginEntryPointsBare] and [superLoginEntryPointsLargeText].

/// A 390pt phone column minus the `Spacing.medium` gutters a form screen leaves
/// on both sides. The widget adds no horizontal padding of its own — whatever
/// the host gives it is exactly what the two links get.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose: the
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface, so a column left to fill its host would wrap on a phone and not
/// wrap under test.
const double _superLoginEntryPointsColumnWidth = 358;

/// The narrow end: a small device, or an auth form that is already indented.
/// The English labels still fit on one line here; the Arabic ones do not.
const double _superLoginEntryPointsNarrowWidth = 160;

/// Column width for the tap-target probe, sized so the 48pt reference square
/// and the links sit side by side on a phone.
const double _superLoginEntryPointsProbeWidth = 200;

/// WCAG 2.5.5 (AAA) / Material's minimum interactive size, in logical pixels.
const double _superLoginEntryPointsMinTapTarget = 48;

/// Canvas box for the production placement. Tall enough that the 200% rendering
/// of the matrix still fits — a box that clipped it would report a fixture
/// overflow rather than anything about the widget.
const Size _superLoginEntryPointsFooterBox = Size(390, 340);

/// Canvas box for the narrow column: narrow, and tall because the Arabic labels
/// wrap several times inside 160pt at 200%.
const Size _superLoginEntryPointsNarrowBox = Size(240, 460);

/// Canvas box for the pinned-200% state.
const Size _superLoginEntryPointsScaledBox = Size(390, 260);

/// Canvas box for the tap-target probe and the bare widget.
const Size _superLoginEntryPointsProbeBox = Size(390, 180);

/// Renders [child] above a caption naming the state under review.
///
/// The caption is preview scaffolding, not widget output — see the library
/// doc. It sits OUTSIDE any text-scale override the state applies, so the
/// pinned-200% card scales the links under review and not the label describing
/// them.
Widget _superLoginEntryPointsHosted(String caption, Widget child) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: Spacing.medium),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// The widget under review in a column [width] wide, wired to no-op callbacks.
///
/// A preview never navigates: the real callbacks open a modal sheet against the
/// live gateway, which is exactly what a canvas must not do.
Widget _superLoginEntryPointsSubject({required double width}) => SizedBox(
      width: width,
      child: SuperLoginEntryPoints(
        onSuperLogin: () {},
        onSuperLoginPlus: () {},
      ),
    );

/// Stand-in for the login screen's primary CTA, so the links are reviewed where
/// they actually sit: immediately under the button the user is aiming for.
///
/// Deliberately blank. Fake copy here would read as an unlocalized string in the
/// AR rendering of the matrix, which is the one thing that rendering is for.
class _SuperLoginEntryPointsCtaPlaceholder extends StatelessWidget {
  const _SuperLoginEntryPointsCtaPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: _superLoginEntryPointsMinTapTarget,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: OmdsBorderRadius.large,
        ),
      );
}

/// A 48 × 48 reference square: the minimum interactive size a touch target is
/// supposed to have, drawn to scale next to targets that do not have it.
class _SuperLoginEntryPointsMinTargetSquare extends StatelessWidget {
  const _SuperLoginEntryPointsMinTargetSquare();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('superLoginEntryPoints.minTargetSquare'),
      width: _superLoginEntryPointsMinTapTarget,
      height: _superLoginEntryPointsMinTapTarget,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.tertiary),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '48',
            style: TextStyle(fontSize: 10, color: colorScheme.tertiary),
          ),
        ),
      ),
    );
  }
}

/// The production placement: both links stacked directly under the login CTA,
/// in the column width the login screen gives them.
///
/// The state to compare across the matrix rather than admire in EN light:
///
///  * **AR RTL dark** — there is nothing to mirror (every child is a [Center],
///    the separator is a symmetric [SizedBox], and there is no
///    `EdgeInsets.only` anywhere in the widget), so this rendering is really
///    about the copy: `superLoginPlusTitle` is "Super user login plus" in EN and
///    "تسجيل دخول المستخدم الخارق بلس" in AR, half again as wide, and the link
///    ink is `primary` at `UIConstants.opacityMedium` over the dark surface.
///  * **EN 200% text** — the labels double while the `Spacing.medium` gap
///    between them stays 16pt, so two 48pt-tall lines of underlined text end up
///    closer together than either is tall. Measured in the render test.
///
/// The debug links look exactly like a shipped secondary action here, which is
/// the point of reviewing them in place: nothing but the `kDebugMode` gate
/// distinguishes them from a real "forgot password" affordance.
@JeebPreview(
  group: 'registration',
  name: 'Login footer (production placement)',
  size: _superLoginEntryPointsFooterBox,
  matrix: true,
)
Widget superLoginEntryPointsLoginFooter() => _superLoginEntryPointsHosted(
      'Login screen footer · under the CTA',
      SizedBox(
        width: _superLoginEntryPointsColumnWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _SuperLoginEntryPointsCtaPlaceholder(),
            const SizedBox(height: Spacing.medium),
            SuperLoginEntryPoints(
              onSuperLogin: () {},
              onSuperLoginPlus: () {},
            ),
          ],
        ),
      ),
    );

/// The narrow ceiling: 160pt of column, which is what is left on a small device
/// inside an already-indented form.
///
/// The second state worth seeing as a matrix, for one reason: the English
/// labels still fit on a single line at 160pt and the Arabic ones do not, so
/// the EN light card looks settled while the AR card is a three-line block of
/// underlined text. Neither link ellipsizes — [Text] with no `maxLines` wraps —
/// so this degrades rather than truncating, but the two affordances stop
/// reading as two.
@JeebPreview(
  group: 'registration',
  name: 'Narrow column (160pt)',
  size: _superLoginEntryPointsNarrowBox,
  matrix: true,
)
Widget superLoginEntryPointsNarrowColumn() => _superLoginEntryPointsHosted(
      'Narrow column · 160pt',
      _superLoginEntryPointsSubject(
        width: _superLoginEntryPointsNarrowWidth,
      ),
    );

/// The accessibility ceiling, pinned into the fixture so it is reviewable
/// without the matrix and assertable in the render test.
///
/// `Spacing.medium` between the two links is a fixed [SizedBox]: at 200% the
/// labels roughly double and the separation does not move at all. The two
/// underlined blocks converge until they read as one paragraph — and since each
/// link's hit area is its own text box (see [superLoginEntryPointsTapTargets]),
/// the two targets get closer without getting bigger.
@JeebPreview(
  group: 'registration',
  name: 'Text scale 200%',
  size: _superLoginEntryPointsScaledBox,
)
Widget superLoginEntryPointsLargeText() => _superLoginEntryPointsHosted(
      'Text scale 200% · gap stays 16pt',
      MediaQuery.withClampedTextScaling(
        minScaleFactor: 2,
        maxScaleFactor: 2,
        child: _superLoginEntryPointsSubject(
          width: _superLoginEntryPointsColumnWidth,
        ),
      ),
    );

/// The state that breaks for the users this widget has: the hit areas, drawn
/// next to the 48 × 48 square they are supposed to fill.
///
/// Each link is a bare [GestureDetector] wrapped around a `bodySmall` [Text] —
/// no [IconButton], no [InkWell], no padding, no `MaterialTapTargetSize` floor.
/// `deferToChild` hit testing means the tappable region is exactly the glyph
/// box: about 16pt tall, a third of the minimum, and the two of them sit 16pt
/// apart. Nothing in the canvas shows this on its own, which is why the
/// reference square is drawn beside it and the box is measured in the render
/// test.
///
/// It is debug-only UI, so this is a nuisance rather than a shipped defect —
/// but it is a nuisance on every mis-tap during a demo, and the fix is one
/// `Padding` inside the [GestureDetector].
@JeebPreview(
  group: 'registration',
  name: 'Hit area vs the 48dp minimum',
  size: _superLoginEntryPointsProbeBox,
)
Widget superLoginEntryPointsTapTargets() => _superLoginEntryPointsHosted(
      'Hit area vs the 48dp minimum',
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const _SuperLoginEntryPointsMinTargetSquare(),
          const SizedBox(width: Spacing.medium),
          _superLoginEntryPointsSubject(
            width: _superLoginEntryPointsProbeWidth,
          ),
        ],
      ),
    );

/// The widget alone on the plain surface, at the width the login screen gives
/// it and at 1.0 text scale.
///
/// The baseline every other state is measured against — link height, gap and
/// centre are all read off this one in the render test — and the fastest way to
/// see what the widget actually is: two underlined labels in `primary` at 60%
/// opacity, with no container, no icon and no separator between them.
@JeebPreview(
  group: 'registration',
  name: 'Bare on surface (baseline)',
  size: _superLoginEntryPointsProbeBox,
)
Widget superLoginEntryPointsBare() => _superLoginEntryPointsHosted(
      'Bare widget on surface · baseline',
      _superLoginEntryPointsSubject(
        width: _superLoginEntryPointsColumnWidth,
      ),
    );
