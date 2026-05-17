import 'package:flutter/material.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool _offers = true;
  bool _statusUpdates = true;
  bool _chat = true;
  bool _ratings = true;
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: [
          _PrefTile(title: 'New Offers', subtitle: 'Get notified when offers arrive', value: _offers, onChanged: (v) => setState(() => _offers = v)),
          _PrefTile(title: 'Status Updates', subtitle: 'Delivery status changes', value: _statusUpdates, onChanged: (v) => setState(() => _statusUpdates = v)),
          _PrefTile(title: 'Chat Messages', subtitle: 'New messages from Jeebers/Clients', value: _chat, onChanged: (v) => setState(() => _chat = v)),
          _PrefTile(title: 'Ratings', subtitle: 'When your rating is revealed', value: _ratings, onChanged: (v) => setState(() => _ratings = v)),
          _PrefTile(title: 'Promotions', subtitle: 'Special offers and updates', value: _promotions, onChanged: (v) => setState(() => _promotions = v)),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
