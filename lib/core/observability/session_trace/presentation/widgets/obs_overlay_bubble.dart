import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../previews/jeeb_preview.dart';

class ObsOverlayBubble extends StatelessWidget {
  const ObsOverlayBubble({
    super.key,
    required this.controller,
    this.recordingOverride,
  });

  final ObsOverlayController controller;
  final bool? recordingOverride;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: Spacing.medium,
      bottom: Spacing.xLarge,
      child: Semantics(
        identifier: 'obs_overlay_bubble',
        button: true,
        label: 'Session trace overlay',
        child: _BubbleButton(
          controller: controller,
          recording: recordingOverride ?? controller.recording,
        ),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  const _BubbleButton({required this.controller, required this.recording});

  final ObsOverlayController controller;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('obs-overlay-bubble'),
      // A bare FAB is periwinkle (M0-2 ruling 3). `primaryContainer` is the
      // deep-burnt orange step, which no board tile draws and a dev disc.
      color: colorScheme.secondary,
      shape: const CircleBorder(),
      elevation: UIConstants.elevationMedium,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: controller.toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.small),
          child: _BubbleIcon(recording: recording),
        ),
      ),
    );
  }
}

class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.data_object, color: colorScheme.onSecondary),
          if (recording)
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
      key: const Key('obs-overlay-recording-dot'),
      width: Sizes.xSmall,
      height: Sizes.xSmall,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Distance from the viewport's **physical right** edge — `Positioned.right`,
/// not `PositionedDirectional.end`, which is why the AR RTL rendering of every
const double obsOverlayBubbleEndInset = Spacing.medium;

/// Distance from the viewport's bottom edge. Raw, not inset-aware: the overlay
/// is mounted from `MaterialApp.builder` outside any `SafeArea`, so this is
const double obsOverlayBubbleBottomInset = Spacing.xLarge;

/// The bubble's rendered diameter: a `Sizes.xLarge` icon box plus
/// `Spacing.small` of padding on each side. Restated here so the test can
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
const Size _obsOverlayBubblePhoneCanvas = Size(390, 470);

/// A short stage that crops to the bottom edge — where every question about
/// this widget actually lives. Doubles as the split-screen/landscape check.
const Size _obsOverlayBubbleBottomEdgeViewport = Size(390, 200);

/// The bottom-edge stage plus the same caption headroom.
const Size _obsOverlayBubbleBottomEdgeCanvas = Size(390, 310);

/// One inert controller, shared by every preview.
/// `ObsOverlayController()` is pure until `attach()` — no timer, no sink
final ObsOverlayController _obsOverlayBubbleInertController =
    ObsOverlayController();

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
                  ObsOverlayBubble(
                    controller: _obsOverlayBubbleInertController,
                    recordingOverride: recordingRequested,
                  ),
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
  const _ObsOverlayBubbleFakeScreen({
    required this.title,
    required this.rows,
    this.bottom,
  });

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
                  title: Text(
                    row,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        if (bottom case final Widget b) b,
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
  const _ObsOverlayBubbleNavDestination({
    required this.icon,
    required this.label,
    super.key,
  });

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
          // Periwinkle: a bare primary act is `secondary` under Midnight
          // (M0-2 ruling 3). `primary` here drew an orange the app never does.
          color: colors.secondary,
          borderRadius: const BorderRadius.all(Radius.circular(Spacing.small)),
        ),
        child: Text('Place order', style: TextStyle(color: colors.onSecondary)),
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
          borderRadius: const BorderRadius.all(
            Radius.circular(Sizes.threeXSmall),
          ),
        ),
      ),
    );
  }
}

/// The production geometry, with nothing underneath to argue with: the bubble
/// docked 16pt from the physical right edge and 24pt up from the bottom, at a
@JeebPreview(
  group: 'core',
  name: 'Docked (production geometry)',
  size: _obsOverlayBubblePhoneCanvas,
)
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
@JeebPreview(
  group: 'core',
  name: 'Over the bottom nav bar',
  size: _obsOverlayBubblePhoneCanvas,
)
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
/// The button spans the width minus 16pt gutters and sits 16pt off the bottom;
@JeebPreview(
  group: 'core',
  name: 'Over a docked primary CTA',
  size: _obsOverlayBubblePhoneCanvas,
)
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
@JeebPreview(
  group: 'core',
  name: 'Recording requested (dot is gated)',
  size: _obsOverlayBubblePhoneCanvas,
)
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
@JeebPreview(
  group: 'core',
  name: 'Over the home indicator',
  size: _obsOverlayBubbleBottomEdgeCanvas,
)
Widget obsOverlayBubbleOverGestureInset() => const _ObsOverlayBubbleStage(
  caption: 'Home indicator · 24pt vs 34pt',
  viewport: _obsOverlayBubbleBottomEdgeViewport,
  content: _ObsOverlayBubbleFakeScreen(
    title: 'Chat',
    rows: <String>['Ali: on my way', 'You: thanks!'],
    bottom: _ObsOverlayBubbleFakeGestureBand(),
  ),
);
