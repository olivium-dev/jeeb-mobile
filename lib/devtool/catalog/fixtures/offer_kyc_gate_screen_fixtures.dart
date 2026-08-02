// Shared dev-only fixtures for `OfferKycGateScreen` (JM-044, D38/D67).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_07_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart`.
//
// The catalog owned a one-line private helper
// (`_offerKycGate(KycStatus) => OfferKycGateScreen(gateway: FakeKycGateway(...))`)
// driving three states — Not Submitted / Pending / Rejected. It could not reach
// the other three the cubit can actually emit: `resubmitRequested` (the E19
// tri-state `_GateStatusLine` has a branch for), the LOADING phase, and the
// ERROR phase, because `FakeKycGateway.fetchStatus` always resolves and never
// throws. The gateways below add those, and both surfaces now import this file
// so the two notions of "the designed state" cannot drift.
//
// ## Everything here is local
//
// `OfferKycGateScreen` takes a `gateway:` seam and only falls through to
// `sl<KycGateway>()` when it is null, so neither surface ever constructs the
// Dio-backed gateway — network-free by construction, not merely by the
// `CatalogNetworkGuard` both hosts install.
//
// ## Why there is a window, and why the window is pinned HERE
//
// Three of this screen's six reachable states render byte-identical pixels:
// `_GateStatusLine` collapses to `SizedBox.shrink()` for LOADING, for ERROR and
// for a `ready` read of `notSubmitted`/`approved`, so four of the six states
// paint exactly the same five ARB strings. "Which state is this?" cannot be
// answered from the rendered copy, and the second axis — how much room the
// composition has — carries as much of the risk as the data does (the body copy
// is three long centered sentences, and the compact + 200% reading is where it
// stops fitting).
//
// [OfferKycGateScreenPreviewHost] therefore pins the frame itself (a
// `MediaQuery` override plus a `SizedBox`) and paints a caption naming the
// fixture. The frame has to be pinned by the fixture rather than left to the
// canvas `size:`, because the render tests in `test/previews/` pump onto a fixed
// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
// measured at 800 x 600 and every window would silently collapse into the same
// rendering. The caption is what lets a render test tell two otherwise
// byte-identical states apart — the same device the
// `notification_preferences_screen` fixtures use for the same reason.
//
// ## Why the host owns a Router
//
// Every affordance on this screen navigates, and all three go through go_router
// extensions that THROW when no `Router` is in scope:
// `context.goNamed('kyc-status')`, `context.goNamed('delivery-register-prompt')`
// and `_popToDeliveryTab`'s `context.canPop()` / `context.go('/')` (which the
// app-bar arrow shares, per the JEBV4-13 P1-6 fix). None of them runs during
// `build`, so the screen PAINTS fine without a router and then dies the moment
// anyone touches it: a canvas that looks right and is dead to the tap.
//
// The stack the host seeds is the PRODUCTION one. `jeeber_feed_tab_view` reaches
// this screen with `goNamed('offer-kyc-gate')` — a stack-REPLACING navigation —
// so the gate is the lone page, `canPop()` is false, and both back affordances
// take the `context.go('/')` branch. `AppRouter.backFallbacks['offer-kyc-gate']`
// is `'/'` as well, so the system back gesture agrees.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/kyc/domain/kyc_contract_template.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gateways
// ─────────────────────────────────────────────────────────────────────────────

/// Base for the canned [KycGateway]s below.
///
/// `OfferKycGateCubit` calls exactly one method — [fetchStatus] — so the other
/// four are wired to throw rather than to return plausible-looking data: if a
/// future edit makes the gate submit or read a form schema, the preview should
/// fail loudly instead of quietly succeeding against a fiction.
abstract class OfferKycGateScreenGateway implements KycGateway {
  const OfferKycGateScreenGateway();

  Never _unused(String method) => throw UnsupportedError(
        'OfferKycGateScreen never calls KycGateway.$method — see '
        'lib/devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart',
      );

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) =>
      _unused('fetchFormSchema');

  @override
  Future<KycContractTemplate> fetchContractTemplate() =>
      _unused('fetchContractTemplate');

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) =>
      _unused('signContract');

  @override
  Future<KycSubmission> submit(KycSubmission draft) => _unused('submit');
}

/// `GET /v1/kyc/status` resolves to a submission carrying [status].
///
/// Drives `OfferKycGatePhase.ready` — the only phase in which
/// `_GateStatusLine` renders anything, and then only for `pending`,
/// `rejected` and `resubmitRequested`.
///
/// `const`-constructible so the Screen Catalog can keep building
/// `const OfferKycGateScreen(gateway: ...)`.
class OfferKycGateScreenFakeGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenFakeGateway({this.status = KycStatus.notSubmitted});

  /// The live decision the gate reads back.
  final KycStatus status;

  @override
  Future<KycSubmission> fetchStatus() async => KycSubmission(status: status);
}

/// A read that never lands, holding the cubit on `OfferKycGatePhase.loading`
/// for as long as the surface is open.
///
/// The cubit emits `loading` from its constructor and leaves it only when the
/// future completes, so this is the only way to inspect the cold-start frame
/// without a real slow connection. There is no spinner to see: the gate
/// deliberately renders its exits immediately and simply omits the status line
/// (R-F — the D38 invariant must not be gated behind the network).
class OfferKycGateScreenPendingGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenPendingGateway();

  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;
}

/// The status read fails, driving `OfferKycGatePhase.error`.
///
/// `OfferKycGateCubit.loadStatus` catches EVERYTHING (`catch (_)`) and degrades
/// to "no status line", so the shape of this throw is deliberately not a typed
/// failure: no caller can tell one from another, which is itself the point of
/// the state.
class OfferKycGateScreenFailingGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenFailingGateway();

  @override
  Future<KycSubmission> fetchStatus() async =>
      throw Exception('offer-kyc-gate preview: GET /v1/kyc/status failed');
}

// ─────────────────────────────────────────────────────────────────────────────
// Window + host
// ─────────────────────────────────────────────────────────────────────────────

/// One simulated device window to render the screen in.
@immutable
class OfferKycGateScreenWindow {
  const OfferKycGateScreenWindow({
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  ///
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES
  /// padding for everything below it, so a window that wants insets has to
  /// restore them itself.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class OfferKycGateScreenWindows {
  OfferKycGateScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const OfferKycGateScreenWindow phone =
      OfferKycGateScreenWindow(size: Size(390, 844));

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class), at the accessibility ceiling. A 64 pt icon, a two-line
  /// headline, a two-sentence body, a two-line status block, a two-line note
  /// and three stacked CTAs in 568 pt — this is where the composition stops
  /// fitting.
  static const OfferKycGateScreenWindow compactLargeText =
      OfferKycGateScreenWindow(size: Size(320, 568), textScale: 2);
}

/// Where `gate_back_cta` and the app-bar arrow land: the DELIVERY tab feed.
///
/// Public so the render tests can pin WHICH exit was taken. The gate is entered
/// by a stack-replacing `goNamed`, so `canPop()` is false and both affordances
/// take `context.go('/')`.
const String offerKycGateScreenFeedStandInLabel =
    'jeeber_feed_root · preview stand-in';

/// Where `gate_start_kyc_cta` lands: the KYC wizard (`kyc-status`).
const String offerKycGateScreenKycStandInLabel =
    'kyc_wizard_root · preview stand-in';

/// Where `gate_register_link` lands: the standalone register prompt (the W2
/// RD-1 fix — a pop-back would have re-resolved the DELIVERY tab and landed on
/// the feed instead).
const String offerKycGateScreenRegisterStandInLabel =
    'delivery_register_prompt · preview stand-in';

/// A minimal, obviously-fake destination so a tap on one of the gate's three
/// exits lands somewhere legible instead of throwing or escaping into the real
/// app.
class OfferKycGateScreenStandIn extends StatelessWidget {
  const OfferKycGateScreenStandIn({required this.label, super.key});

  /// What this stand-in is playing — read by the render tests to tell the three
  /// exits apart.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: Center(
        child: Text(
          label,
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph.
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Hosts `OfferKycGateScreen` in one [OfferKycGateScreenWindow], with a real
/// `Router` above it so its three exits work.
///
/// The screen is INJECTED rather than constructed here, for two reasons: it
/// keeps this file free of a circular import back into the feature library,
/// and — the load-bearing one — `tool/preview_coverage.dart` credits a preview
/// section only when the section itself literally constructs the widget its
/// previews are named after.
///
/// Pass `window: null` (and `caption: null`) to render at the ambient window
/// with no frame and no caption — the form the Screen Catalog uses, where the
/// real device IS the frame.
///
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the stack `canPop()` reads.
/// `Router.withConfig` is exactly what `MaterialApp.router` does internally, so
/// this adds a Router and nothing else — the ambient theme, locale and text
/// scale still come from the preview host above it.
class OfferKycGateScreenPreviewHost extends StatefulWidget {
  const OfferKycGateScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.caption,
  });

  /// The screen under review — `OfferKycGateScreen(gateway: …)`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final OfferKycGateScreenWindow? window;

  /// Caption painted above the frame, and the string each preview is pinned by.
  ///
  /// Four of this screen's six states paint identical copy — `_GateStatusLine`
  /// renders nothing for loading, for error, for `notSubmitted` and for
  /// `approved` — so without a caption a render test cannot tell a preview
  /// wired to the wrong gateway from a correct one.
  final String? caption;

  @override
  State<OfferKycGateScreenPreviewHost> createState() =>
      _OfferKycGateScreenPreviewHostState();
}

class _OfferKycGateScreenPreviewHostState
    extends State<OfferKycGateScreenPreviewHost> {
  late final GoRouter _router = _buildRouter();

  /// The production stack: the gate is the LONE page.
  ///
  /// `jeeber_feed_tab_view` navigates with `goNamed('offer-kyc-gate')`, which
  /// replaces the stack, so `canPop()` is false and `_popToDeliveryTab` takes
  /// its `context.go('/')` branch. The paths mirror `app_router.dart` exactly
  /// (`/jeeber/offer-gate`, `/profile/kyc`, `/jeeber/register-prompt`) so a
  /// route rename shows up here as a dead exit rather than as a silent pass.
  GoRouter _buildRouter() => GoRouter(
        initialLocation: '/jeeber/offer-gate',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenFeedStandInLabel,
            ),
          ),
          GoRoute(
            path: '/jeeber/offer-gate',
            name: 'offer-kyc-gate',
            builder: (_, _) => widget.screen,
          ),
          GoRoute(
            path: '/profile/kyc',
            name: 'kyc-status',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenKycStandInLabel,
            ),
          ),
          GoRoute(
            path: '/jeeber/register-prompt',
            name: 'delivery-register-prompt',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenRegisterStandInLabel,
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
    final Widget routed = Router.withConfig(config: _router);
    final OfferKycGateScreenWindow? window = widget.window;
    if (window == null) return routed;

    final ThemeData theme = Theme.of(context);
    final String? caption = widget.caption;
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              caption,
              // Forced LTR: a diagnostic label, not shipped copy.
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            // ZEROES `padding` for everything below it. Restoring it here is
            // what makes an inset window mean anything at all.
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbound on both axes. The render tests pump onto 800 x 600 and the phone
    // frame is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt,
    // which is exactly the measurement these previews depend on not being
    // faked.
    //
    // The `Material` is for the Screen Catalog rather than the canvas: the
    // catalog mounts a state inside a bare `Stack` with no `Scaffold`
    // (`catalog_screen.dart` · `_CatalogPreview`), and the caption `Text` above
    // needs a `Material` ancestor to pick up a text style. Inside
    // `jeebPreviewHost`'s `Scaffold` it is a no-op.
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: framed,
        ),
      ),
    );
  }
}
