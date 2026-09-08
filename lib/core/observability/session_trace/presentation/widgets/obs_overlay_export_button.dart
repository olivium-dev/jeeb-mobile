import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../obs_overlay_controller.dart';
import '../../../../widgets/jeeb/jeeb_snack.dart';

class ObsOverlayExportButton extends StatefulWidget {
  const ObsOverlayExportButton({super.key, required this.controller});

  final ObsOverlayController controller;

  @override
  State<ObsOverlayExportButton> createState() => _ObsOverlayExportButtonState();
}

class _ObsOverlayExportButtonState extends State<ObsOverlayExportButton> {
  bool _busy = false;

  Future<void> _onExport() async {
    setState(() => _busy = true);
    await widget.controller.exportAndShare();
    if (!mounted) return;
    setState(() => _busy = false);
    _showFeedback();
  }

  void _showFeedback() {
    final message = widget.controller.lastExportMessage;
    if (message == null) return;
    if (widget.controller.lastExportSucceeded) {
      showJeebSuccessSnack(
        context,
        identifier: 'devtool_session_logs_export_success',
        message: message,
      );
    } else {
      showJeebErrorSnack(
        context,
        identifier: 'devtool_session_logs_export_error',
        message: message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsLoadingButton(
          key: const Key('obs-overlay-export'),
          identifier: 'devtool.session_logs.export',
          text: 'Export / Share JSONL',
          isLoading: _busy,
          onTap: _onExport,
        ),
        if (widget.controller.lastExportedPath != null)
          _ExportedPathLabel(path: widget.controller.lastExportedPath!),
      ],
    );
  }
}

class _ExportedPathLabel extends StatelessWidget {
  const _ExportedPathLabel({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.twoXSmall),
      child: SelectableText(
        path,
        key: const Key('obs-overlay-export-path'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
