// Shared dev-only fixtures for `ClientUnreachableScreen`.

import 'package:flutter/material.dart';

/// The delivery ids the two dev surfaces hand to `ClientUnreachableScreen`.
/// Separate constants rather than literals at the call sites — not because the
final class ClientUnreachableScreenDeliveryIds {
  ClientUnreachableScreenDeliveryIds._();

  /// The short, human-sized id the Screen Catalog has always shown.
  static const String catalog = 'delivery-demo-1';

  /// The shape a real delivery id has everywhere else in the app — the same
  /// 36-character form `DeliveryDetailScreen` and the live-tracking route carry.
  static const String route = 'b7d1a4c8-2f60-4e5b-9a31-5c8e1f0d77ae';
}

/// One simulated device window.
/// The frame has to be pinned by the fixture rather than left to the canvas
@immutable
class ClientUnreachableScreenWindow {
  const ClientUnreachableScreenWindow({
    required this.label,
    required this.size,
    this.textScale,
  });

  /// Short name for the geometry, used in dartdoc and in debugging.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The geometries this screen is reviewed in.
final class ClientUnreachableScreenWindows {
  ClientUnreachableScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const ClientUnreachableScreenWindow phone =
      ClientUnreachableScreenWindow(
    label: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class). The notice card's paragraph is a centred `Text` with no line
  static const ClientUnreachableScreenWindow compact =
      ClientUnreachableScreenWindow(
    label: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const ClientUnreachableScreenWindow phoneLargeText =
      ClientUnreachableScreenWindow(
    label: 'Phone 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window in which the un-scrollable body runs out of room.
  static const ClientUnreachableScreenWindow compactLargeText =
      ClientUnreachableScreenWindow(
    label: 'Compact 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// One designed state: an id, a window, and how the route was reached.
@immutable
class ClientUnreachableScreenFixture {
  const ClientUnreachableScreenFixture({
    required this.label,
    required this.deliveryId,
    this.window,
    this.parentOnStack,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  final String label;

  /// The id handed to `ClientUnreachableScreen.deliveryId`.
  /// Kept per-state even though the screen ignores it, so that "the id is not
  final String deliveryId;

  /// The simulated display, or `null` to render bare at the ambient window —
  /// the form the Screen Catalog uses, where the device IS the frame.
  final ClientUnreachableScreenWindow? window;

  /// Whether a page sits beneath the screen on a LOCAL navigator:
  ///  * `true` — the jeeber reached this from live tracking, so a page is still
  final bool? parentOnStack;
}

/// The designed states, shared by the Screen Catalog and the previews.
final class ClientUnreachableScreenFixtures {
  ClientUnreachableScreenFixtures._();

  /// The catalog's long-standing state, unchanged: the short id, the real
  /// device as the frame, and the catalog's own route underneath it.
  static const ClientUnreachableScreenFixture catalogDefault =
      ClientUnreachableScreenFixture(
    label: 'Default',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
  );

  /// The reference reading, framed as a phone with live tracking underneath.
  static const ClientUnreachableScreenFixture phone =
      ClientUnreachableScreenFixture(
    label: 'Phone · reached from live tracking',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.phone,
    parentOnStack: true,
  );

  /// A stack-replacing arrival carrying a real-shaped delivery id: no back
  /// arrow, and nothing for `pop(true)` to return to.
  static const ClientUnreachableScreenFixture coldArrival =
      ClientUnreachableScreenFixture(
    label: 'Cold arrival · real id · nothing to pop',
    deliveryId: ClientUnreachableScreenDeliveryIds.route,
    window: ClientUnreachableScreenWindows.phone,
    parentOnStack: false,
  );

  /// The smallest display the app supports.
  static const ClientUnreachableScreenFixture compact =
      ClientUnreachableScreenFixture(
    label: 'Compact 320 × 568 · everything still fits',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.compact,
    parentOnStack: true,
  );

  /// The accessibility ceiling on a normal phone.
  static const ClientUnreachableScreenFixture phoneLargeText =
      ClientUnreachableScreenFixture(
    label: 'Phone · 200% text',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.phoneLargeText,
    parentOnStack: true,
  );

  /// Worst case: smallest display, largest text, and the cold-arrival stack
  /// that has no back arrow to fall back on.
  static const ClientUnreachableScreenFixture compactLargeText =
      ClientUnreachableScreenFixture(
    label: 'Compact · 200% text · nothing to pop',
    deliveryId: ClientUnreachableScreenDeliveryIds.route,
    window: ClientUnreachableScreenWindows.compactLargeText,
    parentOnStack: false,
  );
}

/// What the screen pops back to when there IS something underneath it.
/// Public so the render test can tell "the flag CTA returned to the caller"
const String clientUnreachableScreenParentLabel =
    'live tracking (preview stand-in)';

/// Every value `ClientUnreachableScreen` has popped with, newest last.
/// `Navigator.of(context).pop(true)` in the flag CTA is the screen's ENTIRE
final class ClientUnreachableScreenPopLog {
  ClientUnreachableScreenPopLog._();

  /// Pop results, in order. `true` is the flag confirmation; `null` is a
  /// system/back-arrow pop.
  static final List<Object?> results = <Object?>[];

  /// Clears [results]; the list is static, so one test's taps would otherwise
  /// leak into the next.
  static void reset() => results.clear();
}

/// Hosts `ClientUnreachableScreen` in one [ClientUnreachableScreenFixture].
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
class ClientUnreachableScreenPreviewHost extends StatelessWidget {
  const ClientUnreachableScreenPreviewHost({
    required this.fixture,
    required this.screen,
    super.key,
  });

  /// The state being rendered — id, window and navigation stack.
  final ClientUnreachableScreenFixture fixture;

  /// The screen under review, already built with [fixture]'s `deliveryId`.
  final Widget screen;

  /// The screen's own route, wired so its pop result lands in
  /// [ClientUnreachableScreenPopLog].
  Route<Object?> _screenRoute() {
    final MaterialPageRoute<Object?> route =
        MaterialPageRoute<Object?>(builder: (_) => screen);
    route.popped.then(ClientUnreachableScreenPopLog.results.add);
    return route;
  }

  @override
  Widget build(BuildContext context) {
    final bool? parentOnStack = fixture.parentOnStack;

    // A LOCAL Navigator, not the canvas's. Inheriting the ambient one would
    final Widget staged = parentOnStack == null
        ? screen
        : Navigator(
            onGenerateInitialRoutes:
                (NavigatorState navigator, String initialRoute) =>
                    <Route<Object?>>[
              if (parentOnStack)
                MaterialPageRoute<Object?>(
                  builder: (_) => const _ClientUnreachableScreenParent(),
                ),
              _screenRoute(),
            ],
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<Object?>(
              settings: settings,
              builder: (_) => screen,
            ),
          );

    final ClientUnreachableScreenWindow? window = fixture.window;
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

    // Unbind both axes. The render tests pump onto 800 x 600 and the phone
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// The page beneath the screen when it was reached from live tracking.
/// It only has to exist and to be identifiable, so a pop can be shown to reach
/// a page rather than to empty the navigator.
class _ClientUnreachableScreenParent extends StatelessWidget {
  const _ClientUnreachableScreenParent();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            clientUnreachableScreenParentLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
