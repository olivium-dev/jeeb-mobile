import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/image_picker_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/prohibited_item_report_draft.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live path is ProhibitedItemReportService in jeeber_request_detail — see docs/project-understanding/reconciliation/orphans.md

/// redesign-2026-08 (unrendered screen, neighbour = 13 OTP handover): re-skinned
/// onto the Jeeb kit — in-body [JeebTopBar] instead of a Material app bar, the
/// caution panel as a [JeebInfoNote], the two actions as [JeebCtaButton]s and
/// one docked [JeebCtaFooter] under a real spacer. The flow is unchanged: one
/// description field, one optional photo, one report action.
///
/// Copy reads through `AppLocalizations`; the screen pops a
/// [ProhibitedItemReportDraft], never a bare `true` (PIR-01).
class ProhibitedItemReportScreen extends StatefulWidget {
  const ProhibitedItemReportScreen({
    super.key,
    required this.requestId,
    this.initialDescription,
    this.photoPicker,
  });
  final String requestId;

  /// Photo capture seam (defaults to [ImagePickerPhotoPickerService]).
  final PhotoPickerService? photoPicker;

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
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription,
  );
  late final PhotoPickerService _photoPicker =
      widget.photoPicker ?? ImagePickerPhotoPickerService();
  Uint8List? _photoBytes;

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context);
    try {
      final photo = await _photoPicker.pickFromGallery();
      if (!mounted) return;
      setState(() => _photoBytes = Uint8List.fromList(photo.bytes));
    } on PhotoPickException catch (e) {
      if (!mounted || e.failure == PhotoPickFailure.cancelled) return;
      showJeebErrorSnack(
        context,
        identifier: 'prohibited_item_report_photo_error',
        message: e.failure == PhotoPickFailure.permissionDenied
            ? l10n.photoAttachmentPermissionDenied
            : l10n.photoAttachmentUnavailable,
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool canReport = _descriptionController.text.trim().isNotEmpty;
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
                title: l10n.prohibitedItemReportTitle,
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
                          text: l10n.prohibitedItemReportGuidance,
                        ),
                        const SizedBox(height: Spacing.large),
                        OmdsTextField(
                          controller: _descriptionController,
                          labelText: l10n.prohibitedItemReportDescriptionLabel,
                          maxLines: 4,
                          // Aligns the field with the 16px note/card radius
                          // rather than OMDS's 12px default (§4.4).
                          borderRadius: UIConstants.borderRadiusLarge,
                          identifier: 'prohibited_item_report_description',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Spacing.small),
                        JeebCtaButton.outline(
                          label: l10n.prohibitedItemReportAttachPhotoCta,
                          leadingIcon: Icons.camera_alt,
                          identifier: 'prohibited_item_report_attach_photo',
                          onTap: _pickPhoto,
                        ),
                        if (_photoBytes != null) ...[
                          const SizedBox(height: Spacing.small),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Semantics(
                              identifier: 'prohibited_item_report_photo_chip',
                              button: true,
                              container: true,
                              child: JeebSelectChip(
                                role: JeebChipRole.inlineAction,
                                label: l10n.prohibitedItemReportPhotoAttached,
                                selected: true,
                                leading: const Icon(Icons.close, size: 14),
                                onTap: () => setState(() => _photoBytes = null),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  footer: JeebCtaFooter.single(
                    // The report action is this screen's primary CTA, so it
                    // takes the navy pill. The system has no destructive fill
                    // (orange is rationed to decaying actions) — the caution
                    // now reads from the warning note above, not a red slab.
                    child: JeebCtaButton.primary(
                      label: l10n.prohibitedItemReportSubmitCta,
                      isEnabled: canReport,
                      identifier: 'prohibited_item_report_submit',
                      // A typed draft, so no caller can read this as a
                      // completed report (PIR-01).
                      onTap: () => Navigator.of(context).pop(
                        ProhibitedItemReportDraft(
                          requestId: widget.requestId,
                          description: _descriptionController.text.trim(),
                          photoBytes: _photoBytes,
                        ),
                      ),
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
