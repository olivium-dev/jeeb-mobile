import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live path is ProhibitedItemReportService in jeeber_request_detail — see docs/project-understanding/reconciliation/orphans.md
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
    return Scaffold(
      appBar: const OMDSAppBar(title: 'Report Prohibited Item'),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _WarningCard(),
            const SizedBox(height: Spacing.medium),
            OmdsTextField(
              controller: _descriptionController,
              labelText: 'Describe the prohibited item',
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(
              text: 'Attach Photo',
              variant: OmdsButtonVariant.outlined,
              icon: const Icon(Icons.camera_alt),
              onTap: () {},
            ),
            const Spacer(),
            OmdsPrimaryButton(
              text: 'Report Item',
              isEnabled: _descriptionController.text.isNotEmpty,
              backgroundColor: Theme.of(context).colorScheme.error,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Row(
          children: [
            Icon(Icons.warning, color: theme.colorScheme.error),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                'If the Client requested delivery of a prohibited item, '
                'report it here.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
