import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Centered "Today" / "Yesterday" / locale-date separator shown at the top of
/// a day group in the chat timeline (Figma nodes 56535:6659 + 56546:2382).
///
/// Wraps the OMDS [OmdsDateChip] primitive and owns only the relative-date
/// label logic so the same chip renders in both the broadcasting (02) and
/// post-approval (03) chat states. The label resolves through
/// [AppLocalizations] for "today"/"yesterday" and falls back to a locale-aware
/// medium date via [DateFormat] — never a string-built date.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});

  /// The calendar day this separator introduces.
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Semantics(
      identifier: 'chat_detail_date_separator',
      label: _label(l10n, locale),
      child: OmdsDateChip(
        key: const Key('chat-date-separator'),
        text: _label(l10n, locale),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _label(AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return l10n.chatDateChipToday;
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return l10n.chatDateChipYesterday;
    }
    return DateFormat.yMMMMd(locale).format(date);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
