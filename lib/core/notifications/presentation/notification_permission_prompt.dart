import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../data/push_transport.dart';

class NotificationPermissionPrompt extends StatelessWidget {
  const NotificationPermissionPrompt({
    super.key,
    required this.onEnable,
    required this.onDismiss,
    this.title = _defaultTitle,
    this.body = _defaultBody,
    this.enableLabel = _defaultEnable,
    this.dismissLabel = _defaultDismiss,
  });

  final VoidCallback onEnable;
  final VoidCallback onDismiss;
  final String title;
  final String body;
  final String enableLabel;
  final String dismissLabel;

  static const String _defaultTitle = 'Turn on notifications';
  static const String _defaultBody =
      'Get delivery updates and chat messages the moment they happen, even '
      'when the app is closed.';
  static const String _defaultEnable = 'Enable notifications';
  static const String _defaultDismiss = 'Not now';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'notification_permission_prompt',
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: UIConstants.elevationLarge,
        borderRadius: OmdsBorderRadius.uiMedium,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: _PromptBody(
            title: title,
            body: body,
            enableLabel: enableLabel,
            dismissLabel: dismissLabel,
            onEnable: onEnable,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }
}

class _PromptBody extends StatelessWidget {
  const _PromptBody({
    required this.title,
    required this.body,
    required this.enableLabel,
    required this.dismissLabel,
    required this.onEnable,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String enableLabel;
  final String dismissLabel;
  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PromptHeader(title: title),
        const SizedBox(height: Spacing.xSmall),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Spacing.medium),
        _PromptActions(
          enableLabel: enableLabel,
          dismissLabel: dismissLabel,
          onEnable: onEnable,
          onDismiss: onDismiss,
        ),
      ],
    );
  }
}

class _PromptHeader extends StatelessWidget {
  const _PromptHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.notifications_active_outlined, color: colorScheme.primary),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            title,
            key: const Key('notif_perm_title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _PromptActions extends StatelessWidget {
  const _PromptActions({
    required this.enableLabel,
    required this.dismissLabel,
    required this.onEnable,
    required this.onDismiss,
  });

  final String enableLabel;
  final String dismissLabel;
  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Semantics(
          identifier: 'notif_perm_dismiss',
          button: true,
          child: OmdsPrimaryButton(
            key: const Key('notif_perm_dismiss'),
            text: dismissLabel,
            variant: OmdsButtonVariant.text,
            onTap: onDismiss,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        Semantics(
          identifier: 'notif_perm_enable',
          button: true,
          child: OmdsPrimaryButton(
            key: const Key('notif_perm_enable'),
            text: enableLabel,
            onTap: onEnable,
          ),
        ),
      ],
    );
  }
}
