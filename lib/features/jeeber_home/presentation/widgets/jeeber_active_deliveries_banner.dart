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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../../core/previews/jeeb_preview.dart';

class JeeberActiveDeliveriesBanner extends StatefulWidget {
  const JeeberActiveDeliveriesBanner({
    super.key,
    this.repository,
    this.onOpenChat,
  });

  final AcceptedConversationsRepository? repository;

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
      // Orange 12% inside the frame (wave-C ruling 10) — must stay identical to
      // the shell-injected banner's rung; a pair test pins them equal.
      fill: JeebAccentFrameFill.accentTint,
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width; the height varies per state because a self-hidden banner and a
/// three-row banner differ by ~150 logical pixels.
const double _jeeberActiveDeliveriesBannerPhoneWidth = 390;

/// Answers one canned snapshot. Nothing else — no latency, no second read.
class _JeeberActiveDeliveriesBannerCannedRepository
    implements AcceptedConversationsRepository {
  const _JeeberActiveDeliveriesBannerCannedRepository(this.accepted);

  final List<AcceptedConversation> accepted;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => accepted;
}

/// Never answers, so the banner stays in its pre-load state forever.
/// A pending [Completer] is the whole implementation: no timer to leak and no
/// socket to open.
class _JeeberActiveDeliveriesBannerStalledRepository
    implements AcceptedConversationsRepository {
  const _JeeberActiveDeliveriesBannerStalledRepository();

  @override
  Future<List<AcceptedConversation>> fetchAccepted() =>
      Completer<List<AcceptedConversation>>().future;
}

Widget _jeeberActiveDeliveriesBannerHosted(
  AcceptedConversationsRepository repository,
) {
  return SingleChildScrollView(
    child: JeeberActiveDeliveriesBanner(
      repository: repository,
      // Production pushes the `chat-detail` route; a preview has no router.
      onOpenChat: (_) {},
    ),
  );
}

Widget _jeeberActiveDeliveriesBannerWithAccepted(
  List<AcceptedConversation> accepted,
) =>
    _jeeberActiveDeliveriesBannerHosted(
      _JeeberActiveDeliveriesBannerCannedRepository(accepted),
    );

/// One won order, the shape the gateway returns it in: a request id (the
/// `chat-detail` route key), a conversation id, a title and the customer's
@JeebPreview(
  group: 'jeeber_home',
  name: 'One accepted order',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerSingle() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c1',
        requestId: 'r1',
        title: 'Pharmacy run',
        counterpartName: 'Rami Haddad',
      ),
    ]);

/// Three won orders, each resolving its title from a DIFFERENT branch of the
/// row's fallback chain: counterpart name, then order title, then order ref.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Three accepted orders',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 220),
)
Widget jeeberActiveDeliveriesBannerThree() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-201',
        requestId: 'r-201',
        title: 'Grocery run',
        counterpartName: 'Nadia Khoury',
      ),
      AcceptedConversation(
        conversationId: 'c-202',
        requestId: 'r-202',
        title: 'Pharmacy run',
      ),
      AcceptedConversation(
        conversationId: 'c-203',
        requestId: 'r-203',
        displayId: 'ORD-23748',
      ),
    ]);

/// Layout ceiling: the longest plausible counterpart name. **This preview
/// currently shows a defect — read the note before "fixing" the fixture.**
@JeebPreview(
  group: 'jeeber_home',
  name: 'Longest counterpart name',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerLongName() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-long',
        requestId: 'r-long',
        counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      ),
    ]);

/// The last link of the fallback chain: a row carrying NO human label at all.
/// The live `GET /requests?role=jeeber` envelope pinned in
@JeebPreview(
  group: 'jeeber_home',
  name: 'Untitled order · id fallback',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerUntitled() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-77',
        requestId: 'f2244baa-ff25-4316-b723-c08a80cd3da9',
      ),
    ]);

/// No accepted orders — the state EVERY jeeber is in most of the time.
/// Renders `SizedBox.shrink`, deliberately: the banner is additive to the
@JeebPreview(
  group: 'jeeber_home',
  name: 'Empty · self-hidden',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 80),
)
Widget jeeberActiveDeliveriesBannerEmpty() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[]);

/// The read is still in flight — same `SizedBox.shrink`, different reason.
/// Worth its own preview because the two indistinguishable states have very
@JeebPreview(
  group: 'jeeber_home',
  name: 'Loading · self-hidden',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 80),
)
Widget jeeberActiveDeliveriesBannerLoading() =>
    _jeeberActiveDeliveriesBannerHosted(
      const _JeeberActiveDeliveriesBannerStalledRepository(),
    );
