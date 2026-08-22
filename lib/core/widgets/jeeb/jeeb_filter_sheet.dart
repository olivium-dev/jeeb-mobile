import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../theme/jeeb_semantic_colors.dart';
import '../../theme/jeeb_text_styles.dart';
import 'jeeb_cta_button.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';

/// The shared filter-sheet chrome: handle, header, scrolling body, and a
/// pinned ghost/primary footer that alone pays the `viewPaddingOf` inset.
class JeebFilterSheetScaffold extends StatelessWidget {
  const JeebFilterSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onClear,
    required this.onApply,
    required this.clearLabel,
    required this.applyLabel,
    this.subtitle,
    this.identifier,
    this.clearEnabled = true,
    this.clearIdentifier,
    this.applyIdentifier,
  });

  /// Both footer CTAs share one height so the split row cannot look ragged.
  static const double footerButtonHeight = JeebCtaButton.outlineHeight;

  /// Sheet title, e.g. "Filter requests".
  final String title;

  /// Optional one-liner under the title (a live count, a scope reminder).
  final String? subtitle;

  /// The facet groups, laid out in a scrollable column. Pair each with a
  /// [JeebFilterSheetGroupLabel].
  final List<Widget> children;

  /// Resets every facet. Wired to the ghost CTA.
  final VoidCallback onClear;

  /// Commits the draft selection and normally pops the sheet.
  final VoidCallback onApply;

  /// Ghost CTA copy, e.g. "Clear all".
  final String clearLabel;

  /// Primary CTA copy, e.g. "Show results".
  final String applyLabel;

  /// Maestro id for the sheet container.
  final String? identifier;

  /// False when nothing is applied: the ghost CTA dims and stops firing.
  final bool clearEnabled;

  /// Maestro id for the ghost CTA.
  final String? clearIdentifier;

  /// Maestro id for the primary CTA.
  final String? applyIdentifier;

  @override
  Widget build(BuildContext context) {
    // max, not sum: with the keyboard up viewPadding still reports the gesture
    // bar the keyboard already covers, and paying both leaves a dead band.
    final MediaQueryData mq = MediaQuery.of(context);
    final double bottomInset = math.max(
      mq.viewInsets.bottom,
      mq.viewPadding.bottom,
    );

    Widget sheet = SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _FilterSheetDragHandle(),
          _FilterSheetHeader(title: title, subtitle: subtitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.xLarge,
                Spacing.medium,
                Spacing.xLarge,
                Spacing.medium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              0,
              Spacing.xLarge,
              Spacing.medium + bottomInset,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: JeebCtaButton.outline(
                    label: clearLabel,
                    onTap: clearEnabled ? onClear : null,
                    isEnabled: clearEnabled,
                    height: footerButtonHeight,
                    shrinkLabelToFit: true,
                    identifier: clearIdentifier,
                  ),
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: JeebCtaButton.primary(
                    label: applyLabel,
                    onTap: onApply,
                    height: footerButtonHeight,
                    shrinkLabelToFit: true,
                    identifier: applyIdentifier,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (identifier != null) {
      sheet = Semantics(
        identifier: identifier,
        container: true,
        explicitChildNodes: true,
        child: sheet,
      );
    }
    return sheet;
  }
}

/// The letter-spaced group label above a facet block. Casing stays in the ARB
/// string, or every `find.text(l10n.…)` the screens pin would break.
class JeebFilterSheetGroupLabel extends StatelessWidget {
  const JeebFilterSheetGroupLabel({super.key, required this.text});

  /// The group name, e.g. "STATUS".
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Text(
        text,
        style: context.jeebText.label.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Title (+ optional subtitle) and the close circle, over a hairline.
class _FilterSheetHeader extends StatelessWidget {
  const _FilterSheetHeader({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.small,
        Spacing.small,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: context.jeebText.titleProminent.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Spacing.twoXSmall),
                  Text(
                    subtitle!,
                    style: context.jeebText.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            // Guarded: the sheet is also pumped bare in widget tests.
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    // Rows clip hard at the viewport edge; the hairline makes that read as an
    // intentional boundary instead of sliced glyphs.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        header,
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

/// The board's sheet grab handle.
class _FilterSheetDragHandle extends StatelessWidget {
  const _FilterSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors colors =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      child: Center(
        child: SizedBox(
          width: Spacing.twoXLarge,
          height: Spacing.twoXSmall,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassBorderVivid,
              borderRadius: OmdsBorderRadius.pill,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Sheet-sized canvas: tall enough that the body scrolls under the footer.
const Size _jeebFilterSheetScaffoldBox = Size(390, 560);

/// A facet group with a few placeholder rows.
Widget _jeebFilterSheetScaffoldGroup(String label, List<String> options) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      JeebFilterSheetGroupLabel(text: label),
      for (final String option in options)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
          child: Text(option),
        ),
      const SizedBox(height: Spacing.medium),
    ],
  );
}

/// The chrome with two groups in it.
Widget _jeebFilterSheetScaffoldHosted({required bool clearEnabled}) {
  return JeebFilterSheetScaffold(
    title: 'Filter requests',
    subtitle: clearEnabled ? '2 applied' : 'Nothing applied',
    onClear: () {},
    onApply: () {},
    clearLabel: 'Clear all',
    applyLabel: 'Show results',
    clearEnabled: clearEnabled,
    children: <Widget>[
      _jeebFilterSheetScaffoldGroup(
        'STATUS',
        const <String>['Pending', 'Accepted', 'Delivered', 'Cancelled'],
      ),
      _jeebFilterSheetScaffoldGroup(
        'PERIOD',
        const <String>['Today', 'Last 7 days', 'Last 30 days'],
      ),
    ],
  );
}

/// Facets applied: the ghost CTA is live. Matrix, because the split footer is
/// where AR label length actually bites.
@JeebPreview(
  group: 'core',
  name: 'Facets applied',
  size: _jeebFilterSheetScaffoldBox,
  matrix: true,
)
Widget jeebFilterSheetScaffoldApplied() =>
    _jeebFilterSheetScaffoldHosted(clearEnabled: true);

/// Nothing applied: the ghost CTA dims and stops firing.
@JeebPreview(group: 'core', name: 'Nothing applied', size: _jeebFilterSheetScaffoldBox)
Widget jeebFilterSheetScaffoldEmpty() =>
    _jeebFilterSheetScaffoldHosted(clearEnabled: false);

/// The group label on its own, at the size it actually ships.
@JeebPreview(
  group: 'core',
  name: 'Group label',
  size: Size(390, 120),
)
Widget jeebFilterSheetGroupLabelPlain() => const Padding(
      padding: EdgeInsetsDirectional.all(Spacing.xLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          JeebFilterSheetGroupLabel(text: 'STATUS'),
          Text('Pending'),
        ],
      ),
    );
