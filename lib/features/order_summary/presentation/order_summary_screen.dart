import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../application/order_summary_cubit.dart';
import '../application/order_summary_state.dart';
import '../data/fake_order_summary_repository.dart';
import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';
import 'order_summary_l10n.dart';
import 'widgets/order_summary_pinned.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/order_summary_screen_fixtures.dart';

class OrderSummaryScreen extends StatelessWidget {
  const OrderSummaryScreen({
    super.key,
    required this.deliveryId,
    this.repository,
    this.cubitFactory,
  });

  final String deliveryId;

  final OrderSummaryRepository? repository;

  final OrderSummaryCubit Function(
    OrderSummaryRepository repository,
    String deliveryId,
  )? cubitFactory;

  OrderSummaryRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OrderSummaryRepository>()) {
      return sl<OrderSummaryRepository>();
    }
    return FakeOrderSummaryRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OrderSummaryCubit>(
      create: (_) {
        final cubit = cubitFactory?.call(repo, deliveryId) ??
            OrderSummaryCubit(repository: repo, deliveryId: deliveryId);
        cubit.load();
        return cubit;
      },
      child: const _OrderSummaryView(),
    );
  }
}

class _OrderSummaryView extends StatelessWidget {
  const _OrderSummaryView();

  @override
  Widget build(BuildContext context) {
    final l10n = OrderSummaryL10n.of(context);
    return Semantics(
      identifier: 'order_summary_root',
      container: true,
      child: Scaffold(
      appBar: OMDSAppBar(title: l10n.title, showBackButton: true),
      body: SafeArea(
        child: BlocBuilder<OrderSummaryCubit, OrderSummaryState>(
          builder: (context, state) {
            switch (state.status) {
              case OrderSummaryStatus.initial:
              case OrderSummaryStatus.loading:
                return const Center(child: OmdsLoadingState());
              case OrderSummaryStatus.failed:
                return Center(
                  child: OmdsErrorState(
                    message: l10n.errorGeneric,
                    retryLabel: l10n.retryLabel,
                    onRetry: () =>
                        context.read<OrderSummaryCubit>().refresh(),
                  ),
                );
              case OrderSummaryStatus.loaded:
                return _Loaded(summary: state.summary!);
            }
          },
        ),
      ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        Spacing.small,
        0,
        Spacing.xLarge,
      ),
      children: [
        OrderSummaryPinned(
          summary: summary,
          onOpenChat: () => context.pushNamed(
            'chat-detail',
            pathParameters: {
              'id': summary.conversationId.isNotEmpty
                  ? summary.conversationId
                  : (summary.requestId.isNotEmpty
                      ? summary.requestId
                      : summary.deliveryId),
            },
          ),
          onTrack: () => context.pushNamed(
            'live-tracking',
            pathParameters: {'id': summary.deliveryId},
          ),
        ),
      ],
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
// Render tests: test/previews/order_summary/order_summary_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so each card shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `SafeArea`. That is the same nesting the Screen Catalog produces. The box
//    is therefore a real device ([_orderSummaryScreenPhoneBox], 390x844, plus
//    the 320x568 [_orderSummaryScreenCompactBox]) rather than the harness
//    default 390x200 — half of what this screen does is decide how much room
//    the pinned card gets, and a 200 pt strip cannot show that. The width is
//    pinned in the TREE as well as in `size:`, so the render tests measure the
//    same phone instead of the 800 pt test surface.
//
// 2. Every card is frozen with `TickerMode(enabled: false)`. The cold-read
//    state is an `OmdsLoadingState`, i.e. an indeterminate
//    `CircularProgressIndicator` that schedules frames forever, and
//    `pumpAndSettle` waits for frames to STOP being scheduled. Muting the
//    tickers paints a deterministic `t = 0` frame and lets the suite settle.
//
// 3. Four states have no copy of their own to be recognised by — the cold read
//    paints no text at all (`OmdsLoadingState` is built with no `message:`),
//    the two error states are copy-identical (which IS the finding below), and
//    the compact card is a narrower rendering of a card that already exists —
//    so every card carries a dev-chrome CAPTION above the device frame
//    ([OrderSummaryScreenCaptions]). The render test pins real screen copy
//    wherever a state produces some that only it can produce, and the caption
//    for the four that cannot.
//
// 4. The states come from
//    `lib/devtool/catalog/fixtures/order_summary_screen_fixtures.dart`, shared
//    with the Screen Catalog entry (`devtool/catalog/entries/batch_08_entries.dart`),
//    which used to own a private pending repository and an inline sample
//    summary. Every state drives the shipped `repository:` seam with an
//    in-memory fake — nothing here builds a Dio client or resolves DI — so
//    these are network-free by construction rather than by the guard in
//    [jeebPreviewHost]. The one exception is deliberate and is itself a state:
//    `Unconfigured DI` passes NO repository, which is the production path
//    through `_resolveRepository()` this section exists to make visible.
//
// The one thing NOT reproduced is a router. `order_summary_open_chat` and
// `order_summary_track` both call `context.pushNamed`, and there is no
// [GoRouter] above a preview card, so both CTAs are inert here. They are still
// rendered, because whether they are OFFERED in a given state is most of what
// these cards are for. The app-bar back button is safe either way: OMDSAppBar
// defaults to `Navigator.maybePop`.
//
// ## What these previews exposed in the screen
//
//  * **All three typed failures are the same screen.** `OrderSummaryFailure`
//    classifies `network`, `notFound` and `unknown`, `OrderSummaryCubit` stores
//    the value in `state.error` — and `_OrderSummaryView` never reads it. The
//    `failed` arm hardcodes `l10n.errorGeneric` ("Something went wrong. Please
//    try again."), so a 404 on a deleted order, an offline phone and a
//    malformed body are one indistinguishable card. Read `Error · not found`
//    beside `Error · network`: two different failures, two identical pictures,
//    and the only advice on either is a Retry that cannot help the 404.
//  * **Retry gives no feedback at all.** The error CTA calls
//    `OrderSummaryCubit.refresh()`, which — unlike `load()` — never emits
//    `loading`. It awaits the repository and, on a second failure, emits
//    `state.copyWith(error: …)` with the status still `failed`, i.e. the same
//    frame the user was already looking at. Nothing spins, nothing greys out,
//    no snackbar: on a flaky connection the button reads as dead.
//  * **A misconfigured build shows INVENTED order data as authoritative.**
//    `_resolveRepository()` ends in `return FakeOrderSummaryRepository()` when
//    GetIt has no `OrderSummaryRepository` bound, and that fake answers ANY
//    delivery id with a canned order — Kamal Hajj, 9.00 USD, 20 min,
//    "Groceries from Spinneys". `Unconfigured DI · fabricated summary` is that
//    card. There is no badge, no banner and no log line on screen; a customer
//    cannot tell it from a real accepted order, and the number it tells them to
//    hand over in cash is fiction. The guardrail (§6.4) keeps the fake out of
//    DI; this line puts it back in the widget tree.
//  * **`0.00 USD` is presented as a price, not as a missing one.**
//    `DioOrderSummaryRepository` null-coalesces `price` to `0.0` and `currency`
//    to `'USD'` independently of each other, so a thin delivery row renders an
//    authoritative zero — in a currency nobody chose — right above "Pay cash on
//    delivery". The ETA and tier cells beside it both have an honest "Pending"
//    placeholder for exactly this case; the price pill has none. See
//    `Minimal payload`.
//  * **A uuid can stand where the jeeber's name goes.** Same fixture: the
//    parser falls back to `jeeberId` when neither the delivery, the request nor
//    `GET /v1/users/:id` carried a name — and all three enrichment reads are
//    swallowed by design — so the customer is told they are meeting
//    `jbr-7f3c1a92-…`, with `J` in the avatar.
//  * **Nothing on the screen says WHICH order this is.** No delivery id, no
//    request id, no created-at, no status. `OrderSummary` carries the first
//    three and the pinned card renders none of them, so two accepted orders
//    with the same jeeber and the same price are the same picture — on a screen
//    whose entire reason to exist (JM-056) is being deep-linked to from a
//    transaction row.
//  * **Only the loaded state is machine-addressable.** `order_summary_root` is
//    on the whole `Semantics` container and the rest of the ids
//    (`order_summary_price`, `_eta`, `_tier`, `_cash_label`, the two CTAs) live
//    inside [OrderSummaryPinned]. The loading and failed arms carry no
//    identifier of their own, so a Maestro run — and the D30 assertions in
//    63_W1_TEST_PLAN — cannot distinguish "still loading" from "failed" from
//    "mounted but empty": all three are `order_summary_root` with nothing in
//    it.
//  * **A loaded summary can never be refreshed.** `refresh()` exists and the
//    cubit documents it as "pull-to-refresh", but the loaded body is a bare
//    `ListView` with no `RefreshIndicator` and no action anywhere, so the ONLY
//    caller is the error state's Retry. Once the card is on screen its ETA and
//    tier are frozen until the customer leaves the route and comes back.
//  * **The price pill inherits the header overflow.** `Longest content` is a
//    seven-digit SYP amount — ordinary in that market, not adversarial — and
//    `_PriceBlock` is a rigid `Row` child with no width ceiling and no
//    `maxLines`, so it starves the `Expanded` name beside it. Measured on this
//    screen at 390 pt through the REAL Inter/Noto faces (never the 1-em test
//    face, which inflates Latin ~2x and would report a phantom): clean to a
//    text scale of 1.5, overflowing by 4.1 px at 1.8 and by 30 px at 2.0, and
//    by the same 30 px in Arabic at 2.0. The reference card (`14.50 USD`) is
//    clean through 2.0 at 390 — its name ellipsizes instead — so the amount is
//    what decides this, not the accessibility setting. The sibling rendering of
//    this same JM-031 contract (`OrderSummaryPinnedHeader` in `live_tracking`)
//    already made its price `Flexible` with `maxLines: 1`; this one did not.
//    Read the `EN 200% text` cell of the `Longest content` matrix.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _orderSummaryScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _orderSummaryScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map reads the four that pin
/// a state with no copy of its own — see note 3 in the section prose. Dev
/// chrome, never shipped copy, so they are deliberately un-localized and
/// rendered LTR at a fixed text scale.
final class OrderSummaryScreenCaptions {
  OrderSummaryScreenCaptions._();

  /// The reference reading: an accepted order with every field populated.
  static const String loaded = 'preview · loaded · every field populated';

  /// The fetch is on the wire and nothing has come back.
  static const String coldRead = 'preview · cold read · fetch in flight';

  /// A 404 on the delivery read.
  static const String notFound = 'preview · error · NOT FOUND (404)';

  /// Offline / gateway unreachable — the same picture as [notFound].
  static const String networkFailure = 'preview · error · NETWORK (offline)';

  /// Every optional field absent, every required one defaulted.
  static const String minimalPayload = 'preview · minimal payload · 0.00 + uuid';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content · 7-digit SYP';

  /// The same content on the narrowest supported device.
  static const String compact = 'preview · loaded · 320x568 viewport';

  /// No repository, no DI — the shipped fake answers instead.
  static const String unconfiguredDi =
      'preview · unconfigured DI · FABRICATED order';
}

/// Mounts the real screen on one shared designed state, framed, captioned and
/// frozen.
///
/// `TickerMode(enabled: false)` mutes the indeterminate spinner — see note 2 in
/// the section prose. The `SizedBox` pins the device width the layout is
/// designed against; height is pinned too, but a render surface shorter than
/// [box] enforces its own, so only the width is exact in tests. The screen
/// keeps its own `Scaffold`; nothing here substitutes for it.
Widget _orderSummaryScreenHosted(
  OrderSummaryScreenDesignedState state,
  String caption, {
  Size box = _orderSummaryScreenPhoneBox,
}) {
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderSummaryScreenCaption(caption: caption),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: OrderSummaryScreen(
                deliveryId: state.deliveryId,
                repository: state.repository,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _OrderSummaryScreenCaption extends StatelessWidget {
  const _OrderSummaryScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        // latin line and the 200% card does not spend a third of the device on
        // a label.
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// CATALOG · "Loaded". The reference reading: an accepted express order with a
/// rating, a review count, an ETA and an item line, and BOTH CTAs — this route
/// is the only host that mounts both (the chat and tracking hosts each drop the
/// one that would navigate to themselves).
///
/// Matrixed, because this card is where the locale actually changes the layout:
/// Arabic mirrors the avatar/name/price row and both fact cells, and the 200%
/// cell is where a modest `14.50 USD` still costs the name most of its width.
/// This card does NOT overflow at 200% on a 390 pt frame (measured through the
/// real faces) — the name ellipsizes and the CTAs, both `Expanded`, keep their
/// halves. It is the control for `Longest content`, which does.
@JeebPreview(
  group: 'order_summary',
  name: 'Loaded · both CTAs',
  size: _orderSummaryScreenPhoneBox,
  matrix: true,
)
Widget orderSummaryScreenLoaded() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.loaded,
      OrderSummaryScreenCaptions.loaded,
    );

/// CATALOG · "Loading". Cold start: the fetch is in flight and nothing has come
/// back.
///
/// Every order summary opens here, and there is nothing on it — no copy, no
/// skeleton of the card that is coming, no timeout. `OmdsLoadingState` is
/// constructed with no `message:`, so the app-bar title is the only text on the
/// device frame.
@JeebPreview(
  group: 'order_summary',
  name: 'Loading · cold read',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenColdRead() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.coldRead,
      OrderSummaryScreenCaptions.coldRead,
    );

/// CATALOG · "Failed — Not Found". The accepted order is gone, or the deep link
/// carried an id this account cannot see.
///
/// The one thing this card does NOT say is that the order was not found. Read
/// it beside `Error · network`, which is the same card produced by a completely
/// different failure.
@JeebPreview(
  group: 'order_summary',
  name: 'Error · not found',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenNotFound() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.notFound,
      OrderSummaryScreenCaptions.notFound,
    );

/// The offline failure — the one where Retry could actually work, and the one
/// the copy could actually help with ("check your connection").
///
/// It is here as the negative control for `Error · not found`: two different
/// values of [OrderSummaryFailure] reaching the same hardcoded string, because
/// `_OrderSummaryView` never reads `state.error`. If these two cards ever stop
/// looking identical, that gap has been closed.
@JeebPreview(
  group: 'order_summary',
  name: 'Error · network',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenNetworkFailure() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.networkFailure,
      OrderSummaryScreenCaptions.networkFailure,
    );

/// The emptiest LOADED body this screen can reach: every optional field absent
/// and every required one defaulted by the parser.
///
/// This is the closest thing the screen has to an empty state, and it is not
/// presented as one. `0.00 USD` sits in the price pill as an authoritative
/// figure above "Pay cash on delivery"; the jeeber's name is the raw
/// `jeeberId`; the tier and ETA cells at least say "Pending". Every one of
/// those values comes from a `?? ` in `DioOrderSummaryRepository`, reached
/// whenever the delivery row is thin and the three best-effort enrichment reads
/// fail — all of which are swallowed by design.
@JeebPreview(
  group: 'order_summary',
  name: 'Minimal payload',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenMinimalPayload() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.minimalPayload,
      OrderSummaryScreenCaptions.minimalPayload,
    );

/// The ceiling on every axis at once: a seven-digit SYP price, a three-part
/// name, the longest tier label, a four-hour ETA, a five-digit review count and
/// a dictated run-on item summary.
///
/// Matrixed because the three cells fail differently. Arabic mirrors the header
/// row so the price pill moves to the leading edge; the 200% cell is where
/// `_PriceBlock` — a rigid `Row` child with no width ceiling and no `maxLines`
/// — starves the `Expanded` name beside it and runs off the trailing edge by
/// 30 px, in EN and in AR alike (real faces, 390 pt; the onset is between a
/// text scale of 1.5 and 1.8). Note also that the amount renders as a bare
/// `1234567.89` in BOTH locales: no thousands separator, no Arabic-Indic
/// digits, an ISO code rather than a symbol.
@JeebPreview(
  group: 'order_summary',
  name: 'Longest content',
  size: _orderSummaryScreenPhoneBox,
  matrix: true,
)
Widget orderSummaryScreenLongestContent() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.longestContent,
      OrderSummaryScreenCaptions.longestContent,
    );

/// The reference order on the narrowest viewport the app supports.
///
/// 320 pt is where the header row runs out of slack first: the avatar and the
/// price pill are both intrinsic, so every point the pill takes comes out of
/// the name, and the two CTAs have to share a line that is 70 pt narrower than
/// on the phone frame. Nothing here is pinned outside the `ListView`, so the
/// cost of the narrow frame is mostly reach rather than layout — but not
/// entirely: measured through the real faces, this ORDINARY `14.50 USD` card
/// overflows the header row by 4.7 px at a 200% text scale on 320 pt, where the
/// same card on a 390 pt frame is clean. The narrow device is the first place
/// the missing width ceiling on `_PriceBlock` costs a normal order anything.
@JeebPreview(
  group: 'order_summary',
  name: 'Compact viewport',
  size: _orderSummaryScreenCompactBox,
)
Widget orderSummaryScreenCompact() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.loaded,
      OrderSummaryScreenCaptions.compact,
      box: _orderSummaryScreenCompactBox,
    );

/// NO repository and NO DI: what a misconfigured build actually shows.
///
/// This is the one preview that does not hand the screen a fixture — it hands
/// it nothing, which is what production does. `_resolveRepository()` then falls
/// through `sl.isRegistered<OrderSummaryRepository>()` to
/// `FakeOrderSummaryRepository()`, whose built-in default answers ANY delivery
/// id with the same invented order. The card that comes back is indistinguish-
/// able from a real one, down to the cash amount the customer is told to hand
/// over. If this preview ever renders an error state instead, the fallback has
/// been replaced with something honest.
@JeebPreview(
  group: 'order_summary',
  name: 'Unconfigured DI · fabricated summary',
  size: _orderSummaryScreenPhoneBox,
)
Widget orderSummaryScreenUnconfiguredDi() => _orderSummaryScreenHosted(
      OrderSummaryScreenFixtures.unconfiguredDi,
      OrderSummaryScreenCaptions.unconfiguredDi,
    );
