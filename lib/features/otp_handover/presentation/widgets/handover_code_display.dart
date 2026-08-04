import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_code_cells.dart';
import '../../../../l10n/app_localizations.dart';

/// G4: the customer-facing handover-code panel, announced via a Semantics live
/// region.
///
/// Shared by the full-screen OTP display (`OtpHandoverScreen`) and the at-door
/// tracking card (`OtpAtDoorCard`) so the code renders identically wherever it
/// appears. [compact] switches between the two realized forms.
///
/// The full-screen form delegates to [JeebCodeCells.display] — the kit owns the
/// 74×92 r20 navy tiles, the `statDisplay` digits, `JeebShadows.heroNavy`, the
/// LTR bidi isolate and the scale-down that keeps four tiles inside a 360pt
/// phone. Nothing about that geometry is re-derived here.
///
/// The [compact] branch is FROZEN: `otp_at_door_card.dart` consumes it and
/// `live_tracking_handover_code_test.dart` asserts the whole code as a single
/// `find.text('1234')`. Migrating it to [JeebCodeCells.strip] belongs to screen
/// 12's lane, not this one.
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

  /// True renders the in-card variant (one headlineLarge string); false the
  /// full-screen navy tile row.
  final bool compact;

  /// Widget-test handle for the code container. Defaults to the OTP screen's
  /// historical key; in-card instances pass their own so `find.byKey` stays
  /// unambiguous when both surfaces exist in one tree.
  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsIdentifier,
      liveRegion: true,
      label: AppLocalizations.of(context).handoverCodeA11yLabel,
      value: code.split('').join(' '),
      // Tiles only: the wrapper already announces "Handover code / 2 1 4 4"
      // once, and without this each of the four tiles would also announce a
      // bare digit. The compact form is one Text and keeps its old node shape
      // (screen 12's frozen contract).
      excludeSemantics: !compact,
      child: compact
          ? _CompactCode(code: code, displayKey: displayKey)
          : KeyedSubtree(
              key: displayKey,
              child: JeebCodeCells.display(code),
            ),
    );
  }
}

/// FROZEN in-card form — see [HandoverCodeDisplay].
class _CompactCode extends StatelessWidget {
  const _CompactCode({required this.code, required this.displayKey});

  final String code;
  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: displayKey,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.medium,
      ),
      // Bidi guard: an all-numeric code must never reorder when it sits inside
      // an RTL (Arabic) ancestor — pin the digits to LTR.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          code,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            letterSpacing: Spacing.small,
          ),
        ),
      ),
    );
  }
}
