import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../observability_config.dart';
import '../../../../previews/jeeb_preview.dart';

/// Collapsed state of the devtool overlay: a small floating circular toggle
/// docked to the bottom-right corner. Tapping it expands `ObsOverlayPanel`.
///
/// There is no dedicated OMDS "floating toggle bubble" component to reuse
/// (the closest primitives are `Material` + `InkWell`, which OMDS itself
/// builds its own chips/buttons from) — this widget is the small, novel
/// affordance a live devtool overlay needs on top of those primitives.
class ObsOverlayBubble extends StatelessWidget {
  const ObsOverlayBubble({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: Spacing.medium,
      bottom: Spacing.xLarge,
      child: Semantics(
        identifier: 'obs_overlay_bubble',
        button: true,
        label: 'Session trace overlay',
        child: _BubbleButton(controller: controller),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  const _BubbleButton({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('obs-overlay-bubble'),
      color: colorScheme.primaryContainer,
      shape: const CircleBorder(),
      elevation: UIConstants.elevationMedium,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: controller.toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.small),
          child: _BubbleIcon(controller: controller),
        ),
      ),
    );
  }
}

class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.data_object, color: colorScheme.onPrimaryContainer),
          if (controller.recording)
            Positioned(
              right: -Spacing.twoXSmall,
              top: -Spacing.twoXSmall,
              child: _RecordingDot(color: colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.xSmall,
      height: Sizes.xSmall,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
// Render tests: test/previews/core/obs_overlay_bubble_preview_test.dart
// ===========================================================================
//
// Widget previews for [ObsOverlayBubble] — run with
// `flutter widget-preview start`.
//
// [ObsOverlayBubble] is the collapsed state of the devtool session-trace
// overlay: a 48pt circle docked to the bottom-right of whatever is on screen.
// It takes one parameter, and that parameter is not what varies. Its two real
// inputs are both ambient:
//
//  * **A [Stack] ancestor.** The widget returns a [Positioned], so on its own
//    it renders nothing sensible — `obs_overlay.dart` says so in as many
//    words ("the [Stack] is REQUIRED, not decorative"). Every preview below
//    supplies the same full-viewport stack `_ObsOverlayContent` supplies in
//    production, plus the routed content the real bubble floats on top of.
//    That backdrop is the point rather than set dressing: this widget's whole
//    risk profile is *what it covers*, not what it draws — the owner ruling
//    quoted in `observability_config.dart` ("there is a dev red button,
//    remove it") was a complaint about exactly that.
//  * **`controller.recording`**, which is not per-instance state at all. It
//    is a live pass-through of the global `Observability.instance.recording`
//    (`kObsCompiledIn && ObservabilityConfig.enabled`), so the only way to
//    drive it is the global — see [obsOverlayBubbleRecordingRequested], which
//    also documents why the recording dot cannot appear in an ordinary
//    preview or test run.
//
// Network-free by construction: [ObsOverlayController] does nothing at all
// until `attach()` is called (that is what starts the 1s ticker and wraps the
// global observability sink), and no preview here calls it. No session is
// installed, so nothing is captured and no file is ever opened.
//
// **About the captions.** The bubble renders no text — it is an icon in a
// circle — so `find.text` has nothing of the widget's own to bind to. Each
// preview therefore carries a one-line caption naming the state under review;
// the caption is preview scaffolding, useful in the canvas (five unlabelled
// circles are indistinguishable) and used by the test only to address a
// state. What actually proves the states differ is the measured geometry in
// `test/previews/core/obs_overlay_bubble_preview_test.dart`.

/// Distance from the viewport's **physical right** edge — `Positioned.right`,
/// not `PositionedDirectional.end`, which is why the AR RTL rendering of every
/// preview here shows the bubble in the same corner as the EN one.
const double obsOverlayBubbleEndInset = Spacing.medium;

/// Distance from the viewport's bottom edge. Raw, not inset-aware: the overlay
/// is mounted from `MaterialApp.builder` outside any `SafeArea`, so this is
/// measured against the physical bottom of the screen — see
/// [obsOverlayBubbleOverGestureInset].
const double obsOverlayBubbleBottomInset = Spacing.xLarge;

/// The bubble's rendered diameter: a `Sizes.xLarge` icon box plus
/// `Spacing.small` of padding on each side. Restated here so the test can
/// assert the tap target without reaching into the widget's private tree.
const double obsOverlayBubbleDiameter = Sizes.xLarge + 2 * Spacing.small;

/// Keys on the preview scaffolding, exported so the render test can measure
/// what the bubble lands on top of.
const Key obsOverlayBubbleStageKey = Key('obs-bubble-preview-stage');

/// The bottom-nav destination that is FIRST in the row (physically leftmost in
/// EN, physically rightmost in AR).
const Key obsOverlayBubbleFirstDestinationKey = Key('obs-bubble-preview-nav-1');

/// The bottom-nav destination that is LAST in the row (physically rightmost in
/// EN, physically leftmost in AR).
const Key obsOverlayBubbleLastDestinationKey = Key('obs-bubble-preview-nav-4');

/// The full-width primary button in [obsOverlayBubbleOverPrimaryCta].
const Key obsOverlayBubblePrimaryCtaKey = Key('obs-bubble-preview-cta');

/// The simulated system gesture band in [obsOverlayBubbleOverGestureInset].
const Key obsOverlayBubbleGestureBandKey = Key('obs-bubble-preview-gesture');

/// Height of the simulated home-indicator band — an iPhone 15's bottom
/// `viewPadding`, and the most common inset a Jeeb tester's device has.
const double obsOverlayBubbleGestureBandHeight = 34;

/// A phone-shaped stage: tall enough that the content above the bubble reads
/// as a real screen rather than a strip.
const Size _obsOverlayBubblePhoneViewport = Size(390, 360);

/// The phone stage plus room for its caption — including the ~3 lines that
/// caption becomes in the matrix's 200%-text rendering. Sized deliberately: at
/// `_obsOverlayBubblePhoneViewport.height + 20` the large-text rendering of every card here
/// overflowed its own canvas box by 20-82pt, which is preview scaffolding
/// shouting over the widget it is meant to frame.
const Size _obsOverlayBubblePhoneCanvas = Size(390, 470);

/// A short stage that crops to the bottom edge — where every question about
/// this widget actually lives. Doubles as the split-screen/landscape check.
const Size _obsOverlayBubbleBottomEdgeViewport = Size(390, 200);

/// The bottom-edge stage plus the same caption headroom.
const Size _obsOverlayBubbleBottomEdgeCanvas = Size(390, 310);

/// One inert controller, shared by every preview.
///
/// `ObsOverlayController()` is pure until `attach()` — no timer, no sink
/// wrapping, no IO — so a single long-lived instance is both safe and cheaper
/// than minting (and never disposing) a `ChangeNotifier` on every rebuild.
/// `toggleExpanded` fires on tap and flips a flag no preview reads: the bubble
/// never renders the expanded state, because the production host swaps it for
/// `ObsOverlayPanel` instead.
final ObsOverlayController _obsOverlayBubbleInertController = ObsOverlayController();

/// Hosts the bubble the way production does — inside a full-viewport [Stack],
/// over routed content — and captions the state.
class _ObsOverlayBubbleStage extends StatelessWidget {
  const _ObsOverlayBubbleStage({
    required this.caption,
    required this.viewport,
    required this.content,
    this.recordingRequested = false,
  });

  final String caption;
  final Size viewport;
  final Widget content;
  final bool recordingRequested;

  @override
  Widget build(BuildContext context) {
    // The bubble's recording state has NO per-instance seam: `_BubbleIcon`
    // reads `controller.recording`, which forwards to the global
    // `Observability.instance.recording`. Writing the global here — in build,
    // immediately before the bubble's own build — is what keeps each card in
    // the canvas showing ITS own state rather than whichever preview happened
    // to be constructed last. Preview-only code, tree-shaken out of any real
    // build, and inert regardless: with no session installed there is no sink
    // to record into.
    ObservabilityConfig.instance.enabled = recordingRequested;

    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SizedBox.fromSize(
              size: viewport,
              child: Stack(
                key: obsOverlayBubbleStageKey,
                children: <Widget>[
                  Positioned.fill(child: content),
                  ObsOverlayBubble(controller: _obsOverlayBubbleInertController),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for the routed content the overlay floats above: a header, a list,
/// and optionally whatever the screen docks to its own bottom edge.
class _ObsOverlayBubbleFakeScreen extends StatelessWidget {
  const _ObsOverlayBubbleFakeScreen({required this.title, required this.rows, this.bottom});

  final String title;
  final List<String> rows;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: Sizes.fiveXLarge,
          color: colors.surfaceContainerHighest,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
            children: <Widget>[
              for (final String row in rows)
                ListTile(
                  dense: true,
                  title: Text(row, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
        ?bottom,
      ],
    );
  }
}

/// The app's own bottom navigation bar, in the position a real screen puts it.
class _ObsOverlayBubbleFakeBottomNav extends StatelessWidget {
  const _ObsOverlayBubbleFakeBottomNav();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const SizedBox(
        height: Sizes.sixXLarge,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _ObsOverlayBubbleNavDestination(
                key: obsOverlayBubbleFirstDestinationKey,
                icon: Icons.home_outlined,
                label: 'Home',
              ),
            ),
            Expanded(
              child: _ObsOverlayBubbleNavDestination(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
              ),
            ),
            Expanded(
              child: _ObsOverlayBubbleNavDestination(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
              ),
            ),
            Expanded(
              child: _ObsOverlayBubbleNavDestination(
                key: obsOverlayBubbleLastDestinationKey,
                icon: Icons.person_outline,
                label: 'Profile',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObsOverlayBubbleNavDestination extends StatelessWidget {
  const _ObsOverlayBubbleNavDestination({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: Sizes.xLarge),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

/// A full-width primary action, docked with the usual `Spacing.medium` gutter.
class _ObsOverlayBubbleFakePrimaryCta extends StatelessWidget {
  const _ObsOverlayBubbleFakePrimaryCta();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Container(
        key: obsOverlayBubblePrimaryCtaKey,
        height: Sizes.fourXLarge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadius.all(Radius.circular(Spacing.small)),
        ),
        child: Text('Place order', style: TextStyle(color: colors.onPrimary)),
      ),
    );
  }
}

/// A drawn stand-in for the device's bottom `viewPadding` — the home
/// indicator / gesture bar. The canvas has no real insets, so this band exists
/// to make the arithmetic visible rather than to simulate the platform.
class _ObsOverlayBubbleFakeGestureBand extends StatelessWidget {
  const _ObsOverlayBubbleFakeGestureBand();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: obsOverlayBubbleGestureBandKey,
      height: obsOverlayBubbleGestureBandHeight,
      alignment: Alignment.center,
      color: colors.inverseSurface.withValues(alpha: 0.14),
      child: Container(
        width: 120,
        height: 5,
        decoration: BoxDecoration(
          color: colors.onSurface,
          borderRadius: const BorderRadius.all(Radius.circular(Sizes.threeXSmall)),
        ),
      ),
    );
  }
}

/// The production geometry, with nothing underneath to argue with: the bubble
/// docked 16pt from the physical right edge and 24pt up from the bottom, at a
/// 48pt diameter (which is exactly the minimum comfortable tap target, with no
/// margin above it).
///
/// The rendering worth the most attention here is **AR RTL dark**, and not for
/// its Arabic — there is none. The widget anchors with `Positioned.right`, a
/// physical edge, so it does NOT mirror: in Arabic the whole app flips around
/// it and the bubble stays in the same corner, which is now the *leading*
/// corner in reading order. Whether that is right for a devtool is a judgement
/// call (testers arguably want it in a fixed place), but it is currently an
/// accident of `Positioned` rather than a decision anyone wrote down.
@JeebPreview(group: 'core', name: 'Docked (production geometry)', size: _obsOverlayBubblePhoneCanvas)
Widget obsOverlayBubbleDocked() => const _ObsOverlayBubbleStage(
      caption: 'Docked · 16/24pt bottom-right',
      viewport: _obsOverlayBubblePhoneViewport,
      content: _ObsOverlayBubbleFakeScreen(
        title: 'My orders',
        rows: <String>[
          'Order #4821 · In transit',
          'Order #4820 · Delivered',
          'Order #4819 · Cancelled',
        ],
      ),
    );

/// The bubble over the app's own bottom navigation bar — the layout most Jeeb
/// screens actually have underneath it.
///
/// A 64pt nav bar occupies 0-64pt from the bottom; the bubble occupies 24-72pt.
/// It therefore covers 40pt of the bar, centred on one destination's icon and
/// label. Which destination depends on the locale, because the bar mirrors and
/// the bubble does not: **Profile** in English, **Home** in Arabic. A tester
/// who cannot reach their profile tab is the concrete form of the "dev red
/// button" complaint that made this overlay opt-in.
@JeebPreview(group: 'core', name: 'Over the bottom nav bar', size: _obsOverlayBubblePhoneCanvas)
Widget obsOverlayBubbleOverBottomNav() => const _ObsOverlayBubbleStage(
      caption: 'Bottom nav · covers a tab',
      viewport: _obsOverlayBubblePhoneViewport,
      content: _ObsOverlayBubbleFakeScreen(
        title: 'My orders',
        rows: <String>['Order #4821 · In transit', 'Order #4820 · Delivered'],
        bottom: _ObsOverlayBubbleFakeBottomNav(),
      ),
    );

/// The bubble over a docked full-width primary action.
///
/// The button spans the width minus 16pt gutters and sits 16pt off the bottom;
/// the bubble covers its trailing 48pt entirely. Tapping "Place order" near
/// its trailing end opens the devtool overlay instead — and unlike the nav bar
/// above, there is no second way to reach the action.
@JeebPreview(group: 'core', name: 'Over a docked primary CTA', size: _obsOverlayBubblePhoneCanvas)
Widget obsOverlayBubbleOverPrimaryCta() => const _ObsOverlayBubbleStage(
      caption: 'Primary CTA · covers 48pt',
      viewport: _obsOverlayBubblePhoneViewport,
      content: _ObsOverlayBubbleFakeScreen(
        title: 'Review your order',
        rows: <String>['2 items · 14,000 LBP', 'Deliver to: Hamra, Beirut'],
        bottom: _ObsOverlayBubbleFakePrimaryCta(),
      ),
    );

/// Recording requested — and the state that proves the recording dot is
/// currently **unreachable**.
///
/// `_BubbleIcon` shows a red badge dot when `controller.recording` is true.
/// That getter forwards to `Observability.instance.recording`, which is
/// `kObsCompiledIn && ObservabilityConfig.enabled` — and `kObsCompiledIn` is a
/// compile-time `false` unless the build carries BOTH
/// `--dart-define JEEB_DEVTOOL_ENABLED=true` and
/// `--dart-define JEEB_OBS_OVERLAY=true`. The preview canvas and `flutter
/// test` carry neither, so the `&&` folds to false and this preview renders
/// identically to [obsOverlayBubbleDocked] no matter what the runtime switch
/// says.
///
/// This stage flips the runtime switch on regardless, so that (a) the state is
/// real and self-documenting, and (b) anyone who opens the canvas WITH the
/// defines set sees the dot here and only here. The test asserts the contract
/// — dot present iff `Observability.instance.recording` — which holds in both
/// kinds of build.
@JeebPreview(group: 'core', name: 'Recording requested (dot is gated)', size: _obsOverlayBubblePhoneCanvas)
Widget obsOverlayBubbleRecordingRequested() => const _ObsOverlayBubbleStage(
      caption: 'Recording on · dot is gated',
      viewport: _obsOverlayBubblePhoneViewport,
      recordingRequested: true,
      content: _ObsOverlayBubbleFakeScreen(
        title: 'Live tracking',
        rows: <String>['Jeeber en route · 4 min', 'Handover code: 1234'],
      ),
    );

/// The bottom edge, cropped — a short stage that also stands in for
/// split-screen and landscape.
///
/// `ObsOverlayHost` is mounted from `MaterialApp.builder` as a sibling of the
/// routed child, so nothing between it and the screen edge consumes
/// `MediaQuery.padding`: the 24pt anchor is measured against the physical
/// bottom of the display, not against the safe area. On a device with a 34pt
/// home indicator the bubble's lower 10pt sits inside the system gesture
/// region, where a drag is the OS's before it is the app's.
@JeebPreview(group: 'core', name: 'Over the home indicator', size: _obsOverlayBubbleBottomEdgeCanvas)
Widget obsOverlayBubbleOverGestureInset() => const _ObsOverlayBubbleStage(
      caption: 'Home indicator · 24pt vs 34pt',
      viewport: _obsOverlayBubbleBottomEdgeViewport,
      content: _ObsOverlayBubbleFakeScreen(
        title: 'Chat',
        rows: <String>['Ali: on my way', 'You: thanks!'],
        bottom: _ObsOverlayBubbleFakeGestureBand(),
      ),
    );
