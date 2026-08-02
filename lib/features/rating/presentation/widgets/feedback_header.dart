import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'feedback_avatar.dart';
import 'feedback_star_input.dart';

/// Title + audience-aware subtitle block on the feedback screen
/// (Figma 56614:20132). The subtitle swaps between "evaluate the delivery man"
/// and "evaluate the client" depending on who is rating.
class FeedbackHeader extends StatelessWidget {
  const FeedbackHeader({super.key, required this.isClient});

  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = isClient
        ? l10n.feedbackScreenSubtitleJeeber
        : l10n.feedbackScreenSubtitleClient;
    return Column(
      children: [
        _FeedbackTitle(text: l10n.feedbackScreenTitle),
        const SizedBox(height: Spacing.small),
        _FeedbackSubtitle(text: subtitle),
      ],
    );
  }
}

class _FeedbackTitle extends StatelessWidget {
  const _FeedbackTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FeedbackSubtitle extends StatelessWidget {
  const _FeedbackSubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
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
// Render tests: test/previews/rating/feedback_header_preview_test.dart
// ===========================================================================
//
// Widget previews for [FeedbackHeader] — run with
// `flutter widget-preview start`.
//
// The header takes exactly one input, `bool isClient`, and turns it into two
// ARB strings: a fixed title (`feedbackScreenTitle`) over one of two subtitles
// (`feedbackScreenSubtitleJeeber` / `feedbackScreenSubtitleClient`). There is
// no cubit, no repository and no asset load, so "empty / loading / error" do
// not exist for this widget and every preview below is network-free by
// construction rather than merely by the guard in [jeebPreviewHost].
//
// Its states are therefore the audience switch plus HOST states — the width it
// is handed, the text scale, and the brightness of the page — because that is
// where a two-paragraph block actually gives way. What each preview is for is
// on the preview itself; four things they surface, all in the widget rather
// than in the previews:
//
//  * **The title is inked with `colorScheme.secondaryContainer`** — a
//    *container* role, i.e. a fill meant to sit BEHIND ink, and the exact
//    misuse `app_theme.dart` warns about in its own words. It survives in
//    light only because that role is hard-coded to the brand navy (17.13:1 on
//    white). The dark scheme is `ColorScheme.fromSeed(_jeebNavy, dark)`, where
//    it resolves to a dark container tone on a surface of nearly the same tone
//    — **1.98:1**, under even the 3:1 large-text floor. Every `AR RTL dark`
//    rendering below is that defect. `CustomerProfileSectionHeader` and
//    `JeebVerifiedBadge` ink with the same role and their preview tests
//    already pin the same gap.
//
//  * **The subtitle fails AA in LIGHT mode**, which is the more surprising
//    half. It is inked with `colorScheme.onSecondaryContainer`, which the light
//    scheme hard-codes to the Figma "muted text" purple `#777FC0`. On the white
//    surface that measures **3.76:1** against the 4.5:1 WCAG AA floor for
//    14sp body text. Unlike the title defect this one is visible in the default
//    `EN light` rendering that a reviewer signs off — it just looks like
//    intentionally soft type. The role is also being used off-pair: nothing on
//    this screen paints a `secondaryContainer` fill for it to sit on. (In dark
//    the same role resolves to a tone-90 and measures 14.29:1, so the two
//    defects are mirror images — the title is the unreadable one in dark, the
//    subtitle the unreadable one in light.)
//
//  * **The [Column] is greedy.** It leaves `mainAxisSize` at its
//    `MainAxisSize.max` default, so in any parent that passes a bounded height
//    it swells to fill it and pins its own two paragraphs to the top — see
//    [feedbackHeaderBoundedBand]. `_FeedbackContent` gets away with it because
//    a `Column` inside a `SingleChildScrollView` hands its children unbounded
//    height, so the header shrink-wraps there by accident rather than by
//    contract.
//
//  * **It degrades by wrapping, and nothing enforces that.** Neither [Text]
//    sets `maxLines` or `overflow`, so at 200% text on a 320pt device the
//    subtitle roughly doubles its line count instead of clipping — good
//    behaviour that is one `maxLines:` away from becoming an ellipsis through
//    the middle of the only instruction on the screen. [feedbackHeaderCompact]
//    is the state that shows it.
//
// **About the captions.** Two states below ([feedbackHeaderCompact],
// [feedbackHeaderBoundedBand]) differ from a production state only in the box
// they are given — same widget, same two strings — so `find.text` has nothing
// of the widget's own to tell them apart with, and a render test could pass
// while both rendered a plain 390pt header. Each therefore carries a one-line
// caption naming the state, used by the test only to *address* it; the
// assertions that prove the states differ are the measured boxes in
// `test/previews/rating/feedback_header_preview_test.dart`. The two production
// states carry no caption, because they are what a designer signs off.

/// The phone the feedback screen is drawn for.
///
/// Pinned as a real [SizedBox] rather than left to the canvas [Size]: the canvas
/// honours `size`, but the render tests pump onto a fixed 800 x 600 surface, so
/// a header left to fill its host would wrap on the phone and not wrap under
/// test — the state that breaks would only break in one of the two places it is
/// looked at.
const double _feedbackHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _feedbackHeaderCompactPhoneWidth = 320;

/// `_FeedbackScrollArea`'s horizontal padding, restated from
/// `rating_screen.dart` so the header gets the `390 - 40 = 350`pt column it
/// really has rather than the full canvas width.
const double _feedbackHeaderScreenGutter = Spacing.large;

/// Canvas box for the header on a phone: title, `Spacing.small`, and a subtitle
/// that already wraps to three lines at 1.0. Generous on purpose — the
/// `EN 200% text` rendering roughly triples that, and a box that clipped it
/// would report a fixture overflow rather than anything about the widget.
const Size _feedbackHeaderPhoneBox = Size(390, 340);

/// Taller box for the 320pt state, whose subtitle wraps furthest.
const Size _feedbackHeaderCompactBox = Size(390, 440);

/// The header plus the two neighbours it is spaced against.
const Size _feedbackHeaderContextBox = Size(390, 600);

/// The fixed band [feedbackHeaderBoundedBand] drops the header into.
const double _feedbackHeaderBandHeight = 240;

/// Canvas box for the band, plus its caption.
const Size _feedbackHeaderBandBox = Size(390, 320);

/// The name used wherever a ratee is needed, matching
/// `test/feedback_screen_test.dart`.
const String _feedbackHeaderRateeName = 'Sami Fawaz';

/// Hosts [child] the way `_FeedbackScrollArea` + `_FeedbackContent` really do:
/// a fixed-width phone, the screen's 20/16 padding, a [SingleChildScrollView],
/// and a `CrossAxisAlignment.stretch` [Column].
///
/// None of that is decoration.
///
///  * The **scroll view** is what makes the 200% rendering honest. It hands its
///    child unbounded height, so [FeedbackHeader] shrink-wraps (it would not
///    otherwise — see the section doc) and the block scrolls when it outgrows
///    the phone. Host it in a plain bounded [Column] instead and the
///    `EN 200% text` rendering paints a 500pt overflow stripe that production
///    never shows, i.e. a fixture defect wearing a widget's clothes.
///  * The **stretch** gives the header the full `width - 40` content column.
///    Without it the header shrink-wraps to its own glyphs and every centring
///    question answers itself.
Widget _feedbackHeaderHosted(
  Widget child, {
  double width = _feedbackHeaderPhoneWidth,
  String? caption,
}) => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _feedbackHeaderScreenGutter,
            vertical: Spacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              child,
              if (caption != null) ...<Widget>[
                const SizedBox(height: Spacing.small),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

/// The state that ships to clients, and the one to read first.
///
/// A client rating the jeeber is the overwhelmingly common arrival at
/// `/orders/:id/feedback`, so this is the rendering a designer signs off. Read
/// the `EN light` variant for the subtitle contrast (3.76:1 — soft-looking type
/// that is actually under AA) and the `AR RTL dark` variant for the title,
/// which nearly dissolves into the page at 1.98:1. Both are palette defects,
/// not preview artefacts; the preview test pins the numbers.
@JeebPreview(
  group: 'rating',
  name: 'Client rates the jeeber',
  size: _feedbackHeaderPhoneBox,
)
Widget feedbackHeaderClientAudience() =>
    _feedbackHeaderHosted(const FeedbackHeader(isClient: true));

/// The other audience: a jeeber rating the client after handover.
///
/// Worth its own preview rather than being assumed identical to the state
/// above. Only the subtitle changes and only in its last two words, which is
/// exactly the kind of difference a single-state preview hides — and the copy
/// that has to be right, because showing "evaluate the delivery man" to a
/// delivery man asking him to rate a client is a wrong-audience bug that
/// `test/feedback_screen_test.dart` already guards on the screen.
@JeebPreview(
  group: 'rating',
  name: 'Jeeber rates the client',
  size: _feedbackHeaderPhoneBox,
)
Widget feedbackHeaderJeeberAudience() =>
    _feedbackHeaderHosted(const FeedbackHeader(isClient: false));

/// The layout ceiling: the longest of the two subtitles on the narrowest
/// supported device.
///
/// `feedbackScreenSubtitleJeeber` is 108 characters — by far the longest string
/// this widget can be handed — and 320pt leaves it `320 - 40 = 280`pt to wrap
/// in. This is the state to open at `EN 200% text`, which is the real
/// accessibility ceiling for this screen: the block grows past a phone
/// viewport, and it degrades by wrapping rather than clipping only because
/// neither [Text] sets `maxLines` or `overflow`. Nothing enforces that; add
/// either and this state starts truncating the instruction that tells the user
/// what the screen is for.
@JeebPreview(
  group: 'rating',
  name: 'Compact 320pt device',
  size: _feedbackHeaderCompactBox,
)
Widget feedbackHeaderCompact() => _feedbackHeaderHosted(
      const FeedbackHeader(isClient: true),
      width: _feedbackHeaderCompactPhoneWidth,
      caption: '320pt device — narrowest supported',
    );

/// The header in the only place it actually appears: between the ratee's avatar
/// and the star row of `_FeedbackContent`, reproduced spacing for spacing.
///
/// A title/subtitle block cannot be reviewed alone, because half its job is
/// spatial. Two things only become visible here:
///
///  * **Rhythm.** `Spacing.xLarge` (24) separates the header from the avatar
///    above and from the rating group below, while `Spacing.small` (12) binds
///    the subtitle to its own title. At 200% text the type doubles and none of
///    those gaps do, so the grouping weakens exactly where the block is
///    tallest.
///  * **Centring.** The avatar, the header, the `Rate {name}` line and the
///    stars are all centred on the same 350pt content column, so any one of
///    them drifting off-axis reads immediately here and nowhere else.
///
/// The neighbours are reproduced from `rating_screen.dart` rather than imported
/// (`_FeedbackRateName` is private), so this stays a preview of the header and
/// not of the screen. Both are inert: [FeedbackAvatar] falls back to the
/// ratee's initial when `avatarUrl` is null, so nothing here fetches.
@JeebPreview(
  group: 'rating',
  name: 'In screen context',
  size: _feedbackHeaderContextBox,
)
Widget feedbackHeaderInScreenContext() => _feedbackHeaderHosted(
      Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FeedbackAvatar(name: _feedbackHeaderRateeName),
              const SizedBox(height: Spacing.xLarge),
              const FeedbackHeader(isClient: true),
              const SizedBox(height: Spacing.xLarge),
              Text(
                AppLocalizations.of(
                  context,
                ).feedbackRateName(_feedbackHeaderRateeName),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Spacing.medium),
              FeedbackStarInput(stars: 4, onChanged: (int _) {}),
            ],
          );
        },
      ),
    );

/// The caller hazard, made visible: the same header inside a parent that passes
/// a bounded height.
///
/// [FeedbackHeader] leaves `mainAxisSize` at [MainAxisSize.max], so it does not
/// shrink-wrap — it takes every pixel the parent offers and pins its two
/// paragraphs to the TOP of them. In the 240pt band below, that is a title
/// block flush against the top edge over a stretch of dead space, on a widget
/// whose every other alignment decision (`TextAlign.center`, the [Column]'s
/// default `CrossAxisAlignment.center`) says "centred block". The outline is
/// drawn only so the band itself is visible.
///
/// Not reachable from today's single caller, which nests the header in a
/// `Column` inside a `SingleChildScrollView` and so hands it unbounded height.
/// It is one refactor away — a `Stack`, an `Expanded`, a fixed-height
/// bottom-sheet header — and it would land as "the title block sticks to the
/// top of its slot", which reads as a padding bug rather than as a missing
/// `mainAxisSize: MainAxisSize.min` three files away.
@JeebPreview(
  group: 'rating',
  name: 'Bounded 240pt band (greedy column)',
  size: _feedbackHeaderBandBox,
)
Widget feedbackHeaderBoundedBand() => _feedbackHeaderHosted(
      Builder(
        builder: (BuildContext context) => SizedBox(
          height: _feedbackHeaderBandHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const FeedbackHeader(isClient: true),
          ),
        ),
      ),
      caption: 'Bounded 240pt band — the column fills it',
    );
