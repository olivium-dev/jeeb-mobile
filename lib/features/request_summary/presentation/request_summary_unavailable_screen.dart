import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// Graceful fallback rendered when `/request-summary` is reached without a
/// `RequestDraft` (e.g. a cold deep-link). Replaces a raw scaffold that carried
/// hardcoded English copy, so the AR build no longer leaks English here.
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
