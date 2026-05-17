import 'package:flutter/material.dart';

class DisputeScreen extends StatefulWidget {
  final String deliveryId;
  const DisputeScreen({super.key, required this.deliveryId});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  String? _category;
  final _descriptionController = TextEditingController();
  final List<String> _photoUrls = [];

  static const _categories = [
    'Wrong items delivered',
    'Items damaged',
    'Missing items',
    'Overcharged',
    'Jeeber misconduct',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('What went wrong?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _photoUrls.add('photo_${_photoUrls.length + 1}')),
            icon: const Icon(Icons.camera_alt),
            label: Text('Add Photo (${_photoUrls.length})'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _category == null || _descriptionController.text.isEmpty ? null : () => Navigator.of(context).pop(true),
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );
  }
}
