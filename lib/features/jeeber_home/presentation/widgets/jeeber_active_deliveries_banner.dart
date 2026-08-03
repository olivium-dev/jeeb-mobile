import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/data/dio_accepted_conversations_repository.dart';
import '../../../chat/domain/accepted_conversation.dart';

/// S007-P1B — Jeeber in-app re-entry to ACCEPTED (won) order chats.
///
/// The jeeber's request feed only lists OPEN requests; once an offer is
/// accepted the order drops off the feed and was reachable only by tapping a
/// push. This banner surfaces the jeeber's accepted orders at the top of the
/// Dashboard's no-requests state and routes each into the order chat
/// (`/chat/:id`, role-aware → "Start delivery").
///
/// Self-contained + DI-safe: it resolves an [AcceptedConversationsRepository]
/// from the injected seam or `sl<Dio>()`; when neither is available (bare
/// widget tests) it fetches nothing and renders [SizedBox.shrink]. It also
/// renders nothing while loading, on error, or when there are no accepted
/// orders — so it is purely additive and never disturbs the existing layout.
class JeeberActiveDeliveriesBanner extends StatefulWidget {
  const JeeberActiveDeliveriesBanner({
    super.key,
    this.repository,
    this.onOpenChat,
  });

  /// Test seam — when null, resolved from `sl<Dio>()` (or no-op without DI).
  final AcceptedConversationsRepository? repository;

  /// Tap handler for a row; defaults to a `chat-detail` GoRouter push.
  final void Function(String routeId)? onOpenChat;

  @override
  State<JeeberActiveDeliveriesBanner> createState() =>
      _JeeberActiveDeliveriesBannerState();
}

class _JeeberActiveDeliveriesBannerState
    extends State<JeeberActiveDeliveriesBanner> {
  List<AcceptedConversation> _accepted = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = _resolveRepository();
    if (repository == null) {
      setState(() => _loaded = true);
      return;
    }
    final accepted = await repository.fetchAccepted();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loaded = true;
    });
  }

  AcceptedConversationsRepository? _resolveRepository() {
    if (widget.repository != null) return widget.repository;
    if (sl.isRegistered<Dio>()) {
      // Jeeber-scoped: GET /requests?role=jeeber returns the jeeber's won
      // (accepted) orders, each with the conversationId for chat re-entry.
      return DioAcceptedConversationsRepository(sl<Dio>(), role: 'jeeber');
    }
    return null;
  }

  void _open(String routeId) {
    final handler = widget.onOpenChat;
    if (handler != null) {
      handler(routeId);
      return;
    }
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': routeId},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _accepted.isEmpty) return const SizedBox.shrink();
    return _ActiveDeliveriesSection(accepted: _accepted, onOpen: _open);
  }
}

/// The board's active-work band: one orange-framed row per won delivery, no
/// section heading — each card says "Active: …" itself. Kept visually
/// identical to the shell-injected banner (W-3) so this `??` fallback cannot
/// drift away from the surface the jeeber actually sees.
class _ActiveDeliveriesSection extends StatelessWidget {
  const _ActiveDeliveriesSection({required this.accepted, required this.onOpen});

  final List<AcceptedConversation> accepted;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'jeeber_active_deliveries_section',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.small,
          Spacing.xLarge,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in accepted)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
                child: _ActiveDeliveryCard(conversation: c, onOpen: onOpen),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.conversation, required this.onOpen});

  final AcceptedConversation conversation;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebAccentFrameCard(
      // The frozen id rides the card node itself: the kit applies it as an
      // explicit `Semantics(container, explicitChildNodes)` wrapper, so an
      // extra wrapper here would only add an unlabelled duplicate node.
      identifier: 'jeeber_active_delivery_card_${conversation.routeId}',
      onTap: () => onOpen(conversation.routeId),
      child: Row(
        children: [
          const _VehicleDisc(),
          const SizedBox(width: Spacing.small),
          Expanded(child: _CardTitle(text: _title(context, l10n))),
          const SizedBox(width: Spacing.small),
          _OpenChatPill(
            routeId: conversation.routeId,
            label: l10n.orderSummaryOpenChat,
            onOpen: onOpen,
          ),
        ],
      ),
    );
  }

  /// "Active: {order} → {dropoff}". The arrow is resolved from the ambient
  /// direction — a hardcoded `→` points the wrong way once the row mirrors.
  String _title(BuildContext context, AppLocalizations l10n) {
    final subject =
        conversation.title ??
        conversation.counterpartName ??
        conversation.displayId ??
        conversation.routeId;
    final destination = conversation.destinationLabel?.trim();
    final head = '${l10n.jeeberActiveLabel}: $subject';
    if (destination == null || destination.isEmpty) return head;
    final arrow = Directionality.of(context) == TextDirection.rtl ? '←' : '→';
    return '$head $arrow $destination';
  }
}

/// Ø38 accent disc — the one orange fill this card is allowed (R5).
class _VehicleDisc extends StatelessWidget {
  const _VehicleDisc();

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return Container(
      width: Sizes.threeXLarge,
      height: Sizes.threeXLarge,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: roles.accent),
      child: Icon(
        Icons.two_wheeler,
        size: Sizes.large,
        color: roles.onAccent,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.jeebText.body.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// The navy pill at the card's end edge (the board's `Manage`). Its frozen
/// identifier is what the jeeber flows tap, so it stays a distinct node inside
/// the card.
class _OpenChatPill extends StatelessWidget {
  const _OpenChatPill({
    required this.routeId,
    required this.label,
    required this.onOpen,
  });

  final String routeId;
  final String label;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    void onTap() => onOpen(routeId);
    return Semantics(
      identifier: 'jeeber_active_delivery_open_chat_$routeId',
      button: true,
      container: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: JeebSelectChip(
            key: Key('jeeber-active-open-chat-$routeId'),
            role: JeebChipRole.inlineAction,
            label: label,
            selected: true,
          ),
        ),
      ),
    );
  }
}
