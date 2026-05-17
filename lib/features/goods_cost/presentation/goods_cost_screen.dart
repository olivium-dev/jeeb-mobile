import 'package:flutter/material.dart';

class GoodsCostScreen extends StatefulWidget {
  final String deliveryId;
  const GoodsCostScreen({super.key, required this.deliveryId});

  @override
  State<GoodsCostScreen> createState() => _GoodsCostScreenState();
}

class _GoodsCostScreenState extends State<GoodsCostScreen> {
  final _costController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Goods Cost')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How much did the goods cost?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Enter the amount the Client needs to pay for the purchased goods.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Goods Cost (LBP)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _costController.text.isEmpty || _isSubmitting
                  ? null
                  : () async {
                      setState(() => _isSubmitting = true);
                      await Future.delayed(const Duration(seconds: 1));
                      if (mounted) Navigator.of(context).pop(double.tryParse(_costController.text));
                    },
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm Cost'),
            ),
          ],
        ),
      ),
    );
  }
}
