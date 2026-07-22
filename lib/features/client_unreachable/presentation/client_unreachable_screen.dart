import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live flow is live_tracking + tracking_noshow_sheet — see docs/project-understanding/reconciliation/orphans.md
class ClientUnreachableScreen extends StatelessWidget {
  const ClientUnreachableScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'client_unreachable_root',
      container: true,
      child: Scaffold(
        appBar: const OMDSAppBar(title: 'Client Unreachable'),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _UnreachableNoticeCard(),
              const SizedBox(height: Spacing.xLarge),
              Semantics(
                identifier: 'client_unreachable_call_again_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Try Calling Again',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.phone),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'client_unreachable_chat_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Send Chat Message',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.chat),
                  onTap: () {},
                ),
              ),
              const Spacer(),
              Semantics(
                identifier: 'client_unreachable_flag_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Flag as Unreachable',
                  backgroundColor: Theme.of(context).colorScheme.error,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreachableNoticeCard extends StatelessWidget {
  const _UnreachableNoticeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          children: [
            Icon(
              Icons.phone_disabled,
              size: Sizes.fourXLarge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              'Cannot reach the Client',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              'If the Client is not responding, you can flag them as '
              'unreachable. They will have 15 minutes to respond before the '
              'delivery is escalated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
