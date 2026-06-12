import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class NoOfferTimeoutScreen extends StatelessWidget {
  const NoOfferTimeoutScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(title: 'No Offers Yet'),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: Spacing.twoXLarge),
            OmdsPrimaryButton(
              text: 'Upgrade Tier',
              onTap: () => Navigator.of(context).pop('upgrade'),
            ),
            const SizedBox(height: Spacing.small),
            OmdsPrimaryButton(
              text: 'Keep Waiting',
              variant: OmdsButtonVariant.outlined,
              onTap: () => Navigator.of(context).pop('wait'),
            ),
            const SizedBox(height: Spacing.small),
            OmdsPrimaryButton(
              text: 'Cancel Request',
              variant: OmdsButtonVariant.text,
              textColor: Theme.of(context).colorScheme.error,
              onTap: () => Navigator.of(context).pop('cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.hourglass_empty,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          'No offers received yet',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.small),
        Text(
          'Your request has been waiting for a while. You can upgrade to a '
          'higher tier for faster matching.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
