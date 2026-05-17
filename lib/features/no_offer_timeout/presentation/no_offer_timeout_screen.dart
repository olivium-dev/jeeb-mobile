import 'package:flutter/material.dart';

class NoOfferTimeoutScreen extends StatelessWidget {
  final String requestId;
  const NoOfferTimeoutScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('No Offers Yet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(height: 24),
            Text('No offers received yet', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your request has been waiting for a while. You can upgrade to a higher tier for faster matching.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: () => Navigator.of(context).pop('upgrade'), child: const Text('Upgrade Tier')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.of(context).pop('wait'), child: const Text('Keep Waiting')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Cancel Request', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}
