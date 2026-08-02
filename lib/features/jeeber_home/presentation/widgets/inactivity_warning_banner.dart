import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../chat/domain/accepted_conversation.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'jeeber_active_deliveries_banner.dart';
import 'jeeber_no_requests_view.dart';

class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({super.key, required this.onExtend});

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return Container(
      key: rootKey,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: roles.warningContainer,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(color: roles.warning),
      ),
      child: _BannerBody(onExtend: onExtend),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BannerHeader(),
        const SizedBox(height: Spacing.xSmall),
        const _BannerDescription(),
        const SizedBox(height: Spacing.small),
        _BannerCta(onExtend: onExtend),
      ],
    );
  }
}

class _BannerHeader extends StatelessWidget {
  const _BannerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.access_time, color: context.jeebRoles.onWarningContainer),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            l10n.availabilityInactivityWarningTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.jeebRoles.onWarningContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerDescription extends StatelessWidget {
  const _BannerDescription();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityInactivityWarningBody,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: context.jeebRoles.onWarningContainer,
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        identifier: 'availability_inactivity_extend_cta',
        container: true,
        button: true,
        child: OmdsPrimaryButton(
          key: InactivityWarningBanner.ctaKey,
          text: l10n.availabilityInactivityWarningCta,
          onTap: onExtend,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
final DateTime _inactivityWarningBannerLastActivityAt =
    DateTime(2026, 8, 2, 9, 30);

/// The dashboard snapshot that RAISES the banner: ready, online
AvailabilityViewState _inactivityWarningBannerWarned() => AvailabilityViewState(
      loadPhase: AvailabilityLoadPhase.ready,
      status: AvailabilityStatus(
        state: AvailabilityState.online,
        activeDeliveryCount: 0,
        lastActivityAt: _inactivityWarningBannerLastActivityAt,
      ),
      warningVisible: true,
    );

/// Canned stand-in for `AcceptedConversationsRepository`. Retur
class _InactivityWarningBannerCannedConversations
    implements AcceptedConversationsRepository {
  const _InactivityWarningBannerCannedConversations(this._rows);

  final List<AcceptedConversation> _rows;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => _rows;
}

/// The banner in its production composition, at an optional dev
Widget _inactivityWarningBannerDashboard({
  required String profileName,
  Widget? activeDeliveriesBanner,
  double? width,
  double? height,
}) {
  final Widget body = JeeberNoRequestsView(
    view: _inactivityWarningBannerWarned(),
    profileName: profileName,
    activeDeliveriesBanner: activeDeliveriesBanner,
    onToggle: () {},
    onExtendActivity: () {},
  );
  if (width == null && height == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, height: height, child: body),
  );
}

/// The bare card, exactly as `_NoRequestsColumn` emits it — `In
@JeebPreview(group: 'jeeber_home', name: 'Banner alone', size: Size(390, 320))
Widget inactivityWarningBannerAlone() =>
    InactivityWarningBanner(onExtend: () {});

/// Small-phone width (320 dp), the narrowest width the app ship
@JeebPreview(group: 'jeeber_home', name: 'Small phone 320dp', size: Size(320, 560))
Widget inactivityWarningBannerSmallPhone() =>
    _inactivityWarningBannerDashboard(profileName: 'Nadia', width: 320);

/// The real dashboard: greeting, the COMPACT online switch row,
@JeebPreview(group: 'jeeber_home', name: 'Online dashboard', size: Size(390, 620))
Widget inactivityWarningBannerOnlineDashboard() =>
    _inactivityWarningBannerDashboard(profileName: 'Sami');

/// The longest plausible stack: idle on the feed while holding 
@JeebPreview(group: 'jeeber_home', name: 'Under active deliveries', size: Size(390, 760))
Widget inactivityWarningBannerUnderActiveDeliveries() =>
    _inactivityWarningBannerDashboard(
      profileName: 'Rana',
      activeDeliveriesBanner: JeeberActiveDeliveriesBanner(
        repository: const _InactivityWarningBannerCannedConversations(
          <AcceptedConversation>[
            AcceptedConversation(
              conversationId: 'conv-8821',
              requestId: 'req-8821',
              displayId: 'ORD-23748',
              counterpartName: 'Kamal Hajj',
            ),
            AcceptedConversation(
              conversationId: 'conv-8822',
              requestId: 'req-8822',
              displayId: 'ORD-23751',
              counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            ),
          ],
        ),
        onOpenChat: (_) {},
      ),
    );

/// A 260 dp tall slot — landscape, split view, or a small phone
@JeebPreview(group: 'jeeber_home', name: 'Short viewport 260dp', size: Size(390, 320))
Widget inactivityWarningBannerShortViewport() =>
    _inactivityWarningBannerDashboard(
      profileName: 'Layla',
      width: 390,
      height: 260,
    );
