import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../model/obs_event.dart';
import '../obs_overlay_event_formatter.dart';

/// One row of the live event list. Tapping it expands/collapses an inline
/// pretty-printed view of the (redacted) raw payload — handy for actually
/// debugging a signal without leaving the running app.
class ObsOverlayEventTile extends StatefulWidget {
  const ObsOverlayEventTile({super.key, required this.event});

  final ObsEvent event;

  @override
  State<ObsOverlayEventTile> createState() => _ObsOverlayEventTileState();
}

class _ObsOverlayEventTileState extends State<ObsOverlayEventTile> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventSummaryRow(
          event: widget.event,
          expanded: _expanded,
          onTap: _toggle,
        ),
        if (_expanded) _EventRawPayload(event: widget.event),
      ],
    );
  }
}

class _EventSummaryRow extends StatelessWidget {
  const _EventSummaryRow({
    required this.event,
    required this.expanded,
    required this.onTap,
  });

  final ObsEvent event;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OmdsSettingsRow(
      title: ObsOverlayEventFormatter.summaryFor(event),
      subtitle: '#${event.seq} · ${ObsOverlayEventFormatter.timeLabel(event)}',
      leadingIcon: ObsOverlayEventFormatter.iconFor(event.type),
      leadingIconColor: Theme.of(context).colorScheme.primary,
      icon: expanded ? Icons.expand_less : Icons.expand_more,
      onTap: onTap,
    );
  }
}

class _EventRawPayload extends StatelessWidget {
  const _EventRawPayload({required this.event});

  final ObsEvent event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('obs-overlay-event-raw'),
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xSmall),
      margin: const EdgeInsets.only(bottom: Spacing.xSmall),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.xSmall,
      ),
      child: SelectableText(
        ObsOverlayEventFormatter.prettyPayload(event),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
