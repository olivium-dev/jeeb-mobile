import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../core/dev_flags.dart';
import '../../core/observability/session_trace/presentation/obs_overlay_controller.dart';
import '../../core/observability/session_trace/presentation/widgets/obs_overlay_control_bar.dart';
import '../../core/observability/session_trace/presentation/widgets/obs_overlay_export_button.dart';

final ObsOverlayController _sessionLogsController = ObsOverlayController();

class SessionLogsPage extends StatefulWidget {
  const SessionLogsPage({super.key, this.controller});

  final ObsOverlayController? controller;

  @override
  State<SessionLogsPage> createState() => _SessionLogsPageState();
}

class _SessionLogsPageState extends State<SessionLogsPage> {
  late ObsOverlayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _sessionLogsController;
    _controller.attach();
  }

  @override
  void didUpdateWidget(covariant SessionLogsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextController = widget.controller ?? _sessionLogsController;
    if (identical(_controller, nextController)) return;
    _controller.detach();
    _controller = nextController;
    _controller.attach();
  }

  @override
  void dispose() {
    _controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assertDevToolOnly('SessionLogsPage');
    return Semantics(
      identifier: 'devtool.session_logs.screen',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: const OMDSAppBar(
          title: 'Session Logs',
          showBackButton: true,
          centerTitle: false,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _SessionLogsBody(controller: _controller),
          ),
        ),
      ),
    );
  }
}

class _SessionLogsBody extends StatelessWidget {
  const _SessionLogsBody({required this.controller});

  final ObsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Spacing.medium),
      children: [
        const OMDSSectionCard(
          title: 'Stored locally on this device',
          content: Text(
            'Start recording, close the Dev Tool, reproduce the issue, then '
            'return here to stop and share the JSONL files.',
          ),
        ),
        OMDSSectionCard(
          title: 'Recording',
          content: ObsOverlayControlBar(controller: controller),
        ),
        OMDSSectionCard(
          title: 'Export',
          showDivider: false,
          content: ObsOverlayExportButton(controller: controller),
        ),
      ],
    );
  }
}
