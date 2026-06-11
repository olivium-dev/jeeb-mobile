import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Tappable composer affordance — attach, voice, or send.
///
/// OMDS has no icon-only / circular-pill button primitive (flagged as an OMDS
/// gap), so this composes the circular send / borderless attach affordances
/// from structural primitives (`Material` + `InkWell`) wired entirely to
/// `colorScheme` roles and spacing tokens — no raw `IconButton`, no hex
/// colours, no magic dimensions. Every instance carries a Semantics
/// identifier + label for Maestro and screen readers.
class ChatComposerIconButton extends StatelessWidget {
  const ChatComposerIconButton({
    super.key,
    required this.icon,
    required this.semanticsId,
    required this.semanticsLabel,
    required this.onPressed,
    this.filled = false,
  });

  /// Glyph to render.
  final IconData icon;

  /// Stable Maestro/a11y identifier.
  final String semanticsId;

  /// Localized accessibility label.
  final String semanticsLabel;

  /// Tap handler; a null handler renders the disabled (reduced-emphasis) state.
  final VoidCallback? onPressed;

  /// When true, renders the navy circular send pill; otherwise a borderless
  /// tap target tinted with the muted on-surface variant.
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
