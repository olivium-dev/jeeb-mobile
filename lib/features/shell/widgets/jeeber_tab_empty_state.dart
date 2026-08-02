import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class JeeberTabEmptyState extends StatelessWidget {
  const JeeberTabEmptyState({
    super.key,
    required this.identifier,
    required this.icon,
    this.title,
    this.subtitle,
  });

  const JeeberTabEmptyState.dashboard({super.key})
      : identifier = dashboardIdentifier,
        icon = Icons.two_wheeler_outlined,
        title = null,
        subtitle = null;

  const JeeberTabEmptyState.earnings({super.key})
      : identifier = earningsIdentifier,
        icon = Icons.payments_outlined,
        title = null,
        subtitle = null;

  static const String dashboardIdentifier = 'jeeber_dashboard_empty_state';

  static const String earningsIdentifier = 'jeeber_earnings_empty_state';

  final String identifier;

  final IconData icon;

  final String? title;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: identifier,
      child: Center(
        child: OmdsEmptyState(
          icon: icon,
          title: title ?? l10n.becomeJeeberCardTitle,
          subtitle: subtitle ?? l10n.becomeJeeberCardSubtitle,
          buttonText: l10n.becomeJeeberCardCta,
          onButtonTap: () => _openBecomeJeeber(context),
        ),
      ),
    );
  }

  void _openBecomeJeeber(BuildContext context) {
    GoRouter.maybeOf(context)?.goNamed('kyc-status');
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/shell/jeeber_tab_empty_state_preview_test.dart
// ===========================================================================
//
// This is the body a NON-jeeber gets on the two additive jeeber tabs
// (consolidated-lessons §12: the tabs are always present, only their body
// depends on `available_roles`). It has no cubit, no repository and no
// arguments beyond four values, so there is nothing to seed and nothing to
// fake — these previews are network-free because there is nothing to fetch,
// not merely because [jeebPreviewHost] guards them. Its one side effect is the
// CTA, and that is already written to degrade: `GoRouter.maybeOf(context)?`
// is a no-op in a router-less host, which is exactly what a preview is.
//
// What varies between states is therefore the **copy** and the **box**, and
// the box is the half that breaks. The widget is
// `Semantics > Center > OmdsEmptyState`, and `OmdsEmptyState` is a bare
// `Column(mainAxisSize: min)` — 24pt padding a side, an icon whose size is a
// hard-coded 80 logical px, then title / subtitle / [FilledButton] — with no
// scroll view anywhere. It cannot shrink and it cannot scroll: hand it less
// height than its content and it paints the overflow stripe and clips the CTA,
// which is the last child.
//
// The floors, measured rather than guessed (height of the empty-state column,
// English then Arabic):
//
// | copy            | width | 100%      | 200%       |
// |-----------------|-------|-----------|------------|
// | become-a-jeeber | 390   | 360 / 328 | 568 / 504  |
// | become-a-jeeber | 320   | 380 / 328 | **704** / 576 |
// | kyc resubmit    | 390   | 420 / 400 | 872 / 792  |
// | kyc pending     | 390   | 440 / 420 | 952 / 848  |
//
// Arabic is shorter in every single cell — the ARB copy is more compact than
// the English — so English is the harder locale here and an Arabic-first spot
// check would miss all of it.
//
// Short heights are declared to the canvas via the annotation `size` and never
// baked into the tree, following `jeeber_unregistered_view_preview.dart`: a
// height compiled into the widget would make the render suite throw on every
// run instead of on the case under review. Width IS baked where the state is
// about a narrow device, because a 320pt phone is a real device and a state
// that is only compact in the canvas is not a state.

/// The slot a jeeber tab hands this widget on a modern phone: full body height
/// once the status bar and the bottom nav bar are gone.
const Size _jeeberTabEmptyStatePhoneBody = Size(390, 680);

/// The narrowest device the app still supports.
const Size _jeeberTabEmptyStateCompactBox = Size(320, 600);

/// A short body — a small phone in a locale with a tall system font, or any
/// host that keeps chrome above and below.
const Size _jeeberTabEmptyStateShortBody = Size(390, 420);

/// One state, optionally pinned to a device width.
///
/// `height: double.infinity` against the loose constraints [Center] passes down
/// keeps the height bounded, so the inner [Column] still gets a real ceiling to
/// overflow against rather than an unbounded one.
Widget _jeeberTabEmptyStateHosted(Widget state, {double? width}) {
  if (width == null) return state;
  return Center(
    child: SizedBox(width: width, height: double.infinity, child: state),
  );
}

/// The `title` / `subtitle` overrides take raw [String]s, not ARB keys, so a
/// caller needs a [BuildContext] to stay localized — and a preview function has
/// none. Hence the [Builder]: it keeps the override states rendering real
/// Arabic in the `AR RTL dark` pane instead of English literals, which is the
/// only way those panes say anything useful.
Widget _jeeberTabEmptyStateWithCopy({
  required String identifier,
  required IconData icon,
  required String Function(AppLocalizations) title,
  required String Function(AppLocalizations) subtitle,
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return JeeberTabEmptyState(
        identifier: identifier,
        icon: icon,
        title: title(l10n),
        subtitle: subtitle(l10n),
      );
    },
  );
}

/// Exactly how `shell_screen.dart` builds the Dashboard tab for a user whose
/// `available_roles` has no `jeeber` — the become-a-jeeber invitation standing
/// in for the availability toggle + request feed.
///
/// This is the single most-seen state of the widget: every client account in
/// the app renders it on two of its five tabs. Fits comfortably at 390×680 in
/// both locales, and still fits at 200% text (568pt of 680pt).
@JeebPreview(
  group: 'shell',
  name: 'Dashboard tab · non-jeeber',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateDashboard() =>
    _jeeberTabEmptyStateHosted(const JeeberTabEmptyState.dashboard());

/// The Earnings tab for the same user — the SAME invitation, deliberately.
///
/// Pixel-identical to [jeeberTabEmptyStateDashboard] apart from the icon
/// (`payments_outlined` vs `two_wheeler_outlined`), because the two tabs share
/// one become-a-jeeber funnel rather than offering two different pitches. The
/// difference that does matter is invisible here and asserted in the render
/// suite instead: the screen-level Semantics id, `jeeber_earnings_empty_state`
/// vs `jeeber_dashboard_empty_state`. QA's Maestro / adb ui-tree assertions key
/// off those ids to prove which tab a non-jeeber actually landed on, so a
/// copy-paste that gave both tabs the same id would make the two flows
/// indistinguishable while looking perfect on screen.
@JeebPreview(
  group: 'shell',
  name: 'Earnings tab · non-jeeber',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateEarnings() =>
    _jeeberTabEmptyStateHosted(const JeeberTabEmptyState.earnings());

/// **The state that breaks.** The production invitation on a 320pt phone.
///
/// Width is baked, so this is genuinely narrow rather than merely narrow in the
/// canvas. At 100% it is fine — 380pt of content in a 600pt body, only 20pt
/// worse than at 390pt wide. Open the `EN 200% text` pane: 24pt of padding a
/// side leaves 272pt of text width, "Become a Jeeber" wraps to two lines and
/// the subtitle to four, and the column's floor jumps to **704pt** against the
/// 600pt body — it **overflows by 104pt**, and the child that falls off the
/// bottom is the [FilledButton]. A user on a small phone with large text is
/// therefore invited to become a jeeber and given no way to accept: the CTA is
/// clipped, and nothing scrolls to reach it.
///
/// The `AR RTL dark` pane does NOT reproduce it — Arabic needs 576pt and fits —
/// so this is an English-only accessibility break. The fix belongs to the
/// widget (wrap the [Center] in a `SingleChildScrollView`), not to its two
/// hosts, which is why it is previewed here.
///
/// 320pt is the app's stated floor; the Galaxy S22 the team tests on is 360pt
/// wide, where the same copy needs 568pt and survives an ordinary body. That is
/// exactly why this needs a preview — the test device does not show it.
@JeebPreview(
  group: 'shell',
  name: 'Compact 320pt phone',
  size: _jeeberTabEmptyStateCompactBox,
)
Widget jeeberTabEmptyStateCompactPhone() => _jeeberTabEmptyStateHosted(
      const JeeberTabEmptyState.dashboard(),
      width: 320,
    );

/// The override API, driven with real ARB copy: a KYC applicant who has been
/// asked to resubmit.
///
/// `title` / `subtitle` are exposed and completely unused by production — the
/// shell only ever builds the two named constructors — so this is the untested
/// half of the widget's public surface. It is not hypothetical: an applicant
/// mid-KYC still has no `jeeber` role, so the shell still renders this widget
/// at them, and re-pitching "Become a Jeeber / Start now" to someone who
/// already applied is the obvious next caller.
///
/// Longest plausible content, and the state that shows what the overrides cost:
/// a two-line title plus a three-line subtitle needs 420pt at 100% (fine at
/// 680pt) but **872pt at 200%**, so the `EN 200% text` pane **overflows by
/// 192pt** on an ordinary phone body — no narrow device required. Arabic
/// overflows by 112pt. Whoever wires this up needs the scroll view first.
@JeebPreview(
  group: 'shell',
  name: 'KYC resubmit copy',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateKycResubmit() => _jeeberTabEmptyStateWithCopy(
      identifier: JeeberTabEmptyState.earningsIdentifier,
      icon: Icons.upload_file_outlined,
      title: (AppLocalizations l10n) => l10n.kycStatusResubmitTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycStatusResubmitBody,
    );

/// The longest ARB copy in a 420pt body — the only state that clips at **100%**
/// text.
///
/// The `EN light` pane overflows by 20pt with the system font untouched, which
/// is what makes this one worth keeping separate from
/// [jeeberTabEmptyStateCompactPhone]: every other break here needs 200% text to
/// appear, so a reviewer who only skims the default pane would call the widget
/// healthy. Arabic needs exactly 420pt and fits to the pixel, so the AR pane is
/// clean and the defect is English-only again. At 200% the same box overflows
/// by 532pt.
///
/// 420pt is not a strawman: it is a phone in landscape, a small phone with the
/// system font one notch up, or any host that keeps chrome above and below.
/// Note that the height is declared to the canvas only and never baked, so the
/// render suite (which pumps at 800×600) sees a widget that fits and stays
/// green — the overflow shows up where a human is looking at it.
@JeebPreview(
  group: 'shell',
  name: 'KYC pending · short body',
  size: _jeeberTabEmptyStateShortBody,
)
Widget jeeberTabEmptyStateKycPendingShortBody() =>
    _jeeberTabEmptyStateWithCopy(
      identifier: JeeberTabEmptyState.dashboardIdentifier,
      icon: Icons.hourglass_top_outlined,
      title: (AppLocalizations l10n) => l10n.kycStatusPendingTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycStatusPendingBody,
    );
