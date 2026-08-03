import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const String customerWalletStubScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// One simulated device window to render [CustomerWalletStubScreen] in.
/// The frame has to be pinned by the fixture rather than left to the canvas
@immutable
class CustomerWalletStubScreenWindow {
  const CustomerWalletStubScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class CustomerWalletStubScreenWindows {
  CustomerWalletStubScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const CustomerWalletStubScreenWindow phone =
      CustomerWalletStubScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class). This screen's content is a fixed-height column inside a
  static const CustomerWalletStubScreenWindow compact =
      CustomerWalletStubScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  /// The screen is mounted as a bare top-level `GoRoute` — `app_router.dart`
  static const CustomerWalletStubScreenWindow notched =
      CustomerWalletStubScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const CustomerWalletStubScreenWindow phoneLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. Both of this screen's paragraphs are long, so this is the state that
  static const CustomerWalletStubScreenWindow compactLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The notched phone at the accessibility ceiling — the one combination in
  /// which the body actually SCROLLS on a device that has a home indicator, and
  static const CustomerWalletStubScreenWindow notchedLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );
}

class CustomerWalletStubScreenPreviewHost extends StatefulWidget {
  const CustomerWalletStubScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
  });

  /// The screen under review — `const CustomerWalletStubScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final CustomerWalletStubScreenWindow? window;

  @override
  State<CustomerWalletStubScreenPreviewHost> createState() =>
      _CustomerWalletStubScreenPreviewHostState();
}

class _CustomerWalletStubScreenPreviewHostState
    extends State<CustomerWalletStubScreenPreviewHost> {
  late final GoRouter _router = GoRouter(
    // The wallet chip reaches this screen with a stack-REPLACING
    initialLocation: '/wallet/customer',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _CustomerWalletStubScreenShellStandIn(),
      ),
      GoRoute(
        path: '/wallet/customer',
        name: 'customer-wallet',
        builder: (_, _) => widget.screen,
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget routed = Router.withConfig(config: _router);
    final CustomerWalletStubScreenWindow? window = widget.window;
    if (window == null) return routed;

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
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbound both axes. The render tests pump onto 800 x 600 and every frame
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

class _CustomerWalletStubScreenShellStandIn extends StatelessWidget {
  const _CustomerWalletStubScreenShellStandIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            customerWalletStubScreenShellStandInLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
