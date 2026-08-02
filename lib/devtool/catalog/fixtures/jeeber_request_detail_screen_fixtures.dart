// Shared dev-only fixtures for `JeeberRequestDetailScreen` — the jeeber-side
// request hub at `/jeeber/requests/:id`, and the ONLY in-app entry to the
// offer-composition form.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_05_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart`.
//
// The catalog entry DID have fixtures, and they are extracted here verbatim:
// [JeeberRequestDetailScreenRequests.described] and
// [JeeberRequestDetailScreenRequests.withoutDescription] are byte-for-byte the
// payloads its two states ("With request description (G1)" / "Without
// description (legacy/edge payload)") were hand-built with, so the designer
// signs off against exactly what the canvas draws. The rest of the payloads
// below are new, and each exists because it is a shape the FEED can really
// produce — see their dartdoc.
//
// ## Network-free by construction
//
// `JeeberRequestDetailScreen` has no cubit, no repository and no GetIt lookup:
// it renders the [FeedRequest] it is handed and calls two callbacks. Its one
// injected dependency, [ProhibitedItemReportService], is a stub whose `report`
// awaits nothing (and which this screen never calls — see the preview section).
// So both hosts are network-free before `CatalogNetworkGuard` is consulted; the
// guard is the net, not the plan.
//
// ## Why WINDOWS are fixtures here
//
// The screen's data axis is thin — three optional-ish strings — and its real
// failure axis is geometry: a `Column` of `Expanded(scrolling summary)` over a
// FIXED-height action bar, inside a body whose height the device decides. The
// frame therefore has to be pinned by the fixture (a `MediaQuery` override plus
// a `SizedBox`) rather than left to the canvas `size:`, because the render
// tests in `test/previews/` pump onto a fixed 800 x 600 surface: a state that
// merely ASKED for a 320 x 568 canvas would be measured at 800 x 600 and every
// state would silently collapse into the same widget.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'package:flutter/material.dart';

import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';

/// The prohibited-item reporting seam both dev surfaces pass in.
///
/// `ProhibitedItemReportService` is still the 2026-05-17 sanity-build stub — its
/// `report()` is an empty `async` body — so this is inert by definition and
/// `const`, which keeps every fixture payload below `const` too.
const ProhibitedItemReportService jeeberRequestDetailScreenReportService =
    ProhibitedItemReportService();

/// The [FeedRequest] payloads this screen is reviewed with.
///
/// Every one of them is a shape `_recoverFeedRequestById`
/// (`app_router.dart:1830`) or the dashboard feed-row tap
/// (`jeeber_home_screen.dart:528`) can actually hand over: `shortLabel` is
/// `pickup.label` and `description` is `itemsSummary`, both straight off the
/// frozen jeeber feed item.
final class JeeberRequestDetailScreenRequests {
  JeeberRequestDetailScreenRequests._();

  /// G1 (sprint-009 P0), the reference reading: the client's own "What do you
  /// need?" text is present, so it leads the card in full.
  ///
  /// Verbatim the payload the Screen Catalog's "With request description (G1)"
  /// state was built with. Note the id: `req-101` starts with a
  /// `_humanReferencePrefixes` entry, so `friendlyReference` passes it through
  /// untouched instead of shortening it — the reference row reads `req-101`.
  static const FeedRequest described = FeedRequest(
    id: 'req-101',
    shortLabel: 'Hamra, Beirut',
    description: '1 kilo potato, water gallon, coffee blend',
  );

  /// The legacy/edge payload: `description` is null, because it is optional on
  /// the feed DTO and older items carry none.
  ///
  /// Verbatim the payload the catalog's "Without description (legacy/edge
  /// payload)" state was built with. The whole description row disappears, and
  /// what the jeeber is asked to bid on is a pickup label and a reference.
  static const FeedRequest withoutDescription = FeedRequest(
    id: 'req-102',
    shortLabel: 'Achrafieh, Beirut',
  );

  /// The longest plausible payload, and the only one shaped like production: a
  /// real gateway UUID, a pickup label with a landmark in it, and a shopping
  /// list a client actually types.
  ///
  /// G1 renders `description` FIRST and in full — `maxLines` is deliberately
  /// null — so this is the payload that decides whether the summary card
  /// scrolls or overflows. `friendlyReference` shortens the id to `#775EAE`.
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
  ///
  /// This is not synthetic. `DioRequestFeedRepository._parseRequest` documents
  /// "DEGRADE-DON'T-DROP" and falls back to
  /// `RequestLocation(label: '', latitude: 0, longitude: 0)` when the frozen
  /// feed omits `pickup` — dropping the item was "a second cause of the empty
  /// feed" — and `_parseFeedLocation` defaults `label` to `''` whenever the
  /// item carries coordinates but no `address`. That empty string is copied
  /// into `FeedRequest.shortLabel` unchanged, and this screen renders it
  /// unguarded.
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
  ///
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES the
  /// padding for everything below it, so the host has to put these back or the
  /// screen's own `SafeArea` would have nothing to clear.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The named windows this screen is reviewed in.
///
/// Two devices at two text scales. The device axis matters because the action
/// bar is a FIXED 156 dp (24 dp padding + 48 dp button + 12 dp gap + 48 dp
/// button + 24 dp padding) that the summary above it has to give way to; the
/// text axis matters because the summary is the only half that grows.
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
///
/// The screen is passed IN rather than constructed here, for two reasons: it
/// keeps this library free of a circular import back into the feature, and —
/// the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget its previews are named after,
/// so the `JeeberRequestDetailScreen(...)` has to appear below the banner in the
/// screen's own file.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form the Screen Catalog uses, where the device IS the
/// frame.
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
  /// states which share a payload and differ only in window — or share a window
  /// and differ only in payload — are still told apart by one string.
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
        // text scaler would take the credit for any overflow the screen caused
        // on its own in the 200% renderings.
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
    // here is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 dp — the
    // exact measurement the "does the summary still have room" assertions
    // depend on not being faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}
