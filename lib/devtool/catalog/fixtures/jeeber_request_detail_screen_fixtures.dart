// Shared dev-only fixtures for `JeeberRequestDetailScreen` — the jeeber-side

import 'package:flutter/material.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';

/// The prohibited-item reporting seam both dev surfaces pass in.
/// `ProhibitedItemReportService` is still the 2026-05-17 sanity-build stub — its
const ProhibitedItemReportService jeeberRequestDetailScreenReportService =
    ProhibitedItemReportService();

/// A by-id recovery that fails on transport — the loader's retryable rung
/// (LR-14), as distinct from a genuine miss.
Future<FeedRequest?> Function() throwingRequestDetailFetch(
  AppFailure failure,
) => () async => throw failure;

/// A by-id recovery that MISSES — the request is genuinely gone, so the loader
/// still lands on the unavailable screen.
Future<FeedRequest?> Function() missingRequestDetailFetch() => () async => null;

/// The [FeedRequest] payloads this screen is reviewed with.
/// Every one of them is a shape `_recoverFeedRequestById`
final class JeeberRequestDetailScreenRequests {
  JeeberRequestDetailScreenRequests._();

  /// G1 (sprint-009 P0), the reference reading: the client's own "What do you
  /// need?" text is present, so it leads the card in full.
  static const FeedRequest described = FeedRequest(
    id: 'req-101',
    shortLabel: 'Hamra, Beirut',
    description: '1 kilo potato, water gallon, coffee blend',
  );

  /// The legacy/edge payload: `description` is null, because it is optional on
  /// the feed DTO and older items carry none.
  static const FeedRequest withoutDescription = FeedRequest(
    id: 'req-102',
    shortLabel: 'Achrafieh, Beirut',
  );

  /// The longest plausible payload, and the only one shaped like production: a
  /// real gateway UUID, a pickup label with a landmark in it, and a shopping
  static const FeedRequest longest = FeedRequest(
    id: 'e30b7f2e-7914-402d-8dd3-e699e6775eae',
    shortLabel: 'Souq Waqif — gold souq entrance, Doha 30215',
    description: '2 kg Turkish coffee, extra fine grind, from the roastery '
        'beside the gold souq — plus 3 boxes of Ceylon tea if they have the '
        'green tin, and a litre of laban. Please check the roast date before '
        'you pay, and call me if the tea is out of stock instead of picking '
        'a substitute.',
  );

  /// The degraded payload, and the reason it is a fixture rather than a
  /// curiosity: `shortLabel` is EMPTY and there is no description either.
  static const FeedRequest unlabelledPickup = FeedRequest(
    id: '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145',
    shortLabel: '',
  );
}

/// One simulated device window to render `JeeberRequestDetailScreen` in.
@immutable
class JeeberRequestDetailScreenWindow {
  const JeeberRequestDetailScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Geometry half of the caption painted above the frame.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES the
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The named windows this screen is reviewed in.
/// Two devices at two text scales. The device axis matters because the action
final class JeeberRequestDetailScreenWindows {
  JeeberRequestDetailScreenWindows._();

  /// The reference device: a 390 x 844 handset with a 47 dp status bar and a
  /// 34 dp home indicator — what a jeeber taps a push or a feed row on.
  static const JeeberRequestDetailScreenWindow phone =
      JeeberRequestDetailScreenWindow(
    label: 'Phone · 390 × 844 · inset 47/34',
    size: Size(390, 844),
    insets: EdgeInsets.only(top: 47, bottom: 34),
  );

  /// The small-phone floor the app still has to survive — 320 x 568 (iPhone SE
  /// 1st gen / the small Android estate), no system chrome.
  static const JeeberRequestDetailScreenWindow compact =
      JeeberRequestDetailScreenWindow(
    label: 'Compact · 320 × 568 · no insets',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on the reference device.
  static const JeeberRequestDetailScreenWindow phoneLargeText =
      JeeberRequestDetailScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    insets: EdgeInsets.only(top: 47, bottom: 34),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text, against a bottom bar that does not shrink.
  static const JeeberRequestDetailScreenWindow compactLargeText =
      JeeberRequestDetailScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// Hosts `JeeberRequestDetailScreen` in one [JeeberRequestDetailScreenWindow],
/// captioned so a state wired to the wrong frame fails its render test instead
/// of looking plausible in the canvas.
class JeeberRequestDetailScreenPreviewHost extends StatelessWidget {
  const JeeberRequestDetailScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.payloadLabel,
  });

  /// The screen under review — `JeeberRequestDetailScreen(request: …)`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final JeeberRequestDetailScreenWindow? window;

  /// The payload half of the caption ("description present", "pickup label
  /// empty"). Appended to [JeeberRequestDetailScreenWindow.label] so that two
  final String? payloadLabel;

  /// The caption this host paints for [window] and [payloadLabel]. The render
  /// tests pin previews by it, so it is computed in one place.
  static String captionFor(
    JeeberRequestDetailScreenWindow window,
    String? payloadLabel,
  ) =>
      payloadLabel == null ? window.label : '${window.label} · $payloadLabel';

  @override
  Widget build(BuildContext context) {
    final JeeberRequestDetailScreenWindow? window = this.window;
    if (window == null) return screen;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Preview chrome, pinned to no scaling: a caption that grew with the
        MediaQuery.withNoTextScaling(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              captionFor(window, payloadLabel),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: screen),
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
