import 'package:flutter/material.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text('Total Earnings', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('0 LBP', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('This month', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatCard(title: 'Deliveries', value: '0')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Commission', value: '0 LBP')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _StatCard(title: 'Net Payout', value: '0 LBP')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Rating', value: '—')),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('Download Statement'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
