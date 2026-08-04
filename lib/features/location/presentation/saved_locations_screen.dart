import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/root_aware_back_scope.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
          // MIDNIGHT M3-28: R22's own field — `content` variant, orange glow
          // top-end, board-still. This manager is R22's MORE-band child.
          child: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.topEnd,
            animateDecor: false,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              // Redesign: the header is an in-body row, not a Material app bar
              // — no elevation, no surface tint, no centred title (kit §5 #1),
              // and the Add CTA sits on the board's docked pill footer.
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    JeebTopBar.back(
                      title: l10n.savedAddressesTitle,
                      identifier: 'saved_addresses_back',
                    ),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                // JeebCtaFooter applies no SafeArea of its own — the docked pad
                // is 24/0/24/32, the board's own footer inset.
                child: JeebCtaFooter.single(
                  child: _AddAddressCta(
                    // The Add CTA is the screen's signature id — present in
                    // EVERY non-fatal state (incl. empty), per the jm-049 flow
                    // (AC2/AC5 assert it right after opening the manager).
                    enabled:
                        !_isMutating(state) && state is! SavedLocationsLoading,
                    onPressed: () => _onAdd(context),
                  ),
                ),
              ),
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
      return const _LoadingView();
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

/// The Add-address CTA — the board's docked navy pill, not a floating action
/// button (no FAB is drawn anywhere on the redesign board). Same affordance,
/// same action, same `saved_address_add_cta` signature id.
class _AddAddressCta extends StatelessWidget {
  const _AddAddressCta({required this.enabled, required this.onPressed});

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
      // Deliberately NOT ExcludeSemantics: the wrapper mirrors the shape the
      // FAB had (annotations over a live, tappable child), so the node keeps a
      // real tap action.
      child: JeebCtaButton.primary(
        label: l10n.savedLocationsAddNew,
        leadingIcon: Icons.add,
        isEnabled: enabled,
        onTap: onPressed,
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
        ListView(
          // The board's 24px side gutter (§4.3 `--screen-gutter`).
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.medium,
            Spacing.xLarge,
            Spacing.medium,
          ),
          children: [
            // R22 carry-in: one glass band with 1px inset dividers, exactly the
            // MORE card that links here — not a stack of one-row cards.
            JeebOutlinedCard.grouped(
              children: [
                for (var i = 0; i < locations.length; i++)
                  _LocationTile(
                    index: i,
                    location: locations[i],
                    isMutating: isMutating,
                  ),
              ],
            ),
          ],
        ),
        if (isMutating) const Center(child: CircularProgressIndicator()),
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

  /// R22's navigation-row rung: `JeebListRow`'s 19px glyph and 12px gap, the
  /// metrics this hand-built row has to match because it cannot use the kit row.
  static const double _glyphSize = 19;
  static const double _gap = 12;

  /// List position; drives the `saved_address_<index>_edit` id (63 §2.16
  /// coins index-0 for the seeded fixture; pattern `saved_address_<n>_edit`).
  final int index;
  final SavedLocation location;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = JeebSurfaceTone.of(context);
    // Deliberately NOT `JeebListRow`: its title is a plain `String`, and this
    // row has to carry the default badge INLINE with the label while keeping
    // the edit/overflow controls fixed-width — the original no-overflow
    // constraint. Folding badge + two affordances into the kit row's single
    // `trailing` slot is exactly the crowding that constraint forbids. Every
    // metric and ink below is the kit row's, so the two cannot drift.
    return InkWell(
      onTap: isMutating ? null : () => _onEdit(context),
      child: Padding(
        // The trailing icon buttons carry their own 48dp box, so the row keeps
        // JeebListRow's 14 horizontal inset with the vertical one trimmed.
        padding: const EdgeInsetsDirectional.fromSTEB(
          14,
          Spacing.twoXSmall,
          Spacing.xSmall,
          Spacing.twoXSmall,
        ),
        child: Row(
          children: [
            // R10: filled glyphs only — the outline variants are off the board.
            // MIDNIGHT: title ink, NOT `colorScheme.primary` (now #D73B00).
            Icon(
              _iconFor(location.category),
              size: _glyphSize,
              color: tone.titleInk,
            ),
            const SizedBox(width: _gap),
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
                          style: context.jeebText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tone.titleInk,
                          ),
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
                    const SizedBox(height: Sizes.threeXSmall),
                    Text(
                      location.address!,
                      style: context.jeebText.caption
                          .copyWith(color: tone.mutedInk),
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
      // EXEMPT: OmdsBottomSheet lacks a typed-return action-list variant. No
      // `shape:` override — the Midnight `bottomSheetTheme` owns the rung.
      isScrollControlled: true,
      showDragHandle: true,
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
    // Was `OmdsConfirmationDialog`: a solid `error` slab with WHITE `onPrimary`
    // ink, 3.1:1 on #FF5252 — the pair §1 refuses. Q-041's danger CTA replaces it.
    final confirmed = await _showDeleteConfirmSheet(context, l10n) ?? false;
    if (!confirmed || !context.mounted) return;
    await context.read<SavedLocationsCubit>().delete(location.id);
  }

  Future<bool?> _showDeleteConfirmSheet(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DeleteConfirmSheet(
        title: l10n.savedLocationsDeleteConfirmTitle,
        body: l10n.savedLocationsDeleteConfirmBody(location.label),
        confirmLabel: l10n.savedLocationsDelete,
        cancelLabel: l10n.actionCancel,
      ),
    );
  }

  /// R10 — filled, single-colour glyphs, byte-matching the category glyphs the
  /// sibling `SavedAddressPillRow` (screen 09) already draws.
  IconData _iconFor(SavedLocationCategory cat) {
    switch (cat) {
      case SavedLocationCategory.home:
        return Icons.home;
      case SavedLocationCategory.work:
        return Icons.work;
      case SavedLocationCategory.other:
        return Icons.place;
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
    final label = _defaultBadgeLabel(locale);
    // "Default" is a settled fact about this row, not a do-it-now moment, so it
    // takes the kit's quiet filled chip — never the rationed orange badge
    // (§4.1: solid accent is reserved for `Recommended` / `Best value`).
    return Semantics(
      identifier: 'saved_address_default_badge',
      label: label,
      child: ExcludeSemantics(
        child: JeebSystemChip.filled(label: label, center: false),
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
          // R22's chevron ink and size class: `onSurfaceVariant` periwinkle at
          // the row's trailing rung, so the white label keeps the lead.
          icon: Icon(
            Icons.edit,
            size: _rowAffordanceGlyphSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
          tooltip: label,
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// R22 draws a 16px chevron in this slot; an interactive glyph takes the row's
/// own 19 rung so the two affordances read as one trailing cluster.
const double _rowAffordanceGlyphSize = 19;

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.index,
    required this.label,
    required this.onTap,
  });

  /// List position; drives the `saved_address_<index>_more` id, mirroring the
  /// sibling `saved_address_<index>_edit` (63 §2.16 index-0 pattern).
  final int index;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Same first-class-node treatment as the sibling [_EditButton]: this button
    // sits inside the tile's InkWell, so a button-flagged Semantics with no
    // action of its own would be merged into that parent button and lose its
    // identifier. A real `onTap` action keeps it separate and addressable;
    // `ExcludeSemantics` hides the inner IconButton's duplicate node.
    return Semantics(
      identifier: 'saved_address_${index}_more',
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          icon: Icon(
            Icons.more_vert,
            size: _rowAffordanceGlyphSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
          tooltip: label,
          onPressed: onTap,
        ),
      ),
    );
  }
}

enum _Action { edit, delete }

/// `radar` is the settings-subtree convention (profile_edit, live_settings,
/// notification_prefs) — the one variant that draws no microphone.
const JeebEmptyStateVariant _kStateArt = JeebEmptyStateVariant.radar;

/// The three real [SavedLocationCategory] values, so the ring is about PLACES
/// rather than radar's default jeeber initials.
const List<JeebEmptyMedallion> _kStateMedallions = <JeebEmptyMedallion>[
  JeebEmptyMedallion(icon: Icons.home),
  JeebEmptyMedallion(icon: Icons.work),
  JeebEmptyMedallion(icon: Icons.place),
];

/// Replaces radar's solid-orange BROADCAST core: nothing broadcasts here, and
/// that disc is unbudgeted orange. `WalletStateMark`'s glass-disc treatment.
class _SavedAddressStateMark extends StatelessWidget {
  const _SavedAddressStateMark();

  static const double _glyphSize = 28;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: semantic.glassFillEmphasis,
        border: Border.fromBorderSide(
          BorderSide(color: semantic.glassBorderStrong),
        ),
      ),
      child: Icon(
        Icons.bookmark,
        size: _glyphSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return JeebMidnightField(
      variant: JeebFieldVariant.sheet,
      animateDecor: false,
      child: SafeArea(
        top: false,
        child: Padding(
          // The board's 24px gutter, top and bottom at the sheet's own rhythm.
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.xSmall,
            Spacing.xLarge,
            Spacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsetsDirectional.only(bottom: Spacing.small),
                child: Text(
                  locationLabel,
                  // MIDNIGHT: sheet heading ink, NOT `primary` (now #D73B00).
                  style: context.jeebText.h2.copyWith(color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A grouped outlined card owns the inset 1px divider, so the
              // free-standing `Divider()` above the rows goes away (R7).
              JeebOutlinedCard.grouped(
                children: [
                  Semantics(
                    identifier: 'saved_address_sheet_edit_cta',
                    container: true,
                    button: true,
                    child: JeebListRow(
                      title: editLabel,
                      icon: Icons.edit,
                      // These rows act in place (they close the sheet and
                      // return a choice), so no chevron — kit ask K2.
                      showChevron: false,
                      onTap: () => Navigator.of(context).pop(_Action.edit),
                    ),
                  ),
                  Semantics(
                    identifier: 'saved_address_sheet_delete_cta',
                    container: true,
                    button: true,
                    child: JeebListRow(
                      title: deleteLabel,
                      icon: Icons.delete,
                      // R22 ruling: destructive ink is danger-SOFT
                      // `onErrorContainer` (#FF7B7B), never `error` (#FF5252).
                      iconColor: scheme.onErrorContainer,
                      titleStyle: TextStyle(color: scheme.onErrorContainer),
                      showChevron: false,
                      onTap: () => Navigator.of(context).pop(_Action.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The terminal destructive act, on Q-041's `JeebCtaVariant.danger` pill.
class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return JeebMidnightField(
      variant: JeebFieldVariant.sheet,
      animateDecor: false,
      child: Semantics(
        identifier: 'saved_address_delete_confirm_sheet',
        container: true,
        explicitChildNodes: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.xSmall,
              Spacing.xLarge,
              Spacing.large,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: context.jeebText.h2.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: Spacing.xSmall),
                Text(
                  body,
                  style: context.jeebText.body
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Spacing.large),
                JeebCtaFooter.split(
                  padding: EdgeInsets.zero,
                  expandLeading: true,
                  leading: Semantics(
                    identifier: 'saved_address_delete_cancel_cta',
                    button: true,
                    child: JeebCtaButton.text(
                      label: cancelLabel,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  trailing: Semantics(
                    identifier: 'saved_address_delete_confirm_cta',
                    button: true,
                    child: JeebCtaButton.danger(
                      label: confirmLabel,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      key: const Key('saved-locations-loading'),
      child: SingleChildScrollView(
        child: JeebEmptyState(
          variant: _kStateArt,
          medallions: _kStateMedallions,
          center: const _SavedAddressStateMark(),
          status: JeebEmptyStateStatus.loading,
          headline: l10n.savedAddressesLoadingHeadline,
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
    // §2.7 zero-state (was `OmdsEmptyState`). The Add CTA stays docked in the
    // footer, so this surface is guidance-only — nothing is saved yet.
    return Center(
      key: const Key('saved-locations-empty'),
      child: SingleChildScrollView(
        child: JeebEmptyState(
          variant: _kStateArt,
          medallions: _kStateMedallions,
          center: const _SavedAddressStateMark(),
          headline: l10n.savedAddressesEmptyTitle,
          body: l10n.savedAddressesEmptyBody,
        ),
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
    // §2.7 error state (was `OmdsErrorState`). [onRetry] re-runs the real
    // saved-locations load — no fabricated data.
    return Center(
      key: const Key('saved-locations-error'),
      child: SingleChildScrollView(
        child: JeebEmptyState(
          variant: _kStateArt,
          medallions: _kStateMedallions,
          center: const _SavedAddressStateMark(),
          status: JeebEmptyStateStatus.error,
          headline: l10n.savedAddressesErrorHeadline,
          body: l10n.savedAddressesErrorBody,
          action: Semantics(
            identifier: 'saved_address_error_retry_cta',
            button: true,
            child: JeebCtaButton.outline(
              label: l10n.savedLocationsRetry,
              expand: false,
              onTap: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}
