import 'package:flutter/material.dart';

import '../catalog/dev_screen_entry.dart';
import 'screen_preview_screen.dart';

/// Lists the previewable states of a single [DevScreenEntry]. Tapping a state
/// opens its live [ScreenPreviewScreen].
class ScreenStatesScreen extends StatelessWidget {
  const ScreenStatesScreen({super.key, required this.entry});

  final DevScreenEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ListView(
        children: <Widget>[
          for (final state in entry.states)
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text(state.label),
              subtitle: Text(state.id),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScreenPreviewScreen(
                    entry: entry,
                    state: state,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
