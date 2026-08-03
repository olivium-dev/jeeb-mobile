import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/cancellation_result.dart';

/// Bottom sheet shown after a successful cancellation.
///
/// EXEMPT: OmdsBottomSheet lacks a `show` static factory with the required
/// scroll-safe body layout. Using Flutter's `showModalBottomSheet` directly
/// with a custom child that uses OMDS design tokens exclusively.
///
/// redesign-2026-08: same sheet, Jeeb ink — the 24px sheet corner the board
/// specifies, a filled confirmation glyph (R10: no `_outlined` variants), the
/// `h2` headline token and the kit's navy CTA pill.
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
        // 24 — the board's sheet corner (Spacing.large is that value).
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
        padding: const EdgeInsetsDirectional.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SuccessIcon(),
            const SizedBox(height: Spacing.medium),
            _SuccessTitle(text: l10n.cancellationSuccess),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'cancellation_sheet_done_cta',
              container: true,
              button: true,
              child: JeebCtaButton.primary(
                label: l10n.actionDone,
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
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(
      // Filled glyph (R10) — the outline variants are off this board.
      Icons.check_circle,
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
      style: context.jeebText.h2,
    );
  }
}
