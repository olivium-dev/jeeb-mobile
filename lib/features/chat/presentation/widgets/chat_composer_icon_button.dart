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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/chat_composer_icon_button_preview_test.dart
// ===========================================================================

// Widget previews for [ChatComposerIconButton] — run with
// `flutter widget-preview start`.
//
// This widget is a pure function of its five arguments: an icon, two
// semantics strings, a nullable handler, and `filled`. It owns no state, has
// no cubit and no repository, so every preview below is a plain constructor
// call — network-free by construction, not just by the guard in
// [jeebPreviewHost].
//
// Two things about the widget shape this file:
//
// * **It renders no text of its own.** A canvas of six near-identical circles
//   is unreadable, and — worse — a render test could not tell one preview
//   from another, which is the exact failure `expectedText` exists to catch.
//   So each preview is a *specimen*: the button, plus a caption naming the
//   state. The caption is preview chrome, not part of the component; it is
//   deliberately `labelSmall` / `onSurfaceVariant` so it never reads as the
//   widget's own label.
// * **The three roles it serves are not equally reachable.** Attach and send
//   are the two live call sites (`chat_composer.dart:241` and `:302`); the
//   voice role is currently hidden by B-04 but keeps its l10n key
//   (`chatVoiceA11y`) and is a supported configuration, so it is previewed
//   here — that is where re-enabling it will be reviewed.
//
// Fixture strings (`chat_detail_attach_button`, `chat_detail_send_button`,
// `chatAttachA11y`, `chatSendA11y`) are the production values read off those
// call sites, and the enabled/disabled send pair is the visual half of the
// contract `test/chat_screen_test.dart` asserts on `onPressed` alone.

/// Specimen box: the button itself is 44dp square, so this is a short, wide
/// box with enough height for the caption to double in the 200%-text
/// rendering without clipping the evidence.
const Size _chatComposerIconButtonSpecimenBox = Size(340, 170);

/// The composer's live semantics ids, copied from `chat_composer.dart`.
const String _chatComposerIconButtonAttachId = 'chat_detail_attach_button';
const String _chatComposerIconButtonSendId = 'chat_detail_send_button';

/// Reserved id for the B-04 voice affordance, matching the attach/send naming.
const String _chatComposerIconButtonVoiceId = 'chat_detail_voice_button';

/// One specimen: the button under review with a caption naming its state.
///
/// [label] is resolved from the ambient [AppLocalizations] rather than passed
/// as a literal, so the AR RTL rendering exercises the real Arabic
/// accessibility label ("إرسال الرسالة") instead of an English placeholder —
/// the semantics label is the only user-facing *string* this widget has, and
/// a preview that hardcoded it would never catch a missing translation.
///
/// When [showTapTargetGuide] is set, the button is centred inside a
/// [kMinInteractiveDimension] circle outlined in the error colour, so the gap
/// between what the widget builds and Material's minimum tap target is
/// visible rather than arithmetic.
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
///
/// This is the low-emphasis end of the widget's range, and the rendering that
/// matters is **AR RTL dark**: a borderless glyph on a dark surface at 0.87
/// alpha is where "muted" turns into "invisible".
@JeebPreview(group: 'chat', name: 'Attach · enabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonAttach() => _chatComposerIconButtonSpecimen(
      caption: 'Attach · enabled',
      icon: Icons.add,
      semanticsId: _chatComposerIconButtonAttachId,
      label: (AppLocalizations l10n) => l10n.chatAttachA11y,
      onPressed: () {},
    );

/// The navy circular send pill with a draft ready to go.
///
/// `Icons.send` carries `matchTextDirection: true`, so the arrow must flip to
/// point *left* in the AR rendering. If it still points right there, the icon
/// has been swapped for a non-directional glyph and the pill now says
/// "backwards" to every Arabic user.
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
///
/// `test/chat_screen_test.dart` pins the *handler* being null on an empty
/// composer; this is the half of that contract a unit test cannot see. Put it
/// beside [chatComposerIconButtonSendEnabled] — if the two are hard to tell
/// apart, users will keep tapping a dead pill and conclude the app is broken,
/// because opacity is the only channel carrying the difference.
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
///
/// It is the worst case in the widget's range — `onSurfaceVariant` at 50%
/// alpha on the surface, with no fill behind it to anchor the glyph. Worth a
/// preview precisely because no existing test or screen reaches it: the first
/// caller to pass `onPressed: null` without `filled: true` will ship this, and
/// this is where you find out whether it is legible.
@JeebPreview(group: 'chat', name: 'Attach · disabled', size: _chatComposerIconButtonSpecimenBox)
Widget chatComposerIconButtonAttachDisabled() => _chatComposerIconButtonSpecimen(
      caption: 'Attach · disabled',
      icon: Icons.add,
      semanticsId: _chatComposerIconButtonAttachId,
      label: (AppLocalizations l10n) => l10n.chatAttachA11y,
    );

/// The third role in the class doc — voice — which no screen currently mounts.
///
/// B-04 hid the mic from the composer because its press-to-record gesture was
/// never built, but `chatVoiceA11y` is still shipped in both locales and the
/// class doc still claims the role. This is the reference rendering for
/// re-enabling it: a mic sits in the same borderless treatment as attach, so
/// the row would carry two identical-weight glyphs on either side of the
/// field. That balance is the thing to review before the mic comes back.
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
/// at Material's [kMinInteractiveDimension] of 48dp.
///
/// The class doc explains that OMDS has no icon-only primitive, so this widget
/// composes `Material` + `InkWell` directly instead of using `IconButton`.
/// What that swap silently gave up is `IconButton`'s built-in 48dp minimum
/// tap target: the ring in this preview is the size the target should be, and
/// the ink circle inside it is the size it actually is.
///
/// The gap does not close at 200% text either — the icon size and padding are
/// fixed tokens, so the **EN 200% text** rendering shows the caption doubling
/// while the target stays 44dp. Users who need 200% text are the same users
/// who need a larger target.
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
