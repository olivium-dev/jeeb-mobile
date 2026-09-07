import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';
import 'jeeb_empty_state.dart';
import 'jeeb_pull_to_refresh.dart';

/// The scroll host for a centred empty/loading/failure block: stays centred at
/// any height, still scrolls when text is scaled, and an EMPTY list is pullable.
class JeebStateHost extends StatelessWidget {
  const JeebStateHost({
    super.key,
    required this.child,
    this.onRefresh,
    this.padding = EdgeInsets.zero,
  });

  /// The centred block — normally a [JeebEmptyState] or a `JeebFailureBlock`.
  final Widget child;

  /// Pull-to-refresh handler. Null renders a plain scroll host.
  final Future<void> Function()? onRefresh;

  /// Gutter around the block.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget scroller = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          // Always scrollable, or a short block never reaches the drag
          // threshold and the refresh gesture is dead on an empty list.
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ),
        );
      },
    );

    final Future<void> Function()? refresh = onRefresh;
    if (refresh == null) {
      return scroller;
    }
    return JeebPullToRefresh(onRefresh: refresh, child: scroller);
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// Phone box, tall enough that the centring is visible.
const Size _jeebStateHostBox = Size(390, 520);

/// Hosts [child] under a caption naming the state under review.
Widget _jeebStateHostHosted(String caption, Widget child) => Column(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    Text(caption),
    SizedBox(height: 420, child: child),
  ],
);

/// The shipping case: an empty block that can still be pulled to refresh.
@JeebPreview(
  group: 'core',
  name: 'Empty block, pullable',
  size: _jeebStateHostBox,
  matrix: true,
)
Widget jeebStateHostPullableEmpty() => _jeebStateHostHosted(
  'Empty block, pullable',
  JeebStateHost(
    onRefresh: () async {},
    child: const JeebEmptyState(
      headline: 'Nothing here yet',
      body: 'Pull down to check again.',
      identifier: 'preview_empty',
    ),
  ),
);

/// No refresh handler — a plain scroll host, no ring.
@JeebPreview(
  group: 'core',
  name: 'No refresh handler',
  size: _jeebStateHostBox,
)
Widget jeebStateHostStatic() => _jeebStateHostHosted(
  'No refresh handler',
  const JeebStateHost(
    child: JeebEmptyState(
      headline: 'Nothing here yet',
      identifier: 'preview_empty_static',
    ),
  ),
);

/// A block taller than the viewport: the host must scroll rather than clip.
@JeebPreview(
  group: 'core',
  name: 'Overflowing block scrolls',
  size: _jeebStateHostBox,
)
Widget jeebStateHostOverflow() => _jeebStateHostHosted(
  'Overflowing block scrolls',
  JeebStateHost(
    onRefresh: () async {},
    child: const SizedBox(
      height: 900,
      child: JeebEmptyState(
        headline: 'Taller than the viewport',
        identifier: 'preview_empty_tall',
      ),
    ),
  ),
);
