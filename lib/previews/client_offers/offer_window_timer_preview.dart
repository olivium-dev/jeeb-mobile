/// Widget previews for [OfferWindowTimer] — run with
/// `flutter widget-preview start`.
///
/// The timer takes a [Duration] and a [bool] and nothing else. It owns no
/// clock, no cubit and no repository: `ClientOffersCubit.tick()` moves the
/// state's `now` and the widget re-renders whatever it is handed, which is
/// exactly why the widget was written against a `Duration` rather than a wall
/// clock ("so the cubit owns 'now' and tests can drive expiry
/// deterministically"). So these previews are network-free because there is
/// nothing to fetch, not merely because [jeebPreviewHost] guards the wire —
/// each one is a frozen instant.
///
/// **Why every state is hosted in a fixed-width box.** The one call site is a
/// direct child of the `ListView` in `client_offers_screen.dart`, whose padding
/// is `Spacing.medium` (16) on both sides — so on a 390pt phone the widget is
/// laid out against a TIGHT 358pt width. That matters more than it looks: the
/// root [Container] has no width of its own, so under tight constraints it
/// spans the full content width as a BAND, and under the loose constraints of a
/// bare canvas (or of the 800×600 test surface) the same code collapses to a
/// compact PILL around its `MainAxisSize.min` row. Reviewed loose, this widget
/// is a small chip and every state looks fine; reviewed at [_contentWidth] you
/// see the coloured band the client actually sees above the offer list. The
/// width is pinned in the fixture rather than left to the canvas [Size] so the
/// canvas and the render tests agree.
///
/// The states are the three colour branches (`neutral` / `urgent` / `expired`),
/// the exact second the urgent branch turns on, and the two inputs that have
/// already produced bugs in this area — see the notes on each. Two things the
/// matrix surfaces, both in the widget rather than in the previews:
///
///  * the `Icon` is pinned at `Sizes.medium` (16) and Flutter's default
///    `applyTextScaling` is `false` (nothing in `AppTheme` registers an
///    `iconTheme`), so at the 200% ceiling the countdown doubles to 24pt while
///    the timer glyph beside it stays exactly 16 — the one element of the band
///    that opts out of the accessibility contract the rest of it honours;
///  * the `Text` sets no `maxLines` and no `overflow`, which is survivable only
///    because the band is full-bleed and the label is short. See
///    [offerWindowTimerSafeWindowFallback] for how long "short" can get.
library;

import 'package:flutter/material.dart';

import '../../features/client_offers/presentation/widgets/offer_window_timer.dart';
import '../harness/jeeb_preview.dart';

/// The width the offer list really gives the band on a 390pt phone: the
/// `ListView` in `client_offers_screen.dart` insets `Spacing.medium` (16) on
/// each side. `390 - 16 - 16 = 358`.
const double _contentWidth = 358;

/// Canvas box for the ordinary counts: phone width, with room for the
/// 200%-text rendering to grow into.
const Size _bandBox = Size(390, 120);

/// Canvas box for the longest label the widget can emit. Given headroom beyond
/// [_bandBox] so a wrap is visible rather than clipped by the box.
const Size _tallBandBox = Size(390, 180);

/// Puts the band at the width its production list really has, pinned to the
/// leading top corner the way the list stacks it.
///
/// [AlignmentDirectional.topStart] rather than `topLeft` on purpose: the AR RTL
/// rendering must show the band hard against the RIGHT edge, and an alignment
/// that ignores direction would hide the one thing the RTL pass is for.
Widget _hosted(
  Duration remaining, {
  bool expired = false,
  double width = _contentWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: OfferWindowTimer(remaining: remaining, expired: expired),
      ),
    );

/// The state that ships for most of the window: a couple of minutes left, well
/// clear of the urgent threshold.
///
/// `2:05` is the value `test/offer_window_timer_test.dart` drives the normal
/// case with, so this is the ordinary reading — and the one to compare the rest
/// of the matrix against rather than to admire in EN light:
///
///  * **AR RTL dark** — the band mirrors unaided: the root padding is
///    `EdgeInsets.symmetric`, the inner gap is a [SizedBox], and the row is
///    order-based, so there is no `EdgeInsets.only` to get wrong. The glyph
///    moves to the right of the label and the band to the right of the list.
///    The digits stay `2:05` and stay left-to-right inside the Arabic sentence
///    — a colon-separated numeric run resolves LTR under Unicode bidi with no
///    explicit isolate, which is the property `CountdownFormat` is documented
///    to rely on. If a future format adds a letter ("2m 05s"), that stops being
///    true and this rendering is where it shows.
///  * **EN 200% text** — the label scales, the 16pt glyph does not.
@JeebPreview(group: 'client_offers', name: 'Fresh window · 2:05', size: _bandBox)
Widget offerWindowTimerFreshWindow() =>
    _hosted(const Duration(minutes: 2, seconds: 5));

/// The last second that is NOT urgent — the off-by-one guard for
/// `remaining.inSeconds <= 30`.
///
/// Beside [offerWindowTimerUrgent] this pins the threshold visually: these two
/// previews are one second apart and must not look alike. If this one ever
/// renders amber, the comparison was widened and the band starts shouting half
/// a minute early, every time.
@JeebPreview(group: 'client_offers', name: 'Threshold · 0:31', size: _bandBox)
Widget offerWindowTimerJustAboveUrgent() => _hosted(const Duration(seconds: 31));

/// The exact second the band escalates: `inSeconds <= 30` turns the neutral
/// surface into the WARNING container pair.
///
/// This is the state the code comment in `offer_window_timer.dart` is about —
/// *"Urgent previously misused the error pair"*. Urgent is not a failure; the
/// window is still open and every Accept button below is still live, so painting
/// it in the error red that [offerWindowTimerExpired] uses told the client the
/// opposite of the truth. The regression is invisible in a description and
/// obvious in a side-by-side, which is the whole reason this state and the
/// expired one are separate previews rather than one "coloured" preview.
///
/// What the side-by-side also shows is how little the escalation actually
/// changes. The copy template, the glyph and the geometry are identical to
/// [offerWindowTimerJustAboveUrgent] — the fill is the entire signal — and in
/// the light scheme that fill moves from `#E5E1E5` to `#FEF3C7`, a **1.16:1**
/// step. The urgent band ends up CLOSER to the white page (1.11:1) than the
/// neutral band it replaced (1.29:1), so the last thirty seconds of the window
/// are announced by a hue change alone. Flip between these two previews rather
/// than reading them one at a time; that is the only way to see it.
///
/// Look at the **AR RTL dark** rendering too: light and dark carry different
/// amber pairs (`#FEF3C7`/`#713F12` vs `#78350F`/`#FDE68A`), so it is the only
/// rendering that shows whether the urgent band still reads as urgent — rather
/// than as brown — on a dark surface.
@JeebPreview(group: 'client_offers', name: 'Urgent · 0:30', size: _bandBox)
Widget offerWindowTimerUrgent() => _hosted(const Duration(seconds: 30));

/// The bottom of the window: single-digit seconds, which must be zero-padded.
///
/// `0:04`, not `0:4`. `test/offer_window_timer_test.dart` asserts exactly this
/// value, and it is the state where the `FontFeature.tabularFigures()` on the
/// label earns its place — without it the band twitches horizontally on every
/// tick as proportional digits change width, which on a once-per-second timer
/// is the most-watched second of the whole screen.
@JeebPreview(group: 'client_offers', name: 'Final seconds · 0:04', size: _bandBox)
Widget offerWindowTimerFinalSeconds() => _hosted(const Duration(seconds: 4));

/// The terminal state — and deliberately NOT a zero countdown.
///
/// The screen passes the two inputs from two different authorities:
/// `expired: state.requestIsExpired` is set only when the gateway says the
/// request is expired, while `remaining: state.windowRemaining` is computed
/// locally from `windowExpiresAt - now`. The state's own comment is explicit
/// that "local countdown progress never sets this lifecycle flag", so the two
/// can and do disagree: a server that expires a request before its display
/// deadline (no offers arrived, tier resolution changed) leaves a client
/// holding a live-looking `1:12`.
///
/// So this preview seeds `expired: true` WITH `1:12` still on the clock. What
/// is under review is that the lifecycle flag wins outright — error container,
/// `timer_off_outlined`, "Offer window expired", and no trace of the stale
/// count. A band reading "Window: 1:12 left" on a dead request is an invitation
/// to keep waiting for offers that can never arrive.
///
/// Compare the two renderings against each other rather than against the other
/// states: `AppTheme.light()` never got an M3 tonal `errorContainer`, so this
/// band is the legacy `#B00020` slab with WHITE text — 7.33:1 against the page,
/// where neutral and urgent sit at 1.29:1 and 1.11:1. `AppTheme.dark()` is
/// restrained by comparison (1.98:1). One state, two very different volumes:
/// an alarm in light, a quiet tint in dark.
@JeebPreview(group: 'client_offers', name: 'Expired · stale 1:12 suppressed', size: _bandBox)
Widget offerWindowTimerExpired() =>
    _hosted(const Duration(minutes: 1, seconds: 12), expired: true);

/// Layout ceiling: the 24-hour window the gateway falls back to.
///
/// This widget used to say out loud that it was safe — *"the window cap is
/// always under 30 min so a 3-digit minute count never appears in practice"* —
/// and the sibling waiting screen held the same unwritten assumption. That is
/// the one that broke: the gateway serves `offerDeadlineInSeconds` from
/// `TierExpiryWindowResolver`, which falls back to a 24 h `SafeExpiryWindow`
/// whenever a request's tier does not resolve, and on real hardware during the
/// live COD run the waiting screen rendered **`1433:18 left`** — 23 h 53 m 18 s
/// printed as 1433 minutes, because `Duration.inMinutes` is the whole duration
/// in minutes and not the minutes-within-the-hour.
///
/// `CountdownFormat` now promotes the field (`23:53:18`) instead of letting it
/// overflow, and this is the same duration that produced the bug. It is the
/// longest label the widget can emit, which makes it the state the AR RTL and
/// 200%-text renderings really exist for: the EN light rendering still looks
/// fine long after the other two have stopped fitting on one line.
@JeebPreview(group: 'client_offers', name: 'Safe-window fallback · 23:53:18', size: _tallBandBox)
Widget offerWindowTimerSafeWindowFallback() =>
    _hosted(const Duration(hours: 23, minutes: 53, seconds: 18));
