import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone-width canvas for the hero variant: 57 pt glyphs plus 16 pt of vertical
/// padding need the height; the width is the 390 pt phone the OTP screen ships
const Size _handoverCodeDisplayHeroBox = Size(390, 200);

/// The in-card variant is half the type scale and 12 pt of vertical padding, so
/// it wants a much shorter box — a tall one would hide how small this panel
const Size _handoverCodeDisplayCompactBox = Size(390, 140);

/// The panel as both call sites build it: shrink-wrapped and centred.
Widget _handoverCodeDisplayHosted(String code, {bool compact = false}) => Center(
      child: HandoverCodeDisplay(code: code, compact: compact),
    );

/// The panel inside the `EdgeInsets.all(Spacing.xLarge)` its call sites impose,
/// pinned to a device width.
Widget _handoverCodeDisplayOnPhone(String code, {required double width}) =>
    Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: _handoverCodeDisplayHosted(code),
        ),
      ),
    );

/// The customer's OTP screen, at the moment the jeeber asks for the code.
/// This is the shipping default (`compact: false`) and the only state that was
@JeebPreview(
  group: 'otp_handover',
  name: 'Hero · 1234',
  size: _handoverCodeDisplayHeroBox,
)
Widget handoverCodeDisplayHero() => _handoverCodeDisplayHosted('1234');

/// The same widget as [OtpAtDoorCard] embeds it (`compact: true`).
/// Worth seeing beside the hero: `compact` is not a small tweak, it is a drop
@JeebPreview(
  group: 'otp_handover',
  name: 'Compact in-card · 5678',
  size: _handoverCodeDisplayCompactBox,
)
Widget handoverCodeDisplayCompact() =>
    _handoverCodeDisplayHosted('5678', compact: true);

/// Bidi guard, made visible: a code whose reading is destroyed by reordering.
/// `0450` is chosen so a failure is unmistakable — a leading zero that must
@JeebPreview(
  group: 'otp_handover',
  name: 'Bidi guard · 0450',
  size: _handoverCodeDisplayHeroBox,
  matrix: true,
)
Widget handoverCodeDisplayBidiGuard() => _handoverCodeDisplayHosted('0450');

/// The 320 pt floor, with the 24 pt page padding both call sites impose — so
/// the panel is laid out into 272 pt, the narrowest it ever gets in production.
@JeebPreview(
  group: 'otp_handover',
  name: 'Narrow phone · 320 pt',
  size: Size(320, 220),
  matrix: true,
)
Widget handoverCodeDisplayNarrowPhone() =>
    _handoverCodeDisplayOnPhone('9061', width: 320);

/// Longest plausible content: a code the gateway widened past four digits.
/// Nothing in this widget, or in the parsers that feed it
@JeebPreview(
  group: 'otp_handover',
  name: 'Widened code · 481902',
  size: _handoverCodeDisplayHeroBox,
)
Widget handoverCodeDisplayWidenedCode() =>
    _handoverCodeDisplayOnPhone('481902', width: 390);
