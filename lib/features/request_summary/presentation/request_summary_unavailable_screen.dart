import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_summary_unavailable_screen_fixtures.dart';

class RequestSummaryUnavailableScreen extends StatelessWidget {
  const RequestSummaryUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.requestSummaryUnavailableTitle,
        showBackButton: true,
      ),
      body: Center(
        child: OmdsErrorState(
          key: const Key('request-summary-unavailable-state'),
          message: l10n.requestSummaryUnavailableBody,
          icon: Icons.inbox_outlined,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _requestSummaryUnavailableScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _requestSummaryUnavailableScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _requestSummaryUnavailableScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
/// The `const RequestSummaryUnavailableScreen()` is constructed HERE rather
Widget _requestSummaryUnavailableScreenHosted(
  RequestSummaryUnavailableScreenWindow? window, {
  bool? parentOnStack = true,
}) =>
    RequestSummaryUnavailableScreenPreviewHost(
      window: window,
      parentOnStack: parentOnStack,
      screen: const RequestSummaryUnavailableScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text,
/// and a page underneath so the back arrow is a real exit.
@JeebPreview(
  group: 'request_summary',
  name: 'Phone 390 × 844',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget requestSummaryUnavailableScreenPhone() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
/// Comfortable — 200 pt of content in the 512 pt the app bar leaves, 312 pt of
@JeebPreview(
  group: 'request_summary',
  name: 'Compact 320 × 568',
  size: _requestSummaryUnavailableScreenCompactCanvas,
)
Widget requestSummaryUnavailableScreenCompact() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
/// `/request-summary` is a bare top-level `GoRoute` — no `ShellRoute`, no
@JeebPreview(
  group: 'request_summary',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _requestSummaryUnavailableScreenNotchedCanvas,
)
Widget requestSummaryUnavailableScreenNotched() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
/// Holds together with room to spare — 360 pt of content inside the 788 pt the
@JeebPreview(
  group: 'request_summary',
  name: 'Phone · 200% text',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenLargeText() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
/// **It fits by 16 pt, and that is a measurement rather than a property.**
@JeebPreview(
  group: 'request_summary',
  name: 'Compact · 200% text',
  size: _requestSummaryUnavailableScreenCompactCanvas,
)
Widget requestSummaryUnavailableScreenCompactLargeText() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.compactLargeText,
    );

/// The same phone as the reference reading, with nothing underneath it.
/// This is the arrival this screen was WRITTEN for: a cold deep link straight
@JeebPreview(
  group: 'request_summary',
  name: 'Cold deep link · nothing to pop',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenDeepLink() =>
    _requestSummaryUnavailableScreenHosted(
      RequestSummaryUnavailableScreenWindows.phoneDeepLink,
      parentOnStack: false,
    );

/// The Screen Catalog's own state, rendered in the canvas.
/// No frame, no caption, no local Navigator — the form
@JeebPreview(
  group: 'request_summary',
  name: 'Catalog state · Unavailable',
  size: _requestSummaryUnavailableScreenPhoneCanvas,
)
Widget requestSummaryUnavailableScreenCatalogState() =>
    _requestSummaryUnavailableScreenHosted(null, parentOnStack: null);
