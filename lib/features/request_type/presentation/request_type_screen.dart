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

/// The phone this screen is designed against.
const Size _requestTypeScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app. The tier list is a `ListView`, so
const Size _requestTypeScreenCompactBox = Size(320, 568);

/// The route the screen pushes, and the one it is pushed from. Same names the
/// app registers (`app_router.dart`), so a preview and the app agree.
const String _requestTypeScreenPath = '/request-type';
const String _requestTypeScreenLocationPath = '/client-location';

/// Every `onTierSelected` / `onContinue` callback the screen invoked, in order.
/// Public because the render test is the only thing that can read it, and what
final List<String> requestTypeScreenSeamCalls = <String>[];

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they exist:
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
/// The real destination (`ClientLocationScreen`) builds its own cubits off DI,
/// so the stand-in only has to exist and say which edge was taken. Un-localized
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
/// Stateful, and the collaborators are built once: a repository rebuilt every
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
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // `Router.withConfig` is exactly what `MaterialApp.router` does
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
/// The heading renders over nothing, the Location row sits under the hole, and
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
/// `Try again` re-runs `load()`, which is exactly the right advice here. Note
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
