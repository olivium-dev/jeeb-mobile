import 'package:flutter/material.dart';

class RatingScreen extends StatefulWidget {
  final String deliveryId;
  const RatingScreen({super.key, required this.deliveryId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How was your experience?', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                iconSize: 40,
                icon: Icon(i < _stars ? Icons.star : Icons.star_border,
                    color: i < _stars ? Colors.amber : Theme.of(context).colorScheme.outline),
                onPressed: () => setState(() => _stars = i + 1),
              )),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Add a comment (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _stars == 0 ? null : () => Navigator.of(context).pop({'stars': _stars, 'comment': _commentController.text}),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }
}
