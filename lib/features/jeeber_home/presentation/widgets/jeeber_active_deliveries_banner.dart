import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/data/dio_accepted_conversations_repository.dart';
import '../../../chat/domain/accepted_conversation.dart';

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

class _ActiveDeliveriesSection extends StatelessWidget {
  const _ActiveDeliveriesSection({required this.accepted, required this.onOpen});

  final List<AcceptedConversation> accepted;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_active_deliveries_section',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.xSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: l10n.availabilityActiveDeliveries(accepted.length)),
            const SizedBox(height: Spacing.xSmall),
            for (final c in accepted)
              _ActiveDeliveryRow(conversation: c, onOpen: onOpen),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActiveDeliveryRow extends StatelessWidget {
  const _ActiveDeliveryRow({required this.conversation, required this.onOpen});

  final AcceptedConversation conversation;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_active_delivery_card_${conversation.routeId}',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
        child: Row(
          children: [
            _RowAvatar(initial: _initial),
            const SizedBox(width: Spacing.small),
            Expanded(child: _RowLabel(text: _title(l10n), theme: theme)),
            const SizedBox(width: Spacing.small),
            _OpenChatButton(
              routeId: conversation.routeId,
              label: l10n.orderSummaryOpenChat,
              onOpen: onOpen,
            ),
          ],
        ),
      ),
    );
  }

  String get _initial {
    final name = conversation.counterpartName ?? conversation.title ?? '?';
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  String _title(AppLocalizations l10n) {
    return conversation.counterpartName ??
        conversation.title ??
        conversation.displayId ??
        'Order ${conversation.routeId}';
  }
}

class _RowAvatar extends StatelessWidget {
  const _RowAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: initial,
      size: Sizes.threeXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _OpenChatButton extends StatelessWidget {
  const _OpenChatButton({
    required this.routeId,
    required this.label,
    required this.onOpen,
  });

  final String routeId;
  final String label;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Sizes.twoXLarge,
      child: Semantics(
        identifier: 'jeeber_active_delivery_open_chat_$routeId',
        button: true,
        child: OMDSOutlinedButton(
          key: Key('jeeber-active-open-chat-$routeId'),
          text: label,
          onTap: () => onOpen(routeId),
        ),
      ),
    );
  }
}
