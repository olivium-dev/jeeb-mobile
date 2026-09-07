import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import 'super_login_picker.dart';
import 'super_login_sheet.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Dev-Tool operator copy: English on purpose, and never in the customer ARB
/// (COPY-30). This whole file is `kDebugMode`-gated.
const String _kMissingPasscodeMessage =
    'Dev build missing SuperAdmin passcode '
    '(JEEB_SUPERADMIN_PASSCODE). Cannot super-login.';

/// Debug-only entry points; kDebugMode-gated, dead-code-eliminated from release.
bool superLoginBlockedByMissingPasscode(BuildContext context) {
  if (!kDebugMode || AppConfig.superAdminPassCode.isNotEmpty) return false;
  showJeebSnack(
    context,
    message: _kMissingPasscodeMessage,
    identifier: 'super_login_missing_passcode_snack',
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
            // Periwinkle, not `primary`: under Midnight `primary` IS the
            // orange, and a dev link is not a CTA (§2.2).
            style: context.jeebText.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.onSurfaceVariant,
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
            // Periwinkle, not `primary`: under Midnight `primary` IS the
            // orange, and a dev link is not a CTA (§2.2).
            style: context.jeebText.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// ===========================================================================

/// A 390pt phone column minus the `Spacing.medium` gutters a form screen leaves
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
const Size _superLoginEntryPointsFooterBox = Size(390, 340);

/// Canvas box for the narrow column: narrow, and tall because the Arabic labels
/// wrap several times inside 160pt at 200%.
const Size _superLoginEntryPointsNarrowBox = Size(240, 460);

/// Canvas box for the pinned-200% state.
const Size _superLoginEntryPointsScaledBox = Size(390, 260);

/// Canvas box for the tap-target probe and the bare widget.
const Size _superLoginEntryPointsProbeBox = Size(390, 180);

/// Renders [child] above a caption naming the state under review.
Widget _superLoginEntryPointsHosted(String caption, Widget child) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: Spacing.medium),
          Builder(
            builder: (BuildContext context) => Text(
              caption,
              textAlign: TextAlign.center,
              style: context.jeebText.caption,
            ),
          ),
        ],
      ),
    );

/// The widget under review in a column [width] wide, wired to no-op callbacks.
Widget _superLoginEntryPointsSubject({required double width}) => SizedBox(
      width: width,
      child: SuperLoginEntryPoints(
        onSuperLogin: () {},
        onSuperLoginPlus: () {},
      ),
    );

/// Stand-in for the login screen's primary CTA, so the links are reviewed where
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
          border: Border.all(color: colorScheme.error),
          borderRadius: OmdsBorderRadius.twoXSmall,
        ),
        child: Center(
          child: Text(
            '48',
            style: context.jeebText.label.copyWith(color: colorScheme.error),
          ),
        ),
      ),
    );
  }
}

/// The production placement: both links stacked directly under the login CTA,
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
