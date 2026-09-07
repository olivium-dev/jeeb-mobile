import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';
import 'jeeb_surface_tone.dart';

/// [OmdsPullToRefresh] with the Midnight ring: OMDS defaults the spinner to
/// the accent orange, which the budget reserves for the tile-drawn act.
class JeebPullToRefresh extends StatelessWidget {
  const JeebPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40,
    this.edgeOffset = 0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  /// Runs when the user pulls. Must complete, or the ring spins forever.
  final Future<void> Function() onRefresh;

  /// The scrollable this wraps.
  final Widget child;

  /// Ring ink. Null takes the muted ink of the surface it is drawn on.
  final Color? color;

  /// Ring backing disc.
  final Color? backgroundColor;

  /// Distance from the edge at which the ring settles.
  final double displacement;

  /// Offset applied before [displacement] — for a pinned header.
  final double edgeOffset;

  /// Which scroll notifications arm the gesture.
  final bool Function(ScrollNotification) notificationPredicate;

  @override
  Widget build(BuildContext context) {
    final JeebSurfaceToneData tone = JeebSurfaceTone.of(context);
    return OmdsPullToRefresh(
      onRefresh: onRefresh,
      color: color ?? tone.mutedInk,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// Phone width with room for a scrollable list under the ring.
const Size _jeebPullToRefreshBox = Size(390, 420);

/// A list long enough to scroll, so the gesture is armed in the canvas.
Widget _jeebPullToRefreshList(String caption, int rows) => Column(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    Text(caption),
    SizedBox(
      height: 300,
      child: JeebPullToRefresh(
        onRefresh: () async {},
        child: ListView.builder(
          itemCount: rows,
          itemBuilder: (BuildContext context, int i) =>
              ListTile(title: Text('Row $i')),
        ),
      ),
    ),
  ],
);

/// The shipping case: a scrollable list the user can pull.
@JeebPreview(
  group: 'core',
  name: 'List (pullable)',
  size: _jeebPullToRefreshBox,
  matrix: true,
)
Widget jeebPullToRefreshList() =>
    _jeebPullToRefreshList('List (pullable)', 20);

/// The case every screen gets wrong: an EMPTY list must still be pullable, or
/// the only way out of an empty state is to leave the screen.
@JeebPreview(
  group: 'core',
  name: 'Empty list (still pullable)',
  size: _jeebPullToRefreshBox,
)
Widget jeebPullToRefreshEmpty() =>
    _jeebPullToRefreshList('Empty list (still pullable)', 0);
