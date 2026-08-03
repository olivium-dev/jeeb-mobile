import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';

/// The "Deliver to" card on the Request type screen (redesign-2026-08 · 07,
/// HTML `tpl 392-398`): a filled `surfaceContainerHigh` card holding a pin
/// glyph, the destination line (plus an optional qualifier under it) and a bare
/// orange "Change" word at the end. Only the word is the tap target.
///
/// The constructor stays source-compatible with the pre-redesign row —
/// `semantics_identifier_surfacing_test.dart` constructs it directly with the
/// original three named arguments.
class RequestLocationRow extends StatelessWidget {
  const RequestLocationRow({
    super.key,
    required this.currentLabel,
    required this.changeLabel,
    required this.onChange,
    this.addressLabel,
    this.qualifierLabel,
    this.changeCtaLabel,
  });

  /// Fallback for the primary line and the label the a11y node keeps when no
  /// resolved [addressLabel] exists yet.
  final String currentLabel;

  /// The spoken label of the change action ("Change Location"). Stays the
  /// accessible name even though the board draws the shorter [changeCtaLabel].
  final String changeLabel;

  /// Opens the location picker.
  final VoidCallback onChange;

  /// The resolved destination line ("Home — Achrafieh, Beirut") when the flow
  /// has one. Null on 07 today: the destination is picked on the NEXT screen.
  final String? addressLabel;

  /// Secondary line under the address ("Current location"). Rendered only when
  /// non-null, so the card collapses to one line rather than showing a stub.
  final String? qualifierLabel;

  /// The visible action word ("Change"). Falls back to [changeLabel].
  final String? changeCtaLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `explicitChildNodes` makes this card a Semantics *boundary*: without it
    // the ambient merge folds the label's `request_type_current_location_label`
    // and the action's `request_type_change_location_button` into one node and
    // the button identifier is swallowed (Maestro/screen-reader can't address
    // it). The boundary keeps both inner identifiers as their own nodes.
    return Semantics(
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.medium,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Row(
          children: [
            // The board paints this pin #E02020; raw hex is banned in
            // lib/features (tool/check_design_tokens.sh) and R10 says icons are
            // navy or periwinkle — the divergence is flagged in the wiring file.
            Icon(Icons.location_on, size: Sizes.large, color: scheme.primary),
            const SizedBox(width: Spacing.small),
            Expanded(child: _AddressBlock(row: this)),
            _ChangeAction(
              label: changeLabel,
              ctaLabel: changeCtaLabel ?? changeLabel,
              onTap: onChange,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.row});

  final RequestLocationRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final qualifier = row.qualifierLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'request_type_current_location_label',
          child: Text(
            row.addressLabel ?? row.currentLabel,
            style: context.jeebText.cardTitle.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (qualifier != null)
          Text(
            qualifier,
            style: context.jeebText.bodySmall
                .copyWith(color: semantics.mutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _ChangeAction extends StatelessWidget {
  const _ChangeAction({
    required this.label,
    required this.ctaLabel,
    required this.onTap,
  });

  /// The spoken name — deliberately longer than the drawn word.
  final String label;

  /// The word the board draws.
  final String ctaLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_type_change_location_button',
      button: true,
      label: label,
      child: InkWell(
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: onTap,
        child: Padding(
          // Keeps a real tap target around a bare 13.5px word; the board draws
          // no chevron and no pill here.
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xSmall,
            vertical: Spacing.small,
          ),
          child: Text(
            ctaLabel,
            style: context.jeebText.body.copyWith(
              fontWeight: FontWeight.w700,
              color: context.jeebRoles.accent,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
