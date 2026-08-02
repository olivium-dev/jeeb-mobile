import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

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
