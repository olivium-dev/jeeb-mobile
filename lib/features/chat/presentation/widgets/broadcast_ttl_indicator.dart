import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Countdown strip shown at the top of the broadcasting-phase chat.
///
/// Displays the seconds remaining in the offer window. When [expiresAt] is
/// null or already past, the strip is hidden. The timer updates every second
/// via an internal [Timer.periodic] so the widget is self-contained — the
/// cubit doesn't need to manage ticking.
class BroadcastTtlIndicator extends StatefulWidget {
  const BroadcastTtlIndicator({
    super.key,
    required this.expiresAt,
  });

  /// UTC instant when the current offer window closes. Pass null to hide the
  /// indicator (e.g. after the phase transitions to accepted).
  final DateTime? expiresAt;

  @override
  State<BroadcastTtlIndicator> createState() => _BroadcastTtlIndicatorState();
}

class _BroadcastTtlIndicatorState extends State<BroadcastTtlIndicator> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _update(),
    );
  }

  @override
  void didUpdateWidget(BroadcastTtlIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    final expires = widget.expiresAt;
    if (expires == null) {
      if (mounted) setState(() => _secondsLeft = 0);
      return;
    }
    final remaining = expires.difference(DateTime.now().toUtc()).inSeconds;
    if (mounted) setState(() => _secondsLeft = remaining < 0 ? 0 : remaining);
  }

  @override
  Widget build(BuildContext context) {
    final expires = widget.expiresAt;
    if (expires == null || _secondsLeft <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('broadcast-ttl-indicator'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      color: colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: Sizes.medium,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              l10n.chatBroadcastTtlLabel(_secondsLeft),
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
// Render tests: test/previews/chat/broadcast_ttl_indicator_preview_test.dart
// ===========================================================================

// Widget previews for [BroadcastTtlIndicator] — run with
// `flutter widget-preview start`.
//
// The indicator takes exactly one argument, a nullable [DateTime], and owns
// everything else itself: it runs its own `Timer.periodic` and reads
// `DateTime.now()` on every tick. There is no cubit, no repository and no
// gateway to fake, so these previews are network-free by construction rather
// than by the guard in [jeebPreviewHost] — each one is a bare instant.
//
// Because the clock is not injectable, every fixture below is expressed as an
// OFFSET FROM NOW (`_inSeconds`), computed when the preview function runs.
// Two consequences worth knowing at the canvas:
//
//   * The countdown is LIVE. `Final seconds` empties itself about five
//     seconds after the canvas builds it, and `One second left` almost
//     immediately — that disappearance is the state under review, not a
//     broken preview. Hot-restart to watch it again.
//   * A half-second is added to every offset so the truncating `inSeconds`
//     lands on the intended number instead of one below it.
//
// The production window comes from `ChatState.broadcastExpiresAt` — the first
// offer card's server `sentAt` plus five minutes — and the strip is mounted
// only while `phase == ConversationPhase.broadcasting`
// (`chat_screen.dart`, `_ChatBody.header`). The fixtures below are the
// endpoints of that window plus the two ways it is reached with nothing to
// show. The previews exist so the *visual* half of the contract that
// `test/features/chat/chat_m1plus_test.dart` asserts behaviourally — a
// full-bleed band on `tertiaryContainer`, an unbounded `Expanded` label beside
// a fixed 16 px icon, and the height that band contributes to the chat
// screen's non-flexible chrome — is reviewable without booting the app,
// signing in and racing a five-minute timer.

/// Canvas box for the ordinary counts: phone width, with room for the
/// 200%-text rendering to wrap into.
///
/// Measured at 390 px wide: the band is 32–48 px tall at a 1.0 text scale and
/// grows to ~112 px at 2.0, because the `Expanded` label has no `maxLines` and
/// wraps instead of ellipsizing. 120 px keeps the tallest rendering inside the
/// box so the growth is visible rather than clipped.
const Size _broadcastTtlIndicatorStripBox = Size(390, 120);

/// Canvas box for the four-digit count. Its label is the longest the widget can
/// produce — and longer again in Arabic — so it is given headroom beyond
/// [_broadcastTtlIndicatorStripBox]; a short box would clip the evidence instead of showing it.
const Size _broadcastTtlIndicatorTallStripBox = Size(390, 200);

/// Canvas box for the two hidden states. Deliberately still 390 px wide: the
/// point of these previews is that the band occupies NO height, which only
/// reads if the box around it is the same width as the visible ones.
const Size _broadcastTtlIndicatorHiddenBox = Size(390, 64);

/// An expiry [seconds] from now, in UTC — the shape `broadcastExpiresAt`
/// produces.
///
/// The extra 500 ms absorbs the few milliseconds between this call and
/// `initState`'s first `_update()`. Without it, `Duration.inSeconds` truncation
/// would render `seconds - 1` and every label below would be off by one.
DateTime _broadcastTtlIndicatorInSeconds(int seconds) => DateTime.now().toUtc().add(
      Duration(seconds: seconds, milliseconds: 500),
    );

/// The moment the first offer card lands: the full five-minute window, which is
/// the widest count `ChatState.broadcastExpiresAt` can legitimately derive.
///
/// This is the band as most clients first see it, and the reading to compare
/// the others against.
@JeebPreview(group: 'chat', name: 'Fresh 5-minute window', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorFreshWindow() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(300));

/// The urgent end of the window, five seconds out.
///
/// The band is a fixed `tertiaryContainer` fill at every count — it does not
/// escalate to an error colour as the window closes — so this preview and
/// `Fresh 5-minute window` should be indistinguishable apart from the digits.
/// Check that in the AR RTL **dark** rendering especially: if the
/// `onTertiaryContainer` label is weak there, the last five seconds of a
/// broadcast are the least legible moment of the whole flow.
@JeebPreview(group: 'chat', name: 'Final seconds', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorFinalSeconds() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(5));

/// The singular boundary — the last count before the strip hides itself.
///
/// `chatBroadcastTtlLabel` is a flat template (`_get(...).replaceFirst`), so
/// this renders "…in 1s" in English and "…خلال 1 ثانية" in Arabic. The AR RTL
/// rendering is the one to look at: this app supplies six CLDR plural forms for
/// comparable counters (`pendingCardCreatedMinutes*`,
/// `dashboardNearbyRequests*`) and none for this one.
@JeebPreview(group: 'chat', name: 'One second left', size: _broadcastTtlIndicatorStripBox)
Widget broadcastTtlIndicatorOneSecond() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(1));

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
@JeebPreview(group: 'chat', name: 'Clock-skewed long count', size: _broadcastTtlIndicatorTallStripBox)
Widget broadcastTtlIndicatorClockSkew() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(3900));

/// The window has already closed: `expiresAt` is thirty seconds in the past.
///
/// The band must collapse to nothing — never "closes in 0s", and never a
/// negative count. The widget keeps ticking behind this empty box (the timer is
/// only cancelled in `dispose`), so what is under review is that no pixel of
/// the strip survives the moment the clock crosses the expiry.
@JeebPreview(group: 'chat', name: 'Expired window', size: _broadcastTtlIndicatorHiddenBox)
Widget broadcastTtlIndicatorExpired() =>
    BroadcastTtlIndicator(expiresAt: _broadcastTtlIndicatorInSeconds(-30));

/// No window at all.
///
/// Production reaches this whenever `broadcastExpiresAt` returns null: the
/// phase left `broadcasting` (an offer was accepted), there is no offer card
/// yet, or the first offer card carries no server timestamp — the case the
/// state's own comment describes as refusing to "claim the broadcast expired in
/// 1970". The strip is a zero-height `SizedBox.shrink`, so the chat header
/// should show no gap, no divider and no stray padding where it used to be.
@JeebPreview(group: 'chat', name: 'No window', size: _broadcastTtlIndicatorHiddenBox)
Widget broadcastTtlIndicatorNoWindow() =>
    const BroadcastTtlIndicator(expiresAt: null);
