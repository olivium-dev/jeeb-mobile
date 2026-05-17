import 'package:flutter/material.dart';

class ProhibitedItemReportScreen extends StatefulWidget {
  final String requestId;
  const ProhibitedItemReportScreen({super.key, required this.requestId});

  @override
  State<ProhibitedItemReportScreen> createState() => _ProhibitedItemReportScreenState();
}

class _ProhibitedItemReportScreenState extends State<ProhibitedItemReportScreen> {
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Prohibited Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'If the Client requested delivery of a prohibited item, report it here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe the prohibited item',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt), label: const Text('Attach Photo')),
            const Spacer(),
            FilledButton(
              onPressed: _descriptionController.text.isEmpty ? null : () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Report Item'),
            ),
          ],
        ),
      ),
    );
  }
}
