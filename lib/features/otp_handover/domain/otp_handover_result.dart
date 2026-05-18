import 'package:equatable/equatable.dart';

class OtpHandoverResult extends Equatable {
  const OtpHandoverResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;

  @override
  List<Object?> get props => [success, message];
}
