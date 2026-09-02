import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';

class ObsOverlayControlBar extends StatelessWidget {
  const ObsOverlayControlBar({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordingSwitch(controller: controller),
        if (controller.lastErrorMessage != null) ...[
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            controller.lastErrorMessage!,
            key: const Key('obs-overlay-recording-error'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Spacing.xSmall),
        _ClearRow(controller: controller),
      ],
    );
  }
}

class _RecordingSwitch extends StatelessWidget {
  const _RecordingSwitch({required this.controller});

  final ObsOverlayController controller;

  void _onChanged(bool value) {
    if (value) {
      unawaited(controller.start());
    } else {
      unawaited(controller.stop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recording = controller.recording;
    return OmdsSwitchTile(
      key: const Key('obs-overlay-recording-switch'),
      identifier: 'devtool.session_logs.recording',
      title: 'Recording',
      subtitle: recording ? 'Capturing screen/api/push/interaction' : 'Paused',
      value: recording,
      onChanged: _onChanged,
      leading: Icon(
        recording ? Icons.fiber_manual_record : Icons.pause_circle_outline,
        color: recording ? colorScheme.error : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ClearRow extends StatelessWidget {
  const _ClearRow({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = controller.totalBuffered;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count buffered',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Sizes.fourXLarge,
            minHeight: Sizes.fourXLarge,
          ),
          child: OMDSOutlinedButton(
            key: const Key('obs-overlay-clear'),
            identifier: 'devtool.session_logs.clear',
            text: 'Clear view',
            icon: const Icon(Icons.delete_outline, size: Sizes.small),
            onTap: controller.clear,
          ),
        ),
      ],
    );
  }
}
