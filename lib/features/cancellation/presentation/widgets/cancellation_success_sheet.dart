import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/cancellation_result.dart';

/// Bottom sheet after success. OmdsBottomSheet lacks scroll-safe body layout.
class CancellationSuccessSheet extends StatelessWidget {
  const CancellationSuccessSheet({
    super.key,
    required this.result,
    required this.onDone,
  });

  final CancellationResult result;
  final VoidCallback onDone;

  static Future<void> show({
    required BuildContext context,
    required CancellationResult result,
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
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'cancellation_sheet_done_cta',
              container: true,
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.actionDone,
                onTap: onDone,
              ),
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
