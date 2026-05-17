import 'package:flutter/material.dart';

class LiveTrackingScreen extends StatelessWidget {
  final String deliveryId;
  const LiveTrackingScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: Stack(
        children: [
          Container(color: Theme.of(context).colorScheme.surfaceContainerLowest),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('Tracking delivery $deliveryId',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Google Maps integration renders here'),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 8),
                      Text('Jeeber is on the way', style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
