import 'package:flutter/material.dart';

class CancellationScreen extends StatefulWidget {
  final String deliveryId;
  final bool isJeeber;
  const CancellationScreen({super.key, required this.deliveryId, required this.isJeeber});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  static const _clientReasons = [
    'Changed my mind',
    'Found alternative',
    'Price too high',
    'Taking too long',
    'Other',
  ];

  static const _jeeberReasons = [
    'Cannot complete delivery',
    'Vehicle issue',
    'Emergency',
    'Prohibited item detected',
    'Other',
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.isJeeber ? _jeeberReasons : _clientReasons;
    return Scaffold(
      appBar: AppBar(title: const Text('Cancel Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Why are you cancelling?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
            )),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherController,
                decoration: const InputDecoration(labelText: 'Please specify', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _selectedReason == null ? null : () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Confirm Cancellation'),
            ),
          ],
        ),
      ),
    );
  }
}
