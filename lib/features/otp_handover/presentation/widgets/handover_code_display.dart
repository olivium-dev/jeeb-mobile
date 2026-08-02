import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class HandoverCodeDisplay extends StatelessWidget {
  const HandoverCodeDisplay({
    super.key,
    required this.code,
    this.semanticsIdentifier = 'otp_handover_code_display',
    this.compact = false,
    this.displayKey = const Key('otpHandover.codeDisplay'),
  });

  final String code;

  final String semanticsIdentifier;

  final bool compact;

  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = compact
        ? theme.textTheme.headlineLarge
        : theme.textTheme.displayLarge;
    return Semantics(
      identifier: semanticsIdentifier,
      liveRegion: true,
      label: AppLocalizations.of(context).handoverCodeA11yLabel,
      value: code.split('').join(' '),
      child: Container(
        key: displayKey,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: compact ? Spacing.xLarge : Spacing.twoXLarge,
          vertical: compact ? Spacing.small : Spacing.medium,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        // Bidi guard: an all-numeric code must never reorder when it sits
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            code,
            style: style?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              letterSpacing: Spacing.small,
            ),
          ),
        ),
      ),
    );
  }
}
