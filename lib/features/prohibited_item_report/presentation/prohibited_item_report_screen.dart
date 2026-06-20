import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../jeeber_request_detail/domain/services/prohibited_item_report_service.dart';

class ProhibitedItemReportScreen extends StatefulWidget {
  const ProhibitedItemReportScreen({
    super.key,
    required this.requestId,
    this.reportService,
  });

  final String requestId;
  final ProhibitedItemReportService? reportService;

  @override
  State<ProhibitedItemReportScreen> createState() =>
      _ProhibitedItemReportScreenState();
}

class _ProhibitedItemReportScreenState
    extends State<ProhibitedItemReportScreen> {
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

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
            OmdsLoadingButton(
              text: 'Report Item',
              isLoading: _isSubmitting,
              isEnabled: _descriptionController.text.isNotEmpty,
              backgroundColor: Theme.of(context).colorScheme.error,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _descriptionController.text.trim();
    if (reason.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.reportService?.report(
        requestId: widget.requestId,
        reason: reason,
      );
      if (!mounted) return;
      showOmdsSnackbar(context, message: 'Report submitted');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showOmdsErrorSnackbar(
        context,
        message: 'Could not submit the report. Please try again.',
      );
    }
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
