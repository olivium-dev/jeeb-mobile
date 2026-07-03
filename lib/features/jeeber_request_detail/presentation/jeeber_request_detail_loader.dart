import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';
import 'jeeber_request_detail_screen.dart';
import 'jeeber_request_unavailable_screen.dart';

/// How the by-id recovery resolved (run-20 pushD gap; run-22 accepted
/// redirect). `redirecting` keeps the loading scaffold on screen while the
/// route swap to the active-delivery screen happens post-frame.
enum _Resolution { loading, resolved, unavailable, redirecting }

/// Entry adapter for `/jeeber/requests/:id` that lets a PUSH tap land on the
/// request detail instead of the "unavailable" fallback.
///
/// Two entry-points reach the route (T-mobile-013):
///   * A feed-row tap hands over the [FeedRequest] via `extra` (or the warm
///     [RequestFeedService] cache), so [initial] is non-null and the detail
///     renders synchronously — the cache-hit path is unchanged.
///   * A PUSH tap carries only the id. The warm feed cache does NOT contain a
///     request created after it was last populated (run-20: a request created
///     seconds before the tap), so [initial] is null. This widget then FETCHES
///     the request by id from the jeeber discovery feed ([fetch]) before
///     deciding — recovering the exact request the push was about.
///
/// Run-22 replacement P1: the discovery feed is `status=pending`-scoped, so a
/// request that was just ACCEPTED (assigned to this jeeber) rightly vanishes
/// from it — the old flow then showed "Request unavailable" for a request the
/// jeeber is actively delivering. On a feed miss the loader now probes
/// [fetchAcceptedDeliveryId] (a by-id delivery read; deliveryId == requestId
/// convention): when an active delivery exists, [onAcceptedRedirect] routes to
/// the jeeber active-delivery screen instead of the dead end.
///
/// A genuinely missing/expired request (the [fetch] returns null or throws AND
/// the accepted probe misses) still lands on the graceful
/// [JeeberRequestUnavailableScreen]: the run-20 fallback is preserved for the
/// cases it was designed for.
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

  /// The request id from the route path.
  final String requestId;

  /// The payload recovered synchronously from `extra` / the warm feed cache.
  /// Non-null ⇒ cache hit ⇒ render detail immediately, no fetch.
  final FeedRequest? initial;

  /// Backend recovery used only on a cache miss (push-tap). Returns the mapped
  /// [FeedRequest] for [requestId], or null when the id is not among the
  /// jeeber's visible pending requests (matched / expired / offline).
  final Future<FeedRequest?> Function() fetch;

  final ProhibitedItemReportService reportService;
  final ValueChanged<String> onDeclined;
  final VoidCallback onBack;

  /// Probe run only AFTER [fetch] misses: resolves the ACTIVE (non-terminal)
  /// delivery id this request became when an offer was accepted, or null when
  /// none exists. Optional — when absent the run-20 unavailable fallback is
  /// unchanged.
  final Future<String?> Function()? fetchAcceptedDeliveryId;

  /// Invoked once (post-frame) with the probed delivery id so the route can
  /// swap to the jeeber active-delivery screen.
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
    // Feed miss — the pending-scoped feed rightly excludes an ACCEPTED
    // request (run-22). Probe for the active delivery before giving up.
    final deliveryId = await _probeAcceptedDelivery();
    if (!mounted) return;
    if (deliveryId != null && widget.onAcceptedRedirect != null) {
      setState(() => _status = _Resolution.redirecting);
      // Route swaps must not happen mid-build.
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

/// Loading scaffold shown while the push-tap request is fetched by id. Mirrors
/// the detail screen's app-bar so the transition to the resolved detail (or the
/// unavailable fallback) does not jump.
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
