import 'package:flutter/material.dart';

/// Request ids for dev surfaces.
final class JeeberRequestUnavailableScreenIds {
  JeeberRequestUnavailableScreenIds._();

  /// The short id the Screen Catalog uses.
  static const String catalog = 'req-404';

  /// The UUID that `/jeeber/requests/:id` uses.
  static const String push = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';

  /// Router fallback when id is empty.
  static const String blank = '';
}

/// One simulated device window; frame size must be pinned for render tests.
@immutable
class JeeberRequestUnavailableScreenWindow {
  const JeeberRequestUnavailableScreenWindow({
    required this.label,
    required this.size,
    this.textScale,
  });

  /// Short name for the geometry.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// Text scale multiplier; null inherits the ambient one.
  final double? textScale;
}

/// Standard device windows.
final class JeeberRequestUnavailableScreenWindows {
  JeeberRequestUnavailableScreenWindows._();

  /// Ordinary modern phone.
  static const JeeberRequestUnavailableScreenWindow phone =
      JeeberRequestUnavailableScreenWindow(
    label: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// Smallest display (iPhone SE 1st gen).
  static const JeeberRequestUnavailableScreenWindow compact =
      JeeberRequestUnavailableScreenWindow(
    label: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// Phone with 200% text.
  static const JeeberRequestUnavailableScreenWindow phoneLargeText =
      JeeberRequestUnavailableScreenWindow(
    label: 'Phone 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// Smallest display with 200% text.
  static const JeeberRequestUnavailableScreenWindow compactLargeText =
      JeeberRequestUnavailableScreenWindow(
    label: 'Compact 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// One designed state: an id, a window, and navigation stack.
@immutable
class JeeberRequestUnavailableScreenFixture {
  const JeeberRequestUnavailableScreenFixture({
    required this.label,
    required this.requestId,
    this.window,
    this.parentOnStack,
  });

  /// Caption for the frame and render test.
  final String label;

  /// The id handed to `JeeberRequestUnavailableScreen.requestId`.
  final String requestId;

  /// The simulated display; null uses the ambient window.
  final JeeberRequestUnavailableScreenWindow? window;

  /// Whether a parent page exists: true/false for local navigator, null to inherit.
  final bool? parentOnStack;
}

/// Designed states for preview and catalog.
final class JeeberRequestUnavailableScreenFixtures {
  JeeberRequestUnavailableScreenFixtures._();

  /// Catalog default: short id, device frame, catalog route.
  static const JeeberRequestUnavailableScreenFixture catalogDefault =
      JeeberRequestUnavailableScreenFixture(
    label: 'Request no longer available',
    requestId: JeeberRequestUnavailableScreenIds.catalog,
  );

  /// Short id framed as a phone for the canvas.
  static const JeeberRequestUnavailableScreenFixture phoneShortId =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · short id (req-404)',
    requestId: JeeberRequestUnavailableScreenIds.catalog,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: true,
  );

  /// Cold push tap: raw UUID, nothing to pop.
  static const JeeberRequestUnavailableScreenFixture pushDeadEnd =
      JeeberRequestUnavailableScreenFixture(
    label: 'Cold push tap · raw UUID · nothing to pop',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: false,
  );

  /// Smallest phone with shipped route id.
  static const JeeberRequestUnavailableScreenFixture compact =
      JeeberRequestUnavailableScreenFixture(
    label: 'Compact 320 × 568 · raw UUID',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.compact,
    parentOnStack: true,
  );

  /// Phone with 200% text.
  static const JeeberRequestUnavailableScreenFixture phoneLargeText =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · 200% text · raw UUID',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.phoneLargeText,
    parentOnStack: true,
  );

  /// Smallest display with 200% text.
  static const JeeberRequestUnavailableScreenFixture compactLargeText =
      JeeberRequestUnavailableScreenFixture(
    label: 'Compact · 200% text · nothing to pop',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.compactLargeText,
    parentOnStack: false,
  );

  /// Router fallback with blank id.
  static const JeeberRequestUnavailableScreenFixture blankId =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · blank id from the router fallback',
    requestId: JeeberRequestUnavailableScreenIds.blank,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: true,
  );
}

/// Parent page for back-arrow testing.
const String jeeberRequestUnavailableScreenParentLabel =
    'jeeber request feed (preview stand-in)';

/// Hosts `JeeberRequestUnavailableScreen` in one [JeeberRequestUnavailableScreenFixture].
class JeeberRequestUnavailableScreenPreviewHost extends StatelessWidget {
  const JeeberRequestUnavailableScreenPreviewHost({
    required this.fixture,
    required this.screen,
    super.key,
  });

  /// The state being rendered.
  final JeeberRequestUnavailableScreenFixture fixture;

  /// The screen under review.
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final bool? parentOnStack = fixture.parentOnStack;

    final Widget staged = parentOnStack == null
        ? screen
        : Navigator(
            onGenerateInitialRoutes:
                (NavigatorState navigator, String initialRoute) => <Route<void>>[
              if (parentOnStack)
                MaterialPageRoute<void>(
                  builder: (_) => const _JeeberRequestUnavailableScreenParent(),
                ),
              MaterialPageRoute<void>(builder: (_) => screen),
            ],
            onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => screen,
            ),
          );

    final JeeberRequestUnavailableScreenWindow? window = fixture.window;
    if (window == null) return staged;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            fixture.label,
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
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: staged),
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// Parent page for back-arrow testing.
class _JeeberRequestUnavailableScreenParent extends StatelessWidget {
  const _JeeberRequestUnavailableScreenParent();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            jeeberRequestUnavailableScreenParentLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
