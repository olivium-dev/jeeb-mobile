import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/kyc_rejected_cubit.dart';
import '../application/kyc_rejected_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/kyc_rejected_screen_fixtures.dart';

/// kyc-rejected (JM-043). FINAL rejection (D52/D87): there is NO resubmit CTA
/// (the divergence the JM-043 fix exists to remove — see 20_GAP_MAP). The only
/// path forward is an appeal via support; the secondary exit returns to the
/// customer profile.
///
/// Wiring (30_BACKLOG JM-043 · 42_GUARDRAILS_MOCK): the structured rejection
/// reason is fetched from `GET /v1/kyc/status` (the app-rewrite of
/// `GET /user-management/users/:userId/kyc`) through the existing [KycGateway]
/// (`DioKycGateway`, bound in `injection_container.dart`). The reason is lifted
/// from `KycStatusView`'s rejected branch and only enriches the body — a failed
/// or non-rejected fetch degrades to the generic FINAL copy, never resubmit.
///
/// Roots/ids match 65_W2_TEST_PLAN §2 JM-043 (`kyc_rejected_root` is the root;
/// `kyc_rejected_resubmit_cta` MUST stay ABSENT — assertNotVisible).
///
/// Edges OWNED here (21_NAV_PLAN §C JM-043):
///   kyc-rejected → support-ticket    (`kyc_rejected_appeal_cta`)  [JM-063, W4]
///   kyc-rejected → customer-profile  (`kyc_rejected_back_cta`)
class KycRejectedScreen extends StatelessWidget {
  const KycRejectedScreen({super.key, this.gateway});

  /// Injectable for widget tests; production resolves via DI (`sl<KycGateway>`).
  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KycRejectedCubit>(
      create: (_) => KycRejectedCubit(gateway ?? _resolveGateway())..load(),
      child: const _KycRejectedView(),
    );
  }

  /// Production resolves the real `DioKycGateway` from DI; the route-resolution
  /// gate (`test/core/router/w2_routes_resolve_test.dart`) builds this screen
  /// with a bare GetIt, so fall back to [FakeKycGateway] when unregistered
  /// (mirrors `KycWizardScreen._resolveGateway`). The Fake returns a
  /// non-rejected stored submission, so the screen simply shows the generic
  /// FINAL copy — never a crash, never a resubmit.
  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    return FakeKycGateway();
  }
}

class _KycRejectedView extends StatelessWidget {
  const _KycRejectedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.kycRejectedTitle,
          showBackButton: true,
          // JEBV4-13 P1-6: without an explicit destination, OMDSAppBar's
          // default `maybePop()` no-ops when this screen is the stack root,
          // leaving the AppBar back arrow dead. Mirror the screen's own
          // `kyc_rejected_back_cta` exit (→ customer-profile) as the
          // fallback when there's nothing to pop.
          onBackPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('customer-profile'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(Icons.error_outline_rounded,
                size: Sizes.sixXLarge, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.large),
            Text(l10n.kycRejectedHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.small),
            Text(l10n.kycRejectedBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            // Structured rejection reason from GET /v1/kyc/status (when the
            // back-office returned one). Self-spacing so the layout collapses
            // cleanly when no structured reason is present.
            const _RejectionReasonSection(),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'kyc_rejected_appeal_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.kycRejectedAppealCta,
                // EDGE → support-ticket (JM-063 AC6, D76). W4 landed the
                // SupportTicketScreen + registered `support-ticket`
                // (path `/support`, app_router.dart) so this is now an honest
                // navigation, not the AP-9 guarded coming-soon it was before the
                // route existed. Mirrors account-status / dispute-status, which
                // both `goNamed('support-ticket')` to the same `support_root`.
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'kyc_rejected_back_cta',
              button: true,
              container: true,
              child: TextButton(
                // EDGE → customer-profile.
                onPressed: () => context.goNamed('customer-profile'),
                child: Text(l10n.kycRejectedBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Renders the structured rejection cause (when the status fetch resolves to a
/// rejected submission carrying a `rejection_reason`). Silent while loading or
/// on failure so the FINAL copy is never blocked.
class _RejectionReasonSection extends StatelessWidget {
  const _RejectionReasonSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KycRejectedCubit, KycRejectedState>(
      builder: (context, state) {
        // The reason chip is a NON-BLOCKING enrichment: the FINAL copy + CTAs
        // above are the primary content and must never wait on the status
        // fetch. So while loading (or on error / no structured reason) we render
        // nothing rather than an infinite-ticker spinner — this also keeps the
        // route-resolution gate's pumpAndSettle from hanging.
        final reason = state.rejectionReason;
        if (reason == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.large),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

/// Error-container notice naming the structured rejection cause. Copy is reused
/// from `KycStatusView`'s rejected branch (the source this screen was extracted
/// from) so the localized causes stay consistent across the two surfaces.
class _RejectionReasonNotice extends StatelessWidget {
  const _RejectionReasonNotice({required this.reason});

  final KycRejectionReason reason;

  String _label(AppLocalizations l10n) {
    switch (reason) {
      case KycRejectionReason.idUnreadable:
        return l10n.kycRejectionReasonIdUnreadable;
      case KycRejectionReason.selfieMismatch:
        return l10n.kycRejectionReasonSelfieMismatch;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
        // The D20-removed `vehicleDocumentMissing` reason now folds into "other".
        return l10n.kycRejectionReasonOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_reason',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                _label(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
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
// Render tests: test/previews/kyc_rejected/kyc_rejected_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + a `ListView` body) and
//    [jeebPreviewHost] wraps every child in one as well, so each card shows two
//    nested Scaffolds. The inner one is the real surface; the outer contributes
//    a background and the `SafeArea`. That is the same nesting the Screen
//    Catalog produces. The box is therefore a real device
//    ([_kycRejectedScreenPhoneBox], 390x844, plus the 320x568
//    [_kycRejectedScreenCompactBox]) rather than the harness default 390x200 —
//    a scrolling error column with two stacked CTAs cannot be judged in a 200 pt
//    strip, and where the fold falls IS the finding on the compact card. The
//    width is pinned in the TREE as well as in `size:`, so the
//    render tests measure the same phone instead of the 800 pt test surface.
//
// 2. Every affordance on this screen navigates: `kyc_rejected_appeal_cta`
//    (`goNamed('support-ticket')`), `kyc_rejected_back_cta`
//    (`goNamed('customer-profile')`) and the AppBar arrow, whose JEBV4-13 P1-6
//    fallback is `context.canPop() ? context.pop() : goNamed('customer-profile')`.
//    All three are GoRouter extensions, so they throw WHEN TAPPED unless a
//    `Router` sits above the screen — which neither the canvas host nor the
//    render harness provides. (The screen paints fine without one; only the taps
//    die, which is the worst version of this: a canvas that looks right and is
//    dead to the touch.) [_KycRejectedScreenHost] supplies one over a local
//    [GoRouter] whose stand-in routes catch both destinations, and its
//    `initialLocation` is this route with NOTHING beneath it — which is how
//    dashboard_tab and notifications_list_screen actually arrive here
//    (`goNamed('kyc-rejected')`, stack-replacing). So the canvas reproduces the
//    exact stack in which the arrow used to be dead.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy — see
//    [KycRejectedScreenCaptions]. Five of these nine previews have no copy of
//    their own to pin, because `_RejectionReasonSection` collapses to
//    `SizedBox.shrink()` whenever `state.rejectionReason == null`: loading,
//    failed, rejected-without-a-reason and non-rejected all render the identical
//    surface, and the compact card is an existing card at a different width. A
//    suite that pinned screen copy would pass with two previews wired to the
//    same fixture. The render test's `preview specifics` group then asserts the
//    real state behind every caption, so the caption is never the whole proof.
//
// 4. The states come from
//    `lib/devtool/catalog/fixtures/kyc_rejected_screen_fixtures.dart`, shared
//    with the Screen Catalog entry
//    (`devtool/catalog/entries/batch_05_entries.dart`), which used to own four
//    inline `FakeKycGateway(initial: KycSubmission(...))` literals. Nothing here
//    resolves DI — every state drives the shipped `gateway:` seam with a local
//    fake, so `_resolveGateway()` and its `sl<KycGateway>()` branch are never
//    reached and these are network-free by construction rather than by the guard
//    in [jeebPreviewHost].
//
// ## What these previews exposed in the screen
//
//  * **Every structured reason tells the user to do something this screen does
//    not let them do.** The decision is FINAL and there is deliberately no
//    resubmit CTA (D52/D87 — the divergence JM-043 exists to remove), but the
//    reason copy is lifted verbatim from `KycStatusView`'s rejected branch,
//    where resubmit WAS reachable. So the body reads "This decision is final"
//    and the notice directly under it reads "Please review your details and
//    resubmit." (`other`), "Retake the selfie in better lighting."
//    (`selfieMismatch`) or "Submit a current document." (`expired`) — three of
//    the four reasons, in both EN and AR. `test/decision_violations_test.dart`
//    asserts `find.textContaining('resubmit')` finds NOTHING on this screen; it
//    passes only because it builds a bare `FakeKycGateway()`, whose stored
//    submission is `notSubmitted`, so no reason renders at all. Wire it to the
//    catalog's own `Reason — other/generic` state and the D52 guard fails. Both
//    are pinned below: [kycRejectedScreenOtherReason] renders it, and the render
//    test holds it as a KNOWN.
//  * **Four different upstream outcomes are one picture.** `load()` reaches
//    `loading`, `error`, `loaded`-with-a-reason and `loaded`-without-one, and
//    three of those four paint pixel-identically: the reason section is a
//    `SizedBox.shrink()` in all of them. A user whose status read 500s, one whom
//    the back-office rejected without writing a cause, and one whose fetch is
//    still in flight all see the same screen, and nothing on it — no spinner, no
//    retry, no diagnostic — distinguishes them. The non-blocking choice is right
//    (the FINAL copy must never wait on the fetch); having no signal at all is
//    what these three cards are for.
//  * **`KycRejectedState.submittedAt` is fetched, stored and never rendered.**
//    The cubit lifts it off the status response into state on every load and no
//    widget in this file reads it, so the screen cannot tell the user WHEN the
//    decision landed — the one fact that would let them judge whether an appeal
//    is still worth filing.
//  * **A `resubmitRequested` submission is shown as FINAL.** `load()` clears the
//    reason for any status that is not `rejected`, so the tri-state third path
//    (E19/Q-040/SM-6 — actionable, fix-and-resend, `resubmitSteps` attached)
//    renders as an appeal-only dead end with its per-slot instructions dropped.
//    The route is only supposed to be reached on a rejected decision, so this is
//    a defence-in-depth gap rather than a live bug — but the degrade goes the
//    wrong way: it turns an actionable state into a terminal one.
//    See [kycRejectedScreenResubmitRequested].
//  * **The appeal CTA is not in the tree on a compact device.** The body is a
//    `ListView`, so it does not overflow — but it also does not BUILD what is
//    past the fold. Measured with real fonts on a 320x568 device:
//    `kyc_rejected_appeal_cta` and `kyc_rejected_back_cta` are absent from the
//    element tree from 150% text upward, and come back on scroll. Nothing is
//    lost for a user (the sliver reports scrollable semantics and the scroll
//    reaches both), but 65_W2_TEST_PLAN §2 JM-043 pairs an
//    `assertNotVisible(kyc_rejected_resubmit_cta)` with presence checks on the
//    two real CTAs, and those checks are device- and text-scale-dependent:
//    green on a 390 pt phone, red on a compact one, for no change in the
//    screen. Pinned by the render test as a KNOWN.
//
// What these previews did NOT find, which is worth recording because the sibling
// screens all break here: nothing overflows. `AccountStatusScreen`,
// `DisputeStatusScreen` and the JM-062 sheet all centre a non-scrolling
// `Column`; this screen's `ListView` is why every state here is clean on a
// 320x568 device at 200% text in BOTH locales, and why there is no
// KNOWN-overflow table below.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _kycRejectedScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _kycRejectedScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they exist
/// — see note 3 in the section prose. Dev chrome, never shipped copy, so they
/// are deliberately un-localized and rendered LTR at a fixed text scale.
final class KycRejectedScreenCaptions {
  KycRejectedScreenCaptions._();

  /// Rejected with a structured cause: the ID photos could not be read.
  static const String idUnreadable = 'preview · reason · ID unreadable';

  /// Rejected with a structured cause: the selfie did not match.
  static const String selfieMismatch = 'preview · reason · selfie mismatch';

  /// Rejected with a structured cause: the document had expired.
  static const String expired = 'preview · reason · document expired';

  /// Rejected with the catch-all cause — the one that says "resubmit".
  static const String otherReason = 'preview · reason · other/generic';

  /// Rejected, no structured cause on the wire.
  static const String noStructuredReason =
      'preview · rejected · NO structured reason';

  /// `GET /v1/kyc/status` still in flight.
  static const String statusInFlight = 'preview · loading · status in flight';

  /// `GET /v1/kyc/status` threw.
  static const String statusReadFailed = 'preview · error · status read failed';

  /// A non-rejected status that still carried a reason.
  static const String resubmitRequested =
      'preview · resubmitRequested · reason dropped';

  /// The longest reason on the narrowest supported device.
  static const String compactLongest =
      'preview · longest reason · 320x568 viewport';
}

/// Mounts the real screen on one canned gateway, framed and captioned.
///
/// The `SizedBox` pins the device width the layout is designed against; height
/// is pinned too, but a render surface shorter than [box] enforces its own, so
/// only the width is exact in tests. The screen keeps its own `Scaffold`;
/// nothing here substitutes for it.
Widget _kycRejectedScreenHosted(
  KycGateway gateway,
  String caption, {
  Size box = _kycRejectedScreenPhoneBox,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _KycRejectedScreenCaption(caption: caption),
      Expanded(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: _KycRejectedScreenHost(gateway: gateway),
          ),
        ),
      ),
    ],
  );
}

/// The dev-chrome line painted above each device frame.
class _KycRejectedScreenCaption extends StatelessWidget {
  const _KycRejectedScreenCaption({required this.caption});

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

/// The two destinations this screen has, stubbed.
///
/// The real targets are `support-ticket` (JM-063, `/support`, D76) and
/// `customer-profile`; here they only have to exist so a tap lands somewhere and
/// shows which route was taken.
class _KycRejectedScreenStandIn extends StatelessWidget {
  const _KycRejectedScreenStandIn(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph.
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [KycRejectedScreen] so its three exits work.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state.
/// `Router.withConfig` is exactly what `MaterialApp.router` does internally, so
/// this adds a Router and nothing else — the ambient theme, locale and text
/// scale still come from the preview host above it.
///
/// `initialLocation` is the rejected route with nothing beneath it, which is
/// what `goNamed('kyc-rejected')` from the dashboard tab or a notification
/// produces: `context.canPop()` is false, so the AppBar arrow takes the
/// JEBV4-13 P1-6 fallback to `customer-profile` instead of no-opping.
class _KycRejectedScreenHost extends StatefulWidget {
  const _KycRejectedScreenHost({required this.gateway});

  final KycGateway gateway;

  @override
  State<_KycRejectedScreenHost> createState() => _KycRejectedScreenHostState();
}

class _KycRejectedScreenHostState extends State<_KycRejectedScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/kyc/rejected',
    routes: <RouteBase>[
      GoRoute(
        path: '/kyc/rejected',
        name: 'kyc-rejected',
        builder: (_, _) => KycRejectedScreen(gateway: widget.gateway),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) =>
            const _KycRejectedScreenStandIn('support-ticket (JM-063)'),
      ),
      GoRoute(
        path: '/customer-profile',
        name: 'customer-profile',
        builder: (_, _) =>
            const _KycRejectedScreenStandIn('customer-profile (JM-043 exit)'),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

/// The reference reading: the catalog's `Reason — ID unreadable`.
///
/// The only state where every element of the surface is present at once — the
/// error glyph, the FINAL headline and body, the structured-cause notice, and
/// both exits.
///
/// Matrixed because the notice is the one `Row` on this screen: a leading info
/// glyph and an `Expanded` sentence that AR has to mirror and 200% has to wrap.
/// It is also the only place the `errorContainer` tint at `alpha: 0.7` is read
/// against a dark surface, which the EN-light card cannot show.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · ID unreadable',
  size: _kycRejectedScreenPhoneBox,
  matrix: true,
)
Widget kycRejectedScreenIdUnreadable() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.idUnreadable(),
      KycRejectedScreenCaptions.idUnreadable,
    );

/// The catalog's `Reason — selfie mismatch`.
///
/// Read the notice copy, not the layout: "Retake the selfie in better lighting."
/// is an instruction, and this screen has no capture step to reach — see the
/// first finding in the section header.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · selfie mismatch',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenSelfieMismatch() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.selfieMismatch(),
      KycRejectedScreenCaptions.selfieMismatch,
    );

/// The catalog's `Reason — document expired`.
///
/// The shortest of the four causes, and the other instruction the user cannot
/// follow from here ("Submit a current document.").
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · document expired',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenExpired() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.expired(),
      KycRejectedScreenCaptions.expired,
    );

/// The catalog's `Reason — other/generic`, and the D52 finding made visible.
///
/// `kycRejectionReasonOther` reads "Please review your details and resubmit." on
/// a screen whose entire contract is that the decision is FINAL and that no
/// resubmit path exists (D52/D87). The AR string says the same thing
/// ("…وإعادة الإرسال"), which is why this state is matrixed rather than the
/// merely longer ones: the contradiction is in the copy, in both locales, and
/// the EN-light card alone reads like a normal reason line.
///
/// `test/decision_violations_test.dart` asserts no text on this screen contains
/// "resubmit"; it passes only because it builds a bare `FakeKycGateway()` whose
/// stored submission is `notSubmitted`, so the notice never renders. This is the
/// state that breaks that assertion, and the render test pins it as a KNOWN.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · other/generic',
  size: _kycRejectedScreenPhoneBox,
  matrix: true,
)
Widget kycRejectedScreenOtherReason() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.other(),
      KycRejectedScreenCaptions.otherReason,
    );

/// Rejected, with NO structured cause — the closest thing this screen has to an
/// empty state.
///
/// The back-office is not obliged to attach a `rejection_reason` the client can
/// map (`KycRejectionReason` is a closed enum over a server-owned taxonomy, and
/// the Dio layer folds anything it does not recognise), so this is the ordinary
/// degrade rather than a contrived one. The notice collapses to nothing and the
/// user is told only that the decision is final.
///
/// It is also the control for the second finding: this card, [kycRejectedScreenStatusInFlight]
/// and [kycRejectedScreenStatusReadFailed] are the same picture from three
/// different upstream outcomes.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Rejected · no structured reason',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenNoStructuredReason() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.rejectedWithoutReason(),
      KycRejectedScreenCaptions.noStructuredReason,
    );

/// Cold entry, held open by a status read that never lands.
///
/// `KycRejectedCubit.load()` emits `loading` from the screen's `BlocProvider`
/// `create`, and the reason section renders nothing in that phase — deliberately,
/// so the FINAL copy never waits on the fetch and the route-resolution gate's
/// `pumpAndSettle` cannot hang. What that leaves is a screen with no spinner, no
/// skeleton and no timeout: it is complete on first paint and may quietly gain a
/// notice later. Nothing schedules frames, so this card settles like any other.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Loading · status in flight',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenStatusInFlight() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.pending(),
      KycRejectedScreenCaptions.statusInFlight,
    );

/// `GET /v1/kyc/status` threw — the cubit's `error` branch.
///
/// `KycRejectedCubit` catches everything and emits `KycRejectedStatus.error`,
/// and no widget in this file reads `state.status` at all: the surface is
/// byte-identical to a successful read that carried no reason. There is no error
/// banner, no retry and no diagnostic anywhere, so a user who was rejected for a
/// nameable cause and a user whose read 500'd are told exactly the same thing.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Error · status read failed',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenStatusReadFailed() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.failing(),
      KycRejectedScreenCaptions.statusReadFailed,
    );

/// A `resubmitRequested` submission, reason and all, rendered as FINAL.
///
/// The tri-state third path (E19/Q-040/SM-6) is ACTIONABLE — the jeeber re-opens
/// the wizard and re-sends the slots in `resubmitSteps` — and the kyc-service
/// makes a reason mandatory on it, so this payload is one the wire really
/// produces. `load()` passes `clearRejectionReason: status != rejected`, so the
/// cause is dropped and the slots are never read: the card is the appeal-only
/// dead end again.
///
/// The route is only supposed to be reached on a rejected decision, so this is
/// defence-in-depth rather than a live bug — but the degrade goes the wrong way,
/// turning an actionable decision into a terminal one.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'resubmitRequested · reason dropped',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenResubmitRequested() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.resubmitRequestedWithReason(),
      KycRejectedScreenCaptions.resubmitRequested,
    );

/// The layout ceiling: the longest reason on the narrowest supported device.
///
/// There is no free server text on this screen — the cause is a closed enum, so
/// the longest plausible content IS `kycRejectionReasonIdUnreadable`, and the
/// only axis left is the viewport. Measured with real fonts on a 320x568 device
/// in EN and AR: clean at 100%, 150% and 200% text — the body is a `ListView`,
/// so the CTAs go below the fold instead of past the edge.
///
/// The cost of that is the fifth finding, and this is the card that shows it:
/// from 150% upward neither CTA is BUILT until the user scrolls, so a harness
/// that asserts `kyc_rejected_appeal_cta` is present passes on the phone box
/// above and fails on this one.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Longest reason · compact viewport',
  size: _kycRejectedScreenCompactBox,
)
Widget kycRejectedScreenCompactLongest() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.idUnreadable(),
      KycRejectedScreenCaptions.compactLongest,
      box: _kycRejectedScreenCompactBox,
    );
