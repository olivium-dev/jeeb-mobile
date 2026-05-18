import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Stub created by sanity-build pass (2026-05-17). Shown when the router
/// can't resolve a FeedRequest for `/jeeber/requests/:id` (cold deep link
/// after the request was matched/cancelled/expired).
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
    return Scaffold(
      appBar: const OMDSAppBar(title: 'Request unavailable'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Request $requestId is no longer available.'),
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(text: 'Back', onTap: onBack),
          ],
        ),
      ),
    );
  }
}
