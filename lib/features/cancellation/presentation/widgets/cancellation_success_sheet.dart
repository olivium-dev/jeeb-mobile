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
/// MIDNIGHT · M3-04 — the sheet inherits `bottomSheetTheme` (navy surface, the
/// ratified sheet corner) and carries R21's cancelled-status glyph, which is
/// quiet periwinkle: the act is done, not celebrated.
class CancellationSuccessSheet extends StatelessWidget {
  const CancellationSuccessSheet({
    super.key,
    required this.result,
    required this.onDone,
  });

  /// Board glyph size for a sheet's confirmation mark.
  static const double glyphSize = 56;

  final CancellationResult result;
  final VoidCallback onDone;

  static Future<void> show({
    required BuildContext context,
    required CancellationResult result,
    required VoidCallback onDone,
  }) {
    // No `shape:` override — the Midnight `bottomSheetTheme` owns the corner
    // and the surface, so a per-screen radius cannot drift from the ladder.
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
        padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SuccessIcon(),
            const SizedBox(height: Spacing.medium),
            _SuccessTitle(text: l10n.cancellationSuccess),
            const SizedBox(height: Spacing.xLarge),
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
      // R21's cancelled-row glyph, filled (R10 draws no `_outlined` variants).
      Icons.cancel,
      size: CancellationSuccessSheet.glyphSize,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
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
      style: context.jeebText.h2.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
