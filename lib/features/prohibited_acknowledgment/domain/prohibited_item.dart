import 'package:equatable/equatable.dart';

/// A single prohibited item returned by `GET /prohibited-items`.
class ProhibitedItem extends Equatable {
  const ProhibitedItem({
    required this.id,
    required this.name,
    this.category,
    this.severity = ProhibitedItemSeverity.block,
  });

  final String id;
  final String name;
  final String? category;
  final ProhibitedItemSeverity severity;

  @override
  List<Object?> get props => [id, name, category, severity];
}

enum ProhibitedItemSeverity { block, warn }
