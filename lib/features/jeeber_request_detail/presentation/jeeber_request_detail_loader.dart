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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/jeeber_request_detail/jeeber_request_detail_loader_preview_test.dart
// test/previews/jeeber_request_detail/jeeber_request_detail_loading_view_preview_test.dart
// ===========================================================================
//
// This widget is a ROUTER, not a surface: it owns four resolutions
// (`loading`, `resolved`, `unavailable`, `redirecting`) and renders one of
// three screens. The previews below are one per resolution, plus the two
// causes of the dead end, because the whole class of bugs this loader exists
// to fix — run-20's push tap landing on "Request unavailable", run-22's
// accepted request landing there too — is a resolution picked wrongly. In the
// canvas you are reviewing WHICH screen came up, and how it reads.
//
// Network-free by construction: `fetch` and `fetchAcceptedDeliveryId` are
// plain closures on this widget, so a fixture is a one-line function and no
// repository (Dio-backed or otherwise) is ever built. The guard in
// [jeebPreviewHost] is the net, not the plan.
//
// The fixture ids and the "Souq Waqif pickup" label are the ones
// `test/features/jeeber_request_detail/jeeber_request_detail_loader_test.dart`
// already pins, so the canvas and the branch tests describe the same request.
//
// [TickerMode] is disabled around every state: the loading scaffold's
// [OmdsLoadingState] is an indeterminate spinner that never stops scheduling
// frames, which would hang the render tests' `pumpAndSettle`. A still preview
// wants a still spinner anyway.
//
// THREE THINGS THE CANVAS SHOWS THAT THE BRANCH TESTS DO NOT, all pinned as
// assertions in the render test:
//
// * **The unavailable fallback prints the RAW UUID.** The resolved detail
//   screen shortens the id to `#775EAE` (sprint-009 audit §T5,
//   `friendlyReference`); the fallback this same loader routes to hands the
//   raw route id straight to `requestNoLongerAvailable`, so the jeeber reads
//   "Request e30b7f2e-7914-402d-8dd3-e699e6775eae is no longer available." Put
//   `Feed miss · no longer available` next to `Push tap · recovered` and the
//   inconsistency is the first thing you see. In AR it is also a 36-character
//   LTR run dropped into an RTL sentence — which is why that state carries the
//   matrix.
// * **A dead request and a dead network are the same screen.** `_recover`
//   catches every `fetch` error and falls through to the same terminal state,
//   with no retry affordance anywhere — `Feed offline · same dead end` differs
//   from `Feed miss · no longer available` only in the id it happens to print.
// * **At 200% text the dead end has no reachable affordance at all.** Measured
//   in the 390x700 box these previews declare: the fallback is a bare centred
//   `Column` with no scroll view, so it overflows by 240 dp in EN / 72 dp in
//   AR and lays "Browse other requests" — the only thing on the screen a
//   jeeber can act on — out at y 872 / y 704, below the viewport, with nothing
//   to scroll it back. The resolved branch of this same loader survives the
//   same box because its summary scrolls and its action bar is pinned.
//
// And one that is a property of the design rather than a defect: `Push tap ·
// recovering by id` and `Accepted · redirecting` are the SAME frame. The
// redirect branch deliberately holds the loading scaffold up while the route
// swap happens post-frame, so there is nothing to distinguish "still fetching"
// from "about to jump to your active delivery" — including the requestId this
// scaffold takes and never renders.

/// A phone body box: 390 dp wide, and as tall as an 844 dp phone leaves once
/// the status bar and home indicator are taken out. Every state uses the SAME
/// box on purpose — the loading scaffold exists to mirror the detail screen's
/// app bar so the transition does not jump, and that claim is only reviewable
/// when the two are drawn at one size.
const Size _jeeberRequestDetailLoaderPhoneBox = Size(390, 700);

/// The request id the loader's branch tests use, so the canvas and the tests
/// describe the same request.
const String _jeeberRequestDetailLoaderId =
    'e30b7f2e-7914-402d-8dd3-e699e6775eae';

/// A second id, used only by the offline state — the two dead ends render
/// identical copy apart from the id, and different ids make that visible
/// instead of looking like one card drawn twice.
const String _jeeberRequestDetailLoaderOfflineId =
    '4d1c90ab-5f22-4c17-9d0e-0b6a3f77c145';

/// The feed-row payload: what `extra` / the warm feed cache hands over. Lean
/// on purpose — the feed's `description` is optional, and this is the shape a
/// legacy payload still arrives in.
const FeedRequest _jeeberRequestDetailLoaderCached = FeedRequest(
  id: _jeeberRequestDetailLoaderId,
  shortLabel: 'Souq Waqif pickup',
);

/// The longest plausible by-id recovery: a real shopping request typed into
/// "What do you need?", plus a pickup label with a landmark in it.
///
/// G1 renders `description` FIRST and in full — no truncation — so this is the
/// state that decides whether the summary card scrolls or overflows.
const FeedRequest _jeeberRequestDetailLoaderLongRequest = FeedRequest(
  id: _jeeberRequestDetailLoaderId,
  shortLabel: 'Souq Waqif — gold souq entrance, Doha 30215',
  description: '2 kg Turkish coffee, extra fine grind, from the roastery '
      'beside the gold souq — plus 3 boxes of Ceylon tea if they have the '
      'green tin. Please check the roast date before you pay.',
);

/// A by-id feed read that NEVER answers, which is what the loading resolution
/// actually is: the request is in flight.
///
/// `Future.any` over an empty list is a future nobody completes. Deliberately
/// not `Future.delayed` — that arms a real timer, and `flutter_test` fails a
/// test that ends with one pending.
Future<FeedRequest?> _jeeberRequestDetailLoaderPending() =>
    Future.any<FeedRequest?>(const <Future<FeedRequest?>>[]);

/// Mounts the loader the way `/jeeber/requests/:id` does, with every seam a
/// canned closure.
///
/// [fetch] defaults to the never-answering read, so a state that does not name
/// one is the in-flight state.
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
/// never called.
///
/// The payload carries no `description` (the field is optional on the feed
/// DTO), which is the reading worth having next to the recovered state below:
/// with nothing the client typed, all the jeeber is offered to decide on is a
/// pickup label and a reference.
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
///
/// This scaffold is the whole fix for the original defect — before it, this
/// moment WAS "Request unavailable". Note what it does not say: no request
/// reference, no "finding your request", nothing that survives a slow network
/// as an explanation. `requestId` is taken by the scaffold and never rendered.
@JeebPreview(
  group: 'jeeber_request_detail',
  name: 'Push tap · recovering by id',
  size: _jeeberRequestDetailLoaderPhoneBox,
)
Widget jeeberRequestDetailLoaderRecovering() =>
    _jeeberRequestDetailLoaderHosted();

/// run-20 resolved, with the longest content the detail can carry: the by-id
/// read found the request and the client's own text renders first, in full.
///
/// The matrix is here because this is the state where length bites: in AR the
/// labels flip while the client's own English text stays LTR inside them, and
/// at 200% the description alone is taller than the phone.
///
/// It holds up — and it is the control for the dead end. `_RequestSummary`
/// scrolls and the action bar under it is pinned, so at 200% in a 390x700 box
/// there is no overflow and "Send your offer" is still on screen.
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
/// feed rightly misses and no active delivery exists.
///
/// The matrix is here for the subtitle. It interpolates the RAW route id, so
/// the jeeber reads a 36-character UUID the resolved screen would have shown
/// as `#775EAE`; in the AR rendering that LTR run sits inside an RTL sentence,
/// which is the reading that shows what it costs. The 200% rendering is where
/// it stops being cosmetic: this screen does not scroll, and the extra lines
/// push "Browse other requests" clean off the bottom of the phone.
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
///
/// Nothing on this screen says "you are offline", and the only affordance is
/// "Browse other requests" — a second network read that will fail the same
/// way. Side by side with the state above, the ONLY difference is the id.
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
/// delivery and the route swaps to it post-frame.
///
/// What renders meanwhile is the loading scaffold — pixel-identical to
/// `Push tap · recovering by id`. That is deliberate (the swap must not happen
/// mid-build) and it is also the gap: the jeeber gets no signal that they are
/// being taken to a delivery they already own rather than kept waiting.
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
//
// The scaffold the loader above holds up for BOTH `_Resolution.loading` and
// `_Resolution.redirecting`, previewed on its own.
//
// It has no data axis at all. The view takes one argument, `requestId`, and
// never draws it: `build` is `jeeberRequestDetailTitle` in an [OMDSAppBar]
// plus a centred 48 dp indeterminate spinner, and even the `Semantics`
// identifier is a constant. No fixture can make two states of it differ — the
// render test pins that by pumping two different ids and measuring the same
// frame.
//
// What CAN change the picture is the window it is handed and the text scale,
// so those are the six states below: the phone a push tap lands on, the same
// phone held for a redirect, the 320 dp floor, a rotated phone, and both
// ceilings — 200 % text on the phone and 200 % text on the floor. Each window
// is pinned INSIDE its preview with a [MediaQuery] + [SizedBox] rather than
// left to the annotation `size`, for the reason `branded_splash.dart`
// documents — the canvas honours `size`, but the render tests pump onto a
// fixed 800 × 600 surface, so states that merely ASKED for six canvases would
// all be measured at 800 × 600 and silently collapse into one. The caption
// above each frame is what tells them apart, in the canvas and in the test.
//
// Network-free by construction: there is nothing to seed, no cubit and no
// repository, so [jeebPreviewHost]'s `CatalogNetworkGuard` is pure net here.
//
// What the canvas shows that the branch tests do not:
//
// * **The only text on the screen is the app-bar title**, and it is the title
//   of a screen that is not there yet — "Request details" over an empty body.
//   Nothing says which request, nothing says "finding it", and there is no
//   elapsed hint, retry or cancel; the sole control is a Back button that
//   `OMDSAppBar` wires to `Navigator.maybePop()`.
// * **The spinner is centred in the BODY, not in the screen.** A 47 dp status
//   bar and a 56 dp toolbar come off the top and only the 34 dp home indicator
//   comes off the bottom, so the one moving element on the screen sits 34.5 dp
//   BELOW the centre of the glass. Obvious against the phone frame, invisible
//   without one, and pinned in the render test.
// * **Exactly one element responds to the text scaler**, and Material clamps
//   it: at a 2.0 scaler the title grows by 1.34, not by 2, while the 48 dp
//   indicator ignores the scaler entirely. That ratio is the honest half of
//   the 200 % story. The other half — whether the clamped title still FITS —
//   is a real-font question the render tests cannot answer, because widget
//   tests lay text out in the square test font. They pin the band the toolbar
//   reserves (286 dp on a 390 dp phone, 216 dp on the 320 dp floor) and that
//   the title stays inside it; the canvas, drawing the shipped font, is where
//   truncation is a thing you can see.
// * **Mirroring is symmetric**, which is the RTL property worth pinning: the
//   back arrow swaps edges and the title's offset from the axis in AR is the
//   exact negative of its offset in EN, whatever the font does to the string.

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
///
/// The view is a full-bleed [Scaffold] that takes whatever box it is given, so
/// a preview returning it bare would render the host's box and say nothing
/// about the device. This pins both the layout box and the [MediaQuery] its
/// [SafeArea] reads, and labels the result so a state wired to the wrong frame
/// fails the render test instead of looking plausible.
///
/// The caption and the outline are fixtures. Nothing here is production.
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
        // text scaler would take the credit for any overflow the widget caused
        // on its own in the 200% rendering.
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
              // never stops scheduling frames, so a live one hangs the render
              // tests' `pumpAndSettle`. A still preview wants a still spinner.
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
/// onto 800 × 600, which every frame below is taller than and one is wider
/// than.
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
///
/// This frame is the entire fix for the original defect — before the loader
/// existed, this moment was "Request unavailable". Read it for what is NOT
/// here: no reference to the request being fetched, no progress copy, no
/// timeout, no cancel. The matrix is on this state because it is the one to
/// check mirroring on — the AR rendering must move the back arrow to the
/// trailing edge and mirror the title's offset with it — and because the
/// 200 % rendering beside it is where you can see, in the shipped font, how
/// much of "Request details" the toolbar's 1.34 clamp leaves standing.
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
///
/// The request was accepted, the probe found the active delivery, and the
/// loader keeps this scaffold up while the route swap runs post-frame. The id
/// is a different one here (a delivery id) and nothing moves, because the view
/// never renders it — so a jeeber cannot tell "still fetching" from "about to
/// be taken to a delivery you already own", and a stalled redirect looks
/// exactly like a slow network. The render test measures both frames and
/// asserts they match.
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
///
/// The layout has almost nothing to give — a fixed 56 dp toolbar and a 48 dp
/// indicator — so this is where the title runs out of width first. At default
/// text it is comfortable, and the indicator still sits below the middle of
/// the glass because the toolbar is a bigger bite out of a 568 dp screen than
/// out of an 844 dp one. See
/// [jeeberRequestDetailLoadingViewCompactLargeText] for what this box does at
/// the accessibility ceiling.
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
///
/// 393 dp tall before the 56 dp toolbar and the 21 dp home indicator come off,
/// which leaves the body 316 dp for a 48 dp indicator — it holds, and the
/// useful part is the measurement. The width is the other half: the indicator
/// is centred in 852 dp of empty surface, so on a rotated device the one
/// element that says "something is happening" is a small mark in a very large
/// void.
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
///
/// This is the state that breaks a body with copy in it — and the reason it
/// survives here is that there IS no copy. The toolbar keeps its 56 dp, the
/// title grows by 1.34 rather than 2 (Material clamps toolbar text scaling),
/// and the indicator is a fixed 48 dp box that never reads the scaler at all.
/// A user at 200 % gets the same screen as everyone else — which on a surface
/// with nothing to read is the right answer for the wrong reason.
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
///
/// The toolbar hands the title the band left between the back button and the
/// trailing gap: 320 − 56 − 16 − 32 = **216 dp**, seventy less than the same
/// state gets on a 390 dp phone, against a title that has grown by 1.34. This
/// is the reading that decides whether "Request details" ellipsizes on a small
/// phone at the accessibility ceiling — and it has to be READ, not asserted:
/// widget tests lay text out in the square test font, so the render test can
/// only pin the band and the containment, never the truncation. The canvas
/// draws the shipped font. That is the division of labour.
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
