import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';

class JeeberRequestUnavailableScreen extends StatelessWidget {
  const JeeberRequestUnavailableScreen({
    super.key,
    required this.requestId,
    required this.onBack,
  });

  final String requestId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.requestUnavailableTitle),
      body: SafeArea(
        child: Semantics(
          identifier: 'jeeber_request_unavailable',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.large),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OmdsEmptyState(
                    key: const Key('jeeber-request-unavailable-state'),
                    icon: Icons.inbox_outlined,
                    title: l10n.requestUnavailableTitle,
                    subtitle: l10n.requestNoLongerAvailable(requestId),
                  ),
                  const SizedBox(height: Spacing.large),
                  OmdsPrimaryButton(
                    key: const Key('jeeber-request-unavailable-back-cta'),
                    text: l10n.requestUnavailableBrowseCta,
                    onTap: onBack,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
