import 'package:equatable/equatable.dart';

/// Summary card for "Order again" — a previously completed delivery the
/// sender might want to repeat with one tap. Intentionally small: the home
/// tab only renders the most recent one.
class RecentDeliverySummary extends Equatable {
  const RecentDeliverySummary({
    required this.id,
    required this.title,
    required this.destinationLabel,
    required this.completedAt,
  });

  final String id;
  final String title;
  final String destinationLabel;
  final DateTime completedAt;

  @override
  List<Object?> get props => [id, title, destinationLabel, completedAt];
}
