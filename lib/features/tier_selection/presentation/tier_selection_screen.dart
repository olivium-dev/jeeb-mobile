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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/tier_selection/tier_selection_screen_preview_test.dart
// ===========================================================================
//
// [TierSelectionScreen] is the "Choose speed" tier picker: an app bar, a
// one-line subtitle, a scrolling list of [TierCard]s, and a Confirm CTA pinned
// under the list. It hands the chosen [Tier] back through `onConfirmed` and
// navigates nowhere itself, so — unlike its sibling `RequestTypeScreen` — these
// previews need no router above them.
//
// The fakes are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/tier_selection_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry (`devtool/catalog/entries/
// batch_11_entries.dart`), so the designer's browser and this canvas cannot
// drift into showing two different "designed states". None of them can reach the
// network: they answer from a `const` list, throw, or never complete. That is
// load-bearing — `_resolveRepository()` returns `sl<TierRepository>()` whenever
// one is registered, which inside the app is `DioTierRepository` and a real
// `GET /tiers`, and the `CatalogNetworkGuard` in [jeebPreviewHost] passes GETs.
//
// Three things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest; the inner one (OMDSAppBar + list + Confirm) is the real surface.
//    The canvas box is therefore a real device ([_tierSelectionScreenPhoneBox],
//    [_tierSelectionScreenCompactBox]) rather than the harness's 390x200
//    default, and the frame is pinned in the TREE as well as in `size:` so the
//    render tests measure the same phone instead of the 800 pt test surface.
//  * **`repository:` reaches every state but two.** The screen builds its own
//    [TierSelectionCubit] inside `BlocProvider.create` and calls `load()` on it,
//    so answer / stall / throw IS the state. SELECTION is not reachable that way
//    — `selectTier` returns early unless `status == loaded`, so nothing handed
//    to the constructor can pre-select — and neither is the cached banner, which
//    has no producer at all (see below). Both use the other seam, `cubit:`,
//    which mounts through `BlocProvider.value` and does NOT call `load()`.
//  * **Each card carries a caption** ([TierSelectionScreenCaptions]), because
//    several designed states here are indistinguishable by their production
//    copy: `Loaded` and `Selected` render the same three tiers, the two failure
//    modes render the same sentence, and the empty catalogue renders the same
//    subtitle over nothing. Same device as `RequestTypeScreenCaptions`.
//
// What these previews surfaced in the screen — none of it changed here:
//
//  * **`TierSelectionScreen.retryButtonKey` is attached to nothing.** The class
//    publishes four keys; `rootKey`, `listKey` and `confirmButtonKey` are all
//    wired, and `Key('tier-selection-retry')` is wired to nothing at all —
//    `_Body` hands `onRetry` to [OmdsErrorState], which builds its own unkeyed
//    `FilledButton.icon`. Anything keying off it finds nothing, which is exactly
//    what `test/tier_selection_screen_test.dart:158` works around in a comment
//    ("match the FilledButton supertype"). [tierSelectionScreenErrorNetwork] is
//    where you can see the button that key was meant to name.
//  * **The cached-options banner cannot be reached.** `_CachedBanner` renders
//    when `state.usingCachedFallback` is true; [TierSelectionCubit] sets that
//    flag to `false` on all three of its emits and to `true` on none, so neither
//    the widget nor its ARB string (`tierSelectionCachedBanner`) can appear in
//    the app. It is the residue of JEBV4-300, which removed the cached-catalog
//    fallback. [tierSelectionScreenCachedFallback] seeds the state directly to
//    show what the dead code draws; every other preview here goes through the
//    cubit's public API and none of them can produce it.
//  * **Both load failures render the same sentence, and it blames the
//    network.** `_Body` ignores `state.failure` and always passes
//    `l10n.requestSummaryErrorNetwork` — "Couldn't reach Jeeb. Check your
//    connection and try again." — so a `TierLoadFailure.server` (a 5xx, or a
//    body `DioTierRepository._parseResponse` cannot recognise) tells the
//    customer to check a working connection and retry an operation that will
//    fail the same way. Compare [tierSelectionScreenErrorNetwork] and
//    [tierSelectionScreenErrorServer]: the cards are identical. The copy is also
//    borrowed from the request_summary feature, so it names a submit problem on
//    a screen that has not submitted anything.
//  * **An empty catalogue is a silent dead end.** A `200 OK` with no tiers is
//    `TierSelectionStatus.loaded`, so the screen renders "Price varies by
//    Jeeber" over an empty list with a Confirm button that can never enable — no
//    message, no retry, no way forward ([tierSelectionScreenEmptyCatalogue]).
//    Not hypothetical: `DioTierRepository._tierIdFromLabel` drops every tier
//    whose `name` this client cannot map, so a server-side rename empties the
//    screen through the SUCCESS path.
//  * **Confirm is announced as a plain button at every status.** The
//    `Semantics(identifier: 'tier_selection_confirm_cta', button: true)` wrapper
//    never carries `enabled:`, and [OmdsPrimaryButton] is a bare
//    `GestureDetector` underneath, so the disabled CTA exposes no
//    enabled/disabled state to a screen reader — it reads as an ordinary button
//    that silently does nothing. Visible in [tierSelectionScreenServedCatalogue]
//    and [tierSelectionScreenEmptyCatalogue]; pinned in the render test.
//  * **Confirming the same tier twice fires `onConfirmed` once.** `confirm()`
//    re-emits a state that is `==` to the current one, `Cubit.emit` drops it,
//    and the `BlocConsumer` listener never runs. A caller that stays on the
//    screen — or returns to it without changing tier — gets an enabled CTA whose
//    second press does nothing. [tierSelectionScreenSelected] records every
//    callback into [tierSelectionScreenConfirmations]; the render test presses
//    Confirm twice and finds one entry.

/// The phone this screen is designed against.
const Size _tierSelectionScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The tier list is a `ListView`, so
/// this is where scrolling starts rather than where layout breaks.
const Size _tierSelectionScreenCompactBox = Size(320, 568);

/// Every tier handed back through `onConfirmed`, in order.
///
/// Public because the render test is the only thing that can read it, and what
/// it reads is a defect: pressing Confirm twice on the same tier appends ONE
/// entry, because the second `confirm()` re-emits an equal state that
/// `Cubit.emit` drops before the listener runs. Cleared as each host mounts, so
/// one card cannot observe another's taps.
final List<String> tierSelectionScreenConfirmations = <String>[];

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they exist:
/// most of these states put NO distinguishing production copy on screen. Dev
/// chrome, never shipped copy, so they are deliberately un-localized and
/// rendered LTR at a fixed text scale.
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
///
/// Stateful, and the collaborators are built once: a repository rebuilt every
/// frame would restart the load, and a cubit rebuilt every frame would lose the
/// selection it drove itself into.
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
                // one latin line and the 200% card does not spend a third of the
                // device on a label.
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
///
/// A centred spinner and nothing else — note what is missing around it. The
/// subtitle, the list and the Confirm CTA all live inside `_LoadedView`, so the
/// page is an app bar over a hole and then grows its whole body at once. There
/// is no skeleton and no hint of how many options are coming.
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
///
/// Matrixed because this is the whole screen in three readings at once. In AR
/// the subtitle, the cards, the Recommended pill and both meta rows mirror; the
/// prices stay LTR inside their isolates, which is what `MoneyFormat`'s
/// `U+2066`/`U+2069` wrapping is for. Nothing is selected on purpose — a
/// recommendation is display metadata, not a customer choice, which
/// `test/tier_selection_screen_test.dart` pins as a contract.
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
///
/// `selectTier` is a no-op until `load()` has landed, so this one comes in
/// through `cubit:` with the selection chained onto the load. Read it beside the
/// state above: `selected` swaps the fill, the border width, the title colour
/// and the description colour at once and adds a check glyph, and the Confirm
/// CTA goes live. Express rather than Flash on purpose — Flash carries the
/// Recommended pill, and a selected Flash card cannot be told apart from a
/// recommendation at a glance.
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
///
/// The subtitle renders over an empty list and the Confirm button is present and
/// permanently disabled. No message, no retry, no explanation — this is a
/// SUCCESS as far as every layer below the widget is concerned, so nothing on
/// the error path fires. Reachable without any gateway outage:
/// `DioTierRepository._tierIdFromLabel` silently drops every tier whose `name`
/// this client cannot map, so a server-side rename empties the screen one tier
/// at a time.
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
///
/// `Try again` re-runs `load()`, which is exactly the right advice here. This is
/// also the card that shows what `TierSelectionScreen.retryButtonKey` was meant
/// to name: the button [OmdsErrorState] builds carries no key at all, so the
/// published constant matches nothing on the screen.
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
///
/// Identical to [tierSelectionScreenErrorNetwork], because `_Body` ignores
/// `state.failure` and always renders `requestSummaryErrorNetwork`. The customer
/// is told to check a connection that is working and to retry an operation that
/// will fail the same way.
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
///
/// `_CachedBanner` renders when `state.usingCachedFallback` is true, and NOTHING
/// sets that flag: [TierSelectionCubit] writes `false` on all three of its emits
/// and `true` on none, so neither the banner nor its ARB string
/// (`tierSelectionCachedBanner`) can appear in the app. JEBV4-300 removed the
/// cached-catalog fallback that used to raise it — see the two
/// `tier-selection-cached-banner` assertions in
/// `test/tier_selection_screen_test.dart`, which pin its absence — and left the
/// widget, the flag and the copy behind.
///
/// This is the ONE preview here that seeds a state instead of driving the cubit,
/// precisely because no sequence of public calls can reach it. Judge it as "what
/// the dead branch would draw", not as a state the app can be in.
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
///
/// [FakeTierRepository] is the SHIPPING fallback, not a hypothetical — and the
/// two extra tiers own the edges of the copy: On-the-way is the only hyphenated
/// title and the only card with no SLA at all (`No SLA` rather than a time), and
/// Eco's 2880 minutes are the only SLA the screen renders in hours (`≤ 48 hr`,
/// via the `minutes % 60 == 0` branch).
///
/// Matrixed because this is where the three readings diverge. Nothing here can
/// overflow — the body is a `ListView` and `Scaffold` clamps the rest — so what
/// the three cards show is how much of the screen is REACHABLE without
/// scrolling, and how far the Confirm CTA is from the last option a customer can
/// see. The CTA holds `OmdsPrimaryButton`'s fixed 48 pt at every text scale,
/// which is the button's default rather than anything this screen decides.
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
