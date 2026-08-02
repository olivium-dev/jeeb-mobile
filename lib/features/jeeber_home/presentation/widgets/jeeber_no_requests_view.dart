import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import 'availability_card.dart';
import 'inactivity_warning_banner.dart';
import 'jeeber_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../chat/domain/accepted_conversation.dart';
import '../../domain/entities/availability_status.dart';
import 'jeeber_active_deliveries_banner.dart';

class JeeberNoRequestsView extends StatelessWidget {
  const JeeberNoRequestsView({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    this.profileName,
    this.activeDeliveriesBanner,
  });

  static const Key rootKey = Key('jeeber-no-requests-view-root');

  final AvailabilityViewState view;

  final VoidCallback onToggle;

  final VoidCallback onExtendActivity;

  final String? profileName;

  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Spacing.large),
        child: _NoRequestsColumn(
          view: view,
          profileName: profileName,
          activeDeliveriesBanner: activeDeliveriesBanner,
          onToggle: onToggle,
          onExtendActivity: onExtendActivity,
        ),
      ),
    );
  }
}

class _NoRequestsColumn extends StatelessWidget {
  const _NoRequestsColumn({
    required this.view,
    required this.profileName,
    required this.onToggle,
    required this.onExtendActivity,
    required this.activeDeliveriesBanner,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final Widget? activeDeliveriesBanner;
  final VoidCallback onToggle;
  final VoidCallback onExtendActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName),
        AvailabilityCard(view: view, onToggle: onToggle),
        ?activeDeliveriesBanner,
        if (view.warningVisible) ...[
          const SizedBox(height: Spacing.large),
          InactivityWarningBanner(onExtend: onExtendActivity),
        ],
        const SizedBox(height: Spacing.large),
        const _NoRequestsEmpty(),
      ],
    );
  }
}

class _NoRequestsEmpty extends StatelessWidget {
  const _NoRequestsEmpty();

  static const Key rootKey = Key('jeeber-no-requests-empty-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: rootKey,
      icon: Icons.inbox_outlined,
      title: l10n.requestFeedEmptyTitle,
      subtitle: l10n.requestFeedEmptySubtitle,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width. Heights vary per state because the bands stack: the quiet
/// state is a greeting + one switch row + the empty state, while the warning
const double _jeeberNoRequestsViewPhoneWidth = 390;

/// Answers one canned list of won orders. No Dio, no DI lookup, no latency —
/// filling [JeeberActiveDeliveriesBanner.repository] is what stops the banner
/// from resolving `sl<Dio>()` and hitting `GET /requests?role=jeeber`.
class _JeeberNoRequestsViewCannedConversations
    implements AcceptedConversationsRepository {
  const _JeeberNoRequestsViewCannedConversations(this.accepted);

  final List<AcceptedConversation> accepted;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => accepted;
}

AvailabilityViewState _jeeberNoRequestsViewViewState(
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
/// [counterpartName] is nullable on purpose: the conversations list does not
AcceptedConversation _jeeberNoRequestsViewWon({
  required String requestId,
  String? counterpartName,
}) => AcceptedConversation(
  conversationId: 'conv-$requestId',
  requestId: requestId,
  counterpartName: counterpartName,
);

/// The production wiring, minus the network: `JeeberHomeScreen` always passes
/// an active-deliveries banner (it self-hides when the list is empty), so the
Widget _jeeberNoRequestsViewHosted(
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
      repository: _JeeberNoRequestsViewCannedConversations(accepted),
      // Without this the row's CTA falls through to `GoRouter.of(context)`,
      onOpenChat: (_) {},
    ),
  );
}

/// The everyday State 2: online, nothing waiting.
/// Availability collapses to ONE compact switch row here (the full OMDS
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · quiet feed',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 460),
)
Widget jeeberNoRequestsViewOnline() => _jeeberNoRequestsViewHosted(
      _jeeberNoRequestsViewViewState(AvailabilityState.online),
      profileName: 'Karim Haddad',
    );

/// Offline: the availability card expands to the full OMDS section.
/// Worth its own preview because the card changes *shape*, not just its copy —
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · full section',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 520),
)
Widget jeeberNoRequestsViewOffline() => _jeeberNoRequestsViewHosted(
      _jeeberNoRequestsViewViewState(AvailabilityState.offline),
      profileName: null,
    );

/// The system took the Jeeber offline (8h idle / server kick).
/// Deliberately distinguished from plain offline: it adds the
@JeebPreview(
  group: 'jeeber_home',
  name: 'Auto-offline · system flipped',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 540),
)
Widget jeeberNoRequestsViewAutoOffline() => _jeeberNoRequestsViewHosted(
      _jeeberNoRequestsViewViewState(AvailabilityState.autoOffline),
    );

/// 30 minutes before the 8h auto-offline fires.
/// The tall band: an icon+title row, a two-sentence body and an end-aligned CTA
@JeebPreview(
  group: 'jeeber_home',
  name: 'Idle warning · 30 min to auto-offline',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 700),
)
Widget jeeberNoRequestsViewIdleWarning() => _jeeberNoRequestsViewHosted(
      _jeeberNoRequestsViewViewState(AvailabilityState.online, warning: true),
    );

/// Layout ceiling: won work still open, with the longest plausible content.
/// S007-P1B put the jeeber's ACCEPTED orders in this view because an accepted
@JeebPreview(
  group: 'jeeber_home',
  name: 'Active work · longest content',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 640),
)
Widget jeeberNoRequestsViewActiveWork() => _jeeberNoRequestsViewHosted(
  _jeeberNoRequestsViewViewState(AvailabilityState.online, deliveries: 2),
  profileName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
  accepted: <AcceptedConversation>[
    _jeeberNoRequestsViewWon(
      requestId: 'req-23470',
      counterpartName: 'Marie-Christine Abou Jaoudé',
    ),
    _jeeberNoRequestsViewWon(requestId: 'req-23471'),
  ],
);

/// `PUT /api/availability/toggle` in flight.
/// The switch is REPLACED by a spinner (nothing is tappable while the write is
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggle in flight',
  size: Size(_jeeberNoRequestsViewPhoneWidth, 520),
)
Widget jeeberNoRequestsViewToggleInFlight() => _jeeberNoRequestsViewHosted(
      _jeeberNoRequestsViewViewState(
        AvailabilityState.offline,
        inFlight: true,
      ),
    );
