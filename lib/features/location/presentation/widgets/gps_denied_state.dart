import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class GpsDeniedState extends StatelessWidget {
  const GpsDeniedState({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(colorScheme),
            const SizedBox(height: Spacing.medium),
            _buildTitle(context, l10n),
            const SizedBox(height: Spacing.xSmall),
            _buildBody(context, l10n, colorScheme),
            const SizedBox(height: Spacing.large),
            _buildCta(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    return Icon(
      Icons.location_off_rounded,
      size: Sizes.fiveXLarge,
      color: colorScheme.error,
    );
  }

  Widget _buildTitle(BuildContext context, AppLocalizations l10n) {
    return Text(
      l10n.captureLocationGpsDeniedTitle,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Text(
      l10n.captureLocationGpsDeniedBody,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCta(AppLocalizations l10n) {
    return OmdsPrimaryButton(
      text: l10n.captureLocationGpsDeniedOpenSettings,
      isEnabled: onOpenSettings != null,
      onTap: () => onOpenSettings?.call(),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The slot the capture-location screen would give it: phone width, full body
/// height minus the app bar and the "Pin Location" CTA.
const Size _gpsDeniedStatePhoneSlot = Size(390, 560);

/// The narrowest device the app still supports, same body height.
const Size _gpsDeniedStateCompactSlot = Size(320, 560);

/// A fixed-height map card — the shape an inline map preview or a bottom sheet
/// hands its child. Short on purpose: this is the box the widget does not fit.
const Size _gpsDeniedStateCardSlot = Size(390, 200);

/// A phone in landscape: wide, and only ~360 pt tall once the chrome is gone.
const Size _gpsDeniedStateLandscapeSlot = Size(740, 360);

/// One state: the widget in a bounded slot, with the scenario named above it.
/// [wired] decides whether `onOpenSettings` is supplied. It is the widget's
Widget _gpsDeniedStateHosted(String scenario, {bool wired = true, double? width}) =>
    _GpsDeniedStateSlot(scenario: scenario, wired: wired, width: width);

/// The intended state: permission denied on the capture-location screen, with
/// the CTA wired the way a production host wires it.
@JeebPreview(group: 'location', name: 'Full phone slot · CTA wired', size: _gpsDeniedStatePhoneSlot)
Widget gpsDeniedStateWiredCta() => _gpsDeniedStateHosted('Full phone slot · CTA wired');

/// What `const GpsDeniedState()` ships today — literally the default
/// constructor, no arguments.
@JeebPreview(group: 'location', name: 'Default constructor · CTA dead', size: _gpsDeniedStatePhoneSlot)
Widget gpsDeniedStateNoCallback() =>
    _gpsDeniedStateHosted('Default constructor · CTA dead', wired: false);

/// The narrowest supported device, 320 pt — and the state whose `EN 200% text`
/// rendering is the most damning of the three overflows in this file.
@JeebPreview(group: 'location', name: 'Compact 320pt phone', size: _gpsDeniedStateCompactSlot)
Widget gpsDeniedStateCompactPhone() =>
    _gpsDeniedStateHosted('Compact 320pt phone', width: 320);

/// **The state that breaks**: the same widget in a 200 pt map card.
/// [GpsDeniedState] is `Center > Padding > Column(mainAxisSize: min)` with no
@JeebPreview(group: 'location', name: 'Short map card (200pt)', size: _gpsDeniedStateCardSlot)
Widget gpsDeniedStateShortCard() => _gpsDeniedStateHosted('Short map card (200pt)');

/// A phone rotated to landscape: 740 pt wide, ~360 pt tall.
/// Two things to look at. The first is the width — the widget caps its content
@JeebPreview(group: 'location', name: 'Landscape phone (740×360)', size: _gpsDeniedStateLandscapeSlot)
Widget gpsDeniedStateLandscape() =>
    _gpsDeniedStateHosted('Landscape phone (740×360)', width: 740);

// ---------------------------------------------------------------------------

/// The scenario label, and — when the CTA is wired — a live tally of taps.
/// Pinned to [TextScaler.noScaling]: this is preview chrome, and if it grew
/// with the text scaler it would eat the slot in the `EN 200% text` rendering
class _GpsDeniedStateCaption extends StatelessWidget {
  const _GpsDeniedStateCaption({required this.scenario, required this.opened});

  final String scenario;
  final int? opened;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MediaQuery.withNoTextScaling(
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
            if (opened != null)
              Text(
                'settings opened $opened',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// A named, outlined box holding one [GpsDeniedState].
/// The outline is the point of the wrapper: [GpsDeniedState] centres itself in
/// whatever it is given and paints no background, so without a drawn boundary a
class _GpsDeniedStateSlot extends StatefulWidget {
  const _GpsDeniedStateSlot({required this.scenario, required this.wired, this.width});

  final String scenario;
  final bool wired;

  /// Baked device width, when the state is about a device rather than a slot.
  final double? width;

  @override
  State<_GpsDeniedStateSlot> createState() => _GpsDeniedStateSlotState();
}

class _GpsDeniedStateSlotState extends State<_GpsDeniedStateSlot> {
  int _opened = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // The unwired state is built from the bare default constructor on purpose:
    final Widget denied = widget.wired
        ? GpsDeniedState(onOpenSettings: () => setState(() => _opened++))
        : const GpsDeniedState();

    final Widget frame = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _GpsDeniedStateCaption(
          scenario: widget.scenario,
          opened: widget.wired ? _opened : null,
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: denied,
          ),
        ),
      ],
    );

    final double? width = widget.width;
    if (width == null) return frame;
    // `height: double.infinity` against the loose constraints [Center] passes
    return Center(
      child: SizedBox(width: width, height: double.infinity, child: frame),
    );
  }
}
