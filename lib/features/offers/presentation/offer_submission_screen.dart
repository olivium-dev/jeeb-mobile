import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../domain/offer_submission_service.dart';

/// Stub created by sanity-build pass (2026-05-17). app_router.dart routes
/// `/jeeber/requests/:id/offer` here. The wave-2-4 batch created a different
/// screen at `lib/features/offer_submission/` that is NOT wired into the
/// router. This stub satisfies the router's call site; the other implementation
/// will be reconciled in a follow-up.
class OfferSubmissionScreen extends StatelessWidget {
  const OfferSubmissionScreen({
    super.key,
    required this.requestId,
    required this.submissionService,
    required this.onWithdrawn,
  });

  final String requestId;
  final OfferSubmissionService submissionService;
  final VoidCallback onWithdrawn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(
        title: 'Submit offer — $requestId',
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onWithdrawn,
        ),
      ),
      body: Center(child: Text('Offer submission stub for $requestId')),
    );
  }
}
