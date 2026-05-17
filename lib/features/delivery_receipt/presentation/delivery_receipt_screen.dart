import 'package:flutter/material.dart';

class DeliveryReceiptScreen extends StatelessWidget {
  final String deliveryId;
  const DeliveryReceiptScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Icon(Icons.check_circle, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Delivery Complete!', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Order #$deliveryId', style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            _ReceiptRow(label: 'Goods Cost', value: '50,000 LBP'),
            _ReceiptRow(label: 'Delivery Fee', value: '15,000 LBP'),
            _ReceiptRow(label: 'Commission', value: '-2,250 LBP'),
            const Divider(),
            _ReceiptRow(label: 'Total', value: '62,750 LBP', isBold: true),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share),
              label: const Text('Share Receipt'),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _ReceiptRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final style = isBold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: style), Text(value, style: style)]),
    );
  }
}
