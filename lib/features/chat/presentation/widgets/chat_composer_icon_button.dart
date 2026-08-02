import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Tappable composer affordance — attach, voice, or send. Composed from Material+InkWell
/// wired to colorScheme roles (OMDS lacks icon-only circular-pill primitive). Every instance
/// carries Semantics identifier + label for Maestro and screen readers.
class ChatComposerIconButton extends StatelessWidget {
  const ChatComposerIconButton({
    super.key,
    required this.icon,
    required this.semanticsId,
    required this.semanticsLabel,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;

  // Stable Maestro/a11y identifier.
  final String semanticsId;

  final String semanticsLabel;

  // Null handler renders disabled (reduced-emphasis) state.
  final VoidCallback? onPressed;

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final primary = enabled
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: UIConstants.opacityDisabled);
    final muted = colorScheme.onSurfaceVariant.withValues(
      alpha: enabled ? UIConstants.opacityHigh : UIConstants.opacityDisabled,
    );
    final background = filled ? primary : Colors.transparent;
    final foreground = filled ? colorScheme.onPrimary : muted;
    return Semantics(
      identifier: semanticsId,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.small),
            child: Icon(icon, color: foreground, size: Sizes.large),
          ),
        ),
      ),
    );
  }
}
