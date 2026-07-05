import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// G4: the customer-facing handover-code panel — large glyphs on a
/// primary-container OMDS card, announced via a Semantics live region.
///
/// Shared by the full-screen OTP display (`OtpHandoverScreen`) and the
/// at-door tracking card (`OtpAtDoorCard`) so the code renders identically
/// wherever it appears. [compact] tunes the type scale down for in-card use.
class HandoverCodeDisplay extends StatelessWidget {
  const HandoverCodeDisplay({
    super.key,
    required this.code,
    this.semanticsIdentifier = 'otp_handover_code_display',
    this.compact = false,
    this.displayKey = const Key('otpHandover.codeDisplay'),
  });

  /// The 4-digit handover code. Rendered verbatim on screen (it is the
  /// customer's own credential) but NEVER logged — see `DiagRedaction`.
  final String code;

  /// QA: uiautomator-addressable handle for this display instance.
  final String semanticsIdentifier;

  /// True renders the in-card variant (headlineLarge); false the full-screen
  /// hero variant (displayLarge).
  final bool compact;

  /// Widget-test handle for the code container. Defaults to the OTP screen's
  /// historical key; in-card instances pass their own so `find.byKey` stays
  /// unambiguous when both surfaces exist in one tree.
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
        // inside an RTL (Arabic) ancestor — pin the digits to LTR.
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
