// Shared dev-only fixtures for `RequestSummaryUnavailableScreen`.

import 'package:flutter/material.dart';

/// The Screen Catalog's long-standing label for this screen's single state.
/// Pinned here rather than left as a literal in the entry, because it is the
const String requestSummaryUnavailableScreenCatalogStateLabel = 'Unavailable';

/// What the app-bar back arrow lands on when there IS something to pop.
/// Public so the render test can tell "the arrow popped to a real page" apart
const String requestSummaryUnavailableScreenParentStandInLabel =
    'create-request step (preview stand-in)';

/// One simulated device window to render `RequestSummaryUnavailableScreen` in.
/// The frame has to be pinned by the fixture rather than left to the canvas
@immutable
class RequestSummaryUnavailableScreenWindow {
  const RequestSummaryUnavailableScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The geometries this screen is reviewed in.
final class RequestSummaryUnavailableScreenWindows {
  RequestSummaryUnavailableScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const RequestSummaryUnavailableScreenWindow phone =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st gen
  /// class). The body is a centred, non-scrolling `Column`, so this is the width
  static const RequestSummaryUnavailableScreenWindow compact =
      RequestSummaryUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  /// `/request-summary` is a bare top-level `GoRoute` — no `ShellRoute`, no
  static const RequestSummaryUnavailableScreenWindow notched =
      RequestSummaryUnavailableScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const RequestSummaryUnavailableScreenWindow phoneLargeText =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest text.
  /// This is the window in which the un-scrollable body runs out of room.
  static const RequestSummaryUnavailableScreenWindow compactLargeText =
      RequestSummaryUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The ordinary phone again, but reviewed for its NAVIGATION state rather than
  /// its geometry: the screen as the lone page on the stack, which is what a
  static const RequestSummaryUnavailableScreenWindow phoneDeepLink =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · cold deep link (nothing to pop)',
    size: Size(390, 844),
  );
}

/// Hosts `RequestSummaryUnavailableScreen` in one
/// [RequestSummaryUnavailableScreenWindow], with a real [Navigator] above it so
/// the app-bar back arrow resolves the way it resolves in production.
class RequestSummaryUnavailableScreenPreviewHost extends StatelessWidget {
  const RequestSummaryUnavailableScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.parentOnStack,
  });

  /// The screen under review — `const RequestSummaryUnavailableScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final RequestSummaryUnavailableScreenWindow? window;

  /// Whether a page sits beneath the screen on a LOCAL navigator, or `null` to
  /// mount no navigator at all.
  final bool? parentOnStack;

  @override
  Widget build(BuildContext context) {
    final bool? parentOnStack = this.parentOnStack;

    // A LOCAL Navigator, not the canvas's. Inheriting the ambient one would
    final Widget staged = parentOnStack == null
        ? screen
        : Navigator(
            onGenerateInitialRoutes:
                (NavigatorState navigator, String initialRoute) => <Route<void>>[
              if (parentOnStack)
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const _RequestSummaryUnavailableScreenParentStandIn(),
                ),
              MaterialPageRoute<void>(builder: (_) => screen),
            ],
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<void>(settings: settings, builder: (_) => screen),
          );

    final RequestSummaryUnavailableScreenWindow? window = this.window;
    if (window == null) return staged;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            window.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: staged),
          ),
        ),
      ],
    );

    // Unbind both axes. The render tests pump onto 800 x 600 and every frame
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// The page beneath the screen when the route was reached by an in-app push.
/// It only has to exist and to be identifiable, so a tap on the back arrow can
/// be shown to reach a page rather than to do nothing.
class _RequestSummaryUnavailableScreenParentStandIn extends StatelessWidget {
  const _RequestSummaryUnavailableScreenParentStandIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            requestSummaryUnavailableScreenParentStandInLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
