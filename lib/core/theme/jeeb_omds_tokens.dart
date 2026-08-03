import 'dart:ui';

import 'package:omds/omds.dart';

import 'jeeb_midnight_palette.dart';

/// The one Midnight OmdsColorTokens set — omds widgets read tokens directly,
/// so app.dart AND the capture harness must provide this same instance.
const OmdsColorTokens jeebMidnightOmdsTokens = OmdsColorTokens(
  textLight: JeebMidnight.ink,
  textMedium: JeebMidnight.inkMuted,
  textDisabled: Color(0x61FFFFFF),
  bodyTextColor: JeebMidnight.ink,
  secondaryTextColor: JeebMidnight.inkMuted,
  dividerColor: JeebMidnight.divider,
  surfaceGreyScale: JeebMidnight.surfaceHigh,
  greyScale700: JeebMidnight.surfaceLow,
  greyScale600: JeebMidnight.surface,
  greyScale500: JeebMidnight.surfaceHigh,
  greyScale400: JeebMidnight.surfaceHighest,
  greyScale300: JeebMidnight.glassBorderStrong,
  greyScale200: JeebMidnight.glassBorder,
  greyScale100: JeebMidnight.glassFillEmphasis,
  greyScale50: JeebMidnight.glassFill,
  shimmerBase: JeebMidnight.glassFill,
  shimmerHighlight: JeebMidnight.glassFillPressed,
  inputFillColor: JeebMidnight.glassFill,
  inputBorderColor: JeebMidnight.glassBorder,
  inputLabelColor: JeebMidnight.inkMuted,
  successColor: JeebMidnight.success,
  warningColor: JeebMidnight.amber,
  infoColor: JeebMidnight.inkMuted,
  semanticErrorColor: JeebMidnight.danger,
  favoriteActiveColor: JeebMidnight.danger,
  favoriteInactiveColor: JeebMidnight.inkMuted,
  starRatingColor: JeebMidnight.amber,
  starInactiveColor: JeebMidnight.glassBorderStrong,
);
