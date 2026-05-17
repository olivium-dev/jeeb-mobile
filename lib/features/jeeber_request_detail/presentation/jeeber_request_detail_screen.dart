import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../jeeber_home/domain/entities/feed_request.dart';
import '../domain/services/prohibited_item_report_service.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// Deviation note: router call-site requires `request`, `reportService`, and
// `onDeclined`; fields are retained but unused so the import-graph stays green.
class JeeberRequestDetailScreen extends StatefulWidget {
  const JeeberRequestDetailScreen({
    super.key,
    required this.request,
    required this.reportService,
    required this.onDeclined,
  });

  final FeedRequest request;
  final ProhibitedItemReportService reportService;
  final ValueChanged<String> onDeclined;

  @override
  State<JeeberRequestDetailScreen> createState() =>
      _JeeberRequestDetailScreenState();
}

class _JeeberRequestDetailScreenState extends State<JeeberRequestDetailScreen> {
  static const _featureId = 'jeeber-request-detail';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Jeeber Request Detail coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Jeeber Request Detail coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
