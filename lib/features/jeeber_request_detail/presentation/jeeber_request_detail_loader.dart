import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';
import 'jeeber_request_detail_screen.dart';
import 'jeeber_request_unavailable_screen.dart';

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
