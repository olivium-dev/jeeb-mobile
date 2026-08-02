import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../tier_selection/cubit/tier_selection_cubit.dart';
import '../../tier_selection/cubit/tier_selection_state.dart';
import '../../tier_selection/data/tier_repository.dart';
import '../../tier_selection/domain/tier.dart';
import '../../location/presentation/widgets/delivery_create_layout.dart';
import '../../request_summary/application/compose_request_controller.dart';
import '../../request_summary/domain/request_draft.dart';
import 'request_type_radio_id.dart';
import 'request_tier_card.dart';
import 'request_location_row.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_type_screen_fixtures.dart';

class RequestTypeScreen extends StatelessWidget {
  const RequestTypeScreen({
    super.key,
    this.cubit,
    this.repository,
    this.onChangeLocation,
    this.onTierSelected,
    this.onContinue,
  });

  final TierSelectionCubit? cubit;
  final TierRepository? repository;

  final VoidCallback? onChangeLocation;

  final ValueChanged<Tier>? onTierSelected;

  final ValueChanged<RequestDraft>? onContinue;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<TierSelectionCubit>.value(
        value: provided,
        child: _Scaffold(onChangeLocation: onChangeLocation),
      );
    }
    return BlocProvider<TierSelectionCubit>(
      create: (_) =>
          TierSelectionCubit(repository: repository ?? _resolveRepository())
            ..load(),
      child: _Scaffold(onChangeLocation: onChangeLocation),
    );
  }

  TierRepository _resolveRepository() {
    if (sl.isRegistered<TierRepository>()) return sl<TierRepository>();
    return const FakeTierRepository();
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({this.onChangeLocation});

  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.requestTypeTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: BlocBuilder<TierSelectionCubit, TierSelectionState>(
          builder: (context, state) => _Body(
            state: state,
            onChangeLocation: onChangeLocation,
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<TierSelectionCubit, TierSelectionState>(
        builder: (context, state) => _ContinueFooter(state: state),
      ),
    );
  }
}

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    if (state.status != TierSelectionStatus.loaded) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final hasSelection = state.selectedTierId != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: DeliveryCreateLayout.pagePadding,
        child: Semantics(
          identifier: 'request_type_continue_cta',
          button: true,
          child: OmdsPrimaryButton(
            key: const Key('request-type-continue'),
            text: l10n.requestTypeContinue,
            isEnabled: hasSelection,
            onTap: () => _onContinue(context, hasSelection),
          ),
        ),
      ),
    );
  }

  void _onContinue(BuildContext context, bool hasSelection) {
    if (!hasSelection) return;
    final tier = state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
    context.pushNamed('client-location');
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;

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
        return _LoadedView(
          state: state,
          onChangeLocation: onChangeLocation,
        );
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    this.onChangeLocation,
  });

  final TierSelectionState state;
  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: DeliveryCreateLayout.pagePadding,
      children: [
        _SectionHeading(text: l10n.requestTypeChooseHeading),
        const SizedBox(height: Spacing.medium),
        _TierList(state: state),
        const SizedBox(height: Spacing.twoXLarge),
        _SectionHeading(text: l10n.requestTypeLocationHeading),
        const SizedBox(height: Spacing.medium),
        _LocationSection(onChangeLocation: onChangeLocation),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({this.onChangeLocation});

  final VoidCallback? onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RequestLocationRow(
      currentLabel: l10n.requestTypeCurrentLocation,
      changeLabel: l10n.requestTypeChangeLocation,
      onChange: () => _onChange(context),
    );
  }

  void _onChange(BuildContext context) {
    final tier = context.read<TierSelectionCubit>().state.selectedTier;
    if (tier != null && sl.isRegistered<ComposeRequestController>()) {
      sl<ComposeRequestController>().setTier(tier);
    }
    final handler = onChangeLocation;
    if (handler != null) {
      handler();
      return;
    }
    context.pushNamed('client-location');
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TierList extends StatelessWidget {
  const _TierList({required this.state});

  final TierSelectionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tier in state.tiers) ...[
          _TierEntry(
            tier: tier,
            selected: state.selectedTierId == tier.id,
          ),
          if (tier != state.tiers.last)
            const SizedBox(height: Spacing.small),
        ],
      ],
    );
  }
}

class _TierEntry extends StatelessWidget {
  const _TierEntry({
    required this.tier,
    required this.selected,
  });

  final Tier tier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = _RequestTierCopy.of(l10n, tier.id);
    return RequestTierCard(
      icon: _tierIcon(tier.id),
      title: copy.title,
      speed: copy.speed,
      value: copy.value,
      selected: selected,
      semanticIdentifier: requestTypeRadioId(tier.id),
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: copy.title,
        speed: copy.speed,
        value: copy.value,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
      onTap: () => _onTap(context),
    );
  }

  void _onTap(BuildContext context) {
    context.read<TierSelectionCubit>().selectTier(tier.id);
  }

  static IconData _tierIcon(TierId id) => switch (id) {
        TierId.flash => Icons.bolt_outlined,
        TierId.express => Icons.rocket_launch_outlined,
        TierId.standard => Icons.balance_outlined,
        TierId.onTheWay => Icons.handshake_outlined,
        TierId.eco => Icons.eco_outlined,
      };
}

class _RequestTierCopy {
  const _RequestTierCopy(this.title, this.speed, this.value);

  final String title;
  final String speed;
  final String value;

  static _RequestTierCopy of(AppLocalizations l10n, TierId id) => switch (id) {
        TierId.flash => _RequestTierCopy(
            l10n.tierFlashTitle, l10n.tierFlashSpeed, l10n.tierFlashValue),
        TierId.express => _RequestTierCopy(
            l10n.tierExpressTitle, l10n.tierExpressSpeed, l10n.tierExpressValue),
        TierId.standard => _RequestTierCopy(l10n.tierStandardTitle,
            l10n.tierStandardSpeed, l10n.tierStandardValue),
        TierId.onTheWay => _RequestTierCopy(l10n.tierOnTheWayTitle,
            l10n.tierOnTheWaySpeed, l10n.tierOnTheWayValue),
        TierId.eco => _RequestTierCopy(
            l10n.tierEcoTitle, l10n.tierEcoSpeed, l10n.tierEcoValue),
      };
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/request_type/request_type_screen_preview_test.dart
// ===========================================================================
//
// [RequestTypeScreen] is the first screen of the customer create flow
// (`/request-type`, Figma 56535:2392): a heading, the tier list, a location row,
// and a Continue CTA in the `bottomNavigationBar`.
//
// The fakes are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/request_type_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry (`devtool/catalog/entries/
// batch_10_entries.dart`), so the designer's browser and this canvas cannot
// drift into showing two different "designed states". None of them can reach the
// network: they answer from a `const` list, throw, or never complete. That is
// load-bearing — `_resolveRepository()` returns `sl<TierRepository>()` whenever
// one is registered, which inside the app is `DioTierRepository` and a real
// `GET /tiers`, and the `CatalogNetworkGuard` in [jeebPreviewHost] passes GETs.
//
// Four things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest; the inner one (OMDSAppBar + ListView + Continue footer) is the
//    real surface. The canvas box is therefore a real device
//    ([_requestTypeScreenPhoneBox], [_requestTypeScreenCompactBox]) rather than
//    the harness's 390x200 default, and the frame is pinned in the TREE as well
//    as in `size:` so the render tests measure the same phone instead of the
//    800 pt test surface.
//  * **`repository:` reaches every state except one.** The screen builds its own
//    [TierSelectionCubit] inside `BlocProvider.create` and calls `load()` on it,
//    so answer / stall / throw IS the state. The exception is SELECTION:
//    `selectTier` returns early unless `status == loaded`, so nothing handed to
//    the constructor can pre-select a tier. That state uses the other seam,
//    `cubit:` — which mounts through `BlocProvider.value` and does NOT call
//    `load()`, so a cubit fixture has to drive itself.
//  * **Every preview sits under a stand-in [GoRouter].** Not decoration: BOTH
//    actions on this screen self-navigate with
//    `context.pushNamed('client-location')` — the Continue CTA
//    (`_ContinueFooter._onContinue`) and, when no `onChangeLocation` is passed,
//    the Change Location row (`_LocationSection._onChange`). On a bare host each
//    is an exception rather than a state. `onChangeLocation` is deliberately
//    left null so the canvas exercises the screen's own edge; production passes
//    `() => context.push('/client-location')`, which lands in the same place.
//  * **Each card carries a caption** ([RequestTypeScreenCaptions]), because
//    several designed states here are indistinguishable by their production
//    copy: `Loaded — no selection` and `Selected — Standard` render the same
//    three strings, the two failure modes render the same sentence, and the
//    repriced catalogue is pixel-identical to the served one on purpose. Same
//    device as `GoodsCostScreenCaptions`.
//
// What these previews surfaced in the screen — none of it changed here:
//
//  * **`onTierSelected` and `onContinue` are dead parameters.** Both are
//    declared on [RequestTypeScreen] and neither is read by `build`, which
//    forwards only `cubit`, `repository` and `onChangeLocation` to `_Scaffold`.
//    `app_router.dart:1105` still passes both, wired to
//    `context.push('/request-summary', extra: RequestDraft(...))` — a route the
//    screen has not used since JM-024 re-pointed the flow at `client-location`.
//    A caller reading the constructor would reasonably believe they own the
//    Continue edge; they do not, and nothing tells them. The host below passes
//    both and records every call into [requestTypeScreenSeamCalls]; the render
//    test taps a tier, presses Continue, watches the navigation happen and
//    asserts that list is still empty.
//  * **Everything the gateway says about a tier except its id is discarded.**
//    `_RequestTierCopy.of(l10n, tier.id)` keys all three lines on the id alone,
//    so `priceLow`, `priceHigh`, `currency`, `slaMinutes`, `vehicleClass`,
//    `recommended` and `serverId` are parsed by `DioTierRepository`, carried
//    through the cubit, and dropped at the card. The "value" line a customer
//    reads as a price cue ("Highest price • Priority pickup") is static ARB
//    copy. [requestTypeScreenRepricedCatalogue] is that fact made visible: it
//    prices Flash at 99–125 USD with a five-minute SLA and renders the same card
//    as the 120–160k LBP one beside it.
//  * **Both load failures render the same sentence, and it blames the
//    network.** `_Body` ignores `state.failure` and always passes
//    `l10n.requestSummaryErrorNetwork` — "Couldn't reach Jeeb. Check your
//    connection and try again." — so a `TierLoadFailure.server` (a 5xx, or a
//    response body this client cannot parse: `_parseResponse` throws
//    `TierLoadFailure.server` for a shape it does not recognise) tells the
//    customer to check their connection and press Try again, which cannot help.
//    Compare [requestTypeScreenErrorNetwork] and
//    [requestTypeScreenErrorServer]: the cards are identical.
//  * **An empty catalogue is a silent dead end.** A `200 OK` with no tiers is
//    `TierSelectionStatus.loaded`, so the screen renders "Choose your request"
//    over nothing, the Location row underneath it, and a Continue button that
//    can never enable — no message, no retry, and no way forward.
//    [requestTypeScreenEmptyCatalogue]. This is not hypothetical: every tier
//    whose `name` this client cannot map is dropped by
//    `DioTierRepository._tierIdFromLabel`, so renaming tiers server-side empties
//    the screen through the success path.
//  * **The failure state has no CTA at all.** `_ContinueFooter` returns
//    `SizedBox.shrink()` for anything but `loaded`, so the whole
//    `bottomNavigationBar` disappears on error and on first load — the retry
//    inside the body is the only control on the screen.

/// The phone this screen is designed against.
const Size _requestTypeScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The tier list is a `ListView`, so
/// this is where scrolling starts rather than where layout breaks.
const Size _requestTypeScreenCompactBox = Size(320, 568);

/// The route the screen pushes, and the one it is pushed from. Same names the
/// app registers (`app_router.dart`), so a preview and the app agree.
const String _requestTypeScreenPath = '/request-type';
const String _requestTypeScreenLocationPath = '/client-location';

/// Every `onTierSelected` / `onContinue` callback the screen invoked, in order.
///
/// Public because the render test is the only thing that can read it, and what
/// it reads is a defect: both parameters exist on [RequestTypeScreen] and
/// neither is ever forwarded by `build`, so this list stays EMPTY through a full
/// tier tap and Continue press while the screen navigates itself. Cleared as
/// each host mounts, so one card cannot observe another's taps.
final List<String> requestTypeScreenSeamCalls = <String>[];

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they exist:
/// five of these states put NO distinguishing production copy on screen. Dev
/// chrome, never shipped copy, so they are deliberately un-localized and
/// rendered LTR at a fixed text scale.
final class RequestTypeScreenCaptions {
  RequestTypeScreenCaptions._();

  /// `GET /tiers` has not answered: the first frame of every mount.
  static const String loading = 'preview · tier read in flight';

  /// The three tiers the delivery service serves, nothing chosen.
  static const String servedCatalogue = 'preview · served 3 tiers, no selection';

  /// The same list with Standard already chosen.
  static const String selected = 'preview · Standard selected';

  /// Different prices, SLAs and vehicles — identical cards.
  static const String repricedCatalogue =
      'preview · repriced 99-125 USD · same cards';

  /// `200 OK`, zero tiers: loaded, and unusable.
  static const String emptyCatalogue = 'preview · catalogue answered EMPTY';

  /// The retryable failure.
  static const String errorNetwork = 'preview · tier read failed · network';

  /// The un-retryable one, wearing the same sentence.
  static const String errorServer = 'preview · tier read failed · server 5xx';

  /// All five tiers on the narrowest supported phone.
  static const String fullCatalogueCompact =
      'preview · five tiers · 320 x 568 ceiling';
}

/// What the stand-in destination renders, and what a render test pins to prove
/// the Continue CTA really left the screen.
const String requestTypeScreenDestinationCaption =
    'client-location (preview stand-in)';

/// Where `pushNamed('client-location')` lands: the next step of the create flow.
///
/// The real destination (`ClientLocationScreen`) builds its own cubits off DI,
/// so the stand-in only has to exist and say which edge was taken. Un-localized
/// dev chrome.
class _RequestTypeScreenLocationStandIn extends StatelessWidget {
  const _RequestTypeScreenLocationStandIn();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Text(
            requestTypeScreenDestinationCaption,
            key: const Key('request-type-preview-destination'),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Puts a real router above [RequestTypeScreen], pins the device frame, and
/// captions the state.
///
/// Stateful, and the collaborators are built once: a repository rebuilt every
/// frame would restart the load, a cubit rebuilt every frame would lose the
/// selection it drove itself into, and a regenerated [GoRouter] would drop the
/// navigation state the Continue CTA depends on.
class _RequestTypeScreenHost extends StatefulWidget {
  const _RequestTypeScreenHost({
    required this.caption,
    this.createRepository,
    this.createCubit,
    this.box = _requestTypeScreenPhoneBox,
  });

  /// Called once per mount, so each canvas card gets its own fake.
  final TierRepository Function()? createRepository;

  /// The other seam — for the one state `repository:` cannot reach.
  final TierSelectionCubit Function()? createCubit;

  /// The line painted above the device frame.
  final String caption;

  /// The device this card is judged on.
  final Size box;

  @override
  State<_RequestTypeScreenHost> createState() => _RequestTypeScreenHostState();
}

class _RequestTypeScreenHostState extends State<_RequestTypeScreenHost> {
  late final TierRepository? _repository = widget.createRepository?.call();

  /// Mounted through `BlocProvider.value`, which does not close it — so the
  /// host does.
  late final TierSelectionCubit? _cubit = widget.createCubit?.call();

  late final GoRouter _router = GoRouter(
    initialLocation: _requestTypeScreenPath,
    routes: <RouteBase>[
      GoRoute(
        path: _requestTypeScreenPath,
        name: 'request-type',
        builder: (_, _) => _screen(),
      ),
      GoRoute(
        path: _requestTypeScreenLocationPath,
        name: 'client-location',
        builder: (_, _) => const _RequestTypeScreenLocationStandIn(),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    requestTypeScreenSeamCalls.clear();
  }

  @override
  void dispose() {
    _router.dispose();
    _cubit?.close();
    super.dispose();
  }

  /// The screen as the router mounts it, plus the two callbacks the screen
  /// never calls — see the third finding in the section prose.
  ///
  /// `onChangeLocation` is left null on purpose so the Change Location row takes
  /// the screen's own `pushNamed` edge rather than a preview closure.
  Widget _screen() => RequestTypeScreen(
        cubit: _cubit,
        repository: _repository,
        onTierSelected: (Tier tier) =>
            requestTypeScreenSeamCalls.add('onTierSelected:${tier.id.name}'),
        onContinue: (RequestDraft draft) =>
            requestTypeScreenSeamCalls.add('onContinue:${draft.tierId}'),
      );

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
            // `Router.withConfig` is exactly what `MaterialApp.router` does
            // internally, so this adds a Router and nothing else — the ambient
            // theme, locale and text scale still come from the host above it.
            Expanded(child: Router<Object>.withConfig(config: _router)),
          ],
        ),
      ),
    );
  }
}

Widget _requestTypeScreenHosted(
  TierRepository Function() createRepository,
  String caption, {
  Size box = _requestTypeScreenPhoneBox,
}) =>
    _RequestTypeScreenHost(
      createRepository: createRepository,
      caption: caption,
      box: box,
    );

/// The first frame of EVERY mount: `load()` fired from `BlocProvider.create` and
/// `GET /tiers` has not answered.
///
/// A centred spinner and nothing else — note what is missing around it. The
/// `bottomNavigationBar` is not merely disabled, it is GONE
/// (`_ContinueFooter` short-circuits to `SizedBox.shrink()` for every status but
/// `loaded`), so the page has no footer, then grows one. The app bar and its
/// back arrow are the only stable furniture.
@JeebPreview(
  group: 'request_type',
  name: 'Loading · tier read in flight',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenLoading() => _requestTypeScreenHosted(
      RequestTypeScreenPreviewFixtures.stalled,
      RequestTypeScreenCaptions.loading,
    );

/// The reference reading, and the state the app opens on: Flash, Express and
/// Standard, none of them chosen, Continue disabled.
///
/// Matrixed because this is the whole screen in three readings at once. In AR
/// the headings, the cards and the Change Location chevron all mirror. At 100%
/// text on this phone the list does not scroll at all — measured 0 pt of extent,
/// so every option and the location row are visible before the customer chooses
/// — and at 200% that becomes 318 pt of extent, which puts the location row and
/// part of the last card below the fold. Nothing here is selected on purpose:
/// JM-024 requires a DELIBERATE tap, so "no default tier" is a contract, not an
/// empty state.
@JeebPreview(
  group: 'request_type',
  name: 'Loaded · served catalogue, no selection',
  size: _requestTypeScreenPhoneBox,
  matrix: true,
)
Widget requestTypeScreenServedCatalogue() => _requestTypeScreenHosted(
      RequestTypeScreenPreviewFixtures.servedCatalogue,
      RequestTypeScreenCaptions.servedCatalogue,
    );

/// The same list with Standard chosen — the only state `repository:` cannot
/// produce.
///
/// `selectTier` is a no-op until `load()` has landed, so this one comes in
/// through `cubit:` with the selection chained onto the load. Read it beside
/// the state above: `selected` swaps the fill, the border, the title colour and
/// the description colour at once, and the Continue CTA goes live. The only
/// signal that survives a grayscale reading is the 8 dp dot in the radio ring.
@JeebPreview(
  group: 'request_type',
  name: 'Selected · Standard',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenSelected() => _RequestTypeScreenHost(
      createCubit: () => RequestTypeScreenPreviewFixtures.selectedTierCubit(
        RequestTypeScreenPreviewFixtures.selectedTier,
      ),
      caption: RequestTypeScreenCaptions.selected,
    );

/// The same three tiers with every gateway-owned number changed — and not one
/// pixel of difference.
///
/// Flash is priced 99–125 USD here instead of 120–160k LBP, promised in five
/// minutes instead of sixty, moved to a van, and stripped of its `recommended`
/// flag; Express takes the recommendation instead. Put this card beside
/// [requestTypeScreenServedCatalogue] and they are the same screen, because
/// `_RequestTierCopy.of(l10n, tier.id)` keys every line on the id and reads
/// nothing else off the [Tier]. The three "value" lines a customer compares
/// prices with are static ARB copy.
@JeebPreview(
  group: 'request_type',
  name: 'Repriced catalogue · identical cards',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenRepricedCatalogue() => _requestTypeScreenHosted(
      RequestTypeScreenPreviewFixtures.repricedCatalogue,
      RequestTypeScreenCaptions.repricedCatalogue,
    );

/// `200 OK` with no tiers in it: loaded, and unusable.
///
/// The heading renders over nothing, the Location row sits under the hole, and
/// the Continue button is present and permanently disabled. No message, no
/// retry, no explanation — this is a SUCCESS as far as every layer below the
/// widget is concerned, so nothing on the error path fires. Reachable without
/// any gateway outage: `DioTierRepository._tierIdFromLabel` silently drops every
/// tier whose `name` this client cannot map, so a server-side rename empties the
/// screen one tier at a time.
@JeebPreview(
  group: 'request_type',
  name: 'Empty · catalogue answered 200 with nothing',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenEmptyCatalogue() => _requestTypeScreenHosted(
      RequestTypeScreenPreviewFixtures.emptyCatalogue,
      RequestTypeScreenCaptions.emptyCatalogue,
    );

/// The read failed on the wire — the retryable failure, and the honest one.
///
/// `Try again` re-runs `load()`, which is exactly the right advice here. Note
/// again that the `bottomNavigationBar` is gone: the retry inside the body is
/// the only control on the screen.
@JeebPreview(
  group: 'request_type',
  name: 'Error · network',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenErrorNetwork() => _requestTypeScreenHosted(
      () => RequestTypeScreenPreviewFixtures.failing(TierLoadFailure.network),
      RequestTypeScreenCaptions.errorNetwork,
    );

/// The read reached Jeeb and Jeeb answered badly — a 5xx, or a body
/// `_parseResponse` cannot recognise.
///
/// Identical to [requestTypeScreenErrorNetwork], because `_Body` ignores
/// `state.failure` and always renders `requestSummaryErrorNetwork`: "Couldn't
/// reach Jeeb. Check your connection and try again." The customer is told to
/// check a connection that is working and to retry an operation that will fail
/// the same way. The copy is also borrowed from the request_summary feature,
/// which is why it names a submit problem on a screen that has not submitted
/// anything.
@JeebPreview(
  group: 'request_type',
  name: 'Error · server 5xx (same copy)',
  size: _requestTypeScreenPhoneBox,
)
Widget requestTypeScreenErrorServer() => _requestTypeScreenHosted(
      () => RequestTypeScreenPreviewFixtures.failing(TierLoadFailure.server),
      RequestTypeScreenCaptions.errorServer,
    );

/// The layout ceiling: all five tiers the client can render, on the narrowest
/// phone it supports.
///
/// [FakeTierRepository] is the SHIPPING fallback, not a hypothetical — the two
/// extra tiers own the longest title in the ARB ("On-the-Way", the only
/// hyphenated one) and the longest speed line, and Eco's "24–48" is the one
/// place a Latin digit range is embedded in Arabic copy.
///
/// Matrixed because this is where the three readings diverge. Nothing here can
/// overflow — the body is a `ListView` and `Scaffold` clamps the rest — so what
/// the three cards show is how much of the screen is REACHABLE without
/// scrolling. Measured against a 384 pt viewport: 760 pt of scroll extent at
/// 100%, 2889 at 200% EN and 2485 at 200% AR (Arabic copy runs shorter). The
/// Continue footer sits outside that list and holds its 48 pt at every scale,
/// which is `OmdsPrimaryButton`'s fixed default rather than anything this screen
/// decides.
@JeebPreview(
  group: 'request_type',
  name: 'Full catalogue · compact 320x568',
  size: _requestTypeScreenCompactBox,
  matrix: true,
)
Widget requestTypeScreenFullCatalogueCompact() => _requestTypeScreenHosted(
      RequestTypeScreenPreviewFixtures.fullCatalogue,
      RequestTypeScreenCaptions.fullCatalogueCompact,
      box: _requestTypeScreenCompactBox,
    );
