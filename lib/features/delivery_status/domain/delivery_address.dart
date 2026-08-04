import 'package:equatable/equatable.dart';

class DeliveryAddress extends Equatable {
  const DeliveryAddress({
    required this.label,
    this.detail,
  });

  final String label;

  final String? detail;

  @override
  List<Object?> get props => [label, detail];
}
