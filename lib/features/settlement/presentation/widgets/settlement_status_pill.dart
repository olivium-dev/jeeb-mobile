import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/settlement_statement.dart';

/// The paid / pending state pill shown on a settlement statement.
///
/// **Deliberately not a kit widget.** `JeebSystemChip`'s three tones (filled /
/// outlined / accent) carry no success or warning voice, and paid-vs-pending is
/// the only state signal a statement has — flattening it to one grey pill would
/// drop meaning. So the contrast-gated `jeebRoles` success/warning container
/// pair stays, and only the *geometry* is brought onto the system: stadium
/// shape and the kit chip's `4/12` inset at `jeebText.label`, so it reads at the
/// same scale as every other meta pill on the board.
class SettlementStatusPill extends StatelessWidget {
  const SettlementStatusPill({super.key, required this.status});

  final SettlementStatus status;

  /// The pill's copy — shared with the callers that fold the status into a row
  /// semantics label, so the spoken and the drawn word cannot drift.
  static String labelFor(AppLocalizations l10n, SettlementStatus status) =>
      status == SettlementStatus.paid
          ? l10n.settlementStatusPaid
          : l10n.settlementStatusPending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roles = context.jeebRoles;
    final isPaid = status == SettlementStatus.paid;
    // Semantic roles: paid = success, pending = warning. The old
    // secondary/tertiary container pairs were brand hues doing state duty
    // (onSecondaryContainer on navy fails AA).
    final fill = isPaid ? roles.successContainer : roles.warningContainer;
    final ink = isPaid ? roles.onSuccessContainer : roles.onWarningContainer;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: Text(
        labelFor(l10n, status),
        style: context.jeebText.label.copyWith(color: ink),
      ),
    );
  }
}
