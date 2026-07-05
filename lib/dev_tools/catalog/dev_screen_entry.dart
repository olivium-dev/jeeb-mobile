import 'package:flutter/widgets.dart';

/// Builds the RAW screen widget (with mock data already wired) for a preview.
///
/// The returned widget is the real product screen — LIVE and interactive, not a
/// screenshot. Only DATA and navigation are mocked by the builder; form controls
/// stay untouched so previews behave like the real thing.
typedef DevScreenBuilder = Widget Function(BuildContext context);

/// One previewable state of a screen (e.g. "Populated (EN)", "Empty (AR)").
///
/// A screen usually has several states, each mapping 1:1 to a `testWidgets`
/// case in the matching `integration_test/screens/<file>_test.dart` (its
/// screenshot suffix → [id], its locale → [locale], the widget it pumps →
/// what [builder] returns).
class DevScreenState {
  const DevScreenState({
    required this.id,
    required this.label,
    this.locale = const Locale('en'),
    required this.builder,
  });

  /// Kebab id, e.g. `'populated-en'`.
  final String id;

  /// Human label, e.g. `'Populated (EN)'`.
  final String label;

  /// Preview locale this state defaults to (the preview UI can override it).
  final Locale locale;

  /// Returns the raw screen widget with its mock data / fakes injected.
  final DevScreenBuilder builder;
}

/// A single screen registered in the dev catalog, with all of its states.
class DevScreenEntry {
  const DevScreenEntry({
    required this.id,
    required this.title,
    required this.group,
    this.keywords = const <String>[],
    required this.states,
  });

  /// Route-name-ish id, e.g. `'wallet-activity'`.
  final String id;

  /// Human title, e.g. `'Wallet Activity'`.
  final String title;

  /// Human group name used for grouping in the catalog, e.g. `'Wallet & Earnings'`.
  final String group;

  /// Extra search terms (beyond [title] and [id]).
  final List<String> keywords;

  /// The previewable states of this screen.
  final List<DevScreenState> states;
}
