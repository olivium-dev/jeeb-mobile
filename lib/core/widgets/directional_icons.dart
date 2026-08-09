import 'package:flutter/material.dart';

/// Direction-aware icon resolvers for an Arabic-FIRST product.
///
/// All six arrow/chevron glyphs below declare `matchTextDirection: true`, so
/// [Icon] already mirrors them under RTL: these helpers must return the LTR
/// glyph and never hand-flip, or the glyph mirrors twice and points backwards.
/// The [BuildContext] parameter is kept for call-site stability.
class DirectionalIcons {
  const DirectionalIcons._();

  /// AppBar "back" affordance: points right in RTL, left in LTR.
  static IconData back(BuildContext context) => Icons.arrow_back;

  /// iOS-style back chevron variant (matches `arrow_back_ios` call sites).
  static IconData backIos(BuildContext context) => Icons.arrow_back_ios;

  /// Forward/advance affordance: points left in RTL, right in LTR.
  static IconData forward(BuildContext context) => Icons.arrow_forward;

  /// List-row disclosure chevron: points left in RTL, right in LTR.
  static IconData disclosure(BuildContext context) => Icons.chevron_right;

  /// iOS-style disclosure chevron variant (matches `arrow_forward_ios` rows).
  static IconData disclosureIos(BuildContext context) =>
      Icons.arrow_forward_ios;
}
