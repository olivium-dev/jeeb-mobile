import 'package:flutter/material.dart';

/// Direction-aware icon resolvers for an Arabic-FIRST product.
///
/// Flutter's [Icon] does NOT auto-mirror (`matchTextDirection` defaults to
/// false), so a hardcoded `arrow_back` / `chevron_right` points the WRONG way
/// under RTL. These helpers read [Directionality.of] and pick the correctly
/// mirrored glyph, matching the pattern already used in `chat_app_bar.dart`.
class DirectionalIcons {
  const DirectionalIcons._();

  static bool _isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  /// AppBar "back" affordance: points right in RTL, left in LTR.
  static IconData back(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_forward : Icons.arrow_back;

  /// iOS-style back chevron variant (matches `arrow_back_ios` call sites).
  static IconData backIos(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_forward_ios : Icons.arrow_back_ios;

  /// Forward/advance affordance: points left in RTL, right in LTR.
  ///
  /// Wiring request 01 — the onboarding "Next" pill carries a trailing arrow
  /// and [Icon] never auto-mirrors, so the glyph has to be resolved here.
  static IconData forward(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_back : Icons.arrow_forward;

  /// List-row disclosure chevron: points left in RTL, right in LTR.
  static IconData disclosure(BuildContext context) =>
      _isRtl(context) ? Icons.chevron_left : Icons.chevron_right;

  /// iOS-style disclosure chevron variant (matches `arrow_forward_ios` rows).
  static IconData disclosureIos(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_back_ios : Icons.arrow_forward_ios;
}
