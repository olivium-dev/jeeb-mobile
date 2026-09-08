import 'package:flutter/material.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';

/// The centre disc of the wallet journey's [JeebEmptyState] illustrations — the
/// kit's 94×94 `center` slot, glass over the ring so a money ledger reads as
/// money rather than as a client's shopping run.
///
/// This is R19's `_EarningsMark`, shared: `earnings_dashboard_screen.dart` had
/// already ruled that "E1's mic + shopping medallions are the CLIENT's *bring me
/// anything*; a jeeber's empty ledger gets a money mark instead", and M3-11/12
/// are the same jeeber ledger one screen along.
///
/// It also settles the variant question mechanically. `pocket` is the nearest
/// SUBJECT for an empty wallet, but `_pocketLayers()` ignores the `center` slot
/// and hard-draws a solid orange mic disc plus an accent bloom — an unbudgeted
/// orange act on a read-only surface (R4: the one money action is the only solid
/// orange element). Only `e1` honours `center`, so `e1` + this mark + no
/// medallions is the composition that can obey the budget.
class WalletStateMark extends StatelessWidget {
  const WalletStateMark({required this.glyph, super.key});

  static const double _disc = 94;
  static const double _glyphSize = 46;

  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Center(
      child: SizedBox.square(
        dimension: _disc,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: semantic.glassFillEmphasis,
            border: Border.fromBorderSide(
              BorderSide(color: semantic.glassBorderStrong),
            ),
          ),
          child: Icon(
            glyph,
            size: _glyphSize,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
