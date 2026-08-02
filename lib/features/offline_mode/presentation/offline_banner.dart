import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/offline_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs — see docs/project-understanding/reconciliation/orphans.md
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        // JEBV4-13: honour the per-episode dismissal — DISMISS used to be a
        // dead `onTap: () {}`; the cubit re-arms on the next offline episode.
        if (state.status == ConnectivityStatus.online ||
            state.bannerDismissed) {
          return const SizedBox.shrink();
        }
        return const _OfflineMaterialBanner();
      },
    );
  }
}

class _OfflineMaterialBanner extends StatelessWidget {
  const _OfflineMaterialBanner();

  @override
  Widget build(BuildContext context) {
    // Offline-with-sync-pending is a warning state (recoverable, data safe),
    // not an error -> semantic warning role.
    final roles = context.jeebRoles;
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      content: Text(
        l10n.offlineBannerMessage,
        style: TextStyle(color: roles.onWarningContainer),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: roles.onWarningContainer,
      ),
      backgroundColor: roles.warningContainer,
      actions: [
        Semantics(
          identifier: 'offline_banner_dismiss_cta',
          container: true,
          button: true,
          child: OmdsPrimaryButton(
            text: l10n.commonDismiss,
            variant: OmdsButtonVariant.text,
            textColor: roles.onWarningContainer,
            onTap: () => context.read<OfflineCubit>().dismissBanner(),
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
// Render tests: test/previews/offline_mode/offline_banner_preview_test.dart
// ===========================================================================
//
// Widget previews for [OfflineBanner] — run with
// `flutter widget-preview start`.
//
// [OfflineBanner] is a switch over [OfflineState] with only TWO visual
// outcomes: the warning [MaterialBanner], or `SizedBox.shrink()`. Two of the
// three states that reach it render the second one — online, and an episode the
// user already dismissed — and a preview of a widget that paints nothing is an
// empty card, indistinguishable from a preview that failed to build. So every
// state below is staged on [_OfflineBannerStage]: the banner where a page would
// mount it, over a caption naming the exact cubit calls that produced the
// state. When a card is "empty", the caption is what tells you it is empty ON
// PURPOSE.
//
// **How the state is seeded, and why it is network-free.** The widget reads
// [OfflineCubit] off the context via [BlocBuilder] with no constructor seam and
// no provider of its own, so each preview wraps it in a [BlocProvider] over a
// cubit driven through the same calls the app makes — `setOffline()`,
// `dismissBanner()`, `setOnline()`. [OfflineCubit] takes no repository and
// subscribes to nothing — it is a plain state holder whose setters a caller
// drives — so nothing here can reach Dio: these previews are network-free by
// construction rather than merely by the guard in [jeebPreviewHost].
//
// Driving real transitions instead of constructing an [OfflineState] directly
// is deliberate. `bannerDismissed` is reset by the online→offline TRANSITION,
// not by a setter (JEBV4-13), so a fixture that assigned the field could stage
// a combination the cubit can never actually produce — which is the one thing a
// preview must not do.
//
// The states mirror `test/offline_banner_test.dart`, which walks
// offline → dismiss → online → offline in a single pass; the previews split
// that walk into separate cards so the visual half of the contract (contrast on
// the warning container, RTL mirroring, the 200% ceiling) is reviewable.
//
// Each preview pins its own width rather than leaving it to the canvas [Size]:
// the canvas honours `size`, but the render tests pump onto an 800 × 600
// surface, and a full-bleed banner reviewed at 390 pt and asserted at 800 pt is
// two different layouts.
//
// Worth knowing while reviewing: this widget is an ORPHAN (JEBV4-227, zero
// production references — see the note above the class), so the canvas and the
// Screen Catalog are the only places it renders at all today.

/// A typical phone — the width the banner is reviewed and asserted against.
const double _offlineBannerPhoneWidth = 390;

/// Phone width, with room for the banner plus the fixture caption beneath it.
const Size _offlineBannerBannerBox = Size(_offlineBannerPhoneWidth, 200);

/// Same width, short: in the collapsed states there is nothing but the caption
/// to show, and a tall box would imply the banner left a gap behind.
const Size _offlineBannerCollapsedBox = Size(_offlineBannerPhoneWidth, 110);

/// Keyed by [caption], which is unique per preview.
///
/// Not cosmetic: [BlocProvider]'s `create` runs ONCE per element, so a render
/// test that pumps two of these previews into the same tree would keep the
/// first cubit and silently review the first state twice — the "re-armed"
/// card would show the dismissed cubit and look like a regression that is not
/// there. The key forces a fresh element, and a fresh episode, per state.
Widget _offlineBannerHosted({
  required String caption,
  required OfflineCubit Function() episode,
}) {
  return BlocProvider<OfflineCubit>(
    key: ValueKey<String>(caption),
    create: (BuildContext _) => episode(),
    child: _OfflineBannerStage(caption: caption),
  );
}

/// Mounts [OfflineBanner] the way a page does — pinned to phone width, at the
/// top of the content, with something underneath it.
///
/// The caption is preview scaffolding, not part of the widget: it spells out
/// the cubit calls that produced the state, which is the only way to tell the
/// two collapsed states apart (both render nothing) and the only way to tell
/// either of them from a preview that crashed. It is deliberately unlocalized —
/// seeing English here in the AR RTL rendering is expected, and is how a
/// reviewer separates fixture copy from the banner's own strings.
class _OfflineBannerStage extends StatelessWidget {
  const _OfflineBannerStage({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _offlineBannerPhoneWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const OfflineBanner(),
            ColoredBox(
              color: colors.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.medium),
                child: Text(
                  caption,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The state the widget exists for: the connection dropped and the user has not
/// dismissed the notice yet.
///
/// This is the matrix state, and the one card in this section worth measuring.
///
/// [MaterialBanner]'s single-action path lays the whole thing out as ONE row —
/// `cloud_off`, message, DISMISS — and [OmdsPrimaryButton] sizes to its label
/// and never shrinks, so the message is left with whatever is over. At 390 pt
/// and 1× text that is **187 of 390 pt: six wrapped lines for one sentence, a
/// 122 pt slab**. Open the **EN 200% text** rendering and it gets worse rather
/// than better — the button's label grows too, so the message column narrows to
/// **138 pt and eleven lines, a 332 pt banner**, roughly 40% of a phone screen.
/// Nothing throws: the `Expanded` absorbs the squeeze silently, which is why
/// only this card (and the guard in the render test) shows it.
///
/// The **AR RTL dark** rendering is the control that came back clean: the icon
/// moves to the trailing edge at the same 28 pt inset, and `onWarningContainer`
/// stays legible on the dark `warningContainer` tint.
@JeebPreview(
  group: 'offline_mode',
  name: 'Offline · banner shown',
  size: _offlineBannerBannerBox,
  matrix: true,
)
Widget offlineBannerOffline() => _offlineBannerHosted(
      caption: 'setOffline() · banner armed',
      episode: () => OfflineCubit()..setOffline(),
    );

/// Offline with work waiting: three edits made since the connection dropped.
///
/// It renders identically to [offlineBannerOffline], and that identity IS the
/// finding. [OfflineState.pendingSyncCount] is maintained by the cubit
/// (`enqueuePendingSync` / `syncCompleted`) and never reaches a pixel, so a user
/// with three unsent changes and a user with none read the same generic promise
/// that "changes will sync". This is the card that shows the count has nowhere
/// to appear; if someone surfaces it, this is where it lands.
@JeebPreview(
  group: 'offline_mode',
  name: 'Offline · writes queued',
  size: _offlineBannerBannerBox,
)
Widget offlineBannerPendingSync() => _offlineBannerHosted(
      caption: 'setOffline() + three queued writes',
      episode: () => OfflineCubit()
        ..setOffline()
        ..enqueuePendingSync()
        ..enqueuePendingSync()
        ..enqueuePendingSync(),
    );

/// JEBV4-13, first half: DISMISS has to actually dismiss.
///
/// The action used to be `onTap: () {}` — a dead CTA of the atlas P1 #18 class
/// — so tapping it left the banner on screen for the rest of the outage. Here
/// the cubit has recorded the dismissal, the banner is gone, and the page
/// content sits flush at the top with no leftover gap or divider.
///
/// An empty card is the PASS condition for this state, which is exactly why it
/// is staged over a caption.
@JeebPreview(
  group: 'offline_mode',
  name: 'Dismissed this episode',
  size: _offlineBannerCollapsedBox,
)
Widget offlineBannerDismissed() => _offlineBannerHosted(
      caption: 'setOffline() + dismissBanner() · hidden for this episode',
      episode: () => OfflineCubit()
        ..setOffline()
        ..dismissBanner(),
    );

/// JEBV4-13, second half: one dismissal must not silence the NEXT outage.
///
/// Seeded through the whole episode the app makes — offline, dismiss, back
/// online, offline again — because `bannerDismissed` is re-armed by the
/// transition inside `_setStatus`, not by going online. If this card is ever
/// empty, a user who dismissed one outage would never be told about any later
/// one, and the failure is silent: it looks exactly like the state above.
@JeebPreview(
  group: 'offline_mode',
  name: 'Re-armed by a new outage',
  size: _offlineBannerBannerBox,
)
Widget offlineBannerReArmed() => _offlineBannerHosted(
      caption: 'offline → dismiss → online → offline again',
      episode: () => OfflineCubit()
        ..setOffline()
        ..dismissBanner()
        ..setOnline()
        ..setOffline(),
    );

/// The state the widget is in for almost all of its life: connected.
///
/// It must be invisible AND cost nothing — `SizedBox.shrink()`, not an empty
/// [MaterialBanner] shell and not a stray divider — because a host page mounts
/// it unconditionally at the top of its content. Any height it keeps while
/// online is paid on every screen that ever adopts it, and would show up here
/// as a gap between the top of the card and the caption.
@JeebPreview(
  group: 'offline_mode',
  name: 'Online · collapsed',
  size: _offlineBannerCollapsedBox,
)
Widget offlineBannerOnline() => _offlineBannerHosted(
      caption: 'OfflineCubit() · online, nothing to report',
      episode: OfflineCubit.new,
    );
