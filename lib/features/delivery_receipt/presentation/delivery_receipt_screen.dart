import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class DeliveryReceiptScreen extends StatelessWidget {
  const DeliveryReceiptScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(
        title: 'Delivery Receipt',
        showBackButton: true,
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReceiptHeaderCard(deliveryId: deliveryId),
            const SizedBox(height: Spacing.medium),
            const _ReceiptRow(label: 'Goods Cost', value: '50,000 LBP'),
            const _ReceiptRow(label: 'Delivery Fee', value: '15,000 LBP'),
            const _ReceiptRow(label: 'Commission', value: '-2,250 LBP'),
            const Divider(),
            const _ReceiptRow(
              label: 'Total',
              value: '62,750 LBP',
              isBold: true,
            ),
            const Spacer(),
            OmdsPrimaryButton(
              text: 'Share Receipt',
              variant: OmdsButtonVariant.outlined,
              icon: const Icon(Icons.share),
              onTap: () {},
            ),
            const SizedBox(height: Spacing.xSmall),
            OmdsPrimaryButton(
              text: 'Done',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptHeaderCard extends StatelessWidget {
  const _ReceiptHeaderCard({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              'Delivery Complete!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              'Order #$deliveryId',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = isBold ? textTheme.titleMedium : textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
