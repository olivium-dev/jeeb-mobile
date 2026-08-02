import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/tier_selection_cubit.dart';
import '../cubit/tier_selection_state.dart';
import '../data/tier_repository.dart';
import '../domain/tier.dart';
import 'tier_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/tier_selection_screen_fixtures.dart';

class TierSelectionScreen extends StatelessWidget {
  const TierSelectionScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onConfirmed,
  }) : assert(
          cubit == null || repository == null,
          'Provide either a cubit or a repository, not both.',
        );

  final TierSelectionCubit? cubit;

  final TierRepository? repository;

  final ValueChanged<Tier>? onConfirmed;

  static const Key rootKey = Key('tier-selection-root');
  static const Key listKey = Key('tier-selection-list');
  static const Key confirmButtonKey = Key('tier-selection-confirm');
  static const Key retryButtonKey = Key('tier-selection-retry');
  static Key cardKey(TierId id) => ValueKey('tier-selection-card-${id.name}');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(onConfirmed: onConfirmed),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(onConfirmed: onConfirmed),
    );
  }

  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) {
      return sl<TierRepository>();
    }
    return const FakeTierRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onConfirmed});

  final ValueChanged<Tier>? onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tier_selection_root',
      container: true,
      child: Scaffold(
        key: TierSelectionScreen.rootKey,
        appBar: OMDSAppBar(
          title: l10n.tierSelectionTitle,
          centerTitle: false,
        ),
        body: SafeArea(
          child: BlocConsumer<TierSelectionCubit, TierSelectionState>(
            listenWhen: (prev, curr) =>
                prev.confirmedTierId != curr.confirmedTierId &&
                curr.confirmedTierId != null,
            listener: (context, state) {
              final tier = state.selectedTier;
              if (tier != null) {
                onConfirmed?.call(tier);
              }
            },
            builder: (context, state) => _Body(state: state),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case TierSelectionStatus.initial:
      case TierSelectionStatus.loading:
        return const Center(child: OmdsLoadingState());
      case TierSelectionStatus.error:
        return Center(
          child: OmdsErrorState(
            message: l10n.requestSummaryErrorNetwork,
            onRetry: () => context.read<TierSelectionCubit>().load(),
            retryLabel: l10n.requestSummaryRetry,
          ),
        );
      case TierSelectionStatus.loaded:
        return _LoadedView(state: state);
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.usingCachedFallback)
          _CachedBanner(message: l10n.tierSelectionCachedBanner),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.large,
            Spacing.medium,
            Spacing.large,
            Spacing.small,
          ),
          child: Text(
            l10n.tierSelectionSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: TierSelectionScreen.listKey,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.large),
            itemCount: state.tiers.length,
            separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
            itemBuilder: (context, index) {
              final tier = state.tiers[index];
              return _TierListEntry(
                tier: tier,
                selected: state.selectedTierId == tier.id,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Semantics(
            identifier: 'tier_selection_confirm_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              key: TierSelectionScreen.confirmButtonKey,
              text: l10n.tierSelectionConfirm,
              isEnabled: state.canConfirm,
              onTap: () => context.read<TierSelectionCubit>().confirm(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CachedBanner extends StatelessWidget {
  const _CachedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('tier-selection-cached-banner'),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.xSmall,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: context.jeebRoles.infoContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.jeebRoles.onInfoContainer,
            size: Sizes.large,
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall
                  ?.copyWith(color: context.jeebRoles.onInfoContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierListEntry extends StatelessWidget {
  const _TierListEntry({required this.tier, required this.selected});

  final Tier tier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = _tierName(l10n, tier.id);
    final description = _tierFooter(l10n, tier.id);
    final eta = _slaCopy(l10n, tier.slaMinutes);
    final price = l10n.tierSelectionPriceRange(
      _formatPrice(tier.priceLow, tier.currency),
      _formatPrice(tier.priceHigh, tier.currency),
    );
    final vehicleLabel = _vehicleLabel(l10n, tier.vehicleClass);
    final vehicleIcon = _vehicleIcon(tier.vehicleClass);
    return Padding(
      key: TierSelectionScreen.cardKey(tier.id),
      padding: EdgeInsets.zero,
      child: TierCard(
        identifier: 'tier_selection_card_${tier.id.name}',
        name: name,
        description: description,
        estimatedTime: eta,
        priceRange: price,
        vehicleLabel: vehicleLabel,
        vehicleIcon: vehicleIcon,
        selected: selected,
        onTap: () => context.read<TierSelectionCubit>().selectTier(tier.id),
        recommendedBadgeText:
            tier.recommended ? l10n.tierSelectionRecommendedBadge : null,
        semanticLabel: l10n.tierSelectionCardSemanticLabel(
          name: name,
          sla: eta,
          radius: vehicleLabel,
          price: price,
        ),
        selectedHint: l10n.tierSelectionCardSelectedHint,
      ),
    );
  }

  String _tierName(AppLocalizations l10n, TierId id) {
    switch (id) {
      case TierId.flash:
        return l10n.tierSelectionTierFlash;
      case TierId.express:
        return l10n.tierSelectionTierExpress;
      case TierId.standard:
        return l10n.tierSelectionTierStandard;
      case TierId.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case TierId.eco:
        return l10n.tierSelectionTierEco;
    }
  }

  String _tierFooter(AppLocalizations l10n, TierId id) {
    switch (id) {
      case TierId.flash:
        return l10n.tierSelectionFooterFlash;
      case TierId.express:
        return l10n.tierSelectionFooterExpress;
      case TierId.standard:
        return l10n.tierSelectionFooterStandard;
      case TierId.onTheWay:
        return l10n.tierSelectionFooterOnTheWay;
      case TierId.eco:
        return l10n.tierSelectionFooterEco;
    }
  }

  String _slaCopy(AppLocalizations l10n, int? minutes) {
    if (minutes == null) return l10n.tierSelectionSlaNone;
    if (minutes >= 60 && minutes % 60 == 0) {
      return l10n.tierSelectionSlaHours(minutes ~/ 60);
    }
    return l10n.tierSelectionSlaMinutes(minutes);
  }

  String _vehicleLabel(AppLocalizations l10n, TierVehicleClass cls) {
    switch (cls) {
      case TierVehicleClass.bikeOrScooter:
        return l10n.tierSelectionVehicleBikeScooter;
      case TierVehicleClass.scooterOrCar:
        return l10n.tierSelectionVehicleScooterCar;
      case TierVehicleClass.carOrVan:
        return l10n.tierSelectionVehicleCarVan;
      case TierVehicleClass.any:
        return l10n.tierSelectionVehicleAny;
    }
  }

  IconData _vehicleIcon(TierVehicleClass cls) {
    switch (cls) {
      case TierVehicleClass.bikeOrScooter:
        return Icons.two_wheeler_rounded;
      case TierVehicleClass.scooterOrCar:
        return Icons.directions_car_rounded;
      case TierVehicleClass.carOrVan:
        return Icons.local_shipping_rounded;
      case TierVehicleClass.any:
        return Icons.commute_rounded;
    }
  }

  String _formatPrice(int amount, String currency) =>
      MoneyFormat.format(amount.toDouble(), currency: currency);
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against.
const Size _tierSelectionScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The tier list is a `ListView`, so
const Size _tierSelectionScreenCompactBox = Size(320, 568);

/// Every tier handed back through `onConfirmed`, in order.
/// Public because the render test is the only thing that can read it, and what
final List<String> tierSelectionScreenConfirmations = <String>[];

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they exist:
final class TierSelectionScreenCaptions {
  TierSelectionScreenCaptions._();

  /// `GET /tiers` has not answered: the first frame of every mount.
  static const String loading = 'preview · tier read in flight';

  /// The three tiers the delivery service serves, nothing chosen.
  static const String servedCatalogue = 'preview · served 3 tiers, no selection';

  /// The same list with Express already chosen.
  static const String selected = 'preview · Express selected';

  /// `200 OK`, zero tiers: loaded, and unusable.
  static const String emptyCatalogue = 'preview · catalogue answered EMPTY';

  /// The retryable failure.
  static const String errorNetwork = 'preview · tier read failed · network';

  /// The un-retryable one, wearing the same sentence.
  static const String errorServer = 'preview · tier read failed · server 5xx';

  /// The banner no production path can raise.
  static const String cachedFallback =
      'preview · cached banner · SEEDED, unreachable in app';

  /// All five tiers on the narrowest supported phone.
  static const String fullCatalogueCompact =
      'preview · five tiers · 320 x 568 ceiling';
}

/// Pins the device frame, captions the state, and records the one edge the
/// screen owns (`onConfirmed`).
/// Stateful, and the collaborators are built once: a repository rebuilt every
class _TierSelectionScreenHost extends StatefulWidget {
  const _TierSelectionScreenHost({
    required this.caption,
    this.createRepository,
    this.createCubit,
    this.box = _tierSelectionScreenPhoneBox,
  });

  /// Called once per mount, so each canvas card gets its own fake.
  final TierRepository Function()? createRepository;

  /// The other seam — for the two states `repository:` cannot reach.
  final TierSelectionCubit Function()? createCubit;

  /// The line painted above the device frame.
  final String caption;

  /// The device this card is judged on.
  final Size box;

  @override
  State<_TierSelectionScreenHost> createState() =>
      _TierSelectionScreenHostState();
}

class _TierSelectionScreenHostState extends State<_TierSelectionScreenHost> {
  late final TierRepository? _repository = widget.createRepository?.call();

  /// Mounted through `BlocProvider.value`, which does not close it — so the
  /// host does.
  late final TierSelectionCubit? _cubit = widget.createCubit?.call();

  @override
  void initState() {
    super.initState();
    tierSelectionScreenConfirmations.clear();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: widget.box.width,
        height: widget.box.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.small,
                vertical: Spacing.xSmall,
              ),
              child: Text(
                widget.caption,
                // Dev chrome: LTR and unscaled, so the AR card still reads it as
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: TierSelectionScreen(
                cubit: _cubit,
                repository: _repository,
                onConfirmed: (Tier tier) =>
                    tierSelectionScreenConfirmations.add(tier.id.name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tierSelectionScreenHosted(
  TierRepository Function() createRepository,
  String caption, {
  Size box = _tierSelectionScreenPhoneBox,
}) =>
    _TierSelectionScreenHost(
      createRepository: createRepository,
      caption: caption,
      box: box,
    );

/// The first frame of EVERY mount: `load()` fired from `BlocProvider.create` and
/// `GET /tiers` has not answered.
@JeebPreview(
  group: 'tier_selection',
  name: 'Loading · tier read in flight',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenLoading() => _tierSelectionScreenHosted(
      TierSelectionScreenPreviewFixtures.stalled,
      TierSelectionScreenCaptions.loading,
    );

/// The reference reading, and the state the app opens on: Flash, Express and
/// Standard, none of them chosen, Confirm disabled.
@JeebPreview(
  group: 'tier_selection',
  name: 'Loaded · served catalogue, no selection',
  size: _tierSelectionScreenPhoneBox,
  matrix: true,
)
Widget tierSelectionScreenServedCatalogue() => _tierSelectionScreenHosted(
      TierSelectionScreenPreviewFixtures.servedCatalogue,
      TierSelectionScreenCaptions.servedCatalogue,
    );

/// The same list with Express chosen — one of the two states `repository:`
/// cannot produce.
@JeebPreview(
  group: 'tier_selection',
  name: 'Selected · Express',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenSelected() => _TierSelectionScreenHost(
      createCubit: () => TierSelectionScreenPreviewFixtures.selectedTierCubit(
        TierSelectionScreenPreviewFixtures.selectedTier,
      ),
      caption: TierSelectionScreenCaptions.selected,
    );

/// `200 OK` with no tiers in it: loaded, and unusable.
/// The subtitle renders over an empty list and the Confirm button is present and
@JeebPreview(
  group: 'tier_selection',
  name: 'Empty · catalogue answered 200 with nothing',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenEmptyCatalogue() => _tierSelectionScreenHosted(
      TierSelectionScreenPreviewFixtures.emptyCatalogue,
      TierSelectionScreenCaptions.emptyCatalogue,
    );

/// The read failed on the wire — the retryable failure, and the honest one.
/// `Try again` re-runs `load()`, which is exactly the right advice here. This is
@JeebPreview(
  group: 'tier_selection',
  name: 'Error · network',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenErrorNetwork() => _tierSelectionScreenHosted(
      () => TierSelectionScreenPreviewFixtures.failing(TierLoadFailure.network),
      TierSelectionScreenCaptions.errorNetwork,
    );

/// The read reached Jeeb and Jeeb answered badly — a 5xx, or a body
/// `_parseResponse` cannot recognise.
@JeebPreview(
  group: 'tier_selection',
  name: 'Error · server 5xx (same copy)',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenErrorServer() => _tierSelectionScreenHosted(
      () => TierSelectionScreenPreviewFixtures.failing(TierLoadFailure.server),
      TierSelectionScreenCaptions.errorServer,
    );

/// The cached-options banner — dead code, drawn.
/// `_CachedBanner` renders when `state.usingCachedFallback` is true, and NOTHING
@JeebPreview(
  group: 'tier_selection',
  name: 'Cached banner · SEEDED, no producer in the app',
  size: _tierSelectionScreenPhoneBox,
)
Widget tierSelectionScreenCachedFallback() => const _TierSelectionScreenHost(
      createCubit: TierSelectionScreenPreviewFixtures.cachedFallbackCubit,
      caption: TierSelectionScreenCaptions.cachedFallback,
    );

/// The layout ceiling: all five tiers the client can render, on the narrowest
/// phone it supports.
@JeebPreview(
  group: 'tier_selection',
  name: 'Full catalogue · compact 320x568',
  size: _tierSelectionScreenCompactBox,
  matrix: true,
)
Widget tierSelectionScreenFullCatalogueCompact() => _tierSelectionScreenHosted(
      TierSelectionScreenPreviewFixtures.fullCatalogue,
      TierSelectionScreenCaptions.fullCatalogueCompact,
      box: _tierSelectionScreenCompactBox,
    );
