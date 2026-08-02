import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
const Size _chatDateSeparatorSeparatorBox = Size(390, 96);

const Size _chatDateSeparatorTallSeparatorBox = Size(390, 150);

Widget _chatDateSeparatorHosted(DateTime date) => ChatDateSeparator(date: date);

@JeebPreview(group: 'chat', name: 'Today', size: _chatDateSeparatorSeparatorBox)
Widget chatDateSeparatorToday() => _chatDateSeparatorHosted(DateTime.now());

@JeebPreview(group: 'chat', name: 'Yesterday', size: _chatDateSeparatorSeparatorBox)
Widget chatDateSeparatorYesterday() =>
    _chatDateSeparatorHosted(DateTime.now().subtract(const Duration(days: 1)));

@JeebPreview(group: 'chat', name: 'Older date', size: _chatDateSeparatorSeparatorBox)
Widget chatDateSeparatorOlderDate() => _chatDateSeparatorHosted(DateTime(2026, 3, 8));

@JeebPreview(group: 'chat', name: 'Longest date label', size: _chatDateSeparatorTallSeparatorBox)
Widget chatDateSeparatorLongestLabel() => _chatDateSeparatorHosted(DateTime(2025, 9, 28));

@JeebPreview(group: 'chat', name: 'Epoch anchor (1970)', size: _chatDateSeparatorSeparatorBox)
Widget chatDateSeparatorEpochAnchor() => _chatDateSeparatorHosted(DateTime(1970));

@JeebPreview(group: 'chat', name: 'UTC instant, not localized', size: _chatDateSeparatorTallSeparatorBox)
Widget chatDateSeparatorUtcInstant() =>
    _chatDateSeparatorHosted(DateTime.utc(2024, 12, 31, 22));
