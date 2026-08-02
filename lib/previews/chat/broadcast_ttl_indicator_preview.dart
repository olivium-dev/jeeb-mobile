/// Widget previews for [BroadcastTtlIndicator] — run with
/// `flutter widget-preview start`.
///
/// The indicator takes exactly one argument, a nullable [DateTime], and owns
/// everything else itself: it runs its own `Timer.periodic` and reads
/// `DateTime.now()` on every tick. There is no cubit, no repository and no
/// gateway to fake, so these previews are network-free by construction rather
/// than by the guard in [jeebPreviewHost] — each one is a bare instant.
///
/// Because the clock is not injectable, every fixture below is expressed as an
/// OFFSET FROM NOW (`_inSeconds`), computed when the preview function runs.
/// Two consequences worth knowing at the canvas:
///
///   * The countdown is LIVE. `Final seconds` empties itself about five
///     seconds after the canvas builds it, and `One second left` almost
///     immediately — that disappearance is the state under review, not a
///     broken preview. Hot-restart to watch it again.
///   * A half-second is added to every offset so the truncating `inSeconds`
///     lands on the intended number instead of one below it.
///
/// The production window comes from `ChatState.broadcastExpiresAt` — the first
/// offer card's server `sentAt` plus five minutes — and the strip is mounted
/// only while `phase == ConversationPhase.broadcasting`
/// (`chat_screen.dart`, `_ChatBody.header`). The fixtures below are the
/// endpoints of that window plus the two ways it is reached with nothing to
/// show. The previews exist so the *visual* half of the contract that
/// `test/features/chat/chat_m1plus_test.dart` asserts behaviourally — a
/// full-bleed band on `tertiaryContainer`, an unbounded `Expanded` label beside
/// a fixed 16 px icon, and the height that band contributes to the chat
/// screen's non-flexible chrome — is reviewable without booting the app,
/// signing in and racing a five-minute timer.
library;

import 'package:flutter/material.dart';

import '../../features/chat/presentation/widgets/broadcast_ttl_indicator.dart';
import '../harness/jeeb_preview.dart';

/// Canvas box for the ordinary counts: phone width, with room for the
/// 200%-text rendering to wrap into.
///
/// Measured at 390 px wide: the band is 32–48 px tall at a 1.0 text scale and
/// grows to ~112 px at 2.0, because the `Expanded` label has no `maxLines` and
/// wraps instead of ellipsizing. 120 px keeps the tallest rendering inside the
/// box so the growth is visible rather than clipped.
const Size _stripBox = Size(390, 120);

/// Canvas box for the four-digit count. Its label is the longest the widget can
/// produce — and longer again in Arabic — so it is given headroom beyond
/// [_stripBox]; a short box would clip the evidence instead of showing it.
const Size _tallStripBox = Size(390, 200);

/// Canvas box for the two hidden states. Deliberately still 390 px wide: the
/// point of these previews is that the band occupies NO height, which only
/// reads if the box around it is the same width as the visible ones.
const Size _hiddenBox = Size(390, 64);

/// An expiry [seconds] from now, in UTC — the shape `broadcastExpiresAt`
/// produces.
///
/// The extra 500 ms absorbs the few milliseconds between this call and
/// `initState`'s first `_update()`. Without it, `Duration.inSeconds` truncation
/// would render `seconds - 1` and every label below would be off by one.
DateTime _inSeconds(int seconds) => DateTime.now().toUtc().add(
      Duration(seconds: seconds, milliseconds: 500),
    );

/// The moment the first offer card lands: the full five-minute window, which is
/// the widest count `ChatState.broadcastExpiresAt` can legitimately derive.
///
/// This is the band as most clients first see it, and the reading to compare
/// the others against.
@JeebPreview(group: 'chat', name: 'Fresh 5-minute window', size: _stripBox)
Widget broadcastTtlIndicatorFreshWindow() =>
    BroadcastTtlIndicator(expiresAt: _inSeconds(300));

/// The urgent end of the window, five seconds out.
///
/// The band is a fixed `tertiaryContainer` fill at every count — it does not
/// escalate to an error colour as the window closes — so this preview and
/// `Fresh 5-minute window` should be indistinguishable apart from the digits.
/// Check that in the AR RTL **dark** rendering especially: if the
/// `onTertiaryContainer` label is weak there, the last five seconds of a
/// broadcast are the least legible moment of the whole flow.
@JeebPreview(group: 'chat', name: 'Final seconds', size: _stripBox)
Widget broadcastTtlIndicatorFinalSeconds() =>
    BroadcastTtlIndicator(expiresAt: _inSeconds(5));

/// The singular boundary — the last count before the strip hides itself.
///
/// `chatBroadcastTtlLabel` is a flat template (`_get(...).replaceFirst`), so
/// this renders "…in 1s" in English and "…خلال 1 ثانية" in Arabic. The AR RTL
/// rendering is the one to look at: this app supplies six CLDR plural forms for
/// comparable counters (`pendingCardCreatedMinutes*`,
/// `dashboardNearbyRequests*`) and none for this one.
@JeebPreview(group: 'chat', name: 'One second left', size: _stripBox)
Widget broadcastTtlIndicatorOneSecond() =>
    BroadcastTtlIndicator(expiresAt: _inSeconds(1));

/// Layout ceiling: a four-digit count, which a real device reaches on clock
/// skew.
///
/// The remaining seconds are `expiresAt - DateTime.now()` with only a LOWER
/// clamp (`remaining < 0 ? 0 : remaining`). A handset whose clock runs an hour
/// behind the server therefore renders a ~65-minute countdown on a window the
/// server thinks lasts five, in raw seconds rather than mm:ss. This is the
/// longest label the widget can emit and the state the AR RTL and 200%-text
/// renderings of the matrix exist for — the EN light rendering still looks fine
/// well after the other two have stopped fitting on one line.
@JeebPreview(group: 'chat', name: 'Clock-skewed long count', size: _tallStripBox)
Widget broadcastTtlIndicatorClockSkew() =>
    BroadcastTtlIndicator(expiresAt: _inSeconds(3900));

/// The window has already closed: `expiresAt` is thirty seconds in the past.
///
/// The band must collapse to nothing — never "closes in 0s", and never a
/// negative count. The widget keeps ticking behind this empty box (the timer is
/// only cancelled in `dispose`), so what is under review is that no pixel of
/// the strip survives the moment the clock crosses the expiry.
@JeebPreview(group: 'chat', name: 'Expired window', size: _hiddenBox)
Widget broadcastTtlIndicatorExpired() =>
    BroadcastTtlIndicator(expiresAt: _inSeconds(-30));

/// No window at all.
///
/// Production reaches this whenever `broadcastExpiresAt` returns null: the
/// phase left `broadcasting` (an offer was accepted), there is no offer card
/// yet, or the first offer card carries no server timestamp — the case the
/// state's own comment describes as refusing to "claim the broadcast expired in
/// 1970". The strip is a zero-height `SizedBox.shrink`, so the chat header
/// should show no gap, no divider and no stray padding where it used to be.
@JeebPreview(group: 'chat', name: 'No window', size: _hiddenBox)
Widget broadcastTtlIndicatorNoWindow() =>
    const BroadcastTtlIndicator(expiresAt: null);
