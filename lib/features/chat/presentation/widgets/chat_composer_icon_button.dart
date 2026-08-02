import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [ChatComposerIconButton] — run with

/// Specimen box: the button itself is 44dp square, so this is a short, wide
/// box with enough height for the caption to double in the 200%-text
const Size _chatComposerIconButtonSpecimenBox = Size(340, 170);

/// The composer's live semantics ids, copied from `chat_composer.dart`.
const String _chatComposerIconButtonAttachId = 'chat_detail_attach_button';
const String _chatComposerIconButtonSendId = 'chat_detail_send_button';

/// Reserved id for the B-04 voice affordance, matching the attach/send naming.
const String _chatComposerIconButtonVoiceId = 'chat_detail_voice_button';

/// One specimen: the button under review with a caption naming its state.
/// [label] is resolved from the ambient [AppLocalizations] rather than passed
Widget _chatComposerIconButtonSpecimen({
  required String caption,
  required IconData icon,
  required String semanticsId,
  required String Function(AppLocalizations l10n) label,
  VoidCallback? onPressed,
  bool filled = false,
  bool showTapTargetGuide = false,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      final Widget button = ChatComposerIconButton(
        icon: icon,
        semanticsId: semanticsId,
        semanticsLabel: label(AppLocalizations.of(context)),
        onPressed: onPressed,
        filled: filled,
      );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showTapTargetGuide)
              SizedBox(
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.error),
                  ),
                  child: Center(child: button),
                ),
              )
            else
              button,
            const SizedBox(height: Spacing.xSmall),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The leading "+" as the composer renders it: borderless, tinted with the
/// muted on-surface variant at 87% — never a filled pill.
@JeebPreview(group: 'chat', name: 'Attach · enabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonAttach() => _chatComposerIconButtonSpecimen(
      caption: 'Attach · enabled',
      icon: Icons.add,
      semanticsId: _chatComposerIconButtonAttachId,
      label: (AppLocalizations l10n) => l10n.chatAttachA11y,
      onPressed: () {},
    );

/// The navy circular send pill with a draft ready to go.
/// `Icons.send` carries `matchTextDirection: true`, so the arrow must flip to
@JeebPreview(group: 'chat', name: 'Send · enabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonSendEnabled() => _chatComposerIconButtonSpecimen(
      caption: 'Send · enabled',
      icon: Icons.send,
      semanticsId: _chatComposerIconButtonSendId,
      label: (AppLocalizations l10n) => l10n.chatSendA11y,
      onPressed: () {},
      filled: true,
    );

/// The blank-composer state: `onPressed` is null, so the pill drops to 50%
/// primary and `Semantics.enabled` goes false.
@JeebPreview(group: 'chat', name: 'Send · disabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonSendDisabled() => _chatComposerIconButtonSpecimen(
      caption: 'Send · disabled',
      icon: Icons.send,
      semanticsId: _chatComposerIconButtonSendId,
      label: (AppLocalizations l10n) => l10n.chatSendA11y,
      filled: true,
    );

/// The combination production never builds but the widget fully supports:
/// borderless *and* disabled.
@JeebPreview(group: 'chat', name: 'Attach · disabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonAttachDisabled() => _chatComposerIconButtonSpecimen(
      caption: 'Attach · disabled',
      icon: Icons.add,
      semanticsId: _chatComposerIconButtonAttachId,
      label: (AppLocalizations l10n) => l10n.chatAttachA11y,
    );

/// The third role in the class doc — voice — which no screen currently mounts.
/// B-04 hid the mic from the composer because its press-to-record gesture was
@JeebPreview(group: 'chat', name: 'Voice · B-04 hidden role', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonVoice() => _chatComposerIconButtonSpecimen(
      caption: 'Voice · B-04 hidden role',
      icon: Icons.mic,
      semanticsId: _chatComposerIconButtonVoiceId,
      label: (AppLocalizations l10n) => l10n.chatVoiceA11y,
      onPressed: () {},
    );

/// Accessibility ceiling: the whole button measures 44dp
/// (`Spacing.small` × 2 + `Sizes.large` = 12 + 20 + 12), inside a ring drawn
@JeebPreview(group: 'chat', name: 'Tap target · 44dp in 48dp', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonTapTarget() => _chatComposerIconButtonSpecimen(
      caption: 'Tap target · 44dp in 48dp',
      icon: Icons.send,
      semanticsId: _chatComposerIconButtonSendId,
      label: (AppLocalizations l10n) => l10n.chatSendA11y,
      onPressed: () {},
      filled: true,
      showTapTargetGuide: true,
    );
