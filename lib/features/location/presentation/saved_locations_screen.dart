import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/root_aware_back_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../data/dio_saved_location_repository.dart';
import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';
import 'cubit/saved_locations_cubit.dart';
import 'cubit/saved_locations_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/saved_locations_screen_fixtures.dart';

String _defaultBadgeLabel(Locale locale) =>
    locale.languageCode == 'ar' ? 'الافتراضي' : 'Default';

class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key, this.repository});

  final SavedLocationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SavedLocationsCubit(repository ?? _resolveRepository())
        ..load(),
      child: const _SavedLocationsView(),
    );
  }

  SavedLocationRepository _resolveRepository() {
    if (sl.isRegistered<SavedLocationRepository>()) {
      return sl<SavedLocationRepository>();
    }
    return DioSavedLocationRepository(sl<Dio>());
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
        return RootAwareBackScope(
          fallbackLocation: '/settings',
          child: Scaffold(
            appBar: OMDSAppBar(
              title: l10n.savedAddressesTitle,
              showBackButton: true,
            ),
            body: _buildBody(context, state),
            floatingActionButton: _AddAddressFab(
              enabled: !_isMutating(state) && state is! SavedLocationsLoading,
              onPressed: () => _onAdd(context),
            ),
          ),
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
      return const _EmptyView();
    }
    return _LocationList(locations: locations, isMutating: _isMutating(state));
  }

  Future<void> _onAdd(BuildContext context) async {
    final cubit = context.read<SavedLocationsCubit>();
    await context.pushNamed('address-detail');
    if (!context.mounted) return;
    await cubit.load();
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

class _AddAddressFab extends StatelessWidget {
  const _AddAddressFab({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'saved_address_add_cta',
      button: true,
      enabled: enabled,
      label: l10n.savedLocationsAddNew,
      child: FloatingActionButton.extended(
        heroTag: 'saved-address-add-fab',
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.add),
        label: Text(l10n.savedLocationsAddNew),
      ),
    );
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
            index: i,
            location: locations[i],
            isMutating: isMutating,
          ),
        ),
        if (isMutating) const Center(child: OmdsLoadingState()),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.index,
    required this.location,
    required this.isMutating,
  });

  final int index;
  final SavedLocation location;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      onTap: isMutating ? null : () => _onEdit(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xSmall,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            Icon(_iconFor(location.category), color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          location.label,
                          style: theme.textTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (location.isDefault) ...[
                        const SizedBox(width: Spacing.xSmall),
                        _DefaultBadge(locale: l10n.locale),
                      ],
                    ],
                  ),
                  if (location.address != null) ...[
                    const SizedBox(height: Spacing.twoXSmall),
                    Text(
                      location.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _EditButton(
              index: index,
              label: l10n.savedLocationsEdit,
              onTap: isMutating ? null : () => _onEdit(context),
            ),
            _MoreButton(
              index: index,
              label: location.label,
              onTap: isMutating ? null : () => _onMore(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEdit(BuildContext context) async {
    final cubit = context.read<SavedLocationsCubit>();
    await context.pushNamed(
      'address-detail',
      queryParameters: {'id': location.id},
    );
    if (!context.mounted) return;
    await cubit.load();
  }

  Future<void> _onMore(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final choice = await _showActionsSheet(context, l10n);
    if (choice == null || !context.mounted) return;
    if (choice == _Action.edit) {
      await _onEdit(context);
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

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _defaultBadgeLabel(locale);
    return Semantics(
      identifier: 'saved_address_default_badge',
      label: label,
      child: ExcludeSemantics(
        child: OmdsChip(
          label: label,
          isSelected: true,
          selectedColor: scheme.primaryContainer,
          selectedTextColor: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({
    required this.index,
    required this.label,
    required this.onTap,
  });

  final int index;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'saved_address_${index}_edit',
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: label,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.index,
    required this.label,
    required this.onTap,
  });

  final int index;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'saved_address_${index}_more',
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: label,
          onPressed: onTap,
        ),
      ),
    );
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
            Semantics(
              identifier: 'saved_address_sheet_edit_cta',
              container: true,
              button: true,
              child: OmdsSettingsRow(
                title: editLabel,
                leadingIcon: Icons.edit_outlined,
                trailing: const SizedBox.shrink(),
                onTap: () => Navigator.of(context).pop(_Action.edit),
              ),
            ),
            Semantics(
              identifier: 'saved_address_sheet_delete_cta',
              container: true,
              button: true,
              child: OmdsSettingsRow(
                title: deleteLabel,
                leadingIcon: Icons.delete_outline,
                leadingIconColor: Theme.of(context).colorScheme.error,
                titleStyle: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
                trailing: const SizedBox.shrink(),
                onTap: () => Navigator.of(context).pop(_Action.delete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      key: const Key('saved-locations-empty'),
      child: OmdsEmptyState(
        icon: Icons.place_outlined,
        title: l10n.savedAddressesEmptyTitle,
        subtitle: l10n.savedAddressesEmptyBody,
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
      key: const Key('saved-locations-error'),
      child: OmdsErrorState(
        icon: Icons.cloud_off_outlined,
        message: l10n.savedLocationsError,
        retryLabel: l10n.savedLocationsRetry,
        onRetry: onRetry,
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _savedLocationsScreenPhoneBox = Size(390, 844);

class _SavedLocationsScreenFormStandIn extends StatelessWidget {
  const _SavedLocationsScreenFormStandIn({this.addressId});

  final String? addressId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('address-detail (preview stand-in)')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin identifier
          'id: ${addressId ?? '<add>'}',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _SavedLocationsScreenHost extends StatefulWidget {
  const _SavedLocationsScreenHost({required this.repository});

  final SavedLocationRepository repository;

  @override
  State<_SavedLocationsScreenHost> createState() =>
      _SavedLocationsScreenHostState();
}

class _SavedLocationsScreenHostState extends State<_SavedLocationsScreenHost> {
  late final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) =>
            SavedLocationsScreen(repository: widget.repository),
        routes: <RouteBase>[
          GoRoute(
            path: 'address-detail',
            name: 'address-detail',
            builder: (_, GoRouterState state) =>
                _SavedLocationsScreenFormStandIn(
              addressId: state.uri.queryParameters['id'],
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _savedLocationsScreenHosted(SavedLocationRepository repository) =>
    _SavedLocationsScreenHost(repository: repository);

Widget _savedLocationsScreenWith(List<SavedLocation> locations) =>
    _savedLocationsScreenHosted(
      SavedLocationsScreenFakeRepository(locations),
    );

@JeebPreview(
  group: 'location',
  name: 'Loaded · Home + Office',
  size: _savedLocationsScreenPhoneBox,
  matrix: true,
)
Widget savedLocationsScreenLoaded() =>
    _savedLocationsScreenWith(savedLocationsScreenHomeAndOffice);

@JeebPreview(
  group: 'location',
  name: 'Empty · nothing saved',
  size: _savedLocationsScreenPhoneBox,
)
Widget savedLocationsScreenEmpty() =>
    _savedLocationsScreenWith(const <SavedLocation>[]);

@JeebPreview(
  group: 'location',
  name: 'Error · load failed',
  size: _savedLocationsScreenPhoneBox,
)
Widget savedLocationsScreenError() => _savedLocationsScreenHosted(
      const SavedLocationsScreenFakeRepository(
        <SavedLocation>[],
        failFetch: true,
      ),
    );

@JeebPreview(
  group: 'location',
  name: 'Loading · spinner',
  size: _savedLocationsScreenPhoneBox,
)
Widget savedLocationsScreenLoading() => _savedLocationsScreenHosted(
      const SavedLocationsScreenPendingRepository(),
    );

@JeebPreview(
  group: 'location',
  name: 'Ten saved · at the cap',
  size: _savedLocationsScreenPhoneBox,
  matrix: true,
)
Widget savedLocationsScreenAtCapacity() =>
    _savedLocationsScreenWith(savedLocationsScreenAtCap);
