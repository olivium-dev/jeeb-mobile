import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import 'prohibited_item_report_l10n.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live path is ProhibitedItemReportService in jeeber_request_detail — see docs/project-understanding/reconciliation/orphans.md

/// redesign-2026-08 (unrendered screen, neighbour = 13 OTP handover): re-skinned
/// onto the Jeeb kit — in-body [JeebTopBar] instead of a Material app bar, the
/// caution panel as a [JeebInfoNote], the two actions as [JeebCtaButton]s and
/// one docked [JeebCtaFooter] under a real spacer. The flow is unchanged: one
/// description field, one optional photo, one report action.
///
/// Copy moved off the five hardcoded English literals onto
/// [ProhibitedItemReportL10n], the feature-local stopgap; the shared ARB batch
/// is queued in `docs/redesign-2026-08/wiring/w4-prohibited-item.md`.
class ProhibitedItemReportScreen extends StatefulWidget {
  const ProhibitedItemReportScreen({
    super.key,
    required this.requestId,
    this.initialDescription,
  });
  final String requestId;

  /// Catalog/test seam: pre-fills the description field so the "ready to
  /// report" (CTA-enabled) designed state can be previewed without a live
  /// keystroke. Defaults to null (empty field), matching prior behavior.
  final String? initialDescription;

  @override
  State<ProhibitedItemReportScreen> createState() =>
      _ProhibitedItemReportScreenState();
}

class _ProhibitedItemReportScreenState
    extends State<ProhibitedItemReportScreen> {
  late final _descriptionController =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProhibitedItemReportL10n copy = ProhibitedItemReportL10n.of(context);
    final bool canReport = _descriptionController.text.isNotEmpty;
    return Semantics(
      identifier: 'prohibited_item_report_root',
      container: true,
      // Keep the field/CTA identifiers addressable instead of merged away.
      explicitChildNodes: true,
      child: Scaffold(
        // R-structure: the board's header is an in-body row, not an app bar.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar.back(
                title: copy.title,
                identifier: 'prohibited_item_report_back',
              ),
              Expanded(
                child: _ReportPage(
                  content: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Spacing.xLarge,
                      Spacing.large,
                      Spacing.xLarge,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JeebInfoNote.warning(
                          icon: Icons.warning,
                          text: copy.guidanceNote,
                        ),
                        const SizedBox(height: Spacing.large),
                        OmdsTextField(
                          controller: _descriptionController,
                          labelText: copy.descriptionLabel,
                          maxLines: 4,
                          // Aligns the field with the 16px note/card radius
                          // rather than OMDS's 12px default (§4.4).
                          borderRadius: UIConstants.borderRadiusLarge,
                          identifier: 'prohibited_item_report_description',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Spacing.small),
                        JeebCtaButton.outline(
                          label: copy.attachPhotoCta,
                          leadingIcon: Icons.camera_alt,
                          identifier: 'prohibited_item_report_attach_photo',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  footer: JeebCtaFooter.single(
                    // The report action is this screen's primary CTA, so it
                    // takes the navy pill. The system has no destructive fill
                    // (orange is rationed to decaying actions) — the caution
                    // now reads from the warning note above, not a red slab.
                    child: JeebCtaButton.primary(
                      label: copy.reportCta,
                      isEnabled: canReport,
                      identifier: 'prohibited_item_report_submit',
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// R1's page shape: content at the top, ONE spacer, one docked footer.
///
/// A bare `Column` + `Spacer` asserts once the text scale pushes the content
/// past the viewport, so the whole thing sits in a scroll view whose child is
/// forced to at least the viewport height — the board's genuinely empty lower
/// band at 1×, a scroll at 200 %. Same construction as screen 13.
class _ReportPage extends StatelessWidget {
  const _ReportPage({required this.content, required this.footer});

  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const Spacer(), footer],
            ),
          ),
        ),
      ),
    );
  }
}
