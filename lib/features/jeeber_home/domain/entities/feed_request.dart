import 'package:equatable/equatable.dart';

class FeedRequest extends Equatable {
  const FeedRequest({
    required this.id,
    required this.shortLabel,
    this.description,
  });

  final String id;

  final String shortLabel;

  final String? description;

  @override
  List<Object?> get props => [id, shortLabel, description];
}
