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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/core/min_tap_target_preview_test.dart
// ===========================================================================
//
// Widget previews for [MinTapTarget] — run with
// `flutter widget-preview start`.
//
// [MinTapTarget] has no data and no dependencies: it is a [ConstrainedBox], a
// [GestureDetector] and an [Align]. So these previews are network-free because
// there is nothing to fetch, not merely because [jeebPreviewHost] guards them,
// and what varies between states is not content but **the constraints the
// parent hands down and the child handed in**.
//
// The widget also paints nothing, which makes it invisible in a canvas unless
// something draws its bounds. Every state below therefore renders the target
// inside [_Bounds] — a [DecoratedBox], which sizes itself exactly to its child
// — beside a [_Gauge], a plain 48 dp square. **The review question in every
// preview is the same: does the tinted box reach the outlined square?**
// [A11y.minTapTargetSize] is the promise (AC T-mobile-036: every tappable
// element ≥ 48 dp / 44 pt); the gauge is that promise drawn to scale.
//
// Two states answer "no", and they are the point of the file. Both come from
// the same property, in opposite directions: [ConstrainedBox] applies its
// minimum through `BoxConstraints.enforce`, which **clamps that minimum into
// the constraints the parent handed down** rather than winning over them. So
// the size of a [MinTapTarget] is decided by its parent, not by its name.
//
// * `Narrow parent` — a tighter maximum clamps the floor away and the target
//   comes out UNDER 48 dp, with no assert, no overflow stripe and nothing else
//   to say so.
// * `Stretched parent` — a tighter *minimum* (a stretching [Column], the most
//   ordinary layout in the app) blows the target out to the full width of its
//   parent. [MinTapTarget] hit-tests `opaque` across its whole box, so a 16 dp
//   glyph ends up owning a 358 dp-wide strip of taps.
//
// The chip states mirror the production call sites — `offer_sort_bar.dart` and
// `jeeber_feed_tab_view.dart` both wrap an [OmdsChip] exactly this way — so
// what the canvas shows is the shape that ships, not a strawman.
//
// Scenario titles are deliberately unlocalized: they name the *state*, not the
// product, and seeing English there in the AR RTL rendering is expected. The
// chip labels use the real ARB copy so the Arabic rendering still exercises
// real type and real mirroring.

/// A phone-width box with room for a title, a note and one specimen row.
const Size _minTapTargetSpecimenBox = Size(390, 210);

/// Same width, taller: the stretched state stacks a target over its gauge.
const Size _minTapTargetStackedBox = Size(390, 260);

/// The size of the glyph in the icon states — a dismiss "x", the smallest thing
/// this app asks a user to hit and the case the floor exists for.
const double _minTapTargetGlyph = 16;

/// The happy path, and the whole reason the widget exists.
///
/// A 16 dp glyph is nowhere near tappable on its own. Given room, the floor does
/// all the work: the tinted box should be a 48 dp square exactly covering the
/// gauge's footprint, with the glyph centred inside it.
@JeebPreview(group: 'core', name: 'Tiny icon child', size: _minTapTargetSpecimenBox)
Widget minTapTargetTinyIcon() => const _MinTapTargetSpecimen(
      title: 'Tiny icon child',
      note: 'A 16 dp glyph with room to grow. The floor does all the work.',
      child: _MinTapTargetGaugedTarget(child: Icon(Icons.close_rounded, size: _minTapTargetGlyph)),
    );

/// The production shape: an [OmdsChip], as `offer_sort_bar.dart` wraps it.
///
/// Only ONE axis of the floor binds here, which is easy to miss and worth
/// seeing: the chip is already wider than 48 dp, so the minimum is inert
/// horizontally, but its 8 dp vertical padding leaves it about 32 dp tall and
/// the floor lifts it to 48. The tinted box should overshoot the gauge to the
/// trailing side and match it exactly in height.
@JeebPreview(group: 'core', name: 'Chip child', size: _minTapTargetSpecimenBox)
Widget minTapTargetChip() => const _MinTapTargetSpecimen(
      title: 'Chip child',
      note: 'Production shape. Width is already over the floor; height is not.',
      child: _MinTapTargetGaugedTarget(child: _MinTapTargetSortChip(selected: true)),
    );

/// **The state that breaks.** The floor is not a floor.
///
/// [ConstrainedBox] does not override the constraints it is given, it enforces
/// its own INTO them — `minWidth: 48` becomes `clamp(48, 32, 32) == 32` under a
/// parent that sized the slot at 32 dp. The result is a 32 dp tap target with
/// nothing to tell anyone: no assert fires, no overflow stripe is painted, and
/// the widget's own name still says the minimum was applied.
///
/// A fixed icon slot is the ordinary way to reach this — it is one `SizedBox`
/// away from any of the call sites — and it is invisible in review unless the
/// bounds are drawn, which is what this preview is for. The tinted box stops
/// well short of the gauge.
///
/// The glyph child is not incidental. Squeezing a target squeezes its CHILD:
/// [MinTapTarget] passes the clamped maximum straight down through [Align] and
/// clips nothing, so putting the chip from `Chip child` in this slot paints an
/// overflow stripe from inside [OmdsChip] on top of the undersized target. An
/// [Icon] absorbs the squeeze quietly, which is the more dangerous case and the
/// one worth staring at.
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
///
/// `Column(crossAxisAlignment: CrossAxisAlignment.stretch)` hands its children a
/// tight width, and a tight width is also a *minimum*, so `enforce` keeps it.
/// The 16 dp glyph is centred in a box that now spans the whole column, and
/// because [MinTapTarget] hit-tests with [HitTestBehavior.opaque] over its
/// entire box — deliberately, so the padding around a small glyph is tappable —
/// every one of those 358 dp is live.
///
/// Nothing about the rendering hints at it: the glyph looks correctly placed,
/// and the tinted bounds in this preview are the only way to see that a tap two
/// thirds of the way across the row still fires this target's `onTap`. Put a
/// second control on that line and one of them will not be reachable.
@JeebPreview(group: 'core', name: 'Stretched parent', size: _minTapTargetStackedBox)
Widget minTapTargetStretchedParent() => const _MinTapTargetSpecimen(
      title: 'Stretched parent',
      note: 'A stretching Column makes the 48 dp square a full-width tap strip.',
      child: _MinTapTargetStretchedTarget(),
    );

/// The trap in the implementation: the child's own `onTap` never fires.
///
/// [MinTapTarget] wraps the child in an [IgnorePointer] so the outer gesture
/// owns the whole target — deliberate, and documented in the widget. But the
/// natural call is `MinTapTarget(onTap: f, child: OmdsChip(onTap: f))`, and
/// [OmdsChip] takes an `onTap` that will be silently dead. Tap the chip in the
/// canvas: the counter proves only the outer handler ran.
///
/// The same [IgnorePointer] is why every production call site wraps this widget
/// in `Semantics(button: true, label: …) → ExcludeSemantics(…)` — see the test
/// for what a bare [MinTapTarget] exposes to a screen reader on its own.
@JeebPreview(group: 'core', name: 'Child owns its own onTap', size: _minTapTargetSpecimenBox)
Widget minTapTargetChildOnTapSwallowed() => const _MinTapTargetSpecimen(
      title: 'Child owns its own onTap',
      note: 'IgnorePointer eats it. Tap the chip and watch the counters.',
      child: _MinTapTargetSwallowedOnTap(),
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
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
///
/// Deliberately NOT a hardcoded 48: it reads [A11y.minTapTargetSize], so if that
/// token ever moves the gauge moves with it and these previews keep measuring
/// the real contract instead of a stale number.
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
///
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
///
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
///
/// Beneath rather than beside, because the whole point is that the target now
/// occupies the full width — there is no room left on its line to put anything
/// next to it, which is also the bug.
///
/// The tap counter is the interactive half of the demonstration: tap the empty
/// space at the far end of the strip, nowhere near the glyph, and watch it go
/// up. Stateful only for that counter — no controller, no ticker, nothing to
/// settle.
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
///
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
