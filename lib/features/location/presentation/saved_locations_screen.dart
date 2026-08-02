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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/saved_locations_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so two things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (app bar + FAB) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_savedLocationsScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — an app bar, a list and a floating CTA cannot be judged
//    in a 200 pt strip.
//
// 2. It needs a `Router` ABOVE it to build at all. `_SavedLocationsView` wraps
//    its Scaffold in [RootAwareBackScope] → `BackButtonListener`, whose
//    `didChangeDependencies` calls `Router.of(context)`; under a plain
//    `MaterialApp` (which is what both the canvas host and the render harness
//    provide) there is no `Router` and the screen throws before it paints.
//    [_SavedLocationsScreenHost] supplies one via `Router.withConfig` over a
//    local [GoRouter]. That also makes the canvas honest to tap in: `Add` and
//    the per-row edit affordance both `pushNamed('address-detail')`, and the
//    stand-in route below catches them instead of throwing.
//
// The state itself is driven the only way this screen allows: through the
// `repository:` constructor seam, with the fakes shared with the Screen Catalog
// entry (`lib/devtool/catalog/fixtures/saved_locations_screen_fixtures.dart`).
// No preview builds a `DioSavedLocationRepository`, and `_resolveRepository()`
// — the GetIt path — is never reached, so these are network-free by
// construction rather than by the guard in [jeebPreviewHost].
//
// Two states cannot be reached from here, and both are worth knowing about:
// `SavedLocationsMutating` (the delete-in-flight overlay) and
// `SavedLocationsMutationError` (the cap-reached / delete-failed snackbar) are
// only emitted AFTER a tap, and the screen builds its own
// [SavedLocationsCubit] internally — there is no `cubit:` seam to seed one
// with. In the canvas you can still reach them by hand: "…" → Delete on a row
// whose fake `deleteLocation` hangs or throws.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * the Add CTA is a `FloatingActionButton.extended`, which has no disabled
//    rendering, so during the initial load it looks exactly as tappable as it
//    does when it works (`Loading · spinner`);
//  * the title line of a tile is `Flexible(label) + _DefaultBadge`, and the
//    badge is NOT flexible — it takes its natural width first and the label
//    ellipsizes into what is left. In Arabic at 200% text the badge
//    (`الافتراضي`, wider than `Default`) is alone wider than the 206 pt the
//    title line gets, so the row overflows by 42 pt: `RenderFlex overflowed by
//    42 pixels` on `Row ← Column ← Expanded ← Row` in BOTH list previews.
//    EN at 200% clears it, AR at 100% clears it; only the two together break.
//    Note that the standard matrix cannot show you this — it renders AR at
//    100% and 200% in EN — so it is asserted nowhere and has to be read here.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _savedLocationsScreenPhoneBox = Size(390, 844);

/// The `address-detail` (JM-050) form the manager hands off to, stubbed.
///
/// The real route lives in `app_router.dart` and owns persistence; here it only
/// has to exist so a tap on `saved_address_add_cta` or `saved_address_<n>_edit`
/// lands somewhere and shows WHICH path was taken — add (no id) or edit
/// (`?id=<addressId>`).
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
          // reorders visually inside an RTL paragraph.
          'id: ${addressId ?? '<add>'}',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [SavedLocationsScreen] so it can build.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state the
/// screen's own `pushNamed`/`canPop` calls depend on. `Router.withConfig` is
/// exactly what `MaterialApp.router` does internally, so this adds a Router and
/// nothing else — the ambient theme, locale and text scale still come from the
/// preview host above it.
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

/// The happy path, and the state the JM-049 ACs are written against: `Home` is
/// the default (it carries `saved_address_default_badge`), `Office` is not.
///
/// Matrixed because this row is the whole layout question — icon, label,
/// badge, edit and overflow affordances all competing for one horizontal run.
/// The AR rendering is where the badge changes width (`الافتراضي` vs
/// `Default`) and the whole row mirrors; the 200% rendering is where the badge
/// starts taking the label's space.
///
/// The two together is the state that actually breaks (42 pt overflow, see the
/// section header) and the matrix does not render that combination — to see it,
/// pump this preview at `TextScaler.linear(2)` under `Locale('ar')`.
@JeebPreview(
  group: 'location',
  name: 'Loaded · Home + Office',
  size: _savedLocationsScreenPhoneBox,
  matrix: true,
)
Widget savedLocationsScreenLoaded() =>
    _savedLocationsScreenWith(savedLocationsScreenHomeAndOffice);

/// A new account: nothing saved yet.
///
/// The zero-state is guidance only — the Add CTA stays on the FAB, so this is
/// the one surface where the FAB is the sole way forward. Worth checking that
/// the centred [OmdsEmptyState] body and the floating CTA do not collide at
/// 200% text.
@JeebPreview(
  group: 'location',
  name: 'Empty · nothing saved',
  size: _savedLocationsScreenPhoneBox,
)
Widget savedLocationsScreenEmpty() =>
    _savedLocationsScreenWith(const <SavedLocation>[]);

/// `GET /users/:userId/saved-locations` failed.
///
/// The cubit collapses every failure to `SavedLocationsError('fetch_failed')`,
/// so this one picture covers offline, 401 and 500 alike — the user is told
/// only "could not load" and offered `Try again`, which re-runs the real load.
///
/// Note what the FAB does here: it stays ENABLED on a list that failed to load,
/// so `Add` remains reachable even though the manager cannot show what is
/// already saved — a user can add a duplicate of an address they cannot see.
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

/// The cold-start window, held open by a read that never lands.
///
/// The list area is a centred [OmdsLoadingState] spinner, and the FAB is built
/// with `enabled: false` → `onPressed: null`. `FloatingActionButton.extended`
/// has no disabled rendering: it keeps its filled container colour and its
/// label at full opacity, so the Add CTA here is pixel-identical to the working
/// one two previews up. On a slow connection that is a CTA that looks live and
/// silently swallows taps.
@JeebPreview(
  group: 'location',
  name: 'Loading · spinner',
  size: _savedLocationsScreenPhoneBox,
)
Widget savedLocationsScreenLoading() => _savedLocationsScreenHosted(
      const SavedLocationsScreenPendingRepository(),
    );

/// The layout ceiling: TEN saved addresses — the cap — with the longest label
/// and address a user can plausibly save on the default row.
///
/// Read the first row in the matrix. The tile lays the title line out as
/// `Flexible(label) + badge`, so the badge takes its width first and the label
/// ellipsizes into whatever is left; the row carrying the default badge is
/// therefore the row whose name is cut shortest, which is the opposite of what
/// a user scanning for "my usual address" needs. Row 1 (`Teta`) has no
/// `address` at all and shows the tile's other, single-line layout.
@JeebPreview(
  group: 'location',
  name: 'Ten saved · at the cap',
  size: _savedLocationsScreenPhoneBox,
  matrix: true,
)
Widget savedLocationsScreenAtCapacity() =>
    _savedLocationsScreenWith(savedLocationsScreenAtCap);
