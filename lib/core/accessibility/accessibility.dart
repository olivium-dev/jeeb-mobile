import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../l10n/app_localizations.dart';
import '../previews/jeeb_preview.dart';

class A11y {
  A11y._();

  static const double minTapTargetSize = UIConstants.buttonHeight;

  static const double maxTextScaleFactor = 2.0;

  static MediaQueryData clampTextScaler(MediaQueryData data) {
    return data.copyWith(
      textScaler: _MaxTextScaler(
        delegate: data.textScaler,
        maxScaleFactor: maxTextScaleFactor,
      ),
    );
  }
}

class _MaxTextScaler extends TextScaler {
  const _MaxTextScaler({required this.delegate, required this.maxScaleFactor});

  final TextScaler delegate;
  final double maxScaleFactor;

  @override
  double scale(double fontSize) {
    final scaled = delegate.scale(fontSize);
    final maximum = maxScaleFactor * fontSize;
    return scaled > maximum ? maximum : scaled;
  }

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) {
    return other is _MaxTextScaler &&
        other.delegate == delegate &&
        other.maxScaleFactor == maxScaleFactor;
  }

  @override
  int get hashCode => Object.hash(delegate, maxScaleFactor);
}

Widget jeebA11yBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: A11y.clampTextScaler(MediaQuery.of(context)),
    child: child ?? const SizedBox.shrink(),
  );
}

class MinTapTarget extends StatelessWidget {
  const MinTapTarget({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: A11y.minTapTargetSize,
        minHeight: A11y.minTapTargetSize,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: IgnorePointer(child: child),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A phone-width box with room for a title, a note and one specimen row.
const Size _minTapTargetSpecimenBox = Size(390, 210);

/// Same width, taller: the stretched state stacks a target over its gauge.
const Size _minTapTargetStackedBox = Size(390, 260);

/// The size of the glyph in the icon states — a dismiss "x", the smallest thing
/// this app asks a user to hit and the case the floor exists for.
const double _minTapTargetGlyph = 16;

/// The happy path, and the whole reason the widget exists.
/// A 16 dp glyph is nowhere near tappable on its own. Given room, the floor does
@JeebPreview(group: 'core', name: 'Tiny icon child', size: _minTapTargetSpecimenBox)
Widget minTapTargetTinyIcon() => const _MinTapTargetSpecimen(
      title: 'Tiny icon child',
      note: 'A 16 dp glyph with room to grow. The floor does all the work.',
      child: _MinTapTargetGaugedTarget(child: Icon(Icons.close_rounded, size: _minTapTargetGlyph)),
    );

/// The production shape: an [OmdsChip], as `offer_sort_bar.dart` wraps it.
/// Only ONE axis of the floor binds here, which is easy to miss and worth
@JeebPreview(group: 'core', name: 'Chip child', size: _minTapTargetSpecimenBox)
Widget minTapTargetChip() => const _MinTapTargetSpecimen(
      title: 'Chip child',
      note: 'Production shape. Width is already over the floor; height is not.',
      child: _MinTapTargetGaugedTarget(child: _MinTapTargetSortChip(selected: true)),
    );

/// **The state that breaks.** The floor is not a floor.
/// [ConstrainedBox] does not override the constraints it is given, it enforces
@JeebPreview(group: 'core', name: 'Narrow parent', size: _minTapTargetSpecimenBox)
Widget minTapTargetNarrowParent() => const _MinTapTargetSpecimen(
      title: 'Narrow parent',
      note: 'Slot is 32 dp. The 48 dp minimum is clamped away, silently.',
      child: _MinTapTargetGaugedTarget(
        slot: 32,
        child: Icon(Icons.close_rounded, size: _minTapTargetGlyph),
      ),
    );

/// **The other state that breaks**, and the one more likely to be in the app
/// already: the same target, 7× too WIDE.
@JeebPreview(group: 'core', name: 'Stretched parent', size: _minTapTargetStackedBox)
Widget minTapTargetStretchedParent() => const _MinTapTargetSpecimen(
      title: 'Stretched parent',
      note: 'A stretching Column makes the 48 dp square a full-width tap strip.',
      child: _MinTapTargetStretchedTarget(),
    );

/// The trap in the implementation: the child's own `onTap` never fires.
/// [MinTapTarget] wraps the child in an [IgnorePointer] so the outer gesture
@JeebPreview(group: 'core', name: 'Child owns its own onTap', size: _minTapTargetSpecimenBox)
Widget minTapTargetChildOnTapSwallowed() => const _MinTapTargetSpecimen(
      title: 'Child owns its own onTap',
      note: 'IgnorePointer eats it. Tap the chip and watch the counters.',
      child: _MinTapTargetSwallowedOnTap(),
    );

// ---------------------------------------------------------------------------

/// Title + note + one specimen, on the preview surface.
class _MinTapTargetSpecimen extends StatelessWidget {
  const _MinTapTargetSpecimen({required this.title, required this.note, required this.child});

  final String title;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.medium),
          child,
        ],
      ),
    );
  }
}

/// The 48 dp promise, drawn to scale next to the thing that should meet it.
/// Deliberately NOT a hardcoded 48: it reads [A11y.minTapTargetSize], so if that
/// token ever moves the gauge moves with it and these previews keep measuring
class _MinTapTargetGauge extends StatelessWidget {
  const _MinTapTargetGauge();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: A11y.minTapTargetSize,
      height: A11y.minTapTargetSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(Spacing.twoXSmall),
        ),
        child: Center(
          child: Text(
            '48',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the exact rectangle the target resolved to.
/// [DecoratedBox] sizes itself to its child, so the tint IS the tap target's
/// measured bounds — not an approximation drawn around it.
class _MinTapTargetBounds extends StatelessWidget {
  const _MinTapTargetBounds({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        border: Border.all(color: colors.primary),
      ),
      child: child,
    );
  }
}

/// A gauge, then the target with its bounds drawn.
/// [slot] reproduces a parent that sized the target's box for it — the case
/// `Narrow parent` exists to show.
class _MinTapTargetGaugedTarget extends StatelessWidget {
  const _MinTapTargetGaugedTarget({required this.child, this.slot});

  final Widget child;
  final double? slot;

  @override
  Widget build(BuildContext context) {
    Widget target = _MinTapTargetBounds(
      child: MinTapTarget(onTap: () {}, child: child),
    );
    if (slot != null) {
      target = SizedBox(width: slot, height: slot, child: target);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _MinTapTargetGauge(),
        const SizedBox(width: Spacing.medium),
        Flexible(child: target),
      ],
    );
  }
}

/// One sort chip, with the real ARB copy the offers screen uses.
class _MinTapTargetSortChip extends StatelessWidget {
  const _MinTapTargetSortChip({this.selected = false, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OmdsChip(
        label: AppLocalizations.of(context).offersSortByPrice,
        isSelected: selected,
        onTap: onTap,
      );
}

/// The target inside a stretching [Column], with the gauge stacked beneath it.
/// Beneath rather than beside, because the whole point is that the target now
/// occupies the full width — there is no room left on its line to put anything
class _MinTapTargetStretchedTarget extends StatefulWidget {
  const _MinTapTargetStretchedTarget();

  @override
  State<_MinTapTargetStretchedTarget> createState() => _MinTapTargetStretchedTargetState();
}

class _MinTapTargetStretchedTargetState extends State<_MinTapTargetStretchedTarget> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MinTapTargetBounds(
          child: MinTapTarget(
            onTap: () => setState(() => _taps++),
            child: const Icon(Icons.close_rounded, size: _minTapTargetGlyph),
          ),
        ),
        const SizedBox(height: Spacing.small),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _MinTapTargetGauge(),
              const SizedBox(width: Spacing.medium),
              Text('taps $_taps', style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// A target whose child also wants the tap, with a live tally of who got it.
/// Stateful only so the canvas is interactive; there is no controller, no
/// ticker and nothing to settle.
class _MinTapTargetSwallowedOnTap extends StatefulWidget {
  const _MinTapTargetSwallowedOnTap();

  @override
  State<_MinTapTargetSwallowedOnTap> createState() => _MinTapTargetSwallowedOnTapState();
}

class _MinTapTargetSwallowedOnTapState extends State<_MinTapTargetSwallowedOnTap> {
  int _outer = 0;
  int _child = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MinTapTargetBounds(
          child: MinTapTarget(
            onTap: () => setState(() => _outer++),
            child: _MinTapTargetSortChip(onTap: () => setState(() => _child++)),
          ),
        ),
        const SizedBox(height: Spacing.small),
        Text(
          'outer $_outer / child $_child',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}
