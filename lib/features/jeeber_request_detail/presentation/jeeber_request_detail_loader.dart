import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';
import 'jeeber_request_detail_screen.dart';
import 'jeeber_request_unavailable_screen.dart';

/// How the by-id recovery resolved (run-20 pushD gap).
enum _Resolution { loading, resolved, unavailable }

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
/// A genuinely missing/expired request (the [fetch] returns null or throws)
/// still lands on the graceful [JeeberRequestUnavailableScreen]: the run-20
/// fallback is preserved for the cases it was designed for.
class JeeberRequestDetailLoader extends StatefulWidget {
  const JeeberRequestDetailLoader({
    super.key,
    required this.requestId,
    required this.initial,
    required this.fetch,
    required this.reportService,
    required this.onDeclined,
    required this.onBack,
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
    try {
      final recovered = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _request = recovered;
        _status = recovered != null
            ? _Resolution.resolved
            : _Resolution.unavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Resolution.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _Resolution.loading =>
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
