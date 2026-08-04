import 'package:flutter/material.dart';

import '../../theme/jeeb_radii.dart';
import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_shadows.dart';
import '../../theme/jeeb_text_styles.dart';
import '../../widgets/jeeb/jeeb_cta_button.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';

/// The notification priming card (M6 class-3b restyle).
///
/// It shares [PushBannerHost]'s overlay slot, so it takes the same surface:
/// **opaque raised navy** rather than glass, because the content underneath is
/// arbitrary. Actions follow M0-2 ruling 3 — the affirmative act is the
/// periwinkle [JeebCtaVariant.primary] pill, never orange; orange is rationed
/// to the acts a board tile actually draws.
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'notification_permission_prompt',
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(JeebRadii.lg),
          border: Border.all(color: _semantics(context).glassBorder),
          boxShadow: JeebShadows.floatNav,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 8),
        Text(
          body,
          style: context.jeebText.body.copyWith(
            color: _semantics(context).mutedText,
          ),
        ),
        const SizedBox(height: 16),
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Periwinkle, not `primary`: under Midnight `primary` IS #D73B00, and
        // a card's header glyph labels, it does not act (M0-2 ruling 3).
        Icon(
          Icons.notifications_active_outlined,
          size: 19,
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            key: const Key('notif_perm_title'),
            style: context.jeebText.titleProminent
                .copyWith(color: colorScheme.onSurface),
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
          child: JeebCtaButton.text(
            key: const Key('notif_perm_dismiss'),
            label: dismissLabel,
            onTap: onDismiss,
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          identifier: 'notif_perm_enable',
          button: true,
          child: JeebCtaButton.primary(
            key: const Key('notif_perm_enable'),
            label: enableLabel,
            expand: false,
            onTap: onEnable,
          ),
        ),
      ],
    );
  }
}

/// Read defensively: harnesses that theme with a bare `ThemeData` must not
/// crash on a missing extension.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A 390pt phone. Tall enough for the card plus the extra lines the
/// `EN 200% text` rendering adds.
const Size _notificationPermissionPromptPhoneCard = Size(390, 280);

/// Same phone, taller box — the long-copy state needs the room, and a box that
/// clipped it would hide the thing it is here to show.
const Size _notificationPermissionPromptPhoneCardTall = Size(390, 380);

/// The narrowest device the app still supports.
const Size _notificationPermissionPromptCompactCard = Size(320, 340);

/// The insets `PushBannerHost` gives its overlay card (`left: 12, right: 12`,
/// `top: padding.top + 8`), restated so these previews sit where the prompt is
const EdgeInsets _notificationPermissionPromptBannerSlot = EdgeInsets.fromLTRB(12, 8, 12, 0);

/// Tap counters for the two actions.
/// A priming card whose buttons do nothing reviews nothing, and both actions
final Map<String, int> notificationPermissionPromptTaps = <String, int>{
  'enable': 0,
  'dismiss': 0,
};

/// Resets [notificationPermissionPromptTaps]; the counters are top-level, so
/// one test's taps would otherwise leak into the next.
void notificationPermissionPromptResetTaps() {
  notificationPermissionPromptTaps['enable'] = 0;
  notificationPermissionPromptTaps['dismiss'] = 0;
}

void _notificationPermissionPromptOnEnable() => notificationPermissionPromptTaps['enable'] =
    notificationPermissionPromptTaps['enable']! + 1;

void _notificationPermissionPromptOnDismiss() => notificationPermissionPromptTaps['dismiss'] =
    notificationPermissionPromptTaps['dismiss']! + 1;

/// Places [prompt] the way the banner host does: top of the screen, 12pt
/// insets, full remaining width.
Widget _notificationPermissionPromptHosted(Widget prompt) => Padding(
      padding: _notificationPermissionPromptBannerSlot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[prompt],
      ),
    );

/// The shipped state: the class's own default copy, on a 390pt phone.
/// Built with no copy arguments at all, so this is literally what a caller
@JeebPreview(group: 'core', name: 'Shipped defaults (390pt)', size: _notificationPermissionPromptPhoneCard)
Widget notificationPermissionPromptDefault() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
      ),
    );

/// The second ask, after the system dialog has already been denied once.
/// Android shows the `POST_NOTIFICATIONS` dialog exactly once and never again
@JeebPreview(group: 'core', name: 'After a denial (settings deep-link)', size: _notificationPermissionPromptPhoneCard)
Widget notificationPermissionPromptAfterDenial() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
        title: 'Notifications are off',
        body: 'Android only asks once. To get delivery updates you will need '
            'to turn notifications on in Settings.',
        enableLabel: 'Open settings',
      ),
    );

/// The card with real Arabic copy, on the narrowest supported device.
/// Every other state here shows English in its AR rendering because the
@JeebPreview(group: 'core', name: 'Arabic copy (320pt)', size: _notificationPermissionPromptCompactCard)
Widget notificationPermissionPromptArabicCopy() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
        title: 'فعّل الإشعارات',
        body: 'استلم تحديثات التوصيل ورسائل المحادثة فور وصولها، حتى عندما '
            'يكون التطبيق مغلقاً.',
        enableLabel: 'تفعيل الإشعارات',
        dismissLabel: 'ليس الآن',
      ),
    );

/// Longest plausible content: a title that no longer fits beside the icon, and
/// a body four lines deep.
@JeebPreview(group: 'core', name: 'Long copy (wraps, card grows)', size: _notificationPermissionPromptPhoneCardTall)
Widget notificationPermissionPromptLongCopy() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
        title: 'Turn on delivery and chat notifications for this account',
        body: 'Jeeb notifies you when a jeeber offers on your request, when '
            'your delivery is picked up, when the courier is close to the '
            'door, and whenever a new chat message arrives. Without them you '
            'have to keep the app open to follow a delivery.',
      ),
    );

/// The state that breaks: two ordinary-length action labels on a compact
/// device.
@JeebPreview(group: 'core', name: 'Long action labels (row overflows)', size: _notificationPermissionPromptCompactCard)
Widget notificationPermissionPromptLongActionLabels() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
        title: 'Stay in the loop',
        body: 'Delivery updates and chat messages, the moment they happen.',
        enableLabel: 'Enable notifications now',
        dismissLabel: 'Maybe later',
      ),
    );
