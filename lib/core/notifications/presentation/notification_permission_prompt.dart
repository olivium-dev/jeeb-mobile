import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../data/push_transport.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';

/// In-app priming card for the Android 13+ `POST_NOTIFICATIONS` (and iOS
/// alert) permission.
///
/// Surfaced by [PushBannerHost] when the handler reports a non-granted
/// [PushPermissionStatus] and the host is opted in via
/// `PushBannerHost.showPermissionPrompt`. It is a *priming* affordance, not
/// the OS dialog itself: tapping **Enable** invokes [onEnable] (the host wires
/// this to `PushNotificationHandler.bootstrap()`, which surfaces the real
/// system prompt / deep-links to settings after a prior denial); **Not now**
/// invokes [onDismiss].
///
/// Why a priming step at all: Android only shows the system
/// `POST_NOTIFICATIONS` dialog once, and never again after a denial — the
/// platform guidance is to explain the value first so the grant rate stays
/// high. This card is the branded, RTL-aware, capturable explanation.
///
/// Exposed Semantics identifiers (so the device-driven demo + Maestro can
/// assert on the prompt without depending on visible copy):
///   notification_permission_prompt — the card host (boundary)
///   notif_perm_enable              — primary "Enable" action
///   notif_perm_dismiss             — "Not now" action
///
/// Copy is passed in (with locale-safe English defaults) rather than reaching
/// into the ARB, because the dedicated notification-permission strings are not
/// in the integrator-owned ARB yet; the demo asserts on identifiers, never on
/// text, so this stays copy-polish only.
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/notification_permission_prompt_preview_test.dart
// ===========================================================================
//
// Widget previews for [NotificationPermissionPrompt] — run with
// `flutter widget-preview start`.
//
// The prompt is the in-app priming card for `POST_NOTIFICATIONS`. Its only
// inputs are four strings and two callbacks — no cubit, no repository, no
// plugin — so it is network-free by construction, and its states are COPY
// states inside the box its host hands it.
//
// Copy matters more here than in most widgets, because the class carries
// English literals as defaults (`_defaultTitle`, `_defaultBody`,
// `_defaultEnable`, `_defaultDismiss`) instead of reading `AppLocalizations`
// — its own class doc explains that the dedicated strings "are not in the
// integrator-owned ARB yet". The consequence is visible in the **AR RTL
// dark** rendering of [notificationPermissionPromptDefault]: the card mirrors
// correctly and every word on it is still English.
// [notificationPermissionPromptArabicCopy] is the only state here that shows
// what an Arabic user is meant to see, and it only looks that way because the
// preview passes the strings in by hand.
//
// Host geometry comes from the annotation `size` rather than a `SizedBox` in
// the tree: the card is a full-width block, so the interesting variable is
// the device it is dropped into (390pt phone vs 320pt compact), and letting
// the canvas set that keeps the widget under review unwrapped. [_hosted]
// reproduces the placement `PushBannerHost` documents for it — pinned to the
// top, 12pt insets a side.
//
// These states extend the contract asserted in
// `test/notification_permission_prompt_test.dart` (defaults render, both
// actions fire, custom copy overrides) with the three things that test cannot
// see: long copy, long action labels, and the accessibility ceiling. They
// converge on one defect — see
// [notificationPermissionPromptLongActionLabels].

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
/// documented to appear rather than edge-to-edge.
const EdgeInsets _notificationPermissionPromptBannerSlot = EdgeInsets.fromLTRB(12, 8, 12, 0);

/// Tap counters for the two actions.
///
/// A priming card whose buttons do nothing reviews nothing, and both actions
/// are injected — a preview that wired them to `() {}` would look identical
/// whether or not the buttons were connected. The render test taps them and
/// asserts these move.
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
///
/// `CrossAxisAlignment.stretch` is load-bearing — under the loose constraints
/// an [Align] or [Center] would hand it, the card would shrink-wrap its
/// longest line and every state would be a different width for a reason that
/// has nothing to do with the state.
Widget _notificationPermissionPromptHosted(Widget prompt) => Padding(
      padding: _notificationPermissionPromptBannerSlot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[prompt],
      ),
    );

/// The shipped state: the class's own default copy, on a 390pt phone.
///
/// Built with no copy arguments at all, so this is literally what a caller
/// gets today — if the defaults change, this preview changes with them.
///
/// The rendering worth the most attention is **AR RTL dark**: the icon, title,
/// body and buttons all mirror to the trailing edge correctly (there is no
/// hardcoded `EdgeInsets.only` anywhere in the widget), and the card is still
/// entirely in English. That is the state an Arabic user sees until the four
/// strings reach the ARB. Compare [notificationPermissionPromptArabicCopy].
///
/// Worth a second look in **EN 200% text**: the action row already overflows
/// there with these labels — see
/// [notificationPermissionPromptLongActionLabels] for why.
@JeebPreview(group: 'core', name: 'Shipped defaults (390pt)', size: _notificationPermissionPromptPhoneCard)
Widget notificationPermissionPromptDefault() => _notificationPermissionPromptHosted(
      const NotificationPermissionPrompt(
        onEnable: _notificationPermissionPromptOnEnable,
        onDismiss: _notificationPermissionPromptOnDismiss,
      ),
    );

/// The second ask, after the system dialog has already been denied once.
///
/// Android shows the `POST_NOTIFICATIONS` dialog exactly once and never again
/// after a denial (see the widget's class doc), so on a re-prompt "Enable"
/// cannot summon the OS sheet — `bootstrap()` deep-links to app settings
/// instead. The copy has to change with it, and this state says whether the
/// card still reads sensibly when it does: a blunter title, a body that names
/// where the user is being sent, and a longer primary label than the default.
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
///
/// Every other state here shows English in its AR rendering because the
/// widget's defaults are English literals; this one passes the strings a
/// localized caller would pass. Its **AR RTL dark** rendering is therefore the
/// only place in this file where the prompt is reviewable as an Arabic user
/// will actually meet it: icon on the right, title reading right-to-left,
/// primary action on the left end of the action row.
///
/// Deliberately on the 320pt box — the Arabic wording runs longer than the
/// English, and the compact device is where that first costs a line.
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
///
/// The good news this records: the title sits in an [Expanded] and the body
/// sets no `maxLines`, so both degrade by wrapping and the card simply grows —
/// nothing clips and nothing ellipsizes. The card also never caps its own
/// height, which is fine in the banner slot it is documented for and is worth
/// knowing before someone drops it into a fixed-height sheet.
///
/// What to watch is the header row: the leading [Icon] is a fixed 24pt that
/// does not follow the text scaler, so as the title wraps to two lines here —
/// and four in the `EN 200% text` rendering — the icon stays pinned beside the
/// first line and the row stops reading as one unit.
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
///
/// `_PromptActions` is a bare [Row] with `mainAxisAlignment: end` holding two
/// `OmdsPrimaryButton`s. Neither is wrapped in [Flexible] or [Expanded], and
/// `OmdsPrimaryButton` sizes itself to its label (`width` defaults to null) —
/// so the row's width is the sum of both labels and nothing in it can shrink.
/// The moment that sum passes the card's content width the row overflows: a
/// yellow stripe plus "A RenderFlex overflowed by N pixels" in debug, silently
/// clipped in release.
///
/// The labels below are ordinary product copy, not a stress test, and the
/// widget offers no `maxLines`, no `Wrap`, and no stacked fallback to absorb
/// them. The render test measures the same failure with the SHIPPED labels at
/// the accessibility ceiling, which is the case that matters most: the buttons
/// grow with the text scaler and the card does not. The fix belongs to the
/// widget — let the actions flex, or stack them when they do not fit — not to
/// this preview.
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
