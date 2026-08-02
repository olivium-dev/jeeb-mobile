import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'availability_status_block.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

const int _kCompactOnlineTitleMaxLines = 2;

class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.view,
    required this.onToggle,
  });

  static const Key rootKey = Key('availability-card-root');

  static const Key toggleKey = Key('availability-toggle-root');
  static const Key spinnerKey = Key('availability-toggle-spinner');

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isCompactOnline =>
      view.status.state == AvailabilityState.online && !view.isToggleInFlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      identifier: 'availability_card',
      container: true,
      explicitChildNodes: true,
      child: _isCompactOnline
          ? _CompactOnlineAvailability(onToggle: onToggle)
          : _FullAvailabilitySection(view: view, onToggle: onToggle),
    );
  }
}

class _CompactOnlineAvailability extends StatelessWidget {
  const _CompactOnlineAvailability({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: true,
      label: l10n.availabilityIndicatorSemanticOnline,
      child: DefaultTextStyle.merge(
        maxLines: _kCompactOnlineTitleMaxLines,
        overflow: TextOverflow.ellipsis,
        child: OmdsSwitchTile(
          key: AvailabilityCard.toggleKey,
          title: l10n.availabilityStatusOnline,
          value: true,
          activeColor: context.jeebRoles.success,
          dense: true,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.xSmall,
          ),
          onChanged: (_) => onToggle(),
        ),
      ),
    );
  }
}

class _FullAvailabilitySection extends StatelessWidget {
  const _FullAvailabilitySection({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      title: l10n.availabilityCardTitle,
      horizontalPadding: Spacing.medium,
      spacing: Spacing.twoXSmall,
      showDivider: false,
      content: view.isToggleInFlight
          ? _AvailabilityProgress(view: view)
          : _AvailabilitySwitchRow(view: view, onToggle: onToggle),
    );
  }
}

class _AvailabilitySwitchRow extends StatelessWidget {
  const _AvailabilitySwitchRow({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isOnline => view.status.state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: _isOnline,
      label: _semanticLabel(l10n),
      child: OmdsSwitchTile(
        key: AvailabilityCard.toggleKey,
        title: _title(l10n),
        subtitle: view.status.state == AvailabilityState.autoOffline
            ? l10n.availabilityAutoOfflineHint
            : null,
        value: _isOnline,
        activeColor: context.jeebRoles.success,
        contentPadding: EdgeInsets.zero,
        onChanged: (_) => onToggle(),
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (view.status.state) {
    AvailabilityState.online => l10n.availabilityStatusOnline,
    AvailabilityState.offline => l10n.availabilityStatusOffline,
    AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
  };

  String _semanticLabel(AppLocalizations l10n) => switch (view.status.state) {
    AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
    AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
    AvailabilityState.autoOffline =>
      l10n.availabilityIndicatorSemanticAutoOffline,
  };
}

class _AvailabilityProgress extends StatelessWidget {
  const _AvailabilityProgress({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AvailabilityStatusBlock(view: view)),
        const SizedBox(width: Spacing.small),
        const SizedBox(
          width: Sizes.fiveXLarge,
          height: Sizes.threeXLarge,
          child: Center(
            child: OmdsLoadingState(
              key: AvailabilityCard.spinnerKey,
              size: Sizes.large,
              padding: EdgeInsets.zero,
            ),
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
// Render tests: test/previews/jeeber_home/availability_card_preview_test.dart
// ===========================================================================
//
// Widget previews for [AvailabilityCard] — run with
// `flutter widget-preview start`.
//
// [AvailabilityCard] is a pure view over one [AvailabilityViewState]: no
// cubit, no gateway, no timer of its own. Every fixture below is a plain value
// object built by `_availabilityCardHosted`, so these previews are network-free
// by construction rather than merely by the guard in [jeebPreviewHost].
//
// The fixture shape mirrors `_viewState(...)` in
// `test/features/jeeber_home/availability_card_test.dart` (ready load phase, a
// delivery count, an in-flight flag) so the canvas and the widget test
// describe the same card.
//
// ## Why this widget needs a canvas
//
// It renders two structurally different layouts and the toggle flips between
// them:
//
// * ONLINE at rest is a compact `OmdsSwitchTile` — no section, no heading, no
//   supporting lines — with its copy clamped to two lines and ellipsized
//   (`_kCompactOnlineTitleMaxLines`).
// * OFFLINE, auto-offline and the in-flight frame are a full `OMDSSectionCard`
//   under an "Availability" heading.
//
// The card therefore changes shape *and* height under the user's thumb, and
// the two branches only make sense read against each other — which is what a
// canvas does and a widget test does not.
//
// ## Measured on this widget
//
// `AvailabilityCard` root height in logical px. Taken with the production
// Inter faces and the deterministic Arabic fallback loaded
// (`test/support/load_test_fonts.dart`), not the square test font, so these
// are device numbers rather than harness numbers:
//
// | state                      | 1.0× | EN 2.0× | AR 2.0× |
// |----------------------------|-----:|--------:|--------:|
// | Online (compact row)       |   64 |     112 |     113 |
// | Offline (full section)     |   76 |     100 |     101 |
// | Auto-offline (+ hint)      |   76 |     214 |     169 |
// | Toggling (offline → on)    |   68 |      92 |      93 |
// | Toggling (online, 3 jobs)  |   88 |     196 |     200 |
//
// Identical at 320 pt and 390 pt except where noted below. No `RenderFlex`
// overflow in any of the 40 combinations measured, and the in-flight spinner
// mirrors correctly (x∈[336,356] in EN, x∈[34,54] in AR at 390 pt).
//
// **Two things that table gives away, both worth opening the canvas for.**
//
// 1. At 200% text the "compact" online row (112 px) is TALLER than the full
//    offline section (100 px) it was designed to be smaller than. The density
//    win inverts exactly at the accessibility ceiling.
// 2. The online copy does not survive that ceiling — see
//    [availabilityCardOnline]. It is clamped, so it truncates instead of
//    growing, and the truncation eats the half of the sentence that carries
//    the state.
//
// The `size:` boxes below are those measured heights plus a little slack at
// real phone width (390 pt), not something roomy enough to look clean.

/// Phone width; clears the two resting layouts at 200% text (112 px / 100 px).
///
/// Deliberately ONE box for both, so the compact/full pair is read at the same
/// scale and the 200% height inversion above is visible rather than inferred.
const Size _availabilityCardRestingBox = Size(390, 130);

/// Phone width; clears the auto-offline section at 200% text (214 px).
const Size _availabilityCardHintBox = Size(390, 240);

/// Phone width; clears the bare progress frame at 200% text (92 px).
const Size _availabilityCardProgressBox = Size(390, 120);

/// Builds the card exactly the way `_JeeberHomeBody` does — the only
/// production caller — with a live `onToggle`, since the whole tile is the tap
/// target.
///
/// Always [AvailabilityLoadPhase.ready], mirroring `_viewState(...)` in the
/// widget test: the card is only mounted once the cubit has resolved its cold
/// start, so the shimmer and the load-error retry belong to the screen above
/// it and are not states of this widget.
Widget _availabilityCardHosted(
  AvailabilityState state, {
  int deliveries = 0,
  bool inFlight = false,
}) {
  return AvailabilityCard(
    view: AvailabilityViewState(
      loadPhase: AvailabilityLoadPhase.ready,
      status: AvailabilityStatus(
        state: state,
        activeDeliveryCount: deliveries,
      ),
      isToggleInFlight: inFlight,
    ),
    onToggle: () {},
  );
}

/// The state a working Jeeber sits in all day: online, at rest.
///
/// The deliberately compact branch — one `OmdsSwitchTile`, no
/// `OMDSSectionCard`, no "Availability" heading, and none of the supporting
/// lines the other states show. Read it against [availabilityCardOffline]
/// directly below: the missing heading is the design, not a dropped widget.
///
/// **Read the EN 200% rendering knowing this: the copy is truncated there.**
/// `_CompactOnlineAvailability` clamps its title to two lines with
/// `TextOverflow.ellipsis`, and at 200% text "You're online — receiving
/// requests" no longer fits. Measured, EN, by the width of the tile's text
/// slot:
///
/// | phone width | text slot | what the Jeeber reads              |
/// |-------------|----------:|------------------------------------|
/// | 320 pt      |    216 px | "You're online — receiving…"       |
/// | 390 pt      |    286 px | "You're online — receiving reque…" |
/// | 430 pt      |    326 px | full string, no ellipsis           |
///
/// So on every phone width below a 430 pt Pro Max, the accessibility ceiling
/// cuts the clause that says what being online actually *does*. Arabic escapes
/// it — `أنت متصل — تستقبل الطلبات` fits two lines at both 320 and 390 pt — so
/// this is an EN-only truncation that the AR rendering will not warn you about.
///
/// Nothing in `test/` sees it either: the two-line budget assertions in
/// `availability_card_test.dart` check the rendered *height* stays within two
/// lines, which an ellipsis satisfies by definition.
///
/// Also check here: the track must be the semantic success green from
/// `JeebColorRoles`, not the theme primary — in the AR RTL **dark** rendering
/// especially, where an on-track that reads as primary means the role lookup
/// fell back.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · compact row',
  size: _availabilityCardRestingBox,
)
Widget availabilityCardOnline() =>
    _availabilityCardHosted(AvailabilityState.online);

/// Offline by the Jeeber's own choice — the full section, switch OFF.
///
/// The structural opposite of [availabilityCardOnline], in the same size box:
/// heading, section padding, and a switch tile with `EdgeInsets.zero` content
/// padding rather than the compact tile's own insets.
///
/// Those two paddings currently cancel out — the compact tile insets itself by
/// `Spacing.medium` while the section insets the tile by `Spacing.medium` and
/// the tile by nothing — so the switch lands at the *same* x in both branches
/// (measured: trailing edge 16 px from the card edge in each). Put the two
/// cards side by side and check it stays that way: they arrive there by
/// different routes, so a change to either padding makes the thumb jump
/// sideways when a Jeeber toggles.
///
/// No auto-offline hint here on purpose: a Jeeber who turned themselves off is
/// not being warned about an idle timer.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · full section',
  size: _availabilityCardRestingBox,
)
Widget availabilityCardOffline() =>
    _availabilityCardHosted(AvailabilityState.offline);

/// The system took them offline — §G2's non-dismissible explanation.
///
/// The only state that renders a *subtitle* under the switch title
/// ("Auto-offline after 8 h idle"), so that being flipped off by the 8-hour
/// rule never reads as "the app forgot my toggle".
///
/// It is also the tallest resting layout by a wide margin at 200% text — 214 px
/// EN against 76 px at 1.0×, because title and subtitle both wrap to two lines
/// there. The AR rendering stops at 169 px, so the EN column is the one that
/// sets the box.
///
/// Check in the canvas: the subtitle is `bodySmall` on `onSurfaceVariant`, and
/// in the AR RTL **dark** rendering it has to stay readable against the dark
/// surface rather than going grey-on-grey.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Auto-offline · with idle hint',
  size: _availabilityCardHintBox,
)
Widget availabilityCardAutoOffline() =>
    _availabilityCardHosted(AvailabilityState.autoOffline);

/// Mid-toggle: the `PUT /api/availability/toggle` is in flight.
///
/// The switch is **gone**, not disabled — `_AvailabilityProgress` replaces it
/// with a spinner keyed `availability-toggle-spinner`, which is what makes the
/// frame tap-proof. Check the spinner sits in its fixed 56×40 slot at the
/// trailing edge, and that the slot mirrors in AR RTL (it does today: plain
/// `Row`, measured at x∈[336,356] EN and x∈[34,54] AR on a 390 pt box — a
/// regression to `Stack`/`Positioned` here would strand it on the left in
/// Arabic).
///
/// Also read what is NOT here: this branch drops the `availability_switch`
/// semantics node entirely, and the spinner carries no label or live region of
/// its own, so for the duration of the request a screen-reader user has no
/// toggle and no announcement that anything is happening.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggling · offline → online',
  size: _availabilityCardProgressBox,
)
Widget availabilityCardToggling() =>
    _availabilityCardHosted(AvailabilityState.offline, inFlight: true);

/// The densest state the card can reach: toggling OFF while online with work
/// already assigned.
///
/// `AvailabilityStatusBlock` keys its supporting lines off `status.isOnline`
/// and the status stays `online` until the gateway confirms, so this frame
/// stacks the "Updating…" headline, "3 active deliveries" and the idle hint
/// into the `Expanded` beside the spinner — three wrapping lines in ~290 pt of
/// width, 196 px tall at 200% text.
///
/// The layout ceiling of the whole widget, and the only preview that exercises
/// the AR `few` plural (`3 توصيلات نشطة`); the other counts route to different
/// ARB keys entirely.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggling · online, 3 deliveries',
  size: Size(390, 230),
)
Widget availabilityCardTogglingWithDeliveries() => _availabilityCardHosted(
      AvailabilityState.online,
      deliveries: 3,
      inFlight: true,
    );
