import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';
import 'obs_overlay_event_tile.dart';

class ObsOverlayEventList extends StatelessWidget {
  const ObsOverlayEventList({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final events = controller.filteredEvents;
    if (events.isEmpty) return const _EmptyEvents();
    return ListView.builder(
      key: const Key('obs-overlay-event-list'),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ObsOverlayEventTile(key: ValueKey(event.id), event: event);
      },
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return const OmdsEmptyState(
      icon: Icons.hourglass_empty,
      title: 'No events yet',
      subtitle: 'Start recording, then use the app to see events here.',
    );
  }
}
