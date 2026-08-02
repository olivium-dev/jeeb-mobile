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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/goods_cost/goods_cost_screen_preview_test.dart
// ===========================================================================
//
// [GoodsCostScreen] is a one-field form: a headline, an amount field labelled
// in the delivery's gateway-authoritative currency, and a submit CTA that
// records the cost and pops with the confirmed [GoodsCost].
//
// The fakes are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/goods_cost_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry (`devtool/catalog/entries/
// batch_04_entries.dart`), so the designer's browser and this canvas cannot
// drift into showing two different "designed states". None of them can reach
// the network: they answer from a const, throw, or never complete. That is
// load-bearing rather than decorative — `_resolveRepository()` falls back to
// `DioGoodsCostRepository(sl<Dio>())` whenever `Dio` is registered, and the
// `CatalogNetworkGuard` in [jeebPreviewHost] passes GETs, so a state that
// forgot `repository:` would read a live delivery.
//
// Four things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest; the inner one (OMDSAppBar + body) is the real surface. The
//    canvas box is therefore a real device ([_goodsCostScreenPhoneBox]) rather
//    than the harness's 390x200 default, and the frame is pinned in the TREE
//    as well as in `size:` so the render tests measure the same phone instead
//    of the 800 pt test surface.
//  * **`repository:` is the ONLY seam.** The screen builds its own
//    [GoodsCostCubit] inside `BlocProvider.create` and calls `loadCurrency()`
//    on it; there is no `cubit:`/`seed:`. So the CURRENCY axis is reachable as
//    a first frame and the SUBMIT axis is not reachable at all until somebody
//    types a parseable amount and presses the CTA — `isEnabled` is
//    `_controller.text.trim().isNotEmpty`, so an untouched screen cannot even
//    arm it. The three `record*` previews open on an ordinary form and are
//    BOUND to their outcome; press Confirm in the canvas to reach it, and the
//    render test performs the press.
//  * **Every preview is hosted under a real [Navigator] with a page below it.**
//    Not decoration: the success listener calls
//    `Navigator.of(context).pop(recorded)`, so on a bare host the first
//    successful submit would pop the ONLY route and blank the card. The
//    stand-in below the screen catches the popped [GoodsCost] and prints it,
//    which turns the pop from a hazard into the one state that shows what this
//    screen returns. It is also the only reason the app bar has a back arrow:
//    `OMDSAppBar` leaves `showBackButton` at its `false` default, so the arrow
//    comes entirely from `automaticallyImplyLeading` finding a route below —
//    see the last bullet.
//  * **Each card carries a caption** ([GoodsCostScreenCaptions]), because the
//    designed states here are nearly invisible: the only production copy that
//    varies is the field label, and two distinct states (`read in flight` and
//    `read failed`) render the identical neutral label. Same device as
//    `DeliveryReceiptScreenCaptions`.
//
// What these previews surfaced in the screen — none of it changed here:
//
//  * **The field prefixes a hardcoded `$`.** `prefixIcon:
//    Icon(Icons.attach_money)` sits immediately left of a label the code goes
//    out of its way to source from the gateway — the comment above `_label`
//    cites 40_GUARDRAILS_ARCH §5, "no hardcoded currency". On
//    [goodsCostScreenCurrencyLbp] the Jeeber is asked for `Goods cost (LBP)`
//    beside a dollar sign, and in AR the mirrored layout puts that dollar sign
//    on the right of an Arabic label. The guardrail was applied to the string
//    and missed the icon.
//  * **`_submit` fails silently on anything `double.tryParse` rejects.**
//    `final amount = double.tryParse(...); if (amount == null) return;` — with
//    a non-empty field the CTA is ENABLED, so pressing it produces no spinner,
//    no error, no state change at all. `12,5` (comma decimal), `12.5.6`, `abc`
//    and `١٢` (Arabic-Indic digits, which is what `TextInputType.number` gives
//    an Arabic keyboard) are all dead presses. There is no `inputFormatters`
//    and no validator, so nothing prevents any of them from being typed.
//  * **Nothing on this screen scrolls, and the keyboard is always up.** The
//    body is a fixed `Column` whose last child is `Expanded`, and inside it a
//    `Column` of field + optional error + `Spacer` + CTA. The `Spacer` gives
//    slack back but cannot create height: once the viewport is shorter than
//    header + field + CTA the whole thing overflows outright. Standing still it
//    fits everywhere — measured in EN with the real Inter face, the slack is
//    532 pt on a 390x844 phone and 256 pt on the narrowest supported one
//    ([_goodsCostScreenCompactBox]), dropping to 356 and ~40 at 200% text. The
//    problem is that this is a TEXT-ENTRY screen, so the software keyboard —
//    ~290 pt, and up the whole time the field is focused — is subtracted from
//    exactly that slack by the screen's own `resizeToAvoidBottomInset`. On the
//    compact frame it does not fit at 100% text, never mind 200%. The render
//    test pins the slack figures and the overflow.
//  * **The pop is unguarded.** `Navigator.of(context).pop(recorded)` in the
//    success listener, on a screen whose app bar leaves `showBackButton` at
//    its `false` default. If this screen is ever reached by a stack-REPLACING
//    navigation, that pop empties the Navigator — the exact failure
//    `OMDSAppBar._buildBackButton` guards against with `maybePop`, documented
//    in its own source. The screen is an orphan today (JEBV4-227), so this is
//    a trap laid for whoever routes it, not a live defect.
//
// The states are the three the Screen Catalog names plus five it does not.

/// The phone this screen is designed against.
const Size _goodsCostScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _goodsCostScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist: four of these states put NO distinguishing production copy on screen.
/// Dev chrome, never shipped copy, so they are deliberately un-localized and
/// rendered LTR at a fixed text scale.
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
///
/// Renders the [GoodsCost] the screen popped with, so the success path — the
/// only thing this screen exists to do — is inspectable instead of being a card
/// that goes blank. Un-localized dev chrome.
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
///
/// Stateful, and both the repository and the routes are built once: a
/// repository rebuilt every frame would re-arm a fake whose `recorded` field is
/// meant to survive a press, and regenerated routes would drop the navigation
/// state the success `pop` depends on. Two routes, not one — the screen is
/// pushed for a result, which is what its own `pop(recorded)` assumes.
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
    // preview would otherwise receive it.
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
                // as one latin line and the 200% card does not spend a third of
                // the device on a label.
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
///
/// Also the ONLY state that completes: `FakeGoodsCostRepository` records
/// happily, so typing an amount and pressing Confirm pops with a
/// gateway-confirmed [GoodsCost] and the stand-in underneath prints it. Try
/// `12.5` — then try `12,5`, which is what a comma-decimal keyboard produces:
/// the CTA is enabled and the press does nothing at all, because `_submit`
/// drops a `double.tryParse` miss on the floor without a word.
///
/// Matrixed because this is the whole screen in three readings at once: in AR
/// the label, the `$` prefix icon and the CTA all mirror, and at 200% text the
/// header grows into the space the `Expanded` body needs.
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
///
/// The label is gateway-authoritative on purpose (40_GUARDRAILS_ARCH §5, quoted
/// above `_label`); the prefix icon next to it is a hardcoded dollar sign. This
/// card is where the two are visible in the same slot, and the AR rendering is
/// where the `$` swaps sides.
@JeebPreview(
  group: 'goods_cost',
  name: 'Currency LBP · hardcoded \$ icon',
  size: _goodsCostScreenPhoneBox,
  matrix: true,
)
Widget goodsCostScreenCurrencyLbp() => _goodsCostScreenHosted(
      GoodsCostScreenPreviewFixtures.lbp,
      GoodsCostScreenCaptions.lbp,
    );

/// The first frame of EVERY mount: `loadCurrency()` is fired from
/// `BlocProvider.create` and has not answered yet.
///
/// Note what is absent. The field is labelled with the neutral `Goods cost`,
/// the CTA is live, and nothing anywhere says a read is in progress — no
/// spinner, no skeleton, no disabled state. A Jeeber who starts typing
/// immediately gets the label relabelled under their finger the moment the read
/// lands. Read it beside [goodsCostScreenCurrencyUnavailable]: the two are
/// pixel-identical and mean opposite things, which is the whole reason the
/// captions exist.
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
///
/// What the Jeeber is left with is a bare `Goods cost` and no way to know which
/// currency the number will be recorded in. The amount is sent as a plain
/// double and the gateway attaches the currency, so nothing is mis-recorded —
/// but the person typing cannot tell whether they are being asked for dollars
/// or for pounds, and the two differ by ~90,000x.
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
///
/// The first frame is an ordinary empty form, because
/// `GoodsCostSubmitStatus.failed` is not constructible without input — see the
/// second bullet in the section prose. Type an amount and press Confirm: the
/// inline `goods-cost-error` appears under the field reading "Enter a valid
/// amount and try again." Then type one more character and watch it vanish —
/// `onChanged` calls `acknowledgeError()`, so the message the Jeeber is meant
/// to act on is destroyed by the act of acting on it, and nothing marks the
/// field itself as invalid. Note also that the client never validates: `-5` and
/// `0` are submitted to the gateway to be rejected there.
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
///
/// Same shape as [goodsCostScreenRecordRejected] and different copy, which is
/// the point — the two are told apart only by the sentence, and only one of
/// them can be fixed by pressing Confirm again. The fixture keeps failing, so
/// a retry here behaves the way it does on a dead connection.
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
///
/// The only way to hold `GoodsCostSubmitStatus.inFlight` on screen — on a real
/// gateway it is a few hundred milliseconds. Type an amount and press Confirm.
/// Worth looking at because it is the one state that takes the field away: the
/// Jeeber can no longer see or correct what they typed while the record is
/// outstanding, and there is no cancel.
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
///
/// Nothing on this screen scrolls. `_GoodsCostView` is a fixed `Column` ending
/// in `Expanded`, and the body inside it is field + optional error + `Spacer` +
/// CTA. The `Spacer` gives slack back but cannot create height, so the moment
/// the viewport is shorter than header + field + CTA the body overflows.
///
/// Standing still this frame is fine in both cards of the matrix: 256 pt of
/// slack at 100% text and about 40 pt at 200% (measured in EN with the real
/// Inter face — the AR figure under the test font is an artifact, see the
/// render test). Focus the field on a device, though, and the keyboard takes
/// ~290 pt out of exactly that slack, which the compact frame does not have at
/// any text scale. The render test pins the slack and pins the overflow that
/// follows.
///
/// The 200% card is worth opening for a second reason: it is where you can see
/// that the CTA has stopped floating at the bottom and is sitting directly
/// under the field, because the `Spacer` has nothing left to give.
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
