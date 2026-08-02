import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_chat_message.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// `package:intl/intl.dart` above exports a `TextDirection` of its own, so the
// preview fixtures reach Flutter's through a prefix rather than making the bare
// name ambiguous for the production code in between.
import 'dart:ui' as ui show TextDirection;

import '../../../../core/previews/jeeb_preview.dart';

/// Locale-aware "HH:mm" timestamp rendered inside a chat bubble's meta row.
///
/// Shared by the offer card (state 02) and the message-bubble footer (state
/// 03) so the time format is identical across both chat states. Uses
/// [DateFormat.Hm] keyed to the active locale — never a string-built clock —
/// and is laid out start-aligned so the parent decides placement.
class ChatBubbleTimestamp extends StatelessWidget {
  const ChatBubbleTimestamp({
    super.key,
    required this.sentAt,
    this.hasServerTimestamp = true,
    this.color,
  });

  /// When the message was sent — meaningless unless [hasServerTimestamp].
  final DateTime sentAt;

  /// [DeliveryChatMessage.hasServerTimestamp] of the message being rendered.
  /// False → [sentAt] is an ordering anchor and no clock is drawn.
  ///
  /// This used to be re-derived here from the VALUE of [sentAt] (an anchor was
  /// "any instant inside 1970"). The message now carries the fact explicitly, so
  /// an anchor that happens to look like a plausible instant can never be
  /// mistaken for a send time.
  final bool hasServerTimestamp;

  /// Optional override colour; defaults to a muted on-surface variant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // A message the server returned with no timestamp carries an ordering
    // anchor, not a send time. Render nothing rather than a fabricated clock.
    if (!hasServerTimestamp) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        DateFormat.Hm(locale).format(sentAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ??
              theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: UIConstants.opacityHigh),
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
// Render tests: test/previews/chat/chat_bubble_timestamp_preview_test.dart
// ===========================================================================

// Widget previews for [ChatBubbleTimestamp] — run with
// `flutter widget-preview start`.
//
// The widget takes three plain values — a [DateTime], a bool and an optional
// [Color] — and emits at most ONE [Text]. No cubit, no repository, no image:
// every state below is a value built in-process, so these previews are
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// Because the widget is one line of ink, the states that matter are not
// "variants of the clock" but the three ways the ink can be WRONG:
//
//  1. **It is drawn when it must not be.** A row the server returned without a
//     `created_at` carries an ordering ANCHOR inside 1970, not a send time.
//     `hasServerTimestamp: false` is what suppresses it — see the undated and
//     epoch states below, which are the same instant with the flag flipped.
//  2. **It is drawn from the wrong clock.** The widget formats [sentAt] as
//     given and never calls `.toLocal()`, unlike the two sibling call sites
//     that use the same `DateFormat.Hm` (`delivery_stage_indicator.dart:136`,
//     `jeeber_feed_card.dart:749`). Hand it a UTC instant and it prints the UTC
//     hour with no hint that it did.
//  3. **It is drawn in ink the surface cannot carry.** The default colour is a
//     surface role (`onSurfaceVariant` at `UIConstants.opacityHigh`), which is
//     right for the grey offer card and unreadable on the sender's filled navy
//     bubble — measured 1.65:1 in light. `ChatMessageBubble` escapes that only
//     because it passes `color:`; the widget itself has no opinion.
//
// The bubble frames below are preview scaffolding, not widget output. They
// exist because the one contract a lone clock in an empty box cannot show is
// the one it actually has: `Align(AlignmentDirectional.centerEnd)`, i.e. the
// clock hugs the bubble's TRAILING edge and moves to the physical left in
// Arabic. Two colours of frame are used, matching the two production callers —
// `surfaceContainerHigh` for `offer_card_bubble.dart:216` and `primary` for
// the sender's bubble in `chat_message_bubble.dart:571`.

/// Canvas box for one bubble plus its meta row.
const Size _chatBubbleTimestampBubbleBox = Size(390, 160);

/// Taller box for the two matrix states: at 200% the body copy wraps to three
/// lines and the caption to three more, so the card needs the headroom or the
/// canvas — not the widget — is what shows stripes.
const Size _chatBubbleTimestampMatrixBox = Size(390, 300);

/// Bubbles in the thread are capped at ~70% of a 390 pt phone (design-spec §4).
const double _chatBubbleTimestampBubbleWidth = 260;

/// A stand-in for the chat bubble the timestamp always lives inside.
///
/// [filled] picks the sender's `primary` bubble over the grey offer card;
/// [caption] labels a state whose whole point is that nothing renders.
class _ChatBubbleTimestampBubble extends StatelessWidget {
  const _ChatBubbleTimestampBubble({required this.child, this.filled = false, this.caption});

  final Widget child;
  final bool filled;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: _chatBubbleTimestampBubbleWidth,
            padding: const EdgeInsets.all(Spacing.small),
            decoration: BoxDecoration(
              color:
                  filled ? scheme.primary : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Spacing.small),
            ),
            child: child,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            SizedBox(
              width: _chatBubbleTimestampBubbleWidth,
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The offer-card footer: body copy over a start-aligned column, the clock
/// aligning itself to the trailing edge.
///
/// Mirrors `_OfferCardBody` (`offer_card_bubble.dart:196`) minus the avatar,
/// stars and CTA row — the parts that would drown the one widget under review.
Widget _chatBubbleTimestampOfferFooter({
  required DateTime sentAt,
  bool hasServerTimestamp = true,
  String? caption,
}) =>
    _ChatBubbleTimestampBubble(
      caption: caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Fast delivery guaranteed'),
          const SizedBox(height: Spacing.twoXSmall),
          ChatBubbleTimestamp(
            sentAt: sentAt,
            hasServerTimestamp: hasServerTimestamp,
          ),
        ],
      ),
    );

/// The sender's bubble footer, built the way `chat_message_bubble.dart:563`
/// builds it: a min-width Row of clock → status tick, force-wrapped in
/// `Directionality(ltr)` so the pair keeps clock-then-tick order in Arabic.
///
/// [overrideColour] reproduces the caller's
/// `color.withValues(alpha: opacityHigh)`; set it false to see what the
/// widget's own default ink does on this bubble.
Widget _chatBubbleTimestampSenderFooter({
  required String body,
  required DateTime sentAt,
  bool overrideColour = true,
  String? caption,
}) =>
    _ChatBubbleTimestampBubble(
      filled: true,
      caption: caption,
      child: Builder(
        builder: (BuildContext context) {
          final ColorScheme scheme = Theme.of(context).colorScheme;
          final Color ink =
              scheme.onPrimary.withValues(alpha: UIConstants.opacityHigh);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(body, style: TextStyle(color: scheme.onPrimary)),
              const SizedBox(height: Spacing.twoXSmall),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    ChatBubbleTimestamp(
                      sentAt: sentAt,
                      color: overrideColour ? ink : null,
                    ),
                    const SizedBox(width: Spacing.twoXSmall),
                    Icon(Icons.done_all, size: Sizes.medium, color: ink),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

/// The reference rendering: an offer that arrived at 12:34, drawn with the
/// widget's default ink on the grey card it was designed for.
///
/// This is the state to read the matrix on, because everything interesting
/// about a five-character string is locale-shaped:
///
///  * **AR RTL dark** — the clock must move to the physical LEFT. The widget's
///    only layout opinion is `AlignmentDirectional.centerEnd`, so a stray
///    `Alignment.centerRight` would pin it right in both locales and only this
///    rendering would show it. What must NOT change is the string itself:
///    intl 0.20.2 ships no `ZERODIGIT` for the generic `ar` symbol set (only
///    `ar_EG` has one), so the Arabic clock renders "12:34", byte-identical to
///    English — measured, and the opposite of what
///    `chat_date_separator_preview.dart` claims for the same locale. The day
///    an `ar_EG` locale is added, this widget switches digit system with no
///    code change.
///  * **EN 200% text** — `labelSmall` doubles and the clock is the widest thing
///    in the footer after the body copy; it must still sit inside the bubble.
///
/// Fixture reuses the offer-card clock (`offer_card_bubble_preview.dart`
/// `sentAt: DateTime(2026, 6, 1, 12, 34)`) so both canvases show one card.
@JeebPreview(group: 'chat', name: 'Offer card footer · 12:34', size: _chatBubbleTimestampMatrixBox, matrix: true)
Widget chatBubbleTimestampOfferFooter() =>
    _chatBubbleTimestampOfferFooter(sentAt: DateTime(2026, 6, 1, 12, 34));

/// The other production caller, done correctly: the sender's navy bubble with
/// the caller's `color:` override.
///
/// Two things are visible only here. The ink is `onPrimary` faded to
/// `opacityHigh` — 13.06:1 on the navy bubble, the state the app actually
/// ships. And the meta row is wrapped in `Directionality(ltr)` by the CALLER,
/// which quietly neutralises the widget's `AlignmentDirectional.centerEnd`:
/// inside the message bubble this clock never mirrors, however Arabic the
/// thread is. That is deliberate (clock-then-tick is a fixed pair) but it means
/// the widget's own directional contract is exercised by the offer card alone.
///
/// Instant reuses `chat_message_bubble_preview.dart` (`DateTime(2026, 6, 11,
/// 9, 41)`), and the leading zero it produces — 09:41 — is itself the check
/// that `DateFormat.Hm` is zero-padding rather than printing "9:41".
@JeebPreview(group: 'chat', name: 'Sender bubble · caller colour', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampSenderBubble() => _chatBubbleTimestampSenderFooter(
      body: 'The blue box, please',
      sentAt: DateTime(2026, 6, 11, 9, 41),
    );

/// The same bubble with the `color:` argument dropped — i.e. what any NEW
/// caller gets by default on a filled bubble.
///
/// The default is `colorScheme.onSurfaceVariant` at `opacityHigh`, a role tuned
/// for a surface. Composited over `colorScheme.primary` it measures **1.65:1**
/// in the light theme (#5C4038 at 87% over #0B1351) — far under the 4.5:1 AA
/// floor for 11 pt text, and the AR RTL DARK rendering of this matrix is worse
/// still, since `ColorScheme.fromSeed` makes both roles pale in dark. The clock
/// is legible in neither.
///
/// Nothing in the app renders this today, and that is the point: the widget
/// carries no assertion, no `assert`, and no contrast-aware default, so the
/// only thing standing between this card and production is one optional named
/// argument at `chat_message_bubble.dart:574`. The numbers are pinned in
/// `test/previews/chat/chat_bubble_timestamp_preview_test.dart`.
@JeebPreview(group: 'chat', name: 'Sender bubble · default colour', size: _chatBubbleTimestampMatrixBox, matrix: true)
Widget chatBubbleTimestampDefaultInkOnBubble() => _chatBubbleTimestampSenderFooter(
      body: 'Coming down now, one minute',
      sentAt: DateTime(2026, 6, 11, 23, 58),
      overrideColour: false,
      caption: 'no colour override — default surface ink',
    );

/// A history row the gateway returned with no usable `created_at`.
///
/// `sentAt` here is the epoch ordering anchor `ChatMessageCodec` substitutes,
/// and `hasServerTimestamp: false` is the flag that says so. The bubble must
/// render its body and NO clock — `SizedBox.shrink()`, not "00:00", not a
/// dimmed placeholder. If a clock ever appears in this card, the whole
/// 56-years-ago class of bug (`chat_undated_band_contract_test.dart`) is back.
///
/// The caption is preview scaffolding: without it an empty footer is
/// indistinguishable from a preview that failed to build.
@JeebPreview(group: 'chat', name: 'Ordering anchor · no clock', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampOrderingAnchor() => _chatBubbleTimestampOfferFooter(
      sentAt: DateTime(1970),
      hasServerTimestamp: false,
      caption: 'anchor only — no clock is drawn',
    );

/// The SAME epoch instant with the flag left at its default `true` — the
/// regression this widget's `hasServerTimestamp` parameter exists to prevent.
///
/// The comment on that field records that the fact used to be re-derived from
/// the VALUE of `sentAt` ("any instant inside 1970"); this card is what a caller
/// that forgets to forward `message.hasServerTimestamp` still ships: a
/// confident, correctly formatted **00:00** over a live conversation.
///
/// It doubles as the format check the happy path cannot make — `DateFormat.Hm`
/// must render a zero-padded 24-hour clock, so midnight is "00:00" and never
/// "12:00 AM".
@JeebPreview(group: 'chat', name: 'Epoch anchor drawn as 00:00', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampEpochDrawn() => _chatBubbleTimestampOfferFooter(sentAt: DateTime(1970));

/// A send time that reached the widget as UTC instead of local time.
///
/// [DateFormat] formats the fields the [DateTime] carries and converts nothing,
/// and this widget — unlike `delivery_stage_indicator.dart:136` and
/// `jeeber_feed_card.dart:749`, which both call `.toLocal()` before formatting
/// the very same `Hm` skeleton — trusts its caller completely. Today
/// `ChatMessageCodec.sentAtOf` localises, which is the only reason the live
/// paths are correct.
///
/// 21:05 UTC on 11 June is 00:05 the NEXT DAY in Beirut, so this card must
/// render **21:05** — three hours and one date-separator wrong — to show what a
/// forgetful new gateway path would put in the thread.
@JeebPreview(group: 'chat', name: 'UTC instant, not localized', size: _chatBubbleTimestampBubbleBox)
Widget chatBubbleTimestampUtcInstant() =>
    _chatBubbleTimestampOfferFooter(sentAt: DateTime.utc(2026, 6, 11, 21, 5));
