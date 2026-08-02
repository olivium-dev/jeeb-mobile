import 'package:equatable/equatable.dart';

import '../../domain/saved_location.dart';

sealed class SavedLocationsState extends Equatable {
  const SavedLocationsState();

  @override
  List<Object?> get props => [];
}

final class SavedLocationsLoading extends SavedLocationsState {
  const SavedLocationsLoading();
}

final class SavedLocationsLoaded extends SavedLocationsState {
  const SavedLocationsLoaded(this.locations);

  final List<SavedLocation> locations;

  @override
  List<Object?> get props => [locations];
}

final class SavedLocationsError extends SavedLocationsState {
  const SavedLocationsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class SavedLocationsMutating extends SavedLocationsState {
  const SavedLocationsMutating(this.locations);

  final List<SavedLocation> locations;

  @override
  List<Object?> get props => [locations];
}

final class SavedLocationsMutationError extends SavedLocationsState {
  const SavedLocationsMutationError({
    required this.locations,
    required this.message,
    this.isCapError = false,
  });

  final List<SavedLocation> locations;
  final String message;

  final bool isCapError;

  @override
  List<Object?> get props => [locations, message, isCapError];
}
