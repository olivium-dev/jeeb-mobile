/// Widget previews for [MinTapTarget] — run with
/// `flutter widget-preview start`.
///
/// [MinTapTarget] has no data and no dependencies: it is a [ConstrainedBox], a
/// [GestureDetector] and an [Align]. So these previews are network-free because
/// there is nothing to fetch, not merely because [jeebPreviewHost] guards them,
/// and what varies between states is not content but **the constraints the
/// parent hands down and the child handed in**.
///
/// The widget also paints nothing, which makes it invisible in a canvas unless
/// something draws its bounds. Every state below therefore renders the target
/// inside [_Bounds] — a [DecoratedBox], which sizes itself exactly to its child
/// — beside a [_Gauge], a plain 48 dp square. **The review question in every
/// preview is the same: does the tinted box reach the outlined square?**
/// [A11y.minTapTargetSize] is the promise (AC T-mobile-036: every tappable
/// element ≥ 48 dp / 44 pt); the gauge is that promise drawn to scale.
///
/// Two states answer "no", and they are the point of the file. Both come from
/// the same property, in opposite directions: [ConstrainedBox] applies its
/// minimum through `BoxConstraints.enforce`, which **clamps that minimum into
/// the constraints the parent handed down** rather than winning over them. So
/// the size of a [MinTapTarget] is decided by its parent, not by its name.
///
/// * `Narrow parent` — a tighter maximum clamps the floor away and the target
///   comes out UNDER 48 dp, with no assert, no overflow stripe and nothing else
///   to say so.
/// * `Stretched parent` — a tighter *minimum* (a stretching [Column], the most
///   ordinary layout in the app) blows the target out to the full width of its
///   parent. [MinTapTarget] hit-tests `opaque` across its whole box, so a 16 dp
///   glyph ends up owning a 358 dp-wide strip of taps.
///
/// The chip states mirror the production call sites — `offer_sort_bar.dart` and
/// `jeeber_feed_tab_view.dart` both wrap an [OmdsChip] exactly this way — so
/// what the canvas shows is the shape that ships, not a strawman.
///
/// Scenario titles are deliberately unlocalized: they name the *state*, not the
/// product, and seeing English there in the AR RTL rendering is expected. The
/// chip labels use the real ARB copy so the Arabic rendering still exercises
/// real type and real mirroring.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../core/accessibility/accessibility.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// A phone-width box with room for a title, a note and one specimen row.
const Size _specimenBox = Size(390, 210);

/// Same width, taller: the stretched state stacks a target over its gauge.
const Size _stackedBox = Size(390, 260);

/// The size of the glyph in the icon states — a dismiss "x", the smallest thing
/// this app asks a user to hit and the case the floor exists for.
const double _kGlyph = 16;

/// The happy path, and the whole reason the widget exists.
///
/// A 16 dp glyph is nowhere near tappable on its own. Given room, the floor does
/// all the work: the tinted box should be a 48 dp square exactly covering the
/// gauge's footprint, with the glyph centred inside it.
@JeebPreview(name: 'Tiny icon child', size: _specimenBox)
Widget minTapTargetTinyIcon() => const _Specimen(
      title: 'Tiny icon child',
      note: 'A 16 dp glyph with room to grow. The floor does all the work.',
      child: _GaugedTarget(child: Icon(Icons.close_rounded, size: _kGlyph)),
    );

/// The production shape: an [OmdsChip], as `offer_sort_bar.dart` wraps it.
///
/// Only ONE axis of the floor binds here, which is easy to miss and worth
/// seeing: the chip is already wider than 48 dp, so the minimum is inert
/// horizontally, but its 8 dp vertical padding leaves it about 32 dp tall and
/// the floor lifts it to 48. The tinted box should overshoot the gauge to the
/// trailing side and match it exactly in height.
@JeebPreview(name: 'Chip child', size: _specimenBox)
Widget minTapTargetChip() => const _Specimen(
      title: 'Chip child',
      note: 'Production shape. Width is already over the floor; height is not.',
      child: _GaugedTarget(child: _SortChip(selected: true)),
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
@JeebPreview(name: 'Narrow parent', size: _specimenBox)
Widget minTapTargetNarrowParent() => const _Specimen(
      title: 'Narrow parent',
      note: 'Slot is 32 dp. The 48 dp minimum is clamped away, silently.',
      child: _GaugedTarget(
        slot: 32,
        child: Icon(Icons.close_rounded, size: _kGlyph),
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
@JeebPreview(name: 'Stretched parent', size: _stackedBox)
Widget minTapTargetStretchedParent() => const _Specimen(
      title: 'Stretched parent',
      note: 'A stretching Column makes the 48 dp square a full-width tap strip.',
      child: _StretchedTarget(),
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
@JeebPreview(name: 'Child owns its own onTap', size: _specimenBox)
Widget minTapTargetChildOnTapSwallowed() => const _Specimen(
      title: 'Child owns its own onTap',
      note: 'IgnorePointer eats it. Tap the chip and watch the counters.',
      child: _SwallowedOnTap(),
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// Title + note + one specimen, on the preview surface.
class _Specimen extends StatelessWidget {
  const _Specimen({required this.title, required this.note, required this.child});

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
class _Gauge extends StatelessWidget {
  const _Gauge();

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
class _Bounds extends StatelessWidget {
  const _Bounds({required this.child});

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
class _GaugedTarget extends StatelessWidget {
  const _GaugedTarget({required this.child, this.slot});

  final Widget child;
  final double? slot;

  @override
  Widget build(BuildContext context) {
    Widget target = _Bounds(
      child: MinTapTarget(onTap: () {}, child: child),
    );
    if (slot != null) {
      target = SizedBox(width: slot, height: slot, child: target);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _Gauge(),
        const SizedBox(width: Spacing.medium),
        Flexible(child: target),
      ],
    );
  }
}

/// One sort chip, with the real ARB copy the offers screen uses.
class _SortChip extends StatelessWidget {
  const _SortChip({this.selected = false, this.onTap});

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
class _StretchedTarget extends StatefulWidget {
  const _StretchedTarget();

  @override
  State<_StretchedTarget> createState() => _StretchedTargetState();
}

class _StretchedTargetState extends State<_StretchedTarget> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Bounds(
          child: MinTapTarget(
            onTap: () => setState(() => _taps++),
            child: const Icon(Icons.close_rounded, size: _kGlyph),
          ),
        ),
        const SizedBox(height: Spacing.small),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Gauge(),
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
class _SwallowedOnTap extends StatefulWidget {
  const _SwallowedOnTap();

  @override
  State<_SwallowedOnTap> createState() => _SwallowedOnTapState();
}

class _SwallowedOnTapState extends State<_SwallowedOnTap> {
  int _outer = 0;
  int _child = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Bounds(
          child: MinTapTarget(
            onTap: () => setState(() => _outer++),
            child: _SortChip(onTap: () => setState(() => _child++)),
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
