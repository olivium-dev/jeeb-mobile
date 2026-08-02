import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class HandoverCodeDisplay extends StatelessWidget {
  const HandoverCodeDisplay({
    super.key,
    required this.code,
    this.semanticsIdentifier = 'otp_handover_code_display',
    this.compact = false,
    this.displayKey = const Key('otpHandover.codeDisplay'),
  });

  final String code;

  final String semanticsIdentifier;

  final bool compact;

  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = compact
        ? theme.textTheme.headlineLarge
        : theme.textTheme.displayLarge;
    return Semantics(
      identifier: semanticsIdentifier,
      liveRegion: true,
      label: AppLocalizations.of(context).handoverCodeA11yLabel,
      value: code.split('').join(' '),
      child: Container(
        key: displayKey,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: compact ? Spacing.xLarge : Spacing.twoXLarge,
          vertical: compact ? Spacing.small : Spacing.medium,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        // Bidi guard: an all-numeric code must never reorder when it sits
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            code,
            style: style?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              letterSpacing: Spacing.small,
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
// Render tests: test/previews/otp_handover/handover_code_display_preview_test.dart
// ===========================================================================
//
// Widget previews for [HandoverCodeDisplay] — run with
// `flutter widget-preview start`.
//
// The widget takes one string and no dependencies: there is no repository,
// cubit, image or route behind it, so these previews are network-free by
// construction rather than by the guard in [jeebPreviewHost]. What they exist
// to review is TYPOGRAPHY UNDER STRESS, which is the only way this widget can
// fail.
//
// Two axes, and the previews below are their corners:
//
// 1. **[compact]** — `false` is the full-screen hero the customer's OTP screen
//    shows (`displayLarge`, 57 pt, `Spacing.twoXLarge` side padding); `true` is
//    the in-card variant [OtpAtDoorCard] drops over the tracking map
//    (`headlineLarge`, 32 pt, `Spacing.xLarge`). Both surfaces ship, and only
//    one of them was ever reviewed by eye.
// 2. **Available width** — both call sites wrap the panel in
//    `EdgeInsets.all(Spacing.xLarge)`, so the panel gets `device - 48`: 342 pt
//    on a 390 pt phone, 272 pt on the 320 pt floor.
//
// **The panel cannot shrink, and when it does not fit it WRAPS MID-NUMBER.**
// The code is a bare [Text] in a padded [Container] — no [FittedBox], no
// `maxLines`, no `overflow`. Flutter's line breaker has no break opportunity
// inside a digit run, so it falls back to breaking it anywhere: `9061` at the
// 320 pt floor is laid out as `906` over `1`, two stacked fragments that read
// as two numbers. Not clipped, not scaled — re-flowed. Nothing in the widget
// enforces the 4-digit contract either; `code` is rendered verbatim at whatever
// length the gateway sends. [handoverCodeDisplayNarrowPhone] and
// [handoverCodeDisplayWidenedCode] are the two states that show where this
// runs out.
//
// **Measured** (widget test, EN, hero variant unless noted). `flutter test`
// substitutes a monospaced font whose glyphs are one em wide, so the absolute
// numbers are the worst case and the canvas (real Inter) reads narrower — the
// ORDERING and the wrap behaviour are what these pin:
//
// | state | slot | panel | code lines |
// |---|---|---|---|
// | 4-digit, 1.0, unconstrained | — | 340 pt | 1 |
// | 4-digit, 2.0, unconstrained | — | 568 pt | 1 |
// | 4-digit, 1.0, 320 pt phone | 272 pt | 272 pt | 2 |
// | 4-digit, 2.0, 320 pt phone | 272 pt | 272 pt | 4 |
// | 6-digit, 1.0, 390 pt phone | 342 pt | 342 pt | 2 |
// | 4-digit compact, 1.0 | — | 224 pt | 1 |
//
// `letterSpacing: Spacing.small` is a fixed 12 pt per glyph that does NOT scale
// with the text scaler while the glyphs do — 48 pt of the hero panel's width is
// spacing alone, on top of 64 pt of padding that does not scale either. That
// fixed 112 pt is what pushes a code over the edge that would otherwise fit.
//
// The one thing the AR RTL rendering confirms is *fine*: the digits never
// bidi-reorder. The [Directionality] pin inside [HandoverCodeDisplay.build] is
// the only thing holding that, and [handoverCodeDisplayBidiGuard] is here to
// make its removal visible.
//
// One thing NO rendering shows, found while pinning the previews and pinned in
// the render test instead: the [Semantics] wrapper sets neither `container` nor
// `explicitChildNodes`, so the code [Text] merges INTO the live region. The
// announced node ends up with the unspaced run in its `label` *and* the spaced
// digits in its `value` — the code is read twice, and the first reading is a
// bare numeral a screen reader may voice as a number rather than as digits.

/// Phone-width canvas for the hero variant: 57 pt glyphs plus 16 pt of vertical
/// padding need the height; the width is the 390 pt phone the OTP screen ships
/// on.
const Size _handoverCodeDisplayHeroBox = Size(390, 200);

/// The in-card variant is half the type scale and 12 pt of vertical padding, so
/// it wants a much shorter box — a tall one would hide how small this panel
/// reads once it is inside [OtpAtDoorCard].
const Size _handoverCodeDisplayCompactBox = Size(390, 140);

/// The panel as both call sites build it: shrink-wrapped and centred.
Widget _handoverCodeDisplayHosted(String code, {bool compact = false}) => Center(
      child: HandoverCodeDisplay(code: code, compact: compact),
    );

/// The panel inside the `EdgeInsets.all(Spacing.xLarge)` its call sites impose,
/// pinned to a device width.
///
/// The pin is load-bearing: the render tests pump an 800 px viewport and ignore
/// [JeebPreview.size], so a state that needs a real width has to carry it
/// itself.
Widget _handoverCodeDisplayOnPhone(String code, {required double width}) =>
    Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: _handoverCodeDisplayHosted(code),
        ),
      ),
    );

/// The customer's OTP screen, at the moment the jeeber asks for the code.
///
/// This is the shipping default (`compact: false`) and the only state that was
/// designed rather than inherited: `displayLarge` on `primaryContainer`, sized
/// to be read at arm's length off a phone held up to a stranger. Fixture `1234`
/// is the code `test/live_tracking_handover_code_test.dart` pins.
@JeebPreview(
  group: 'otp_handover',
  name: 'Hero · 1234',
  size: _handoverCodeDisplayHeroBox,
)
Widget handoverCodeDisplayHero() => _handoverCodeDisplayHosted('1234');

/// The same widget as [OtpAtDoorCard] embeds it (`compact: true`).
///
/// Worth seeing beside the hero: `compact` is not a small tweak, it is a drop
/// from `displayLarge` (57 pt) to `headlineLarge` (32 pt) — roughly half — and
/// it is the variant the customer actually meets first, over the tracking map.
/// If the two ever stop looking like the same component, this is the pair that
/// shows it.
@JeebPreview(
  group: 'otp_handover',
  name: 'Compact in-card · 5678',
  size: _handoverCodeDisplayCompactBox,
)
Widget handoverCodeDisplayCompact() =>
    _handoverCodeDisplayHosted('5678', compact: true);

/// Bidi guard, made visible: a code whose reading is destroyed by reordering.
///
/// `0450` is chosen so a failure is unmistakable — a leading zero that must
/// stay leading, and a value that reads as a different code (`0540`) if the
/// digits mirror. The AR RTL rendering of the matrix is the whole point: the
/// screen around the panel mirrors, the digits must not, and the only thing
/// stopping them is the [Directionality] pin in [HandoverCodeDisplay.build].
/// It is also the state that proves the code is treated as an opaque string
/// rather than a number — a number would have dropped the leading zero long
/// before it reached this widget.
@JeebPreview(
  group: 'otp_handover',
  name: 'Bidi guard · 0450',
  size: _handoverCodeDisplayHeroBox,
  matrix: true,
)
Widget handoverCodeDisplayBidiGuard() => _handoverCodeDisplayHosted('0450');

/// The 320 pt floor, with the 24 pt page padding both call sites impose — so
/// the panel is laid out into 272 pt, the narrowest it ever gets in production.
///
/// This is the state the 200% rendering of the matrix is for, and the state
/// that shows the wrap. The hero panel wants 340 pt under the test font and
/// gets 272, so the code re-flows onto two lines (`906` / `1`); at 2.0 it
/// re-flows onto four, one digit per line, because the glyphs double while the
/// 12 pt letter-spacing and the 32 pt side padding do not. A customer on a
/// small phone with large text set is exactly the customer who most needs to
/// read these four digits as one number.
@JeebPreview(
  group: 'otp_handover',
  name: 'Narrow phone · 320 pt',
  size: Size(320, 220),
  matrix: true,
)
Widget handoverCodeDisplayNarrowPhone() =>
    _handoverCodeDisplayOnPhone('9061', width: 320);

/// Longest plausible content: a code the gateway widened past four digits.
///
/// Nothing in this widget, or in the parsers that feed it
/// (`test/offer_accept_handover_code_test.dart` keeps whatever string the
/// accept response carries), enforces the 4-digit contract — only the JEEBER's
/// submit button does, via `code.length == 4`. So the customer-side display is
/// one gateway change away from this rendering. Reviewed at the shipping 390 pt
/// width, where six digits already want 478 pt and get 342: the code wraps
/// `4819` / `02`, which reads as two numbers rather than one. The Semantics
/// value still announces all six, which is the only reason this degrades
/// survivably at all.
@JeebPreview(
  group: 'otp_handover',
  name: 'Widened code · 481902',
  size: _handoverCodeDisplayHeroBox,
)
Widget handoverCodeDisplayWidenedCode() =>
    _handoverCodeDisplayOnPhone('481902', width: 390);
