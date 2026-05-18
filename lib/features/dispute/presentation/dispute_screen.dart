import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
      appBar: const OMDSAppBar(title: 'Report Issue'),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          Text(
            'What went wrong?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.small),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: Spacing.medium),
          OmdsTextField(
            controller: _descriptionController,
            labelText: 'Describe the issue',
            maxLines: 5,
          ),
          const SizedBox(height: Spacing.medium),
          OMDSOutlinedButton(
            text: 'Add Photo (${_photoUrls.length})',
            icon: const Icon(Icons.camera_alt),
            onTap: () => setState(
              () => _photoUrls.add('photo_${_photoUrls.length + 1}'),
            ),
          ),
          const SizedBox(height: Spacing.xLarge),
          OmdsPrimaryButton(
            text: 'Submit Dispute',
            isEnabled:
                _category != null && _descriptionController.text.isNotEmpty,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
