import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// T-MOB-027: Entry-point card surfaced on the Profile/Settings screen for
/// Client users who want to take on the Jeeber role.
///
/// Visibility rule: hidden once [isAlreadyJeeber] is true (i.e. the user's
/// `available_roles` already includes Jeeber).
///
/// Tapping the card or its CTA calls [onTap], which the host wires to the
/// KYC flow (`/profile/kyc`).
///
/// AC4: the card is announced as 'Become a Jeeber, double tap to start' via
/// [l10n.becomeJeeberCardSemantic].
class BecomeJeeberCard extends StatelessWidget {
  const BecomeJeeberCard({
    super.key,
    required this.onTap,
    this.isAlreadyJeeber = false,
  });

  static const Key rootKey = Key('become-jeeber-card-root');
  static const Key ctaKey = Key('become-jeeber-card-cta');

  /// Whether the user already has the Jeeber role. When true, the card is
  /// hidden entirely per AC2.
  final bool isAlreadyJeeber;

  /// Invoked when the user taps the card or its CTA. The host navigates to
  /// the KYC flow (T-MOB-013).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isAlreadyJeeber) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: rootKey,
      identifier: 'become_jeeber_card_cta',
      label: l10n.becomeJeeberCardSemantic,
      button: true,
      container: true,
      child: ExcludeSemantics(
        child: _BecomeJeeberCardBody(l10n: l10n, onTap: onTap),
      ),
    );
  }
}

class _BecomeJeeberCardBody extends StatelessWidget {
  const _BecomeJeeberCardBody({
    required this.l10n,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: _CardSurface(
        colorScheme: colorScheme,
        onTap: onTap,
        child: _CardContent(
          l10n: l10n,
          onTap: onTap,
          colorScheme: colorScheme,
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.colorScheme,
    required this.onTap,
    required this.child,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: OmdsBorderRadius.large,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.large,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: child,
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.l10n,
    required this.onTap,
    required this.colorScheme,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CardIcon(colorScheme: colorScheme),
        const SizedBox(width: Spacing.medium),
        Expanded(child: _CardText(l10n: l10n)),
        OmdsPrimaryButton(
          key: BecomeJeeberCard.ctaKey,
          text: l10n.becomeJeeberCardCta,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: Sizes.threeXLarge / 2,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.delivery_dining,
        color: colorScheme.onPrimaryContainer,
        size: Sizes.twoXLarge,
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const _CardText({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.becomeJeeberCardTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          l10n.becomeJeeberCardSubtitle,
          style: theme.textTheme.bodySmall,
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
// Render tests: test/previews/settings/become_jeeber_card_preview_test.dart
// ===========================================================================
//
// Widget previews for [BecomeJeeberCard] — run with
// `flutter widget-preview start`.
//
// The card (T-MOB-027) takes exactly two inputs: an `onTap` and the boolean
// [BecomeJeeberCard.isAlreadyJeeber]. Its copy is fixed by the ARB, so there
// is no data to seed and nothing to fake — no cubit, no repository, no
// network. **Every state below is a LAYOUT state**, and layout is precisely
// where this widget fails: its body is one unwrapped [Row] of
// `avatar + Expanded(text) + OmdsPrimaryButton`, and neither the avatar
// (`Sizes.threeXLarge`) nor the button (which sizes to its label, never
// shrinks) yields a single pixel. Everything the card loses comes out of the
// text column.
//
// Measured at 1× text scale, English, card width = available width:
//
// | width | text column | title lines | card height |
// |-------|-------------|-------------|-------------|
// | 320   | 41 pt       | 7           | 412 pt      |
// | 390   | 111 pt      | 3           | 204 pt      |
// | 700   | 242 pt      | 1           | 96 pt       |
//
// So the ~80 pt design is only ever achieved on a tablet; on a real phone the
// card is a 204 pt slab with a three-line title. The 200%-text rendering of
// the matrix is worse still and is the reason these previews exist — see the
// note on [becomeJeeberCardPhone] and the regression guard in
// `test/previews/settings/become_jeeber_card_preview_test.dart`.
//
// Each preview pins its own width instead of leaving it to the canvas [Size].
// The canvas honours `size`, but the render tests pump onto a fixed 800 × 600
// surface — a 320 pt state that only asked for a 320 pt canvas would be
// rendered at 800 pt under test and silently become the same widget as the
// default one.

/// A typical phone — the width the card is designed against.
const double _becomeJeeberCardPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen and the
/// small Android estate). This is the card's squeeze point.
const double _becomeJeeberCardNarrowPhoneWidth = 320;

/// Tablet / landscape: the only width at which the card's single [Row] has room
/// for the layout its design implies.
const double _becomeJeeberCardWideWidth = 700;

/// 390 pt wide, tall enough for the measured 204 pt card plus breathing room.
const Size _becomeJeeberCardPhoneBox = Size(_becomeJeeberCardPhoneWidth, 240);

/// 320 pt wide. Deliberately 440 pt tall: the card really is 412 pt here, and a
/// box that hid that would hide the bug.
const Size _becomeJeeberCardNarrowBox = Size(
  _becomeJeeberCardNarrowPhoneWidth,
  440,
);

/// 700 pt wide, and only 140 pt tall — because at this width the card finally
/// collapses to 96 pt.
const Size _becomeJeeberCardWideBox = Size(_becomeJeeberCardWideWidth, 140);

/// Phone width, sized for two neighbour rows and no card.
const Size _becomeJeeberCardHiddenBox = Size(_becomeJeeberCardPhoneWidth, 180);

/// Pins the width the card is laid out against, so the canvas and the render
/// tests see the same line breaks. Top-aligned so the card keeps its natural
/// height instead of being centred in whatever box it is given.
class _BecomeJeeberCardViewport extends StatelessWidget {
  const _BecomeJeeberCardViewport({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(width: width, child: child),
    );
  }
}

/// Preview-only stand-in for the settings rows that sit under the card in
/// `ProfileTab`.
///
/// It exists for one state — [becomeJeeberCardAlreadyJeeber] — where the card
/// renders `SizedBox.shrink()`. Without a neighbour, that state is an empty
/// canvas that proves nothing: an empty canvas is also what a crashed preview,
/// a mis-wired fixture, or a deleted widget looks like. With neighbours, the
/// eye (and the render test) can see the list close up around the gap.
///
/// The labels are intentionally scaffolding-English, not ARB keys — they are
/// not part of the widget under review, and translating them would suggest
/// they are.
class _BecomeJeeberCardNeighbourRow extends StatelessWidget {
  const _BecomeJeeberCardNeighbourRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

Widget _becomeJeeberCardHosted({
  required double width,
  bool isAlreadyJeeber = false,
}) {
  return _BecomeJeeberCardViewport(
    width: width,
    child: BecomeJeeberCard(
      isAlreadyJeeber: isAlreadyJeeber,
      onTap: () {},
    ),
  );
}

/// The shipping state: a client on a normal phone.
///
/// This is the default reading, and it is already wrong. The text column is
/// 111 pt, so "Become a Jeeber" wraps to three lines and the card is 204 pt
/// tall — roughly a quarter of the Profile tab — at 1× text scale.
///
/// **Open the `EN 200% text` rendering of this preview.** At 200% the CTA label
/// alone grows to ~253 pt, the avatar and its gutter take another ~72 pt, and
/// the `Expanded` text column is driven to **zero width**: the title and
/// subtitle are not just cropped, they are gone, and the [Row] still overflows
/// by 15 pt. A card whose entire message vanishes at the accessibility ceiling
/// is the finding this section was written to make visible.
@JeebPreview(
  group: 'settings',
  name: 'Client · 390',
  size: _becomeJeeberCardPhoneBox,
)
Widget becomeJeeberCardPhone() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardPhoneWidth);

/// The squeeze point: the same card at 320 pt.
///
/// 70 pt narrower than [becomeJeeberCardPhone], and every one of those pixels
/// is taken from the text: the column collapses to 41 pt, "Become a Jeeber"
/// wraps to SEVEN lines, and the card grows to 412 pt tall — taller than it is
/// wide. At 200% text this state overflows by 85 pt.
@JeebPreview(
  group: 'settings',
  name: 'Narrow 320',
  size: _becomeJeeberCardNarrowBox,
)
Widget becomeJeeberCardNarrowPhone() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardNarrowPhoneWidth);

/// The control: the same widget, same copy, at tablet width.
///
/// Title on one line, card 96 pt tall — the design as drawn. Keeping this state
/// next to the two phone states is what turns "the card looks cramped" into a
/// diagnosis: the copy is not too long, the [Row] simply has no wrap or
/// [Wrap]/[Column] fallback, so the fix belongs in the layout and not in the
/// ARB.
@JeebPreview(
  group: 'settings',
  name: 'Wide 700',
  size: _becomeJeeberCardWideBox,
)
Widget becomeJeeberCardWide() =>
    _becomeJeeberCardHosted(width: _becomeJeeberCardWideWidth);

/// T-MOB-027 AC2, made visible: once the user's `available_roles` already
/// include Jeeber, the card must disappear ENTIRELY — not grey out, not say
/// "you are already a jeeber".
///
/// Worth its own preview because the widget returns `SizedBox.shrink()`, so a
/// regression here is silent: a card that failed to build and a card that
/// correctly hid itself look identical. The neighbour rows are the control —
/// they must still be there, and the gap between them must close completely
/// (no leftover padding, no 8 pt ghost).
@JeebPreview(
  group: 'settings',
  name: 'Already a Jeeber · hidden',
  size: _becomeJeeberCardHiddenBox,
)
Widget becomeJeeberCardAlreadyJeeber() => _BecomeJeeberCardViewport(
      width: _becomeJeeberCardPhoneWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _BecomeJeeberCardNeighbourRow('Settings row above the card'),
          BecomeJeeberCard(isAlreadyJeeber: true, onTap: () {}),
          const _BecomeJeeberCardNeighbourRow('Settings row below the card'),
        ],
      ),
    );
