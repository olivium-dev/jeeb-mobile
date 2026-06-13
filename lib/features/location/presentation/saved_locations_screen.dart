import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';
import 'cubit/saved_locations_cubit.dart';
import 'cubit/saved_locations_state.dart';
import 'widgets/add_edit_location_sheet.dart';

/// Saved-locations CRUD screen (T-MOB-025).
///
/// Profile → Settings → Addresses route.
/// Lifted from salehly-mobile location_screen.dart pattern, restyled with
/// OMDS tokens and backed by `/v1/users/me/saved-locations` CRUD.
class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key, this.repository});

  /// Injectable for widget tests; production resolves via DI.
  final SavedLocationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) {
        final repo = repository ?? ctx.read<SavedLocationRepository>();
        return SavedLocationsCubit(repo)..load();
      },
      child: const _SavedLocationsView(),
    );
  }
}

class _SavedLocationsView extends StatelessWidget {
  const _SavedLocationsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SavedLocationsCubit, SavedLocationsState>(
      listenWhen: _shouldListen,
      listener: _onStateChange,
      builder: (context, state) {
        return Scaffold(
          appBar: OMDSAppBar(
            title: l10n.savedAddressesTitle,
            showBackButton: true,
          ),
          body: _buildBody(context, state),
          floatingActionButton: _buildFab(context, state, l10n),
        );
      },
    );
  }

  bool _shouldListen(SavedLocationsState prev, SavedLocationsState curr) {
    return curr is SavedLocationsMutationError;
  }

  void _onStateChange(BuildContext context, SavedLocationsState state) {
    if (state is! SavedLocationsMutationError) return;
    final l10n = AppLocalizations.of(context);
    if (state.isCapError) {
      showOmdsSnackbar(context, message: l10n.savedLocationsCapReached);
    } else if (state.message == 'delete_failed') {
      showOmdsSnackbar(context, message: l10n.savedLocationsDeleteError);
    } else {
      showOmdsSnackbar(context, message: l10n.savedLocationsSaveError);
    }
    context.read<SavedLocationsCubit>().acknowledgeError();
  }

  Widget _buildBody(BuildContext context, SavedLocationsState state) {
    final locations = _locationsFrom(state);
    if (state is SavedLocationsLoading) {
      return const Center(child: OmdsLoadingState());
    }
    if (state is SavedLocationsError) {
      return _ErrorView(
        onRetry: () => context.read<SavedLocationsCubit>().load(),
      );
    }
    if (locations.isEmpty) {
      return _EmptyView();
    }
    return _LocationList(locations: locations, isMutating: _isMutating(state));
  }

  Widget? _buildFab(
    BuildContext context,
    SavedLocationsState state,
    AppLocalizations l10n,
  ) {
    if (state is SavedLocationsLoading || state is SavedLocationsError) {
      return null;
    }
    // EXEMPT: No OmdsFloatingActionButton exists in the OMDS component library.
    // FloatingActionButton.extended is used here following the approved fleet
    // pattern until an OMDS FAB variant ships (tracked under T-MOB-025).
    return FloatingActionButton.extended(
      heroTag: 'add-location-fab',
      onPressed: _isMutating(state) ? null : () => _onAdd(context),
      icon: const Icon(Icons.add),
      label: Text(l10n.savedLocationsAddNew),
    );
  }

  Future<void> _onAdd(BuildContext context) async {
    final result = await AddEditLocationSheet.show(
      context: context,
      existing: null,
    );
    if (result == null || !context.mounted) return;
    await context.read<SavedLocationsCubit>().create(
          latitude: result.latitude,
          longitude: result.longitude,
          label: result.label,
          category: result.category,
          address: result.address,
        );
  }

  List<SavedLocation> _locationsFrom(SavedLocationsState state) {
    return switch (state) {
      SavedLocationsLoaded(:final locations) => locations,
      SavedLocationsMutating(:final locations) => locations,
      SavedLocationsMutationError(:final locations) => locations,
      _ => const [],
    };
  }

  bool _isMutating(SavedLocationsState state) {
    return state is SavedLocationsMutating;
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({required this.locations, required this.isMutating});

  final List<SavedLocation> locations;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          itemCount: locations.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (ctx, i) => _LocationTile(
            location: locations[i],
            isMutating: isMutating,
          ),
        ),
        if (isMutating)
          const Center(child: OmdsLoadingState()),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location, required this.isMutating});

  final SavedLocation location;
  final bool isMutating;

  String _semanticLabel(AppLocalizations l10n) {
    final addr = location.address ?? '';
    // AC4: accessible label per ticket spec
    return '${location.label}, $addr, double tap to edit';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: _semanticLabel(l10n),
      child: OmdsSettingsRow(
        title: location.label,
        subtitle: location.address,
        leadingIcon: _iconFor(location.category),
        trailing: const Icon(Icons.more_vert),
        onTap: isMutating ? null : () => _onEdit(context),
        titleStyle: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Future<void> _onEdit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final choice = await _showActionsSheet(context, l10n);
    if (choice == null || !context.mounted) return;
    if (choice == _Action.edit) {
      await _handleEdit(context);
    } else {
      await _handleDelete(context, l10n);
    }
  }

  Future<_Action?> _showActionsSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<_Action>(
      context: context,
      // EXEMPT: OmdsBottomSheet lacks a typed-return action-list variant.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (_) => _ActionSheet(
        locationLabel: location.label,
        editLabel: l10n.savedLocationsEdit,
        deleteLabel: l10n.savedLocationsDelete,
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context) async {
    final result = await AddEditLocationSheet.show(
      context: context,
      existing: location,
    );
    if (result == null || !context.mounted) return;
    await context.read<SavedLocationsCubit>().update(
          id: location.id,
          latitude: result.latitude,
          longitude: result.longitude,
          label: result.label,
          category: result.category,
          address: result.address,
        );
  }

  Future<void> _handleDelete(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.savedLocationsDeleteConfirmTitle,
      content: l10n.savedLocationsDeleteConfirmBody(location.label),
      confirmText: l10n.savedLocationsDelete,
      cancelText: l10n.actionCancel,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SavedLocationsCubit>().delete(location.id);
  }

  IconData _iconFor(SavedLocationCategory cat) {
    switch (cat) {
      case SavedLocationCategory.home:
        return Icons.home_outlined;
      case SavedLocationCategory.work:
        return Icons.work_outline;
      case SavedLocationCategory.other:
        return Icons.place_outlined;
    }
  }
}

enum _Action { edit, delete }

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.locationLabel,
    required this.editLabel,
    required this.deleteLabel,
  });

  final String locationLabel;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.small),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.medium,
                vertical: Spacing.xSmall,
              ),
              child: Text(
                locationLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            OmdsSettingsRow(
              title: editLabel,
              leadingIcon: Icons.edit_outlined,
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.of(context).pop(_Action.edit),
            ),
            OmdsSettingsRow(
              title: deleteLabel,
              leadingIcon: Icons.delete_outline,
              leadingIconColor: Theme.of(context).colorScheme.error,
              titleStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.of(context).pop(_Action.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.place_outlined, size: 64),
          const SizedBox(height: Spacing.medium),
          Text(
            l10n.savedAddressesEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.small),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xLarge),
            child: Text(
              l10n.savedAddressesEmptyBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: Spacing.medium),
          Text(l10n.savedLocationsError),
          const SizedBox(height: Spacing.medium),
          OmdsPrimaryButton(
            text: l10n.earningsLoadRetry,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}
