/// Widget previews for [CustomerRegisterPill] — run with
/// `flutter widget-preview start`.
///
/// The pill takes **one** argument ([CustomerRegisterPill.onTap]) and renders
/// **one** string, the localized `customerProfileRegisterCta`. Nothing about it
/// varies with data, so six previews of the pill on its own would be six
/// identical stadiums and a render test could not tell them apart — the exact
/// failure `expectedText` exists to catch. What varies, and what breaks, is the
/// **context**: it is the trailing affordance of a [CustomerProfileRow] whose
/// label is [Expanded]; it is a **fixed-height** control (`Sizes.threeXLarge` =
/// 40 dp) whose label is not fixed height; and its "hugs its label" width turns
/// out to be borrowed from that [Row] rather than owned (see
/// [customerRegisterPillInBoundedParent]).
///
/// So each state below is the pill in one real composition — built from the
/// production [CustomerProfileRow], with the same icon / label / semantics id
/// `CustomerProfileRows` gives it — plus a caption naming the state. The caption
/// is preview chrome (`labelSmall` / `onSurfaceVariant`) and is deliberately
/// unlocalized: it names the *state*, not the product, so English in the AR RTL
/// rendering is expected.
///
/// **Network-free by construction.** The pill owns no cubit, no repository and
/// no image; every `onTap` here is a no-op closure, so unlike the shell previews
/// these are safe to tap in the canvas. [jeebPreviewHost]'s `CatalogNetworkGuard`
/// is the net, not the plan.
///
/// The a11y contract the widget documents (JEBV4-98 / F10-F11: the pill's own
/// semantics are excluded so the row stays the single announced button) is not
/// visible in the canvas at all — it is asserted in
/// `test/previews/customer_profile/customer_register_pill_preview_test.dart`,
/// which is the honest place for it. That assertion holds; what it turned up on
/// the way is that [CustomerProfileRow] announces its own label **twice**
/// ("Register as a delivery\nRegister as a delivery" — once from its `Semantics`
/// wrapper, once from the visible `Text` it does not exclude). That one belongs
/// to the row, not to the pill.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/customer_profile/presentation/widgets/customer_profile_row.dart';
import '../../features/customer_profile/presentation/widgets/customer_register_pill.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// A phone-width slice of the profile list: enough width for the row's label to
/// have somewhere to go, and room for the caption at 200%.
const Size _rowBox = Size(390, 170);

/// The narrow phones still in the fleet (iPhone SE, Galaxy A0x): 70 fewer
/// logical pixels for the [Expanded] label to give up before it ellipsizes.
const Size _narrowRowBox = Size(320, 170);

/// Two rows plus caption.
const Size _twoRowBox = Size(390, 230);

/// Content width of the slab each state is laid out in. Matches the canvas box
/// width so the canvas and the render test measure the same layout.
const double _phoneWidth = 390;
const double _narrowWidth = 320;

/// One specimen: the composition under review, framed, with a caption naming
/// the state beneath it.
Widget _hosted({
  required String caption,
  required Widget child,
  double width = _phoneWidth,
}) =>
    _Specimen(caption: caption, width: width, child: child);

/// The component on its own, in a host that constrains it the way a [Row] does
/// — outlined so its footprint is measurable by eye.
///
/// This is the intrinsic size the design brief describes: **144.8 × 40 dp** at
/// 1.0×. Two things to check. The pill hugs its label (no `width` is passed to
/// [OmdsPrimaryButton], so it shrink-wraps `Spacing.medium` of padding either
/// side of the text), and it is exactly 40 dp tall — a full 8 dp shorter than
/// the library default (`Sizes.fourXLarge`), which is what makes it read as a
/// chip rather than a CTA.
///
/// Note the host: a `mainAxisSize.min` [Row], not a bare [Align]. That is not
/// decoration — see [customerRegisterPillInBoundedParent] for what the same
/// widget does when its parent hands it a bounded width instead.
@JeebPreview(name: 'Pill alone', size: _rowBox)
Widget customerRegisterPillAlone() => _hosted(
      caption: 'Pill alone · hugs its label, 40 dp tall',
      child: const Padding(
        padding: EdgeInsets.all(Spacing.xSmall),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[CustomerRegisterPill(onTap: _noop)],
        ),
      ),
    );

/// The production composition: the "Register as a delivery" row of the customer
/// profile (JM-035 AC2), the only place this widget is ever mounted.
///
/// This is the state to read the design against — 32 dp navy disc, muted label,
/// navy pill hard against the trailing edge, the whole row on a 56 dp
/// (`Sizes.fiveXLarge`) minimum. **AR RTL** is the half worth staring at: the
/// row's padding is [EdgeInsetsDirectional], so disc and pill should swap sides
/// as a unit and the pill should end up on the leading (left) edge.
@JeebPreview(name: 'In profile row', size: _rowBox)
Widget customerRegisterPillInRow() => _hosted(
      caption: 'In profile row · 390 dp',
      child: const _RegisterRow(),
    );

/// The same row where it is tightest: a 320 dp phone.
///
/// The pill is not flexible — it takes the width its label needs and the
/// [Expanded] label absorbs the whole difference, so 70 fewer pixels of screen
/// come out of the label alone. This is where "Register as a delivery"
/// ellipsizes first, and the state that answers whether the truncated label
/// still says enough for the row to be tappable with meaning.
@JeebPreview(name: 'Narrow phone', size: _narrowRowBox)
Widget customerRegisterPillNarrowRow() => _hosted(
      caption: 'Narrow phone · 320 dp',
      width: _narrowWidth,
      child: const _RegisterRow(),
    );

/// The pill next to the neighbour it has to live with: the chevron rows.
///
/// Every other row in `CustomerProfileRows` ends in a 16 dp chevron; this one
/// ends in a 40 dp-tall filled pill. Two things only a side-by-side rendering
/// answers: whether the trailing edges line up (the pill's stadium ends where
/// the chevron ends, both inside `Spacing.xLarge` of row padding), and whether
/// the row heights stay even — the pill is 40 dp inside a 56 dp minimum, so it
/// must not push its row taller than its neighbour. In **dark** (the AR RTL
/// rendering) the filled navy pill is also the only saturated block in the
/// list; this is where to judge whether it is emphasis or noise.
@JeebPreview(name: 'Beside chevron rows', size: _twoRowBox)
Widget customerRegisterPillBesideChevronRows() => _hosted(
      caption: 'Beside chevron rows · alignment + weight',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[_RegisterRow(), _PasswordRow()],
      ),
    );

/// **The ceiling, and it is flush.** The same row forced to 200% text.
///
/// [OmdsPrimaryButton] lays its label out inside an `AnimatedContainer` with a
/// hard `height:` — [CustomerRegisterPill] passes `Sizes.threeXLarge` (40 dp) —
/// so the pill's box does NOT scale while its label does. Measured at 390 dp:
///
/// | scale | pill box    | label line box |
/// |-------|-------------|----------------|
/// | 1.0×  | 144.8 × 40  | 112.8 × 20     |
/// | 2.0×  | 256.8 × 40  | 224.8 × **40** |
///
/// At the 200% ceiling the label exactly fills the pill — **0.0 dp of vertical
/// headroom**. It does not clip here, but nothing above 200% survives: at 250%
/// the label's natural line box is 50 dp and `RenderParagraph` silently crops it
/// back to 40 (no stripes, no exception), and the [Row] itself overflows by 11 px
/// because the pill is non-flexible and keeps growing while the [Expanded] label
/// has already collapsed to nothing. iOS accessibility Dynamic Type goes past
/// 250%. The render test pins both numbers.
///
/// The scale is clamped here rather than left to the matrix on purpose: it puts
/// the ceiling in the **default EN light card**, directly comparable with the
/// 1.0× "In profile row" state above. Consequence of the clamp: the matrix's own
/// "EN 200% text" rendering of this one state is identical to its "EN light"
/// rendering, by design. 250% is deliberately NOT a preview — it throws a
/// layout exception, which would fail every render test in the file rather than
/// reporting the one defect.
@JeebPreview(name: 'Row at 200% text', size: _rowBox)
Widget customerRegisterPillRowAtLargeText() => _hosted(
      caption: 'Row at 200% text · pill stays 40 dp',
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 2.0,
        maxScaleFactor: 2.0,
        child: const _RegisterRow(),
      ),
    );

/// **The state that breaks.** The pill given a *bounded* width by its parent.
///
/// "Compact stadium that hugs its label" is not a property of this widget — it
/// is a property of the [Row] it happens to be mounted in. [CustomerProfileRow]
/// puts it in the non-flexible slot of a [Row], where the main-axis constraint
/// is unbounded, so [OmdsPrimaryButton]'s `width: null` container shrink-wraps.
/// Hand it a bounded width instead — a [Column] with
/// `crossAxisAlignment: stretch`, a [SizedBox], a bottom sheet, anything — and
/// the `Center` inside [OmdsPrimaryButton] expands to fill it: measured **374 dp
/// wide** in this 390 dp slab, versus 144.8 dp in the row above. Same widget,
/// same arguments, and it silently stops being a pill and becomes a full-width
/// CTA.
///
/// Nothing in the widget prevents this (no `IntrinsicWidth`, no
/// `mainAxisSize.min` wrapper, no `width`), and nothing warns about it, so the
/// second caller to reuse it is the one who finds out. This state is here so
/// that discovery happens in the canvas.
@JeebPreview(name: 'Bounded parent', size: _rowBox)
Widget customerRegisterPillInBoundedParent() => _hosted(
      caption: 'Bounded parent · stretches, no longer a pill',
      child: const Padding(
        padding: EdgeInsets.all(Spacing.xSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[CustomerRegisterPill(onTap: _noop)],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// Every action in these previews. The pill's `onTap` is required, and in
/// production it opens the jeeber onboarding wizard; a preview has no
/// `GoRouter`, so it does nothing here and tapping in the canvas is safe.
void _noop() {}

/// The register row exactly as `CustomerProfileRows` builds it — same icon,
/// same ARB label, same `Semantics(identifier:)`, same `onTap` shared between
/// the row and its trailing pill (which is *why* the pill excludes its own
/// semantics).
class _RegisterRow extends StatelessWidget {
  const _RegisterRow();

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.delivery_dining_outlined,
      label: AppLocalizations.of(context).customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      onTap: _noop,
      trailing: const CustomerRegisterPill(onTap: _noop),
    );
  }
}

/// The row immediately below it in production: same shape, default chevron
/// trailing. Present only to give the pill a neighbour to be judged against.
class _PasswordRow extends StatelessWidget {
  const _PasswordRow();

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.lock_outline,
      label: AppLocalizations.of(context).customerProfilePasswordSecurity,
      semanticsId: 'customer_profile_password_row',
      onTap: _noop,
    );
  }
}

/// The specimen frame: the composition under review on a fixed-width slab, with
/// a caption naming the state beneath it.
///
/// The slab width is pinned so the canvas and the render test lay the row out
/// at the same width — the whole question in the narrow and 200% states is what
/// the [Expanded] label does with the pixels the pill leaves it, and that answer
/// is meaningless at an arbitrary width. The caption sits below the frame so it
/// reads as a label on it, and is capped at two lines so the 200%-text
/// rendering shrinks it instead of overflowing the canvas box.
class _Specimen extends StatelessWidget {
  const _Specimen({
    required this.caption,
    required this.width,
    required this.child,
  });

  final String caption;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: child,
              ),
              const SizedBox(height: Spacing.xSmall),
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
