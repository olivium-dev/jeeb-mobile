import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../model/obs_event.dart';
import '../obs_overlay_controller.dart';
import '../obs_overlay_event_formatter.dart';

class ObsOverlayFilterBar extends StatelessWidget {
  const ObsOverlayFilterBar({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final counts = controller.counts;
    return OmdsFilterChips<ObsEventType?>(
      filters: <OmdsFilterOption<ObsEventType?>>[
        OmdsFilterOption(label: 'All', value: null, count: _total(counts)),
        for (final type in ObsEventType.values)
          OmdsFilterOption(
            label: ObsOverlayEventFormatter.labelFor(type),
            value: type,
            count: counts[type],
          ),
      ],
      selectedValue: controller.filter,
      onFilterChanged: controller.setFilter,
    );
  }

  int _total(Map<ObsEventType, int> counts) =>
      counts.values.fold(0, (sum, n) => sum + n);
}
