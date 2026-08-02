/// Widget previews for [ChatDateSeparator] — run with
/// `flutter widget-preview start`.
///
/// The separator takes exactly one input, a [DateTime], and turns it into one
/// of three labels: the localized "today", the localized "yesterday", or a
/// locale-aware medium date from DateFormat. Every state below is therefore
/// just a date — no cubit, no repository, no network by construction.
///
/// The states worth looking at are the ones where that mapping can go wrong or
/// where the resulting label stops fitting: the DateFormat fallback (which is
/// the only branch that is NOT a translated string and so is the one that
/// breaks in Arabic), the longest label the formatter can produce, and the two
/// non-real dates the chat timeline is known to be able to hand this widget —
/// a 1970 ordering anchor and a UTC instant that was never converted to local
/// time.
///
/// Two things these previews already surfaced, both in the widget rather than
/// in the previews: the merged semantics node reads the date TWICE (the
/// `Semantics` wrapper sets a label but not `excludeSemantics`, so the inner
/// `Text` contributes a second copy), and at 200% text the chip loses its side
/// gutters entirely — see the notes on the individual states below.
library;

import 'package:flutter/material.dart';

import '../../features/chat/presentation/widgets/chat_date_separator.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for a timeline separator: phone width, one chip tall.
///
/// The chip adds 16px of vertical margin above and below itself, so even the
/// single-line labels need noticeably more room than the text.
const Size _separatorBox = Size(390, 96);

/// A taller box for the states whose label wraps at 200% text.
const Size _tallSeparatorBox = Size(390, 150);

Widget _hosted(DateTime date) => ChatDateSeparator(date: date);

/// The overwhelmingly common state: the thread's first message was sent today.
///
/// Renders the localized "today" string (`chatDateChipToday`), never a
/// formatted date — this is the branch that proves the relative labels are
/// preferred over DateFormat.
@JeebPreview(name: 'Today', size: _separatorBox)
Widget chatDateSeparatorToday() => _hosted(DateTime.now());

/// The second relative branch: a thread whose first message is one day old.
///
/// Built with the same `now.subtract(const Duration(days: 1))` expression the
/// widget uses internally, so the preview reproduces the widget's own notion of
/// "yesterday" rather than a competing one.
@JeebPreview(name: 'Yesterday', size: _separatorBox)
Widget chatDateSeparatorYesterday() =>
    _hosted(DateTime.now().subtract(const Duration(days: 1)));

/// The DateFormat fallback: an older thread inside the current year.
///
/// This is the ONLY label that does not come from the ARB, so it is the only
/// one that can silently stay English while the rest of the screen is Arabic.
/// The AR RTL rendering of this preview is the check that matters: it must show
/// Arabic month names and Arabic-Indic digits, not "March 8, 2026".
@JeebPreview(name: 'Older date', size: _separatorBox)
Widget chatDateSeparatorOlderDate() => _hosted(DateTime(2026, 3, 8));

/// The layout ceiling: the longest label the formatter can produce.
///
/// `yMMMMd` spells the month out, so September + a two-digit day + a four-digit
/// year is the widest English label a real conversation can produce. At 200%
/// text this is where the chip either wraps or runs past the phone edge, and in
/// Arabic it is where the mirrored digit/month order shows up.
///
/// What it currently shows, measured at 390pt: a centered 239pt pill at 1x, and
/// at 2x a chip that is exactly 390pt wide starting at x=0 — the label wraps to
/// two lines and the pill runs edge to edge with no side gutter, because
/// the chip's default margin is vertical-only and this widget passes no
/// horizontal margin of its own (`OmdsDateChip` defaults `margin` to
/// `EdgeInsets.symmetric(vertical: 16)`).
@JeebPreview(name: 'Longest date label', size: _tallSeparatorBox)
Widget chatDateSeparatorLongestLabel() => _hosted(DateTime(2025, 9, 28));

/// The 1970 ordering anchor, made visible.
///
/// `_ChatMessageList` only emits a separator when the first message
/// `hasServerTimestamp`, precisely because an undated row carries an ordering
/// anchor inside 1970 and "a '1 Jan 1970' divider over a live thread would be a
/// fabrication". That guard lives entirely in the caller: hand this widget an
/// epoch date and it renders it without complaint. This preview is what that
/// regression would look like if the caller-side guard is ever dropped.
@JeebPreview(name: 'Epoch anchor (1970)', size: _separatorBox)
Widget chatDateSeparatorEpochAnchor() => _hosted(DateTime(1970));

/// A send time that reached the widget as UTC instead of local time.
///
/// The day comparison reads `date.year/month/day` directly, so it trusts
/// whatever zone the [DateTime] carries. `ChatMessageCodec.sentAtOf` calls
/// `.toLocal()` today, which is the only reason this cannot happen on the live
/// paths; a new caller that forgets to would shift every late-evening message
/// back a day. 22:00 UTC on 31 Dec is 00:00 on 1 Jan in Beirut, and this
/// preview must render "December 31, 2024" — the wrong day — to show it.
@JeebPreview(name: 'UTC instant, not localized', size: _tallSeparatorBox)
Widget chatDateSeparatorUtcInstant() =>
    _hosted(DateTime.utc(2024, 12, 31, 22));
