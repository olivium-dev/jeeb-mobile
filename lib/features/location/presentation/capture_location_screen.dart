import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/capture_location_pin.dart';
import 'widgets/capture_map_viewport.dart';

class CaptureLocationScreen extends StatelessWidget {
  const CaptureLocationScreen({
    super.key,
    this.onPinned,
    this.mapBuilder,
    this.isConfirming = false,
  });

  final VoidCallback? onPinned;

  final WidgetBuilder? mapBuilder;

  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OMDSAppBar(
        title: l10n.captureLocationTitle,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
      ),
      body: SafeArea(
        child: _Body(
          mapBuilder: mapBuilder,
          onPinned: onPinned,
          isConfirming: isConfirming,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.mapBuilder,
    required this.onPinned,
    required this.isConfirming,
  });

  final WidgetBuilder? mapBuilder;
  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _MapStack(mapBuilder: mapBuilder)),
        _PinCta(onPinned: onPinned, isConfirming: isConfirming),
      ],
    );
  }
}

class _PinCta extends StatelessWidget {
  const _PinCta({required this.onPinned, required this.isConfirming});

  final VoidCallback? onPinned;
  final bool isConfirming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
      ),
      child: Semantics(
        identifier: 'capture_location_pin_cta',
        button: true,
        child: OmdsPrimaryButton(
          text: l10n.captureLocationPinCta,
          isEnabled: !isConfirming,
          onTap: () => _onPin(context),
        ),
      ),
    );
  }

  void _onPin(BuildContext context) {
    final handler = onPinned;
    if (handler != null) {
      handler();
    } else {
      Navigator.of(context).maybePop();
    }
  }
}

class _MapStack extends StatelessWidget {
  const _MapStack({required this.mapBuilder});

  final WidgetBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          identifier: 'capture_location_map',
          label: l10n.captureLocationMapSemantic,
          child: mapBuilder?.call(context) ?? const CaptureMapViewport(),
        ),
        const Center(child: CaptureLocationPin()),
      ],
    );
  }
}
