/// Widget previews for [DashboardTab] — run with
/// `flutter widget-preview start`.
///
/// [DashboardTab] renders nothing itself: it is the jeeber DELIVERY tab's
/// composition root. It makes exactly two decisions and everything visible
/// follows from them —
///
///  1. **which destination the KYC gate resolves** (JM-036 / D38):
///     `none` → the register prompt, `pending`/`approved` → the feed,
///     `rejected` → a post-frame redirect to the `kyc-rejected` screen; and
///  2. **which four cubits the body gets**, all built off `sl<...>()` inside
///     `_JeeberHomeHost`: [AvailabilityCubit], [RequestFeedCubit],
///     [ActiveDeliveriesCubit] and [GreetingProfileCubit].
///
/// So the states worth previewing are the gate branches crossed with the two
/// reads that can fail underneath them, and NOT "the jeeber home with different
/// content" — that belongs to the widgets this tab hosts, which own previews of
/// their own (`jeeber_no_requests_view_preview.dart`,
/// `jeeber_feed_empty_view_preview.dart`,
/// `jeeber_active_deliveries_banner_preview.dart`).
///
/// ## How these are seeded, and why it looks unusual
///
/// This tab has NO constructor seam — `const DashboardTab()` takes only a key.
/// Its dependency seam is GetIt (`sl`), exactly as in production and exactly as
/// `test/features/shell/dashboard_tab_*_test.dart` drives it. So each preview
/// registers a full set of INERT fakes into `sl` and then builds the real,
/// unmodified tab. Nothing here can reach the network: every registered
/// implementation answers from canned data, and `Dio` is deliberately never
/// registered, which is what keeps `_JeeberHomeHost`'s two Dio fallbacks
/// (`DioActiveDeliveriesRepository`, `DioCustomerProfileRepository`) and
/// `JeeberHomeScreen`'s `DioSubmittedOffersRepository` unreachable. The guard in
/// [jeebPreviewHost] is the net, not the plan.
///
/// The registration happens in [_SeededDashboardTab.initState] rather than in
/// the preview function body, and that placement is load-bearing: `sl` is
/// process-global and the canvas mounts every preview on one screen. `initState`
/// runs in the same synchronous pass that then builds the subtree, and all four
/// providers resolve their `sl<...>()` during that pass, so each tab captures
/// ITS OWN fakes. Registering from the preview function instead would run every
/// preview's registration before the first one mounted, and the last writer
/// would win — six identical dashboards.
///
/// Each preview registers the COMPLETE set (never a partial overlay), so a state
/// can never inherit a neighbour's seed.
///
/// ## Telling the states apart
///
/// Four of the six come in look-alike pairs — two register prompts (`none` and
/// `rejected`) and two feeds (`pending` and the won-delivery state) — so each
/// seeds a DIFFERENT profile name and the greeting line is what identifies it,
/// the same discriminator `jeeber_feed_empty_view_preview.dart` uses. This
/// is not fixture decoration: the name arrives through the real
/// [GreetingProfileCubit] → `GET /users/me` lane (P0-X06) that this tab owns,
/// so a preview whose greeting is generic has lost a wire the tab is
/// responsible for.
library;

import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart';
import '../../core/session/jeeber_kyc_status_gate.dart';
import '../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import '../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../features/shell/tabs/dashboard_tab.dart';
import '../harness/jeeb_preview.dart';

/// The box the DELIVERY tab actually gets on the device this team tests on: a
/// Galaxy S22 is 360×780 logical and the shell's bottom nav takes ~80 of it.
///
/// 360 rather than the usual 390 preview width on purpose. Every overflow
/// measured below is width-driven, and 30 px of canvas hides how bad they are:
/// the Arabic feed-row break goes from 32 px at 360 to 2 px at 390, which is
/// easy to read as a rounding artefact and dismiss.
///
/// The height is declared to the canvas ONLY, never baked into the tree, so the
/// render suite (which pumps at 800×600) stays green and the clipping shows up
/// where a human is looking at it — same convention as
/// `jeeber_unregistered_view_preview.dart`.
const Size _tabBody = Size(360, 700);

/// A gate with a canned status and no [Listenable] surface — the shape of the
/// const seam gate and of every DI fake. [JeeberKycGateBuilder] builds these
/// exactly once, which is also the debug/Maestro behaviour.
class _FixedKycGate implements JeeberKycStatusGate {
  const _FixedKycGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

/// Answers `GET /users/me` with one canned name and no avatar.
///
/// The avatar is deliberately absent: [JeeberHomeGreeting] renders a supplied
/// URL through `CachedNetworkImage`, so any URL here would be a fetch the canvas
/// cannot make. Without one the greeting takes its initials-avatar branch, which
/// is the same geometry and needs no bytes.
class _CannedProfileRepository implements CustomerProfileRepository {
  const _CannedProfileRepository(this.name);

  final String name;

  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      CustomerProfileViewData(name: name);
}

/// Answers `GET /v1/deliveries?role=jeeber` with a canned list.
class _CannedActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const _CannedActiveDeliveriesRepository(this.deliveries);

  final List<ActiveDeliverySummary> deliveries;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => deliveries;
}

/// One won order in the shape the gateway returns it, taken verbatim from the
/// live envelope pinned in `test/jeeber_active_deliveries_test.dart` so the
/// canvas and that test describe the same row.
const ActiveDeliverySummary _wonDelivery = ActiveDeliverySummary(
  id: 'req-1',
  status: JeeberDeliveryStatus.inTransit,
  conversationId: 'conv-9',
  title: 'Flash delivery request',
  pickupAddress: 'Hamra',
  dropoffAddress: 'Achrafieh',
);

/// Registers one complete set of inert fakes into `sl` and builds the real
/// [DashboardTab] over them.
///
/// See the library doc for why the registration lives in `initState`.
class _SeededDashboardTab extends StatefulWidget {
  const _SeededDashboardTab({
    required this.kycStatus,
    required this.profileName,
    required this.availabilityFails,
    required this.feed,
    required this.activeDeliveries,
  });

  final JeeberKycStatus kycStatus;

  /// Name the seeded getMe answers with, or `null` to leave the profile
  /// repository unregistered — then the greeting falls back to whatever the tab
  /// threads in (`'Kamal'` on the register-prompt path, nothing on the feed
  /// path).
  final String? profileName;

  /// When true the availability gateway throws, which is the ONLY read whose
  /// failure replaces the whole tab body (with `_LoadErrorView`).
  final bool availabilityFails;

  final List<DeliveryRequest> feed;
  final List<ActiveDeliverySummary> activeDeliveries;

  @override
  State<_SeededDashboardTab> createState() => _SeededDashboardTabState();
}

class _SeededDashboardTabState extends State<_SeededDashboardTab> {
  @override
  void initState() {
    super.initState();
    _put<JeeberKycStatusGate>(_FixedKycGate(widget.kycStatus));
    _put<AvailabilityGateway>(
      InMemoryAvailabilityGateway(
        initial: AvailabilityStatus.initial.copyWith(
          state: AvailabilityState.online,
        ),
        respondWithError: widget.availabilityFails,
      ),
    );
    _put<RequestFeedRepository>(SeededRequestFeedRepository(widget.feed));
    _put<ActiveDeliveriesRepository>(
      _CannedActiveDeliveriesRepository(widget.activeDeliveries),
    );
    final String? name = widget.profileName;
    if (name == null) {
      if (sl.isRegistered<CustomerProfileRepository>()) {
        sl.unregister<CustomerProfileRepository>();
      }
    } else {
      _put<CustomerProfileRepository>(_CannedProfileRepository(name));
    }
  }

  /// Idempotent re-registration. `registerSingleton` throws on a duplicate, and
  /// the canvas mounts these previews repeatedly, so the previous instance is
  /// dropped first. None of the fakes hold a resource, so nothing needs
  /// disposing.
  void _put<T extends Object>(T instance) {
    if (sl.isRegistered<T>()) sl.unregister<T>();
    sl.registerSingleton<T>(instance);
  }

  @override
  Widget build(BuildContext context) => const DashboardTab();
}

/// One state of the tab.
///
/// Every state below seeds the jeeber ONLINE. Offline is not a DashboardTab
/// state: an offline jeeber gets `JeeberNoRequestsView` whatever the feed holds,
/// and that view owns a six-state preview of its own
/// (`jeeber_no_requests_view_preview.dart`) — previewing it again through the
/// tab would review the same widget twice and hide the tab's own branches.
Widget _hosted({
  required JeeberKycStatus kycStatus,
  String? profileName,
  bool availabilityFails = false,
  List<DeliveryRequest> feed = const <DeliveryRequest>[],
  List<ActiveDeliverySummary> activeDeliveries =
      const <ActiveDeliverySummary>[],
}) {
  return _SeededDashboardTab(
    kycStatus: kycStatus,
    profileName: profileName,
    availabilityFails: availabilityFails,
    feed: feed,
    activeDeliveries: activeDeliveries,
  );
}

/// `none` — never onboarded. The only status that should ever reach the
/// register prompt (`delivery_register_prompt`), whose CTA chains into the
/// onboarding wizard (JM-039).
///
/// Seeded with NO profile repository on purpose: this is the one path where the
/// tab still threads a literal name (`profileName: 'Kamal'` in
/// `_JeeberHomeHost`), so the preview shows what that hardcoded fallback
/// actually renders when getMe is unreachable.
///
/// Read the `EN 200% text` rendering: the hero is an `OmdsEmptyState` whose
/// `Column` cannot shrink below a fixed 200 px illustration and does not
/// scroll, so at 360×700 it **overflows by 180 px** and is silently clipped in
/// release. `AR RTL dark` does not reproduce it — "سجّل كموصِّل" still fits on
/// one line — so this is an English-only accessibility break. The defect is
/// `JeeberUnregisteredView`'s (see its own preview), reproduced here because
/// this is the box the DELIVERY tab actually hands it.
@JeebPreview(group: 'shell', name: 'KYC none · register prompt', size: _tabBody)
Widget dashboardTabRegisterPrompt() =>
    _hosted(kycStatus: JeeberKycStatus.none);

/// The W2-closer regression, at the level where it actually happened.
///
/// A registered jeeber whose KYC is still `pending` BROWSES the feed; only
/// offering is gated (`feed_make_offer_cta` → `offer_kyc_gate`, D38). The old
/// `!isApproved` collapse routed this status to `delivery_register_prompt`,
/// which made the offer-KYC gate unreachable and invited an already-registered
/// jeeber to register again. If this preview ever shows "Register as a delivery
/// man", that collapse is back.
///
/// `jeeber_kyc_gate_builder_preview.dart` covers the same decision through a
/// fixture body; this one proves the REAL tab honours it.
///
/// It doubles as the populated-feed baseline (State 3): greeting, availability
/// line, search, tab strip and one request card in a single `CustomScrollView`.
///
/// **Read the `AR RTL dark` rendering first — it shows a defect that ships
/// today.** The card footer is a `Wrap(spaceBetween)` holding a tier chip and
/// `_IncomingActions`, and `_IncomingActions` is a `Row(mainAxisSize: min)` of
/// Ignore + Offer. A `Wrap` cannot split one child, and neither button is
/// flexible or ellipsizing, so the pair claims its full intrinsic width and
/// overflows instead of wrapping. Measured on this fixture at 360 px — the
/// Galaxy S22 the team tests on:
///
/// | rendering | overflow |
/// |-----------|----------|
/// | EN, 100%  | fits     |
/// | AR, 100%  | 32 px    |
/// | EN, 200%  | 145 px   |
/// | AR, 200%  | 228 px   |
///
/// The AR 100% row is the one that matters: it is not an accessibility ceiling,
/// it is every Arabic jeeber on a 360 px phone, today. At 390 px it shrinks to
/// 2 px, which is why this preview is declared at 360 (see [_tabBody]).
@JeebPreview(group: 'shell', name: 'KYC pending · feed reachable', size: _tabBody)
Widget dashboardTabPendingKycFeed() => _hosted(
      kycStatus: JeeberKycStatus.pending,
      profileName: 'Layla',
      feed: DevJeeberFeedFixtures.incoming(),
    );

/// Approved and online, but nothing in range — the state a jeeber spends most
/// of a shift in, and the one that is easiest to mistake for a broken feed.
///
/// The tab drops out of the feed body into `JeeberNoRequestsView` the moment
/// `requests.isEmpty`, so this is a different widget tree from the populated
/// feed, not the same tree with fewer rows: availability moves into a section and
/// the empty hero appears. It is also the branch JEBV4-13 P2-6 had to wire
/// pull-to-refresh into, because the empty copy promises "Pull down to refresh".
///
/// Measured at 360×700 it is one of only two states that survives all three
/// renderings without clipping (the other is the load error) — because it is
/// the only content-bearing one that both scrolls and has no non-flexible
/// button in a `Row`.
@JeebPreview(group: 'shell', name: 'KYC approved · quiet feed', size: _tabBody)
Widget dashboardTabApprovedQuietFeed() => _hosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Nadia',
    );

/// A won order, riding above a feed that is still non-empty (PUSH-UI-REACTION).
///
/// This is the regression the 2026-07-05 fix landed for: right after the jeeber
/// offers, the offered request KEEPS the feed non-empty, so the tab renders the
/// feed branch — and the active-deliveries card used to be passed only to the
/// no-requests branch. The just-won delivery therefore surfaced nowhere until
/// the feed emptied ~95 s later. If this preview shows the feed with no
/// "Your active deliveries" disclosure above it, that regression is back.
///
/// Compare against `KYC pending · feed reachable`: same populated feed, no
/// active delivery. The KYC status differs between the two only because both
/// `pending` and `approved` land on the feed (D38) and a jeeber who has WON an
/// order is necessarily approved.
///
/// The disclosure opens COLLAPSED by design (one row, so active work cannot
/// bury the incoming-request task) — the card itself is behind "View all".
/// That one row is the second thing to look at here: "Your active deliveries"
/// is `Expanded` + 2-line ellipsis, but the "View all (1)" button beside it is
/// neither flexible nor ellipsizing, so at 200% text it claims its intrinsic
/// width and the row **overflows by 85 px** (84 px in AR) at 360 px. Same shape
/// and same fix as JEBV4-286 applied to the sibling banner.
@JeebPreview(group: 'shell', name: 'Won delivery · banner over feed', size: _tabBody)
Widget dashboardTabWonDeliveryBanner() => _hosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Zeina',
      feed: DevJeeberFeedFixtures.incoming(),
      activeDeliveries: const <ActiveDeliverySummary>[_wonDelivery],
    );

/// The one read whose failure replaces the ENTIRE tab: availability.
///
/// `GET /v1/availability` throwing takes the body down to an icon, one line and
/// a Retry button — no greeting, no feed, no active-delivery card, even though
/// the feed and the deliveries list may have loaded perfectly. On the real
/// device the usual cause is not the network but a CLIENT-scoped bearer 403ing
/// a jeeber endpoint (JEBV4-271/279), which is why `_RegisteredBody` tries to
/// self-heal by re-minting the token before the jeeber ever taps Retry.
///
/// That self-heal is invisible here on purpose: it needs a `RoleCubit` +
/// `RoleSwitchRepository`, none of which a preview provides, so the tab
/// degrades to exactly the manual-retry frame a jeeber sees when the activator
/// is not wired.
@JeebPreview(group: 'shell', name: 'Availability load failed', size: _tabBody)
Widget dashboardTabAvailabilityLoadError() => _hosted(
      kycStatus: JeeberKycStatus.approved,
      profileName: 'Karim',
      availabilityFails: true,
      feed: DevJeeberFeedFixtures.incoming(),
    );

/// `rejected` (D52/D87) — the frame before the redirect, made permanent.
///
/// In the app this destination is a post-frame `goNamed('kyc-rejected')`, and
/// the body carries `delivery_register_prompt` for the single frame before it
/// fires. A preview has no router, so `GoRouter.maybeOf` returns null, the
/// redirect no-ops, and that one frame is all you see — which is precisely the
/// point: a terminally rejected jeeber is shown a fully actionable "Register as
/// a delivery man" CTA that would walk them back into the onboarding wizard they
/// have already been rejected from. Whether that frame is short enough not to
/// matter is a judgement, and this is the only place it is visible.
///
/// Distinguished from the `none` preview by its greeting: a rejected jeeber has
/// a real getMe name on file, so the ambient profile wins over the tab's
/// hardcoded `'Kamal'`. It clips at `EN 200% text` for the same reason and by
/// the same 180 px — it is the same view.
@JeebPreview(group: 'shell', name: 'KYC rejected · pre-redirect frame', size: _tabBody)
Widget dashboardTabRejectedFrame() => _hosted(
      kycStatus: JeeberKycStatus.rejected,
      profileName: 'Nour',
    );
