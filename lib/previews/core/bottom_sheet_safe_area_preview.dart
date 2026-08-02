/// Widget previews for [BottomSheetSafeArea] — run with
/// `flutter widget-preview start`.
///
/// [BottomSheetSafeArea] is a [Padding] and nothing else: it renders no pixels
/// of its own, has no data, and needs no cubit or repository. These previews are
/// network-free because the widget has nothing to fetch, not merely because
/// [jeebPreviewHost] guards it.
///
/// What varies is therefore not content but the ambient insets it reads, and
/// only ONE of the two is injectable from inside the widget tree:
///
/// * **The keyboard term** comes from `MediaQuery.of(context).viewInsets.bottom`,
///   so [_SimulatedKeyboard] can seed it and the canvas shows a real, correctly
///   sized lift.
/// * **The nav-bar term** comes from `View.of(context).viewPadding` — the raw
///   [FlutterView], chosen so it survives the modal route (see the extension
///   docs in `bottom_inset.dart`). There is no widget that can substitute a
///   [FlutterView] mid-tree, so **no preview can simulate a soft-button nav
///   bar**: in the canvas (a desktop window, `viewPadding == 0`) that half
///   always resolves to zero. It is assertable only from a widget test via
///   `tester.view.viewPadding`, which is what
///   `test/previews/core/bottom_sheet_safe_area_preview_test.dart` does and what
///   `test/core/layout/bottom_inset_test.dart` already did.
///
/// One consequence of that choice is visible in these previews and is worth
/// knowing before reading them: because the nav-bar term bypasses [MediaQuery],
/// it cannot tell that an ancestor already reserved the same inset. Every
/// preview here is inside the [SafeArea] that [jeebPreviewHost] wraps around it,
/// so on a device the band below the CTA would be the nav-bar inset reserved
/// TWICE. That is harmless in a real modal sheet, which has no such ancestor,
/// and is why [BottomInsetX.scrollBodyBottomInset] — for content that DOES sit
/// under one — reads MediaQuery instead. The preview test pins the doubling
/// rather than the previews hiding it.
///
/// So read these previews as: *the sheet body sits this far above the bottom of
/// its box, and on a device the nav-bar inset is added on top of that.*
/// [_InsetReadout] prints the number the widget actually computed
/// (`context.sheetBottomInset`) so the reviewer never has to guess which of the
/// two terms produced the gap.
///
/// The sheet body is a fixture, not a production widget — [BottomSheetSafeArea]
/// has no callers of its own yet (all three live sheets call
/// [BottomInsetX.sheetBottomInset] directly), so there is no real body to
/// borrow. Its title line and inset readout are deliberately unlocalized: they
/// name the *scenario*, and seeing English there in the AR RTL rendering is
/// expected. The CTA uses the real ARB copy (`orderHistoryFilterApply`) so the
/// Arabic rendering still exercises real type and real mirroring — the CTA is
/// also the thing a nav bar actually eats, which is the whole point of the
/// widget.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../core/layout/bottom_inset.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// A phone-width box, tall enough for a short sheet plus its reserved band.
///
/// 360 is not arbitrary: the two-line body measures 196 pt at 1.0 and 356 pt at
/// 200% text, so the **EN 200% text** rendering just fits and any overflow
/// stripe the canvas paints here belongs to the widget rather than to the box.
const Size _sheetBox = Size(390, 360);

/// Same width, plus room for the 300 dp simulated keyboard.
const Size _keyboardBox = Size(390, 620);

/// A full phone, so the modal previews have a backdrop to anchor against.
const Size _phoneBox = Size(390, 700);

/// Representative software-keyboard height in logical pixels.
///
/// Matches the 300 dp the helper's own unit test uses
/// (`test/core/layout/bottom_inset_test.dart`), so preview and test stay
/// comparable.
const double _kKeyboardDp = 300;

/// The bare widget, bottom-anchored on a contrasting backdrop.
///
/// [BottomSheetSafeArea] contributes no pixels, so the only way to see what it
/// reserved is to give the body an opaque surface and paint something else
/// behind it: the band between the body's bottom edge and the bottom of the box
/// IS the inset.
Widget _hosted({
  required String title,
  double keyboardDp = 0,
  bool tallBody = false,
}) =>
    _SystemChromeBackdrop(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _SimulatedKeyboard(
          keyboardDp: keyboardDp,
          child: BottomSheetSafeArea(
            child: _SheetBody(title: title, tall: tallBody),
          ),
        ),
      ),
    );

/// The regression this widget exists for.
///
/// Keyboard closed means `viewInsets.bottom == 0`, so a sheet that padded by
/// the keyboard alone would reserve NOTHING here and hand its CTA straight to
/// the soft buttons. The readout should show the keyboard at 0 and the reserved
/// total equal to the nav bar — which in the canvas is also 0 (see the library
/// doc), so what you are checking here is the shape the CTA takes when it sits
/// flush against the bottom edge: that is exactly the pixel row a 48 dp
/// 3-button nav bar covers.
@JeebPreview(group: 'core', name: 'Keyboard closed', size: _sheetBox)
Widget bottomSheetSafeAreaKeyboardClosed() =>
    _hosted(title: 'Sheet CTA, keyboard closed');

/// Typing in a sheet: the keyboard term at its representative height.
///
/// This is the one term a preview can drive end to end, and it is worth
/// watching because it is *additive* — on a device the nav-bar inset is stacked
/// on top of this gap, not merged into it.
///
/// **This is the state that breaks.** [BottomSheetSafeArea] pads OUTSIDE its
/// child, and the child is a [Column] with no scroll fallback — the shape the
/// widget's own doc example shows (`BottomSheetSafeArea(child: MySheetBody())`).
/// So the inset does not compress the body, it pushes it past the top of the
/// box: measured at 390 pt wide, this body is 196 pt at 1.0 and 356 pt at 200%
/// text, and 356 + 300 = 656 does not fit the 620 pt box — the **EN 200% text**
/// rendering of the matrix overflows by 36 pt. The box is not a strawman; it is
/// roughly a small phone with the keyboard up, and on the 568 pt-tall phone the
/// app still supports there is less room, not more. (Measured under
/// `flutter test`, whose monospaced substitute font runs wider than the
/// production Inter face, so treat 36 pt as the pessimistic end.)
///
/// Two of the three live callers of [BottomInsetX.sheetBottomInset] wrap their
/// body in a [SingleChildScrollView] and so degrade to a scroll instead. The
/// third, `super_login_sheet.dart`, pads a plain non-scrolling
/// `_SuperLoginFormColumn` — and it is a two-field form, so the keyboard is up
/// by definition, i.e. it is this preview's shape in production. Nothing in
/// [BottomSheetSafeArea] or its docs asks a caller to add the scroll view.
@JeebPreview(group: 'core', name: 'Keyboard open', size: _keyboardBox)
Widget bottomSheetSafeAreaKeyboardOpen() => _hosted(
      title: 'Sheet CTA, keyboard open',
      keyboardDp: _kKeyboardDp,
    );

/// A realistic sheet body — three fields and a CTA — rather than the two lines
/// the states above use.
///
/// Two things this catches that a short body cannot. First, it makes the AR RTL
/// rendering legible at all: [BottomSheetSafeArea] pads only the bottom edge, so
/// it has no directional component of its own to get wrong, and what these rows
/// actually check is that nothing between the canvas and the body drops the
/// ambient direction — if the start-aligned labels stay hard left in Arabic,
/// something above the sheet did. Second, it is the height baseline for the
/// overflow described on
/// `Keyboard open` — measured 356 pt at 1.0 and 492 pt at 200% text, i.e. this
/// body alone still fits its 620 pt box at the accessibility ceiling, and it is
/// the 300 pt keyboard inset stacked on top that does not.
@JeebPreview(group: 'core', name: 'Tall body', size: _keyboardBox)
Widget bottomSheetSafeAreaTallBody() =>
    _hosted(title: 'Tall sheet body', tallBody: true);

/// The production shape: pushed by `showModalBottomSheet`, over a scrim.
///
/// This is the only pair of previews that renders the widget where it is meant
/// to be used, and it is the one to keep an eye on. The extension's docs say a
/// modal route CONSUMES the bottom padding, which is why the helper bypasses
/// [MediaQuery] for the nav-bar term. Measured on Flutter 3.44.2 in a plain
/// [MaterialApp] host that is no longer true: inside a default
/// `showModalBottomSheet` builder (`useSafeArea: false`, i.e.
/// `MediaQuery.removePadding(removeTop: true)`) both `padding.bottom` and
/// `viewPadding.bottom` still carry the full 48 dp. If that holds on device the
/// bypass is no longer buying anything and is only costing the double pad
/// described above — but nothing here proves the on-device case, so this stays
/// a flag for whoever owns `bottom_inset.dart`, not a change.
///
/// Note that the reserved band is invisible in this framing, and correctly so:
/// the sheet's own [Material] paints behind the padding, so what you check is
/// the gap between the CTA and the bottom edge of the sheet — not a change of
/// colour.
@JeebPreview(group: 'core', name: 'Modal route', size: _phoneBox)
Widget bottomSheetSafeAreaInModalRoute() =>
    _modalPresentation(title: 'Inside a modal sheet');

/// The full field-editing case: a modal sheet with the keyboard up.
///
/// Both terms are live at once, which is the only configuration that checks the
/// second half of the extension's claim — that `viewInsets.bottom` IS
/// propagated into the sheet even though the padding is not. If this renders
/// identically to `Modal route`, the propagation has broken and every sheet
/// with a text field will hide its CTA behind the keyboard.
@JeebPreview(group: 'core', name: 'Modal route · keyboard open', size: _phoneBox)
Widget bottomSheetSafeAreaInModalRouteWithKeyboard() => _modalPresentation(
      title: 'Modal sheet, keyboard open',
      keyboardDp: _kKeyboardDp,
    );

/// Hosts the sheet in a real modal route.
///
/// The local [Navigator] is what makes this self-contained: `showModalBottomSheet`
/// needs a navigator to push onto, and a preview must not assume the canvas (or
/// a test harness) supplies one it can safely mutate.
Widget _modalPresentation({required String title, double keyboardDp = 0}) =>
    Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _SheetOverBackdrop(
          title: title,
          keyboardDp: keyboardDp,
        ),
      ),
    );

/// Opens the sheet over the backdrop on the first frame.
class _SheetOverBackdrop extends StatefulWidget {
  const _SheetOverBackdrop({required this.title, required this.keyboardDp});

  final String title;
  final double keyboardDp;

  @override
  State<_SheetOverBackdrop> createState() => _SheetOverBackdropState();
}

class _SheetOverBackdropState extends State<_SheetOverBackdrop> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because the sheet needs a mounted route to push onto.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _SimulatedKeyboard(
        keyboardDp: widget.keyboardDp,
        child: BottomSheetSafeArea(child: _SheetBody(title: widget.title)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const _SystemChromeBackdrop(child: SizedBox.expand());
}

/// Seeds the keyboard half of [BottomInsetX.sheetBottomInset].
///
/// `viewInsets` is the only one of the two inputs that lives in [MediaQuery],
/// so it is the only one a preview can set. Written as a widget rather than an
/// inline [MediaQuery] so `MediaQuery.of` resolves against the ambient data and
/// this overrides one field of it instead of replacing the whole thing.
class _SimulatedKeyboard extends StatelessWidget {
  const _SimulatedKeyboard({required this.keyboardDp, required this.child});

  final double keyboardDp;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboardDp),
        ),
        child: child,
      );
}

/// Everything outside the sheet: the pixels the reserved band exposes.
class _SystemChromeBackdrop extends StatelessWidget {
  const _SystemChromeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.inverseSurface.withValues(alpha: 0.14),
          colors.surface,
        ),
      ),
      child: child,
    );
  }
}

/// A stand-in sheet body: drag handle, title, inset readout, CTA.
///
/// Inert by construction — no controller, no ticker, and an `onTap` that does
/// nothing — so the render harness can `pumpAndSettle` it.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, this.tall = false});

  final String title;

  /// Adds filler rows so the body approaches the height of its box.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Spacing.large),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.small,
          Spacing.medium,
          Spacing.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.twoXSmall),
            const _InsetReadout(),
            if (tall) ...<Widget>[
              const SizedBox(height: Spacing.medium),
              for (final String label in const <String>[
                'From · any date',
                'To · any date',
                'Status · all',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xSmall),
                  child: _FieldRow(label: label),
                ),
            ],
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(
              text: l10n.orderHistoryFilterApply,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// An inert stand-in for a form field — shape only, no controller.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      height: 48,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.small),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Spacing.small),
      ),
      child: Text(label, style: theme.textTheme.bodyMedium),
    );
  }
}

/// Prints what the widget under review actually reserved.
///
/// The total comes from [BottomInsetX.sheetBottomInset] itself — the fixture
/// does not re-implement the formula, so if the helper changes this readout
/// changes with it. Only the keyboard term is read separately, to split the
/// total into the half a preview can drive and the half it cannot.
class _InsetReadout extends StatelessWidget {
  const _InsetReadout();

  @override
  Widget build(BuildContext context) {
    final double reserved = context.sheetBottomInset;
    final double keyboard = MediaQuery.of(context).viewInsets.bottom;
    final ThemeData theme = Theme.of(context);
    return Text(
      'reserved ${reserved.toStringAsFixed(0)} dp '
      '= keyboard ${keyboard.toStringAsFixed(0)} '
      '+ nav bar ${(reserved - keyboard).toStringAsFixed(0)}',
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
