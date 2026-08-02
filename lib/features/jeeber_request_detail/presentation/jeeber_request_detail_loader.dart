import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';
import 'jeeber_request_detail_screen.dart';
import 'jeeber_request_unavailable_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

enum _Resolution { loading, resolved, unavailable, redirecting }

class JeeberRequestDetailLoader extends StatefulWidget {
  const JeeberRequestDetailLoader({
    super.key,
    required this.requestId,
    required this.initial,
    required this.fetch,
    required this.reportService,
    required this.onDeclined,
    required this.onBack,
    this.fetchAcceptedDeliveryId,
    this.onAcceptedRedirect,
  });

  final String requestId;

  final FeedRequest? initial;

  final Future<FeedRequest?> Function() fetch;

  final ProhibitedItemReportService reportService;
  final ValueChanged<String> onDeclined;
  final VoidCallback onBack;

  final Future<String?> Function()? fetchAcceptedDeliveryId;

  final ValueChanged<String>? onAcceptedRedirect;

  @override
  State<JeeberRequestDetailLoader> createState() =>
      _JeeberRequestDetailLoaderState();
}

class _JeeberRequestDetailLoaderState extends State<JeeberRequestDetailLoader> {
  late _Resolution _status;
  FeedRequest? _request;

  @override
  void initState() {
    super.initState();
    _request = widget.initial;
    _status =
        _request != null ? _Resolution.resolved : _Resolution.loading;
    if (_request == null) _recover();
  }

  Future<void> _recover() async {
    FeedRequest? recovered;
    try {
      recovered = await widget.fetch();
    } catch (_) {
      recovered = null;
    }
    if (!mounted) return;
    if (recovered != null) {
      setState(() {
        _request = recovered;
        _status = _Resolution.resolved;
      });
      return;
    }
    final deliveryId = await _probeAcceptedDelivery();
    if (!mounted) return;
    if (deliveryId != null && widget.onAcceptedRedirect != null) {
      setState(() => _status = _Resolution.redirecting);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAcceptedRedirect!(deliveryId);
      });
      return;
    }
    setState(() => _status = _Resolution.unavailable);
  }

  Future<String?> _probeAcceptedDelivery() async {
    final probe = widget.fetchAcceptedDeliveryId;
    if (probe == null) return null;
    try {
      final id = await probe();
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _Resolution.loading ||
      _Resolution.redirecting =>
        JeeberRequestDetailLoadingView(requestId: widget.requestId),
      _Resolution.resolved => JeeberRequestDetailScreen(
          request: _request!,
          reportService: widget.reportService,
          onDeclined: widget.onDeclined,
        ),
      _Resolution.unavailable => JeeberRequestUnavailableScreen(
          requestId: widget.requestId,
          onBack: widget.onBack,
        ),
    };
  }
}

class JeeberRequestDetailLoadingView extends StatelessWidget {
  const JeeberRequestDetailLoadingView({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.jeeberRequestDetailTitle,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Semantics(
          identifier: 'jeeber-request-detail-loading',
          child: const Center(child: OmdsLoadingState()),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A phone body box: 390 dp wide, and as tall as an 844 dp phone leaves once
/// the status bar and home indicator are taken out. Every state uses the SAME
const Size _jeeberRequestDetailLoaderPhoneBox = Size(390, 700);

/// The request id the loader's branch tests use, so the canvas and the tests
/// describe the same request.
const String _jeeberRequestDetailLoaderId =
    'e30b7f2e-7914-402d-8dd3-e699e6775eae';

/// A second id, used only by the offline state — the two dead ends render
/// identical copy apart from the id, and different ids make that visible
const String _jeeberRequestDetailLoaderOfflineId =
    '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145';

/// The feed-row payload: what `extra` / the warm feed cache hands over. Lean
/// on purpose — the feed's `description` is optional, and this is the shape a
const FeedRequest _jeeberRequestDetailLoaderCached = FeedRequest(
  id: _jeeberRequestDetailLoaderId,
  shortLabel: 'Souq Waqif pickup',
);

/// The longest plausible by-id recovery: a real shopping request typed into
/// "What do you need?", plus a pickup label with a landmark in it.
const FeedRequest _jeeberRequestDetailLoaderLongRequest = FeedRequest(
  id: _jeeberRequestDetailLoaderId,
  shortLabel: 'Souq Waqif — gold souq entrance, Doha 30215',
  description: '2 kg Turkish coffee, extra fine grind, from the roastery '
      'beside the gold souq — plus 3 boxes of Ceylon tea if they have the '
      'green tin. Please check the roast date before you pay.',
);

/// A by-id feed read that NEVER answers, which is what the loading resolution
/// actually is: the request is in flight.
Future<FeedRequest?> _jeeberRequestDetailLoaderPending() =>
    Future.any<FeedRequest?>(const <Future<FeedRequest?>>[]);

/// Mounts the loader the way `/jeeber/requests/:id` does, with every seam a
/// canned closure.
Widget _jeeberRequestDetailLoaderHosted({
  String id = _jeeberRequestDetailLoaderId,
  FeedRequest? initial,
  Future<FeedRequest?> Function()? fetch,
  Future<String?> Function()? probeAcceptedDelivery,
}) {
  return TickerMode(
    enabled: false,
    child: JeeberRequestDetailLoader(
      requestId: id,
      initial: initial,
      fetch: fetch ?? _jeeberRequestDetailLoaderPending,
      fetchAcceptedDeliveryId: probeAcceptedDelivery,
      onAcceptedRedirect: (_) {},
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
      onBack: () {},
    ),
  );
}

/// The unchanged path: a feed-row tap handed the payload over in `extra`, so
/// the detail renders on the FIRST frame — no loading flash, and `fetch` is
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Feed-row tap · cached payload',
  size: _jeeberRequestDetailLoaderPhoneBox,
)
Widget jeeberRequestDetailLoaderCacheHit() =>
    _jeeberRequestDetailLoaderHosted(
      initial: _jeeberRequestDetailLoaderCached,
    );

/// run-20, mid-flight: a push tap carries only an id, the warm feed cache
/// never held a request created seconds ago, so the loader is fetching it.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Push tap · recovering by id',
  size: _jeeberRequestDetailLoaderPhoneBox,
)
Widget jeeberRequestDetailLoaderRecovering() =>
    _jeeberRequestDetailLoaderHosted();

/// run-20 resolved, with the longest content the detail can carry: the by-id
/// read found the request and the client's own text renders first, in full.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Push tap · recovered',
  size: _jeeberRequestDetailLoaderPhoneBox,
  matrix: true,
)
Widget jeeberRequestDetailLoaderRecovered() => _jeeberRequestDetailLoaderHosted(
      fetch: () async => _jeeberRequestDetailLoaderLongRequest,
    );

/// The dead end the run-20 fallback was designed for: the id really is gone —
/// expired, cancelled, or matched to another jeeber — so the pending-scoped
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Feed miss · no longer available',
  size: _jeeberRequestDetailLoaderPhoneBox,
  matrix: true,
)
Widget jeeberRequestDetailLoaderUnavailable() =>
    _jeeberRequestDetailLoaderHosted(fetch: () async => null);

/// The same dead end reached for the opposite reason: the request is fine and
/// the JEEBER is offline, so `fetch` throws and `_recover` swallows it.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Feed offline · same dead end',
  size: _jeeberRequestDetailLoaderPhoneBox,
)
Widget jeeberRequestDetailLoaderOffline() => _jeeberRequestDetailLoaderHosted(
      id: _jeeberRequestDetailLoaderOfflineId,
      fetch: () async => throw Exception('feed offline'),
    );

/// run-22: the request was ACCEPTED by this jeeber, so the `status=pending`
/// discovery feed rightly no longer lists it. The by-id probe finds the active
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Accepted · redirecting',
  size: _jeeberRequestDetailLoaderPhoneBox,
)
Widget jeeberRequestDetailLoaderRedirecting() =>
    _jeeberRequestDetailLoaderHosted(
      fetch: () async => null,
      probeAcceptedDelivery: () async => _jeeberRequestDetailLoaderId,
    );

// ─── JeeberRequestDetailLoadingView ────────────────────────────────────────

/// The phone a push tap lands on: a 390 × 844 handset with a 47 dp status bar
/// and a 34 dp home indicator.
const Size _jeeberRequestDetailLoadingViewPhoneFrame = Size(390, 844);
const EdgeInsets _jeeberRequestDetailLoadingViewPhoneInsets = EdgeInsets.only(
  top: 47,
  bottom: 34,
);

/// The small-phone floor the app still has to survive — a 320 × 568 handset
/// (iPhone SE 1 / the small Android estate), no insets.
const Size _jeeberRequestDetailLoadingViewCompactFrame = Size(320, 568);

/// The same phone rotated. A push tap can arrive while the device is in
/// landscape, and the body is a single centred child with no scroll view.
const Size _jeeberRequestDetailLoadingViewLandscapeFrame = Size(852, 393);
const EdgeInsets _jeeberRequestDetailLoadingViewLandscapeInsets =
    EdgeInsets.only(left: 59, right: 59, bottom: 21);

/// Canvas boxes: the simulated frame, its 1 pt outline and the caption strip.
const Size _jeeberRequestDetailLoadingViewPhoneBox = Size(402, 888);
const Size _jeeberRequestDetailLoadingViewCompactBox = Size(332, 612);
const Size _jeeberRequestDetailLoadingViewLandscapeBox = Size(864, 437);

/// The route id `jeeber_request_detail_loader_test.dart` pins, so the canvas
/// and the branch tests describe the same request.
const String _jeeberRequestDetailLoadingViewRequestId =
    'e30b7f2e-7914-402d-8dd3-e699e6775eae';

/// The id the redirect state carries instead (deliveryId == requestId), used
/// only to demonstrate that nothing on this screen depends on it.
const String _jeeberRequestDetailLoadingViewDeliveryId =
    '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145';

/// Simulates one window around [JeeberRequestDetailLoadingView] and captions
/// it.
/// The view is a full-bleed [Scaffold] that takes whatever box it is given, so
class _JeeberRequestDetailLoadingViewFrame extends StatelessWidget {
  const _JeeberRequestDetailLoadingViewFrame({
    required this.label,
    required this.frame,
    required this.requestId,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  final String label;
  final Size frame;
  final String requestId;
  final EdgeInsets insets;
  final double? textScale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Preview chrome, pinned to no scaling: a caption that grew with the
        MediaQuery.withNoTextScaling(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              label,
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
              size: frame,
              padding: insets,
              viewPadding: insets,
              viewInsets: EdgeInsets.zero,
              textScaler: textScale == null
                  ? null
                  : TextScaler.linear(textScale!),
            ),
            child: SizedBox.fromSize(
              size: frame,
              // `OmdsLoadingState` is an indeterminate progress indicator; it
              child: TickerMode(
                enabled: false,
                child: JeeberRequestDetailLoadingView(requestId: requestId),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unbounds both axes so a simulated frame taller or wider than the host is
/// rendered at its real size instead of clamped to it — the render tests pump
Widget _jeeberRequestDetailLoadingViewHosted({
  required String label,
  Size frame = _jeeberRequestDetailLoadingViewPhoneFrame,
  EdgeInsets insets = _jeeberRequestDetailLoadingViewPhoneInsets,
  String requestId = _jeeberRequestDetailLoadingViewRequestId,
  double? textScale,
}) =>
    SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _JeeberRequestDetailLoadingViewFrame(
          label: label,
          frame: frame,
          insets: insets,
          requestId: requestId,
          textScale: textScale,
        ),
      ),
    );

/// The reference reading: run-20's push tap, mid-recovery, on the phone the
/// jeeber is holding.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Loading scaffold · phone 390 × 844',
  size: _jeeberRequestDetailLoadingViewPhoneBox,
  matrix: true,
)
Widget jeeberRequestDetailLoadingViewPushTap() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Push tap · by-id fetch in flight · 390 × 844 · inset 47/34',
    );

/// run-22's redirect hold, and the point of previewing this view separately:
/// it is PIXEL-IDENTICAL to the state above.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Redirect hold · same frame, other id',
  size: _jeeberRequestDetailLoadingViewPhoneBox,
)
Widget jeeberRequestDetailLoadingViewRedirectHold() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Redirect hold · route swap pending · 390 × 844 · inset 47/34',
      requestId: _jeeberRequestDetailLoadingViewDeliveryId,
    );

/// The small-phone floor: 320 × 568, no insets.
/// The layout has almost nothing to give — a fixed 56 dp toolbar and a 48 dp
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact phone 320 × 568',
  size: _jeeberRequestDetailLoadingViewCompactBox,
)
Widget jeeberRequestDetailLoadingViewCompactPhone() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Compact phone · 320 × 568 · no insets',
      frame: _jeeberRequestDetailLoadingViewCompactFrame,
      insets: EdgeInsets.zero,
    );

/// The short viewport: the same phone rotated, tapped from the notification
/// shade in landscape.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Landscape 852 × 393',
  size: _jeeberRequestDetailLoadingViewLandscapeBox,
)
Widget jeeberRequestDetailLoadingViewLandscape() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Landscape · 852 × 393 · inset 59/59/21',
      frame: _jeeberRequestDetailLoadingViewLandscapeFrame,
      insets: _jeeberRequestDetailLoadingViewLandscapeInsets,
    );

/// The accessibility ceiling, pinned into the tree rather than left to the
/// canvas matrix so the render test measures the same layout the canvas draws.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Text ceiling · EN 200%',
  size: _jeeberRequestDetailLoadingViewPhoneBox,
)
Widget jeeberRequestDetailLoadingViewLargeText() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Text ceiling · EN 200% · 390 × 844 · inset 47/34',
      textScale: 2.0,
    );

/// The two ceilings together — the 320 dp floor at 200 % text — and the state
/// to actually look at, because it is the only one with anything to lose.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Compact 320 × 568 · EN 200%',
  size: _jeeberRequestDetailLoadingViewCompactBox,
)
Widget jeeberRequestDetailLoadingViewCompactLargeText() =>
    _jeeberRequestDetailLoadingViewHosted(
      label: 'Compact + 200% · 320 × 568 · title band 216 dp',
      frame: _jeeberRequestDetailLoadingViewCompactFrame,
      insets: EdgeInsets.zero,
      textScale: 2.0,
    );
