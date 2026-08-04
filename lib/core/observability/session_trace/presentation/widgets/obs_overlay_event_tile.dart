import 'package:flutter/material.dart';

import '../../../../theme/jeeb_radii.dart';
import '../../../../theme/jeeb_semantic_colors.dart';
import '../../../../theme/jeeb_text_styles.dart';
import '../../../../widgets/jeeb/jeeb_list_row.dart';
import '../../model/obs_event.dart';
import '../obs_overlay_event_formatter.dart';

/// One expandable event row in the observability overlay (M6 class-3b
/// restyle).
///
/// The summary line is a real [JeebListRow] rather than an OMDS settings row:
/// the OMDS row is a light-theme shape that only forwarded a colour, and the
/// colour it was being handed was `colorScheme.primary` — orange under
/// Midnight, on a read-only diagnostic glyph.
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
    final JeebSemanticColors semantics = _semantics(context);
    return JeebListRow(
      title: ObsOverlayEventFormatter.summaryFor(event),
      subtitle: '#${event.seq} · ${ObsOverlayEventFormatter.timeLabel(event)}',
      icon: ObsOverlayEventFormatter.iconFor(event.type),
      iconColor: Theme.of(context).colorScheme.secondary,
      showChevron: false,
      trailing: Icon(
        expanded ? Icons.expand_less : Icons.expand_more,
        size: 16,
        color: semantics.mutedText,
      ),
      onTap: onTap,
    );
  }
}

class _EventRawPayload extends StatelessWidget {
  const _EventRawPayload({required this.event});

  final ObsEvent event;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics = _semantics(context);
    return Container(
      key: const Key('obs-overlay-event-raw'),
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
      margin: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8),
      decoration: BoxDecoration(
        color: semantics.glassFill,
        borderRadius: BorderRadius.circular(JeebRadii.sm),
        border: Border.all(color: semantics.glassBorder),
      ),
      child: SelectableText(
        ObsOverlayEventFormatter.prettyPayload(event),
        style: context.jeebText.bodySmall.copyWith(color: semantics.inkSoft),
      ),
    );
  }
}

/// Read defensively: harnesses that theme with a bare `ThemeData` must not
/// crash on a missing extension.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
