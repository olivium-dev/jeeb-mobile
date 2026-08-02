import 'package:flutter/material.dart';

/// Direction-aware icon resolvers. Flutter Icon doesn't auto-mirror,
/// so these read [Directionality.of] to pick the correctly mirrored glyph.
class DirectionalIcons {
  const DirectionalIcons._();

  static bool _isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  static IconData back(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_forward : Icons.arrow_back;

  static IconData backIos(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_forward_ios : Icons.arrow_back_ios;

  static IconData disclosure(BuildContext context) =>
      _isRtl(context) ? Icons.chevron_left : Icons.chevron_right;

  static IconData disclosureIos(BuildContext context) =>
      _isRtl(context) ? Icons.arrow_back_ios : Icons.arrow_forward_ios;
}
