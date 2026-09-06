import 'package:equatable/equatable.dart';

import '../../../../core/network/app_failure.dart';
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
  const SavedLocationsLoaded(this.locations, {this.refreshError});

  final List<SavedLocation> locations;

  /// A refresh failed while these rows are on screen; the rows survive.
  final AppFailure? refreshError;

  @override
  List<Object?> get props => [locations, refreshError];
}

final class SavedLocationsError extends SavedLocationsState {
  const SavedLocationsError(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class SavedLocationsMutating extends SavedLocationsState {
  const SavedLocationsMutating(this.locations);

  final List<SavedLocation> locations;

  @override
  List<Object?> get props => [locations];
}

/// Which mutation failed — the copy the screen shows follows from this, not
/// from a stringly code.
enum SavedLocationsMutation { create, update, delete }

final class SavedLocationsMutationError extends SavedLocationsState {
  const SavedLocationsMutationError({
    required this.locations,
    required this.mutation,
    this.failure,
    this.isCapError = false,
  });

  final List<SavedLocation> locations;
  final SavedLocationsMutation mutation;

  /// Null only for the cap rule, which is a product limit, not a transport
  /// failure.
  final AppFailure? failure;

  final bool isCapError;

  @override
  List<Object?> get props => [locations, mutation, failure, isCapError];
}
