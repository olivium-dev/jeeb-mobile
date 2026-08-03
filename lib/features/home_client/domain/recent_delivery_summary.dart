import 'package:equatable/equatable.dart';

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
