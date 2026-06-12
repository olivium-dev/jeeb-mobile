import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

class CancellationScreen extends StatefulWidget {
  const CancellationScreen({
    super.key,
    required this.deliveryId,
    required this.isJeeber,
  });
  final String deliveryId;
  final bool isJeeber;

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
      appBar: const OMDSAppBar(title: 'Cancel Delivery'),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PromptText(),
            const SizedBox(height: Spacing.medium),
            RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final reason in reasons)
                    RadioListTile<String>(
                      title: Text(reason),
                      value: reason,
                    ),
                ],
              ),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: Spacing.xSmall),
              OmdsTextField(
                controller: _otherController,
                labelText: 'Please specify',
                maxLines: 3,
              ),
            ],
            const Spacer(),
            OmdsPrimaryButton(
              text: 'Confirm Cancellation',
              isEnabled: _selectedReason != null,
              backgroundColor: Theme.of(context).colorScheme.error,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Why are you cancelling?',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
