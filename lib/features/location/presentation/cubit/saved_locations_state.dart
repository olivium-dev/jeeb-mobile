import 'package:equatable/equatable.dart';

import '../../domain/saved_location.dart';

/// All states for the saved locations CRUD screen (T-MOB-025).
sealed class SavedLocationsState extends Equatable {
  const SavedLocationsState();

  @override
  List<Object?> get props => [];
}

/// Fetching the initial list.
final class SavedLocationsLoading extends SavedLocationsState {
  const SavedLocationsLoading();
}

/// List loaded successfully.
final class SavedLocationsLoaded extends SavedLocationsState {
  const SavedLocationsLoaded(this.locations);

  final List<SavedLocation> locations;

  @override
  List<Object?> get props => [locations];
}

/// Failed to load the list.
final class SavedLocationsError extends SavedLocationsState {
  const SavedLocationsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// A mutating operation (create/update/delete) is in progress.
final class SavedLocationsMutating extends SavedLocationsState {
  const SavedLocationsMutating(this.locations);

  final List<SavedLocation> locations;

  @override
  List<Object?> get props => [locations];
}

/// Mutation failed; reverts to the last known good list.
final class SavedLocationsMutationError extends SavedLocationsState {
  const SavedLocationsMutationError({
    required this.locations,
    required this.message,
    this.isCapError = false,
  });

  final List<SavedLocation> locations;
  final String message;

  /// True when the error is a cap-of-10 hit (HTTP 409).
  final bool isCapError;

  @override
  List<Object?> get props => [locations, message, isCapError];
}
