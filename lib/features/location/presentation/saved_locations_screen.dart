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

/// `saved-addresses` (JM-049). Saved-address manager at `/settings/addresses`.
///
/// Reachable from `customer-profile` (`customer_profile_addresses_row`) and
/// `location-select` (`location_select_saved_addresses_row`) — both already
/// `goNamed('settings-addresses')` (integrator-wired); this screen owns only
/// the manager surface.
///
/// Exposes the 63_W1_TEST_PLAN §2.16 ids:
///   * `saved_address_add_cta`       — Add CTA (also the screen signature id),
///                                     → `address-detail` (add path).
///   * `saved_address_default_badge` — marks the default address (the seam
///                                     seeds `Home` as default).
///   * `saved_address_<n>_edit`      — per-row edit (index-0 pattern),
///                                     → `address-detail?id=<addressId>` (JM-050).
///
/// Backed by `GET/POST /users/:userId/saved-locations` via
/// [SavedLocationRepository] (`DioSavedLocationRepository`, repointed to the
/// journey-honest userId path in JM-049 — see 50_ROUTE_REQUESTS.md). Add/edit
/// hand off to the JM-050 `address-detail-form` route, which owns persistence;
/// this screen reloads on return so a newly-saved row appears.
/// Feature-local label for the default-address badge — the one string with no
/// dedicated ARB key (see the JM-049 request in 50_ROUTE_REQUESTS.md). Falls
/// back to English for any non-Arabic locale.
String _defaultBadgeLabel(Locale locale) =>
    locale.languageCode == 'ar' ? 'الافتراضي' : 'Default';

class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key, this.repository});

  /// Injectable for widget tests; production resolves via DI.
  final SavedLocationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SavedLocationsCubit(repository ?? _resolveRepository())
        ..load(),
      child: const _SavedLocationsView(),
    );
  }

  /// Resolves the repository the same way the sibling [ClientLocationScreen]
  /// does (40_GUARDRAILS_ARCH §5.4 — screen self-provides): prefer a DI-
  /// registered interface (`injection_container.dart` registers it over the
  /// app Dio), else self-provide the Dio impl over the registered Dio.
  ///
  /// The router builds `const SavedLocationsScreen()` with no `repository`, and
  /// nothing supplies a `SavedLocationRepository` in the *widget* tree — it
  /// lives in GetIt (`sl`), not a `RepositoryProvider`. The previous
  /// `context.read<SavedLocationRepository>()` therefore threw
  /// `ProviderNotFoundException` on build, so the manager never mounted and
  /// `saved_address_add_cta` was never visible (jm-024/049/050 root cause).
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
        // BACK-nav defect fix: this manager is reached via
        // `context.goNamed('settings-addresses')` from `customer-profile` (and
        // the address-form `goNamed` on save), which REPLACES the stack — so as
        // the stack root, BACK exited the app. The root-aware scope pops to
        // `/settings` (its route parent) when there is no back stack, and pops
        // normally when it was `push`ed (settings / location-select entries).
        return RootAwareBackScope(
          fallbackLocation: '/settings',
          child: Scaffold(
            appBar: OMDSAppBar(
              title: l10n.savedAddressesTitle,
              showBackButton: true,
            ),
            body: _buildBody(context, state),
            floatingActionButton: _AddAddressFab(
              // The Add CTA is the screen's signature id — present in EVERY
              // non-fatal state (incl. empty), per the jm-049 flow (AC2/AC5
              // assert it directly after opening the manager).
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

  /// Add path: route to the JM-050 form (no `id` → add). Reload on return so a
  /// freshly-saved address surfaces. The form owns the POST.
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

/// The Add-address CTA. EXEMPT: no `OmdsFloatingActionButton` exists in the OMDS
/// component library (the same approved fleet exemption the prior T-MOB-025
/// screen carried). Carries the `saved_address_add_cta` signature id.
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

  /// List position; drives the `saved_address_<index>_edit` id (63 §2.16
  /// coins index-0 for the seeded fixture; pattern `saved_address_<n>_edit`).
  final int index;
  final SavedLocation location;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Custom row (not OmdsSettingsRow) so the title/subtitle column is the
    // flexible part and the trailing edit/overflow controls stay fixed-width —
    // no overflow when the badge + two affordances coexist on a narrow tile.
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
              label: location.label,
              onTap: isMutating ? null : () => _onMore(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Edit path: route to the JM-050 form for THIS address (`?id=`). The form
  /// owns the PUT; the manager reloads on return.
  Future<void> _onEdit(BuildContext context) async {
    final cubit = context.read<SavedLocationsCubit>();
    await context.pushNamed(
      'address-detail',
      queryParameters: {'id': location.id},
    );
    if (!context.mounted) return;
    await cubit.load();
  }

  /// The overflow menu keeps Delete reachable (Edit also offered for parity).
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

/// The default-address badge carrying `saved_address_default_badge` (JM-049 AC).
///
/// No dedicated ARB key exists and the ARB layer is integrator-owned, so the
/// single word resolves via a feature-local EN/AR helper (the JM-031
/// `order_summary_l10n.dart` / JM-032 resolver precedent — see
/// 50_ROUTE_REQUESTS.md). Maestro asserts on the id, never the text, so swapping
/// to `l10n.savedAddressDefaultBadge` once the integrator lands it is a
/// no-call-site change.
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

/// Per-row edit affordance carrying `saved_address_<index>_edit` (→ JM-050 form).
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
    // The enclosing tile is itself an `InkWell` button. A button-flagged
    // Semantics node with no *action* of its own is treated as decorative
    // content and gets absorbed (merged) into that parent button — which
    // destroyed this node's `identifier` whenever the row also carried the
    // `saved_address_default_badge` (the default row), leaving
    // `saved_address_<index>_edit` unreachable to Maestro and widget tests.
    // Giving the Semantics a real `onTap` action makes it a first-class
    // actionable node (like the sibling `_MoreButton`), so it stays separate
    // and keeps its identifier. `ExcludeSemantics` still hides the inner
    // IconButton's duplicate node.
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
  const _MoreButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      tooltip: label,
      onPressed: onTap,
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
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // OMDS-consistent zero-state (was a hand-rolled Icon+Text column). The Add
    // CTA stays on the screen FAB, so this surface is guidance-only — honest:
    // there is genuinely nothing saved yet.
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
    // OMDS-consistent error state with retry (was a hand-rolled column reusing
    // the unrelated `earningsLoadRetry` label). [onRetry] re-runs the real
    // saved-locations load — no fabricated data.
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
