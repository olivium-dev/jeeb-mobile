import 'package:flutter/material.dart';

class ClientUnreachableScreen extends StatelessWidget {
  final String deliveryId;
  const ClientUnreachableScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Unreachable')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Icon(Icons.phone_disabled, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text('Cannot reach the Client', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'If the Client is not responding, you can flag them as unreachable. '
                    'They will have 15 minutes to respond before the delivery is escalated.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.phone), label: const Text('Try Calling Again')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.chat), label: const Text('Send Chat Message')),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Flag as Unreachable'),
            ),
          ],
        ),
      ),
    );
  }
}
