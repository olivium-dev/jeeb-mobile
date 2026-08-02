import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'widgets/capture_location_pin.dart';
import 'widgets/capture_map_viewport.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/capture_location_screen_fixtures.dart';

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
// ============================== JEEB PREVIEWS ==============================

const Size _captureLocationScreenPhoneBox = Size(390, 844);
const Size _captureLocationScreenCompactBox = Size(320, 568);

/// Scenario label plus confirmed pins tally.
class _CaptureLocationScreenCaption extends StatelessWidget {
  const _CaptureLocationScreenCaption({
    required this.scenario,
    required this.pinned,
  });

  final String scenario;
  final int pinned;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  scenario,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'pins confirmed $pinned',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen under a caption strip; tracks confirmed pins.
class _CaptureLocationScreenSlot extends StatefulWidget {
  const _CaptureLocationScreenSlot({
    required this.scenario,
    this.mapBuilder,
    this.isConfirming = false,
    this.width,
  });

  final String scenario;
  final WidgetBuilder? mapBuilder;
  final bool isConfirming;
  final double? width;

  @override
  State<_CaptureLocationScreenSlot> createState() =>
      _CaptureLocationScreenSlotState();
}

class _CaptureLocationScreenSlotState
    extends State<_CaptureLocationScreenSlot> {
  int _pinned = 0;

  @override
  Widget build(BuildContext context) {
    final Widget frame = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CaptureLocationScreenCaption(
          scenario: widget.scenario,
          pinned: _pinned,
        ),
        Expanded(
          child: CaptureLocationScreen(
            mapBuilder: widget.mapBuilder,
            isConfirming: widget.isConfirming,
            onPinned: () => setState(() => _pinned++),
          ),
        ),
      ],
    );

    final double? width = widget.width;
    if (width == null) return frame;
    return Center(
      child: SizedBox(width: width, height: double.infinity, child: frame),
    );
  }
}

@JeebPreview(
  group: 'location',
  name: 'Placeholder map (ships today)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenPlaceholderMap() =>
    const _CaptureLocationScreenSlot(
      scenario: 'Placeholder map · nothing to pin',
    );

@JeebPreview(
  group: 'location',
  name: 'Live map (production shape)',
  size: _captureLocationScreenPhoneBox,
  matrix: true,
)
Widget captureLocationScreenLiveMap() => _CaptureLocationScreenSlot(
      scenario: 'Live map · pan to move the pin',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
    );

@JeebPreview(
  group: 'location',
  name: 'Confirming (CTA disabled, nothing else is)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenConfirming() => _CaptureLocationScreenSlot(
      scenario: 'Confirming · map and back still live',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      isConfirming: true,
    );

@JeebPreview(
  group: 'location',
  name: 'Permission denied (via the map seam)',
  size: _captureLocationScreenPhoneBox,
)
Widget captureLocationScreenPermissionDenied() => _CaptureLocationScreenSlot(
      scenario: 'Permission denied · pin still confirmable',
      mapBuilder: CaptureLocationScreenPreviewFixtures.permissionDenied(
        onOpenSettings: () {},
      ),
    );

@JeebPreview(
  group: 'location',
  name: 'Outside service area (longest copy)',
  size: _captureLocationScreenPhoneBox,
  matrix: true,
)
Widget captureLocationScreenOutsideServiceArea() => _CaptureLocationScreenSlot(
      scenario: 'Outside service area · longest copy',
      mapBuilder: CaptureLocationScreenPreviewFixtures.outsideServiceArea(),
    );

@JeebPreview(
  group: 'location',
  name: 'Compact 320pt phone',
  size: _captureLocationScreenCompactBox,
)
Widget captureLocationScreenCompactPhone() => _CaptureLocationScreenSlot(
      scenario: 'Compact 320 pt phone',
      mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      width: 320,
    );
