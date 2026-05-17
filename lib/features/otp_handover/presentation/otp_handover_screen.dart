import 'package:flutter/material.dart';

class OtpHandoverScreen extends StatelessWidget {
  final String deliveryId;
  final bool isClient;
  const OtpHandoverScreen({super.key, required this.deliveryId, required this.isClient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isClient ? 'Your OTP' : 'Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isClient ? _ClientOtpDisplay(deliveryId: deliveryId) : _JeeberOtpEntry(deliveryId: deliveryId),
      ),
    );
  }
}

class _ClientOtpDisplay extends StatelessWidget {
  final String deliveryId;
  const _ClientOtpDisplay({required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Share this code with your Jeeber', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('1234', style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold, letterSpacing: 12,
            )),
          ),
          const SizedBox(height: 16),
          Text('Do not share until you receive your items', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _JeeberOtpEntry extends StatelessWidget {
  final String deliveryId;
  const _JeeberOtpEntry({required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Enter the OTP from the Client', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: TextField(
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () {}, child: const Text('Verify OTP')),
        ],
      ),
    );
  }
}
