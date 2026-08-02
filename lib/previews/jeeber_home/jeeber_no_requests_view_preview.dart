/// Widget previews for [JeeberNoRequestsView] — run with
/// `flutter widget-preview start`.
///
/// This is State 2 of the Jeeber dashboard: registered, availability visible,
/// feed empty. The view itself is pure composition — greeting, availability
/// card, an optional active-work disclosure, an optional inactivity banner and
/// the empty state — so everything that can go wrong here is a *stacking*
/// problem: which bands are present, and how tall they get in Arabic or at
/// 200% text. That is exactly what the [JeebPreview] matrix renders.
///
/// Every state is a plain [AvailabilityViewState] value object handed straight
/// to the widget: no cubit, no gateway, no ticker, so nothing here can reach
/// the network. The one child that *does* own a fetch —
/// [JeeberActiveDeliveriesBanner] — is given its injectable repository seam
/// filled with a local canned list, so it never resolves `sl<Dio>()`.
///
/// Two notes on coverage:
///
///  * **There is no error state to preview.** [AvailabilityLoadPhase.loadError]
///    never reaches this widget — `JeeberHomeScreen` branches on the load phase
///    *before* choosing this view, and [AvailabilityCard] reads only
///    `status`/`isToggleInFlight`. The closest thing to a failure state this
///    view can render is the in-flight toggle below.
///  * **Fixture values follow the existing suites.** The availability states
///    mirror `test/features/jeeber_home/availability_card_test.dart`; the
///    empty-feed copy ("No requests right now" / "Pull down to refresh…") is
///    the same copy `test/jeeber_feed_empty_ptr_test.dart` drives the real pull
///    gesture against.
library;

import 'package:flutter/material.dart';

import '../../features/chat/domain/accepted_conversation.dart';
import '../../features/jeeber_home/application/availability_state.dart';
import '../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart';
import '../../features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart';
import '../harness/jeeb_preview.dart';

/// Phone width. Heights vary per state because the bands stack: the quiet
/// state is a greeting + one switch row + the empty state, while the warning
/// state adds a three-line banner with a CTA on top of that.
const double _phoneWidth = 390;

/// Answers one canned list of won orders. No Dio, no DI lookup, no latency —
/// filling [JeeberActiveDeliveriesBanner.repository] is what stops the banner
/// from resolving `sl<Dio>()` and hitting `GET /requests?role=jeeber`.
class _CannedAcceptedConversations implements AcceptedConversationsRepository {
  const _CannedAcceptedConversations(this.accepted);

  final List<AcceptedConversation> accepted;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => accepted;
}

AvailabilityViewState _view(
  AvailabilityState state, {
  bool inFlight = false,
  bool warning = false,
  int deliveries = 0,
}) {
  return AvailabilityViewState(
    loadPhase: AvailabilityLoadPhase.ready,
    status: AvailabilityStatus(state: state, activeDeliveryCount: deliveries),
    isToggleInFlight: inFlight,
    warningVisible: warning,
  );
}

/// A won order as `GET /requests?role=jeeber` returns one for the banner.
///
/// [counterpartName] is nullable on purpose: the conversations list does not
/// always carry the other party's name, and a row without one falls back
/// through `title` → `displayId` → a manufactured label.
AcceptedConversation _won({
  required String requestId,
  String? counterpartName,
}) => AcceptedConversation(
  conversationId: 'conv-$requestId',
  requestId: requestId,
  counterpartName: counterpartName,
);

/// The production wiring, minus the network: `JeeberHomeScreen` always passes
/// an active-deliveries banner (it self-hides when the list is empty), so the
/// previews always pass one too — an empty list reproduces the common case
/// without changing the code path.
Widget _hosted(
  AvailabilityViewState view, {
  String? profileName = 'Rami Khoury',
  List<AcceptedConversation> accepted = const <AcceptedConversation>[],
}) {
  return JeeberNoRequestsView(
    view: view,
    profileName: profileName,
    onToggle: () {},
    onExtendActivity: () {},
    activeDeliveriesBanner: JeeberActiveDeliveriesBanner(
      repository: _CannedAcceptedConversations(accepted),
      // Without this the row's CTA falls through to `GoRouter.of(context)`,
      // and there is no router in a preview.
      onOpenChat: (_) {},
    ),
  );
}

/// The everyday State 2: online, nothing waiting.
///
/// Availability collapses to ONE compact switch row here (the full OMDS
/// section is reserved for the states that need explaining), so this is the
/// shortest the surface ever gets — greeting, one row, then the empty state.
/// Read the 200% rendering: the compact row's title is capped at two lines with
/// an ellipsis, and this is the state where that cap is doing the work.
@JeebPreview(name: 'Online · quiet feed', size: Size(_phoneWidth, 460))
Widget jeeberNoRequestsOnline() =>
    _hosted(_view(AvailabilityState.online), profileName: 'Karim Haddad');

/// Offline: the availability card expands to the full OMDS section.
///
/// Worth its own preview because the card changes *shape*, not just its copy —
/// a titled section with a switch row instead of a bare row — so the band
/// beneath the greeting grows while the empty state below it stays put. This is
/// also the only state with no name on file, which drops the greeting to the
/// generic "Welcome back" fallback.
@JeebPreview(name: 'Offline · full section', size: Size(_phoneWidth, 520))
Widget jeeberNoRequestsOffline() =>
    _hosted(_view(AvailabilityState.offline), profileName: null);

/// The system took the Jeeber offline (8h idle / server kick).
///
/// Deliberately distinguished from plain offline: it adds the
/// "Auto-offline after 8 h idle" hint under the switch title so the state never
/// reads as "you turned yourself off". Two stacked lines inside a switch tile
/// is the densest the card gets, which makes this the state most likely to
/// clip at 200% text.
@JeebPreview(
  name: 'Auto-offline · system flipped',
  size: Size(_phoneWidth, 540),
)
Widget jeeberNoRequestsAutoOffline() =>
    _hosted(_view(AvailabilityState.autoOffline));

/// 30 minutes before the 8h auto-offline fires.
///
/// The tall band: an icon+title row, a two-sentence body and an end-aligned CTA
/// inside a warning-container box, inserted between availability and the empty
/// state. Three things to check in the matrix — that the CTA stays on the
/// trailing edge when mirrored to Arabic, that the warning container keeps its
/// contrast in dark mode, and that the body does not swallow the CTA at 200%.
@JeebPreview(
  name: 'Idle warning · 30 min to auto-offline',
  size: Size(_phoneWidth, 700),
)
Widget jeeberNoRequestsIdleWarning() =>
    _hosted(_view(AvailabilityState.online, warning: true));

/// Layout ceiling: won work still open, with the longest plausible content.
///
/// S007-P1B put the jeeber's ACCEPTED orders in this view because an accepted
/// order drops off the feed — without this band the only way back into the
/// order chat was a push notification. Each row is
/// `avatar + Expanded(name) + "Open chat"`, and the CTA is NOT flexible and
/// lives in a fixed-height box, so a long counterpart name meets an
/// untruncatable button here. The greeting carries a long name for the same
/// reason. Read the AR RTL and 200% renderings: the English one stays plausible
/// long after the other two have broken.
///
/// The two rows are deliberately different shapes, because the gateway returns
/// both: the first carries a counterpart name, the second carries NOTHING the
/// row can label itself with, which is what makes its untranslated
/// `Order <id>` fallback visible in the Arabic rendering.
@JeebPreview(
  name: 'Active work · longest content',
  size: Size(_phoneWidth, 640),
)
Widget jeeberNoRequestsActiveWork() => _hosted(
  _view(AvailabilityState.online, deliveries: 2),
  profileName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
  accepted: <AcceptedConversation>[
    _won(
      requestId: 'req-23470',
      counterpartName: 'Marie-Christine Abou Jaoudé',
    ),
    _won(requestId: 'req-23471'),
  ],
);

/// `PUT /api/availability/toggle` in flight.
///
/// The switch is REPLACED by a spinner (nothing is tappable while the write is
/// out) and the status line becomes "Updating…". The interesting part is the
/// layout: the progress variant is a `Row` of a text block and a fixed-size
/// spinner box, so the text has to survive at 200% in the space the spinner
/// leaves it.
///
/// This preview never settles — the spinner is an indeterminate
/// `CircularProgressIndicator` — so its render test drives fixed pumps instead
/// of `pumpAndSettle`.
@JeebPreview(name: 'Toggle in flight', size: Size(_phoneWidth, 520))
Widget jeeberNoRequestsToggleInFlight() =>
    _hosted(_view(AvailabilityState.offline, inFlight: true));
