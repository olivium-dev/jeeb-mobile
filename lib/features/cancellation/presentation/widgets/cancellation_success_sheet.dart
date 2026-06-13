import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/cancellation_result.dart';

/// Bottom sheet shown after a successful cancellation (AC3: fee + wallet CTA).
///
/// EXEMPT: OmdsBottomSheet lacks a `show` static factory with the required
/// scroll-safe body layout. Using Flutter's `showModalBottomSheet` directly
/// with a custom child that uses OMDS design tokens exclusively.
class CancellationSuccessSheet extends StatelessWidget {
  const CancellationSuccessSheet({
    super.key,
    required this.result,
    required this.onWalletTap,
    required this.onDone,
  });

  final CancellationResult result;
  final VoidCallback onWalletTap;
  final VoidCallback onDone;

  static Future<void> show({
    required BuildContext context,
    required CancellationResult result,
    required VoidCallback onWalletTap,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      builder: (_) => CancellationSuccessSheet(
        result: result,
        onWalletTap: onWalletTap,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SuccessIcon(),
            const SizedBox(height: Spacing.medium),
            _SuccessTitle(text: l10n.cancellationSuccess),
            if (result.feeApplied > 0) ...[
              const SizedBox(height: Spacing.small),
              _FeeRow(
                label: l10n.cancellationFeeApplied,
                fee: result.feeApplied,
              ),
              const SizedBox(height: Spacing.medium),
              OmdsPrimaryButton(
                text: l10n.cancellationWalletCta,
                onTap: onWalletTap,
              ),
              const SizedBox(height: Spacing.small),
            ] else ...[
              const SizedBox(height: Spacing.medium),
            ],
            OmdsPrimaryButton(
              text: l10n.actionDone,
              variant: result.feeApplied > 0
                  ? OmdsButtonVariant.outlined
                  : OmdsButtonVariant.primary,
              onTap: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_outline,
      size: 56,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _SuccessTitle extends StatelessWidget {
  const _SuccessTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.fee});

  final String label;
  final double fee;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          fee.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
