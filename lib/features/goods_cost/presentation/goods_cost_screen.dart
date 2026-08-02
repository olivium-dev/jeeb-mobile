import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goods_cost_cubit.dart';
import '../application/goods_cost_state.dart';
import '../data/dio_goods_cost_repository.dart';
import '../data/fake_goods_cost_repository.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/goods_cost_screen_fixtures.dart';

class GoodsCostScreen extends StatelessWidget {
  const GoodsCostScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  final GoodsCostRepository? repository;

  GoodsCostRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<GoodsCostRepository>()) {
      return sl<GoodsCostRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioGoodsCostRepository(sl<Dio>());
    }
    return FakeGoodsCostRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<GoodsCostCubit>(
      create: (_) => GoodsCostCubit(
        repository: repo,
        deliveryId: deliveryId,
      )..loadCurrency(),
      child: const _GoodsCostView(),
    );
  }
}

class _GoodsCostView extends StatelessWidget {
  const _GoodsCostView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(title: AppLocalizations.of(context).goodsCostTitle),
      body: const Padding(
        padding: EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            SizedBox(height: Spacing.xLarge),
            Expanded(child: _CostFieldAndSubmit()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.goodsCostHeadline,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.goodsCostBody,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _CostFieldAndSubmit extends StatefulWidget {
  const _CostFieldAndSubmit();

  @override
  State<_CostFieldAndSubmit> createState() => _CostFieldAndSubmitState();
}

class _CostFieldAndSubmitState extends State<_CostFieldAndSubmit> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null) return;
    context.read<GoodsCostCubit>().submit(amount);
  }

  String _label(AppLocalizations l10n, String? currency) =>
      (currency != null && currency.isNotEmpty)
          ? l10n.goodsCostFieldLabel(currency)
          : l10n.goodsCostFieldLabelNeutral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<GoodsCostCubit, GoodsCostState>(
      listenWhen: (prev, next) =>
          prev.submitStatus != next.submitStatus &&
          next.submitStatus == GoodsCostSubmitStatus.succeeded,
      listener: (context, state) {
        final GoodsCost? recorded = state.recorded;
        if (recorded != null) {
          Navigator.of(context).pop(recorded);
        }
      },
      builder: (context, state) {
        final submitting = state.isSubmitting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsTextField(
              controller: _controller,
              labelText: _label(l10n, state.currency),
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.attach_money),
              enabled: !submitting,
              onChanged: (_) {
                if (state.submitStatus == GoodsCostSubmitStatus.failed) {
                  context.read<GoodsCostCubit>().acknowledgeError();
                } else {
                  setState(() {});
                }
              },
            ),
            if (state.submitStatus == GoodsCostSubmitStatus.failed) ...[
              const SizedBox(height: Spacing.small),
              Text(
                _errorCopy(l10n, state.submitError),
                key: const Key('goods-cost-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const Spacer(),
            OmdsLoadingButton(
              text: l10n.goodsCostSubmit,
              isLoading: submitting,
              isEnabled: _controller.text.trim().isNotEmpty && !submitting,
              onTap: _submit,
            ),
          ],
        );
      },
    );
  }

  static String _errorCopy(AppLocalizations l10n, GoodsCostFailure? failure) {
    switch (failure) {
      case GoodsCostFailure.network:
        return l10n.goodsCostErrorNetwork;
      case GoodsCostFailure.notFound:
        return l10n.goodsCostErrorNotFound;
      case GoodsCostFailure.validation:
        return l10n.goodsCostErrorValidation;
      case GoodsCostFailure.unknown:
      case null:
        return l10n.goodsCostErrorGeneric;
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone this screen is designed against.
const Size _goodsCostScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _goodsCostScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
final class GoodsCostScreenCaptions {
  GoodsCostScreenCaptions._();

  /// `GET` answered `USD`; recording succeeds and pops.
  static const String usd = 'preview · USD · record succeeds';

  /// `GET` answered `LBP` — beside a hardcoded `$` prefix icon.
  static const String lbp = 'preview · LBP · note the \$ icon';

  /// The currency read never lands: the first frame of every mount.
  static const String currencyPending = 'preview · currency read in flight';

  /// The currency read threw: the label degrades, entry still works.
  static const String currencyUnavailable = 'preview · currency read failed';

  /// Loads fine; the record is rejected 422. Type an amount and press Confirm.
  static const String recordRejected = 'preview · record rejected 422';

  /// Loads fine; the record never reaches the server.
  static const String recordNetworkDown = 'preview · record fails, network';

  /// Loads fine; the record never lands — the in-flight CTA.
  static const String recordStalled = 'preview · record never lands';

  /// The layout ceiling: 320x568.
  static const String compactCeiling = 'preview · 320 x 568 ceiling';
}

/// The page BELOW the screen in the preview's Navigator: whoever pushed it.
/// Renders the [GoodsCost] the screen popped with, so the success path — the
/// only thing this screen exists to do — is inspectable instead of being a card
class _GoodsCostScreenCallerStandIn extends StatelessWidget {
  const _GoodsCostScreenCallerStandIn({required this.returned});

  final ValueNotifier<GoodsCost?> returned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('preview caller')),
      body: Center(
        child: ValueListenableBuilder<GoodsCost?>(
          valueListenable: returned,
          builder: (BuildContext context, GoodsCost? value, Widget? _) => Text(
            value == null
                ? 'pushed goods-cost entry'
                : 'popped with ${value.amount} ${value.currency}',
            key: const Key('goods-cost-preview-caller'),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Puts a real [Navigator] above [GoodsCostScreen], pins the device frame, and
/// captions the state.
/// Stateful, and both the repository and the routes are built once: a
class _GoodsCostScreenHost extends StatefulWidget {
  const _GoodsCostScreenHost({
    required this.createRepository,
    required this.caption,
    this.box = _goodsCostScreenPhoneBox,
  });

  /// Called once per mount, so each canvas card gets its own fake.
  final GoodsCostRepository Function() createRepository;

  /// The line painted above the device frame.
  final String caption;

  /// The device this card is judged on.
  final Size box;

  @override
  State<_GoodsCostScreenHost> createState() => _GoodsCostScreenHostState();
}

class _GoodsCostScreenHostState extends State<_GoodsCostScreenHost> {
  late final GoodsCostRepository _repository = widget.createRepository();
  final ValueNotifier<GoodsCost?> _returned = ValueNotifier<GoodsCost?>(null);

  @override
  void dispose() {
    _returned.dispose();
    super.dispose();
  }

  List<Route<dynamic>> _initialRoutes(NavigatorState _, String _) {
    final MaterialPageRoute<GoodsCost> entry = MaterialPageRoute<GoodsCost>(
      builder: (_) => GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: _repository,
      ),
    );
    // The screen pops with its gateway-confirmed record and nothing in a
    entry.popped.then((Object? value) {
      if (!mounted) return;
      _returned.value = value is GoodsCost ? value : null;
    });
    return <Route<dynamic>>[
      MaterialPageRoute<void>(
        builder: (_) => _GoodsCostScreenCallerStandIn(returned: _returned),
      ),
      entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: widget.box.width,
        height: widget.box.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.small,
                vertical: Spacing.xSmall,
              ),
              child: Text(
                widget.caption,
                // Dev chrome: LTR and unscaled, so the AR card still reads it
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Navigator(
                onGenerateInitialRoutes: _initialRoutes,
                onGenerateRoute: (RouteSettings settings) =>
                    MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      _GoodsCostScreenCallerStandIn(returned: _returned),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _goodsCostScreenHosted(
  GoodsCostRepository Function() createRepository,
  String caption, {
  Size box = _goodsCostScreenPhoneBox,
}) =>
    _GoodsCostScreenHost(
      createRepository: createRepository,
      caption: caption,
      box: box,
    );

/// The reference reading: the delivery is priced in `USD`, so the field reads
/// `Goods cost (USD)`.
@JeebPreview(
  group: 'goods_cost',
  name: 'Currency USD · records and pops',
  size: _goodsCostScreenPhoneBox,
  matrix: true,
)
Widget goodsCostScreenCurrencyUsd() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.usd,
      GoodsCostScreenCaptions.usd,
    );

/// The same screen for a delivery priced in Lebanese pounds: `Goods cost (LBP)`
/// — beside `Icons.attach_money`.
@JeebPreview(
  group: 'goods_cost',
  name: 'Currency LBP · hardcoded USD icon',
  size: _goodsCostScreenPhoneBox,
  matrix: true,
)
Widget goodsCostScreenCurrencyLbp() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.lbp,
      GoodsCostScreenCaptions.lbp,
    );

/// The first frame of EVERY mount: `loadCurrency()` is fired from
/// `BlocProvider.create` and has not answered yet.
@JeebPreview(
  group: 'goods_cost',
  name: 'Currency read in flight',
  size: _goodsCostScreenPhoneBox,
)
Widget goodsCostScreenCurrencyPending() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.currencyPending,
      GoodsCostScreenCaptions.currencyPending,
    );

/// The currency read threw and the cubit swallowed it — deliberately: the read
/// is best-effort and a failure must not block cost entry.
@JeebPreview(
  group: 'goods_cost',
  name: 'Currency read failed · neutral label',
  size: _goodsCostScreenPhoneBox,
)
Widget goodsCostScreenCurrencyUnavailable() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.currencyUnavailable,
      GoodsCostScreenCaptions.currencyUnavailable,
    );

/// A form that loads perfectly and whose record is rejected with the 422 the
/// gateway returns for a non-positive or out-of-range amount.
@JeebPreview(
  group: 'goods_cost',
  name: 'Record rejected · 422 validation',
  size: _goodsCostScreenPhoneBox,
)
Widget goodsCostScreenRecordRejected() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.recordRejected,
      GoodsCostScreenCaptions.recordRejected,
    );

/// The record never reached the server: the retryable failure, and the one a
/// Jeeber standing in a shop on a bad connection actually hits.
@JeebPreview(
  group: 'goods_cost',
  name: 'Record failed · network',
  size: _goodsCostScreenPhoneBox,
)
Widget goodsCostScreenRecordNetworkDown() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.recordNetworkDown,
      GoodsCostScreenCaptions.recordNetworkDown,
    );

/// The record is in flight and never lands: the CTA spins and the field goes
/// disabled.
@JeebPreview(
  group: 'goods_cost',
  name: 'Record in flight · CTA spinner',
  size: _goodsCostScreenPhoneBox,
)
Widget goodsCostScreenRecordStalled() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.recordStalled,
      GoodsCostScreenCaptions.recordStalled,
    );

/// The layout ceiling: the narrowest supported phone, 320x568.
/// Nothing on this screen scrolls. `_GoodsCostView` is a fixed `Column` ending
@JeebPreview(
  group: 'goods_cost',
  name: 'Compact 320x568 · no scroll anywhere',
  size: _goodsCostScreenCompactBox,
  matrix: true,
)
Widget goodsCostScreenCompactCeiling() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.lbp,
      GoodsCostScreenCaptions.compactCeiling,
      box: _goodsCostScreenCompactBox,
    );
