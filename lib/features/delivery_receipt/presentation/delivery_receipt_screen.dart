import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_receipt_cubit.dart';
import '../application/delivery_receipt_state.dart';
import '../data/dio_delivery_receipt_repository.dart';
import '../data/fake_delivery_receipt_repository.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_receipt_screen_fixtures.dart';

/// `delivered-receipt-confirm` (JM-033) — the **customer** confirm-receipt
/// prompt, reached at `/orders/:id/receipt` (auto-advanced from order-tracking
/// when the Jeeber marks delivered, JM-032; also a deep-link target).
///
/// REWRITE of the orphaned finance-receipt screen (wrong contract: it rendered
/// goods cost / delivery fee / **Commission** in hardcoded LBP). The blueprint
/// contract is a delivery-acknowledgement prompt:
///   - "Did you receive your order?" prompt (signature root `receipt_prompt`).
///   - "Pay $N cash to `<Jeeber>`" — the cash-on-delivery line (D11), customer
///     pays the Jeeber in person.
///   - The proof-of-delivery photo the Jeeber uploaded (D3, D1m sink).
///   - Confirm  → rating screen (JM-034). Records the COD settlement +
///     transitions the delivery to `Done` (D70) before navigating.
///   - Not yet  → dispute-open-evidence (JM-060).
///   - **NO commission / platform-fee line** is shown (JM-033 AC4, D11) — the
///     10% economics live on the jeeber/wallet surfaces, never the customer's.
///
/// Owns the [DeliveryReceiptCubit] lifecycle (load + confirm). [repository] is
/// optional — production resolves [DeliveryReceiptRepository] from GetIt when
/// registered, else constructs the Dio impl over the shared `sl<Dio>()` (the
/// DI registration is integrator-owned and requested in 50_ROUTE_REQUESTS.md;
/// the screen works against `:4010` either way). Pass an explicit repository
/// only in widget tests.
///
/// Semantics identifiers exposed (EXACT, 63_W1_TEST_PLAN §2.13):
///   - `receipt_prompt`               — screen root (signature id)
///   - `receipt_cash_to_jeeber_label` — "Pay $N cash to `<Jeeber>`" (D11)
///   - `receipt_proof_photo`          — proof-of-delivery photo (D3)
///   - `receipt_confirm_cta`          — Confirm → rate-jeeber (JM-034)
///   - `receipt_not_yet_cta`          — Not yet → dispute-open-evidence (JM-060)
///   - `receipt_no_commission_line`   — NEVER rendered (AC4 negative assertion)
class DeliveryReceiptScreen extends StatelessWidget {
  const DeliveryReceiptScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  /// Optional repository override. Production leaves this null (resolves DI /
  /// constructs the Dio impl); widget tests inject a scripted instance.
  final DeliveryReceiptRepository? repository;

  DeliveryReceiptRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    // Prefer the DI-bound interface once the integrator registers it
    // (50_ROUTE_REQUESTS.md). Until then, construct the Dio impl over the
    // shared Dio so the running app reaches the real mock (:4010) — `sl<Dio>()`
    // is registered at boot. A DI-less widget/router test (no GetIt configured)
    // falls back to the in-memory fake so mount-and-find stays green without a
    // network/keystore — mirrors ClientOffersScreen's Fake fallback.
    if (sl.isRegistered<DeliveryReceiptRepository>()) {
      return sl<DeliveryReceiptRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioDeliveryReceiptRepository(sl<Dio>());
    }
    return FakeDeliveryReceiptRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<DeliveryReceiptCubit>(
      create: (_) => DeliveryReceiptCubit(
        repository: repo,
        deliveryId: deliveryId,
      )..load(),
      child: const _DeliveryReceiptView(),
    );
  }
}

class _DeliveryReceiptView extends StatelessWidget {
  const _DeliveryReceiptView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.receiptTitle,
        // Mandatory confirm/dispute path — no back affordance (the customer
        // resolves via Confirm or Not yet). Mirrors the post-delivery terminal.
        showBackButton: false,
        centerTitle: false,
      ),
      body: Semantics(
        identifier: 'receipt_prompt',
        explicitChildNodes: true,
        child: BlocConsumer<DeliveryReceiptCubit, DeliveryReceiptState>(
          listenWhen: (prev, next) =>
              prev.confirmStatus != next.confirmStatus &&
              next.confirmStatus == ReceiptConfirmStatus.succeeded,
          listener: (context, state) {
            // Side effect ONLY in the listener (40_GUARDRAILS_ARCH §3).
            // EDGE (63_W1_TEST_PLAN §3 jm-033 AC2, JM-034): receipt_confirm_cta
            // → rate-jeeber. The canonical post-delivery rating terminal is the
            // blind mutual-rating screen (`mutual-rating`, JM-034 reconciliation
            // — mutual is the compliant terminal). Client mode is the default
            // (no `?mode=jeeber`), so the customer rates the Jeeber. We replace
            // the stack so the mandatory rating cannot be backed out of (D56).
            final id = state.receipt?.deliveryId;
            if (id != null && id.isNotEmpty) {
              context.goNamed(
                'mutual-rating',
                pathParameters: <String, String>{'id': id},
              );
            }
          },
          builder: (context, state) {
            switch (state.status) {
              case DeliveryReceiptStatus.initial:
              case DeliveryReceiptStatus.loading:
                return const OmdsLoadingState();
              case DeliveryReceiptStatus.failed:
                return OmdsErrorState(
                  key: const Key('receipt-load-error'),
                  message: _errorCopy(l10n, state.error),
                  retryLabel: l10n.receiptRetryAction,
                  onRetry: () =>
                      context.read<DeliveryReceiptCubit>().refresh(),
                );
              case DeliveryReceiptStatus.loaded:
                final receipt = state.receipt;
                if (receipt == null) {
                  return OmdsErrorState(
                    message: _errorCopy(l10n, DeliveryReceiptFailure.unknown),
                    retryLabel: l10n.receiptRetryAction,
                    onRetry: () =>
                        context.read<DeliveryReceiptCubit>().refresh(),
                  );
                }
                return _LoadedBody(receipt: receipt, state: state);
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.notFound:
        return l10n.receiptErrorNotFound;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.receipt, required this.state});

  final DeliveryReceipt receipt;
  final DeliveryReceiptState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirming = state.isConfirming;
    // "Pay $N cash to `<Jeeber>`" (D11). Cash is the gross order amount paid in
    // person; the Jeeber name degrades to a generic noun when absent. The copy
    // is a localized template with positional placeholders — Maestro keys on
    // the id, not the text (i18n-safe).
    //
    // Run-22 P1-A: when the gateway omitted the amount (the live
    // `GET /v1/deliveries/{id}` drops `amount` once the delivery is `Done`),
    // the amount is UNKNOWN — degrade to the amount-less line instead of
    // fabricating "Pay $0.00".
    final jeeberLabel = receipt.jeeberName.isNotEmpty
        ? receipt.jeeberName
        : l10n.receiptJeeberFallback;
    final cashText = receipt.hasKnownAmount
        ? l10n.receiptCashToJeeber(
            MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency),
            jeeberLabel,
          )
        : l10n.receiptCashToJeeberNoAmount(jeeberLabel);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: Sizes.fiveXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.medium),
        // "Did you receive your order?" — the prompt heading.
        Text(
          l10n.receiptPromptHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.large),
        // receipt_proof_photo — the proof-of-delivery photo the Jeeber
        // uploaded (D3). Degrades to a neutral placeholder when absent.
        Semantics(
          identifier: 'receipt_proof_photo',
          image: true,
          label: l10n.receiptProofPhotoLabel,
          child: ClipRRect(
            borderRadius: OmdsBorderRadius.medium,
            child: receipt.hasProofPhoto
                ? OmdsCachedImage(
                    url: receipt.proofPhotoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: Sizes.twoXLarge,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Spacing.large),
        // receipt_cash_to_jeeber_label — "Pay $N cash to `<Jeeber>`" (D11).
        Semantics(
          identifier: 'receipt_cash_to_jeeber_label',
          child: Container(
            padding: const EdgeInsets.all(Spacing.medium),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: OmdsBorderRadius.medium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    cashText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // NOTE (JM-033 AC4, D11): there is intentionally NO commission /
        // platform-fee line on this customer-facing surface. The
        // `receipt_no_commission_line` id is a NEGATIVE assertion — the flow
        // asserts it is NOT visible, so nothing emits it. Do not add it.
        if (state.confirmStatus == ReceiptConfirmStatus.failed) ...[
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'receipt_confirm_error',
            child: Text(
              _confirmErrorCopy(l10n, state.confirmError),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.twoXLarge),
        // receipt_confirm_cta — Confirm receipt → rating (JM-034). Disabled +
        // spinner while the confirm round-trip is in flight; success fires the
        // listener navigation.
        Semantics(
          identifier: 'receipt_confirm_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptConfirmCta,
          onTap: confirming
              ? null
              : () => context.read<DeliveryReceiptCubit>().confirmReceipt(),
          child: ExcludeSemantics(
            child: OmdsLoadingButton(
              key: const Key('receipt-confirm-cta'),
              text: l10n.receiptConfirmCta,
              isLoading: confirming,
              isEnabled: !confirming,
              onTap: () =>
                  context.read<DeliveryReceiptCubit>().confirmReceipt(),
            ),
          ),
        ),
        const SizedBox(height: Spacing.small),
        // receipt_not_yet_cta — Not yet → dispute-open-evidence (JM-060). Inert
        // while a confirm is in flight so it can't tear down mid-call.
        Semantics(
          identifier: 'receipt_not_yet_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptNotYetCta,
          onTap: confirming ? null : () => _openDispute(context),
          child: ExcludeSemantics(
            child: OMDSOutlinedButton(
              key: const Key('receipt-not-yet-cta'),
              text: l10n.receiptNotYetCta,
              enabled: !confirming,
              onTap: () => _openDispute(context),
            ),
          ),
        ),
      ],
    );
  }

  /// EDGE (63_W1_TEST_PLAN §3 jm-033 AC3, JM-060): receipt_not_yet_cta →
  /// dispute-open-evidence. The registered route is `escalate`
  /// (`/orders/:id/escalate`), the blueprint `dispute-open-evidence` target
  /// (JM-060 extends `EscalateScreen`; it exposes `dispute_reason`). Push so the
  /// customer can return to the receipt prompt if they opened the dispute by
  /// mistake (the dispute is the non-terminal branch).
  void _openDispute(BuildContext context) {
    context.pushNamed(
      'escalate',
      pathParameters: <String, String>{'id': receipt.deliveryId},
    );
  }

  static String _confirmErrorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.notFound:
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
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
// Render tests: test/previews/delivery_receipt/delivery_receipt_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_deliveryReceiptScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — a scrolling prompt with a 200 pt photo slot and two
//    stacked CTAs cannot be judged in a 200 pt strip.
//
// 2. It is not merely un-tappable without a `Router` — it is un-SURVIVABLE.
//    BOTH CTAs navigate: `receipt_confirm_cta` reaches
//    `context.goNamed('mutual-rating')` through the confirm listener the moment
//    the settlement lands, and `receipt_not_yet_cta` reaches
//    `context.pushNamed('escalate')` directly. A router-less host would throw
//    on either tap — that is, on both of the only two things this screen does.
//    [_DeliveryReceiptScreenHost] supplies a local [GoRouter] whose LONE ROOT
//    page is the receipt prompt (the deep-link stack shape, nothing to pop)
//    plus stand-ins at the two real paths and names.
//
// 3. The ONLY injectable seam is `repository:`. Unlike the rating terminal
//    there is no `cubit:`/`seed:` seam — `DeliveryReceiptScreen.build` builds
//    its own [DeliveryReceiptCubit] inside `BlocProvider.create` and calls
//    `load()` on it — so every state below is reached the way production
//    reaches it: through a repository that answers, stalls, or throws. Two real
//    states are consequently NOT constructible as a first frame:
//    `ReceiptConfirmStatus.inFlight` and `.failed` exist only after a tap.
//    `Confirm rejected · 422` is the closest a preview can get: it loads
//    normally and is bound to reject, so pressing the CTA in the canvas paints
//    `receipt_confirm_error` in place. The render test performs that tap.
//
// 4. Two previews CANNOT settle, and the render test treats them separately.
//    `Loading · fetch in flight` is an indeterminate `CircularProgressIndicator`
//    (`OmdsLoadingState`), and `Loaded · proof photo + $9.00 cash` renders
//    `OmdsCachedImage`, whose shimmer placeholder animates until the CDN
//    answers — which under `flutter test` is never. Every other state below
//    deliberately carries `proofPhotoUrl: null`, which is both the commoner
//    production case and what keeps them poolable by `testPreviewsRender`.
//
// Every state is driven by a fake shared verbatim with the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/delivery_receipt_screen_fixtures.dart`).
// Nothing here builds a `DioDeliveryReceiptRepository` and nothing resolves
// GetIt — network-free by construction rather than by the guard in
// [jeebPreviewHost]. That is load-bearing here: `_resolveRepository()` falls
// back to the Dio implementation whenever `sl<Dio>()` is registered, so a
// preview that forgot `repository:` would read a live delivery.
//
// Each card carries a caption ([DeliveryReceiptScreenCaptions]) because two of
// these states put NO distinguishing copy on screen — the loading spinner has
// none at all, and `Confirm rejected` opens on an ordinary loaded body. Same
// device as `MutualRatingScreenCaptions`.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * `receipt_proof_photo` announces itself as an IMAGE labelled "Proof of
//    delivery photo" even when the jeeber uploaded none. The `Semantics` node
//    wraps the whole `ClipRRect`, so the neutral `image_not_supported`
//    placeholder inherits `image: true` and the same label: a screen-reader
//    user is told proof of delivery exists whenever this screen is open. Every
//    amount-less/photo-less preview below shows it, and the render test pins it.
//  * the 404 state is a DEAD END. `OMDSAppBar(showBackButton: false)` is
//    deliberate for the confirm/dispute fork, but `DeliveryReceiptStatus.failed`
//    replaces the whole body — including `receipt_not_yet_cta`, the escape
//    hatch — and leaves one `Retry` that re-runs the same 404. Reached as the
//    deep link it is documented to be, there is nothing to pop either.
//    `Error · 404 receipt not found` is that screen.
//  * `DeliveryReceiptCubit.acknowledgeConfirmError()` is dead code: nothing in
//    this file (or anywhere in `lib/`) calls it. The confirm banner is cleared
//    only by starting another confirm, so there is no dismiss.
//  * the amount-less degrade is honest but silent: `Pay the order amount in
//    cash to Kamal Hajj` asks the customer to hand over a sum the app declines
//    to name, with no "check with your courier" hint. That is the run-22 P1-A
//    trade — never fabricate `$0.00` — made visible rather than argued about.
//  * at 200% text the whole confirm/dispute fork leaves the first screenful.
//    The proof-photo slot is a hardcoded `height: 200` in BOTH branches, so it
//    does not shrink to make room while everything around it grows: measured on
//    the 390x844 device these previews declare, neither `receipt_confirm_cta`
//    nor `receipt_not_yet_cta` is even built, under a heading still asking a
//    yes/no question. Both are one scroll away, and the render test pins the
//    measurement. Visible in the 200% card of the matrixed states.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryReceiptScreenPhoneBox = Size(390, 844);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason two of
/// them exist — see note 4 in the section prose. Dev chrome, never shipped
/// copy, so they are deliberately un-localized and rendered LTR at a fixed
/// text scale.
final class DeliveryReceiptScreenCaptions {
  DeliveryReceiptScreenCaptions._();

  /// `$9.00` owed to Kamal Hajj, with the D3 proof photo.
  static const String loaded = 'preview · cash + proof photo';

  /// `GET /v1/deliveries/{id}` still in flight — the first frame of every
  /// receipt, and a state with no copy of its own at all.
  static const String loading = 'preview · fetch in flight';

  /// Run-22 P1-A: the gateway dropped `amount`.
  static const String amountUnknown = 'preview · amount absent from payload';

  /// Run-22 P1-A, the other half: the gateway sent `0`.
  static const String amountZero = 'preview · amount arrived as zero';

  /// No courier name on file.
  static const String noJeeberName = 'preview · jeeber name missing';

  /// The longest cash line the screen can produce.
  static const String longContent = 'preview · longest name + LBP amount';

  /// 404 — nothing to confirm, and no way off the screen.
  static const String notFound = 'preview · 404 dead end';

  /// The read never reached the server.
  static const String networkDown = 'preview · load failed, retryable';

  /// Loads fine; the confirm is rejected with a 422. Tap the CTA.
  static const String confirmRejected = 'preview · confirm will be rejected';
}

/// Stands in for the two surfaces this screen hands the customer off to:
/// `mutual-rating` (JM-034) on confirm, `escalate` (JM-060) on "Not yet".
///
/// The real destinations are DI-backed screens; here they only have to exist,
/// so a tap lands somewhere and shows WHICH fork the screen took.
class _DeliveryReceiptScreenEdgeStandIn extends StatelessWidget {
  const _DeliveryReceiptScreenEdgeStandIn({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic, not shipped copy.
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [DeliveryReceiptScreen] and captions the state.
///
/// Stateful, and both the router and the repository are built once and disposed
/// with the host: a [GoRouter] rebuilt every frame would drop the navigation
/// state `goNamed`/`pushNamed` depend on, and a repository rebuilt every frame
/// would re-arm a fake whose `confirmed` flag is supposed to be observable
/// across a tap. The receipt prompt is the LONE ROOT page — the deep-link stack
/// shape, where `showBackButton: false` really does mean no way back.
class _DeliveryReceiptScreenHost extends StatefulWidget {
  const _DeliveryReceiptScreenHost({
    required this.createRepository,
    required this.caption,
  });

  /// Called once per mount, so each canvas card gets its own fake.
  final DeliveryReceiptRepository Function() createRepository;

  /// The line painted above the device frame — see note 4 in the prose.
  final String caption;

  @override
  State<_DeliveryReceiptScreenHost> createState() =>
      _DeliveryReceiptScreenHostState();
}

class _DeliveryReceiptScreenHostState
    extends State<_DeliveryReceiptScreenHost> {
  late final DeliveryReceiptRepository _repository = widget.createRepository();

  /// The three real routes this screen touches, at their real paths and names
  /// (`app_router.dart`): the prompt itself, the rating terminal the confirm
  /// listener `goNamed`s to, and the dispute screen "Not yet" `pushNamed`s.
  late final GoRouter _router = GoRouter(
    initialLocation:
        '/orders/${DeliveryReceiptScreenFixtures.deliveryId}/receipt',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id/receipt',
        name: 'delivered-receipt',
        builder: (_, GoRouterState state) => DeliveryReceiptScreen(
          deliveryId: state.pathParameters['id'] ?? '',
          repository: _repository,
        ),
      ),
      GoRoute(
        path: '/orders/:id/mutual-rate',
        name: 'mutual-rating',
        builder: (_, _) => const _DeliveryReceiptScreenEdgeStandIn(
          label: 'mutual-rating · JM-034',
        ),
      ),
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (_, _) => const _DeliveryReceiptScreenEdgeStandIn(
          label: 'dispute-open-evidence · JM-060',
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Expanded(child: Router.withConfig(config: _router)),
      ],
    );
  }
}

Widget _deliveryReceiptScreenHosted(
  DeliveryReceiptRepository Function() createRepository,
  String caption,
) =>
    _DeliveryReceiptScreenHost(
      createRepository: createRepository,
      caption: caption,
    );

/// The happy path: `$9.00` owed to Kamal Hajj, with the proof-of-delivery photo
/// the jeeber uploaded (D3).
///
/// The one state that renders `OmdsCachedImage`, and therefore the one that
/// never settles: the shimmer placeholder animates until `cdn.jeeb.app`
/// answers. Under `flutter test` it never does, so this preview is asserted by
/// fixed pumps rather than by `pumpAndSettle` — see the dedicated group in the
/// render test. In the canvas it is also the only card that shows the photo
/// slot doing anything other than the neutral placeholder.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Loaded · proof photo + \$9.00 cash',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenLoaded() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.loaded,
      DeliveryReceiptScreenCaptions.loaded,
    );

/// `GET /v1/deliveries/{id}` still in flight — the first frame EVERY customer
/// sees, because `load()` is fired from `BlocProvider.create` on the first
/// build.
///
/// A bare centred spinner: no copy, no skeleton of the prompt, and nothing that
/// says what is being fetched. It is also the state with no text of its own at
/// all, which is why the captions exist.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Loading · fetch in flight',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenLoading() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.pending,
      DeliveryReceiptScreenCaptions.loading,
    );

/// Run-22 P1-A regression guard, made visible: the live
/// `GET /v1/deliveries/{id}` drops `amount` once the delivery reaches `Done`.
///
/// The line must degrade to `receiptCashToJeeberNoAmount` — "Pay the order
/// amount in cash to Kamal Hajj" — and must NEVER read `Pay $0.00`. If this
/// card ever shows a `$` again, `hasKnownAmount` has broken.
///
/// Matrixed because the degraded sentence is a DIFFERENT sentence in each
/// locale (Arabic reorders it around the name) and it is the longest of the two
/// templates; the 200% card is where the amount-less line and the pinned CTAs
/// compete for the fold.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Amount unknown · gateway dropped it',
  size: _deliveryReceiptScreenPhoneBox,
  matrix: true,
)
Widget deliveryReceiptScreenAmountUnknown() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.amountUnknown,
      DeliveryReceiptScreenCaptions.amountUnknown,
    );

/// The other half of the same guard: the amount arrived as `0`.
///
/// `hasKnownAmount` treats zero and negative as unknown, because the cash owed
/// on a priced delivery is never actually zero — a `0` means enrichment broke
/// upstream. Renders the identical degraded copy as `Amount unknown`, against a
/// different courier so the two cards can be told apart.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Amount zero · never fabricate \$0.00',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenAmountZero() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.amountZero,
      DeliveryReceiptScreenCaptions.amountZero,
    );

/// No courier name on file: the copy falls back to the localized generic noun
/// ("the Jeeber" / "الجيبر") rather than asking for cash to nobody.
///
/// The amount is known here, so this is the one card where the fallback noun
/// and a real `$` token share the line.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'No jeeber name · generic fallback',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNoJeeberName() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.noJeeberName,
      DeliveryReceiptScreenCaptions.noJeeberName,
    );

/// The layout ceiling for the cash-on-delivery row: the longest plausible name
/// plus the widest money token `MoneyFormat` produces
/// (`LBP 1,250,000.00` — ISO code, separators, two decimals).
///
/// Matrixed because this is where the money token's RTL handling is actually
/// testable. `MoneyFormat` wraps every amount in a Unicode LTR isolate
/// (U+2066…U+2069) precisely so `LBP 1,250,000.00` does not scramble inside an
/// Arabic sentence; the AR card is the only place that is visible. The 200%
/// card is the one that decides whether `Icon + Expanded(Text)` wraps cleanly
/// or collides.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Long jeeber name · LBP amount',
  size: _deliveryReceiptScreenPhoneBox,
  matrix: true,
)
Widget deliveryReceiptScreenLongContent() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.longContent,
      DeliveryReceiptScreenCaptions.longContent,
    );

/// 404 — the delivery id resolved no receipt, and this screen is a dead end.
///
/// `DeliveryReceiptStatus.failed` replaces the WHOLE body, so
/// `receipt_not_yet_cta` — the dispute escape hatch — goes with it. What is
/// left is a `Retry` that re-runs the same 404 against the same id, under an
/// app bar with `showBackButton: false`. On the deep-link entry this screen is
/// documented for, the router has nothing to pop either.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Error · 404 receipt not found',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNotFound() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.notFound,
      DeliveryReceiptScreenCaptions.notFound,
    );

/// The read never reached the server — the retryable failure, and the one a
/// customer standing at their own door on a bad connection actually hits.
///
/// Same shape as the 404 and a different message, which is the point: the two
/// are told apart only by copy, and only one of them can be fixed by the button
/// underneath it. The fixture keeps failing, so `Retry` behaves here the way it
/// behaves on a dead connection.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Error · network, retry keeps failing',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNetworkDown() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.networkDown,
      DeliveryReceiptScreenCaptions.networkDown,
    );

/// A receipt that loads perfectly and whose CONFIRM is rejected with the 422
/// `transition_not_allowed`.
///
/// The first frame is an ordinary loaded body (`$42.00` to Rami Saab) because
/// `ReceiptConfirmStatus.failed` is not constructible without a tap — see note
/// 3 in the section prose. TAP `receipt_confirm_cta` in the canvas: the button
/// spins, then `receipt_confirm_error` appears between the cash line and the
/// CTAs, and nothing dismisses it (`acknowledgeConfirmError()` is never called
/// by this screen). The render test performs the tap so the state is asserted
/// in CI and not only by hand.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Confirm rejected · 422 transition',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenConfirmRejected() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.confirmRejected,
      DeliveryReceiptScreenCaptions.confirmRejected,
    );
