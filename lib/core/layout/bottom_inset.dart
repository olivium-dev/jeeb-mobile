import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:omds/omds.dart';
import '../../l10n/app_localizations.dart';
import '../previews/jeeb_preview.dart';

/// Edge-to-edge bottom-inset helpers for modals. Must use View.of() not MediaQuery
/// (modal routes consume viewPadding).
extension BottomInsetX on BuildContext {
  /// Keyboard + nav-bar inset for sheets. Use View.of() not MediaQuery.
  double get sheetBottomInset {
    final keyboard = MediaQuery.of(this).viewInsets.bottom;
    final view = View.of(this);
    // Logical pixels.
    final navBar = view.viewPadding.bottom / view.devicePixelRatio;
    return keyboard + navBar;
  }

  /// Nav-bar inset for scrollable bodies. Uses MediaQuery (not View.of()).
  double get scrollBodyBottomInset => MediaQuery.of(this).viewPadding.bottom;
}

/// Wraps a modal sheet body to clear keyboard and nav-bar in edge-to-edge mode.
/// Applies [BottomInsetX.sheetBottomInset] as bottom padding.
class BottomSheetSafeArea extends StatelessWidget {
  const BottomSheetSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.sheetBottomInset),
      child: child,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A phone-width box, tall enough for a short sheet plus its reserved band.
/// 360 is not arbitrary: the two-line body measures 196 pt at 1.0 and 356 pt at
const Size _bottomSheetSafeAreaSheetBox = Size(390, 360);

/// Same width, plus room for the 300 dp simulated keyboard.
const Size _bottomSheetSafeAreaKeyboardBox = Size(390, 620);

/// A full phone, so the modal previews have a backdrop to anchor against.
const Size _bottomSheetSafeAreaPhoneBox = Size(390, 700);

/// Representative software-keyboard height in logical pixels.
/// Matches the 300 dp the helper's own unit test uses
const double _bottomSheetSafeAreaKeyboardDp = 300;

/// The bare widget, bottom-anchored on a contrasting backdrop.
/// [BottomSheetSafeArea] contributes no pixels, so the only way to see what it
Widget _bottomSheetSafeAreaHosted({
  required String title,
  double keyboardDp = 0,
  bool tallBody = false,
}) =>
    _BottomSheetSafeAreaSystemChromeBackdrop(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _BottomSheetSafeAreaSimulatedKeyboard(
          keyboardDp: keyboardDp,
          child: BottomSheetSafeArea(
            child: _BottomSheetSafeAreaSheetBody(title: title, tall: tallBody),
          ),
        ),
      ),
    );

/// The regression this widget exists for.
/// Keyboard closed means `viewInsets.bottom == 0`, so a sheet that padded by
@JeebPreview(group: 'core', name: 'Keyboard closed', size: _bottomSheetSafeAreaSheetBox)
Widget bottomSheetSafeAreaKeyboardClosed() =>
    _bottomSheetSafeAreaHosted(title: 'Sheet CTA, keyboard closed');

/// Typing in a sheet: the keyboard term at its representative height.
/// This is the one term a preview can drive end to end, and it is worth
@JeebPreview(group: 'core', name: 'Keyboard open', size: _bottomSheetSafeAreaKeyboardBox)
Widget bottomSheetSafeAreaKeyboardOpen() => _bottomSheetSafeAreaHosted(
      title: 'Sheet CTA, keyboard open',
      keyboardDp: _bottomSheetSafeAreaKeyboardDp,
    );

/// A realistic sheet body — three fields and a CTA — rather than the two lines
/// the states above use.
@JeebPreview(group: 'core', name: 'Tall body', size: _bottomSheetSafeAreaKeyboardBox)
Widget bottomSheetSafeAreaTallBody() =>
    _bottomSheetSafeAreaHosted(title: 'Tall sheet body', tallBody: true);

/// The production shape: pushed by `showModalBottomSheet`, over a scrim.
/// This is the only pair of previews that renders the widget where it is meant
@JeebPreview(group: 'core', name: 'Modal route', size: _bottomSheetSafeAreaPhoneBox)
Widget bottomSheetSafeAreaInModalRoute() =>
    _bottomSheetSafeAreaModalPresentation(title: 'Inside a modal sheet');

/// The full field-editing case: a modal sheet with the keyboard up.
/// Both terms are live at once, which is the only configuration that checks the
@JeebPreview(group: 'core', name: 'Modal route · keyboard open', size: _bottomSheetSafeAreaPhoneBox)
Widget bottomSheetSafeAreaInModalRouteWithKeyboard() => _bottomSheetSafeAreaModalPresentation(
      title: 'Modal sheet, keyboard open',
      keyboardDp: _bottomSheetSafeAreaKeyboardDp,
    );

/// Hosts the sheet in a real modal route.
/// The local [Navigator] is what makes this self-contained: `showModalBottomSheet`
Widget _bottomSheetSafeAreaModalPresentation({required String title, double keyboardDp = 0}) =>
    Navigator(
      onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => _BottomSheetSafeAreaSheetOverBackdrop(
          title: title,
          keyboardDp: keyboardDp,
        ),
      ),
    );

/// Opens the sheet over the backdrop on the first frame.
class _BottomSheetSafeAreaSheetOverBackdrop extends StatefulWidget {
  const _BottomSheetSafeAreaSheetOverBackdrop({required this.title, required this.keyboardDp});

  final String title;
  final double keyboardDp;

  @override
  State<_BottomSheetSafeAreaSheetOverBackdrop> createState() => _BottomSheetSafeAreaSheetOverBackdropState();
}

class _BottomSheetSafeAreaSheetOverBackdropState extends State<_BottomSheetSafeAreaSheetOverBackdrop> {
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
      builder: (_) => _BottomSheetSafeAreaSimulatedKeyboard(
        keyboardDp: widget.keyboardDp,
        child: BottomSheetSafeArea(child: _BottomSheetSafeAreaSheetBody(title: widget.title)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const _BottomSheetSafeAreaSystemChromeBackdrop(child: SizedBox.expand());
}

/// Seeds the keyboard half of [BottomInsetX.sheetBottomInset].
/// `viewInsets` is the only one of the two inputs that lives in [MediaQuery],
/// so it is the only one a preview can set. Written as a widget rather than an
class _BottomSheetSafeAreaSimulatedKeyboard extends StatelessWidget {
  const _BottomSheetSafeAreaSimulatedKeyboard({required this.keyboardDp, required this.child});

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
class _BottomSheetSafeAreaSystemChromeBackdrop extends StatelessWidget {
  const _BottomSheetSafeAreaSystemChromeBackdrop({required this.child});

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
/// Inert by construction — no controller, no ticker, and an `onTap` that does
/// nothing — so the render harness can `pumpAndSettle` it.
class _BottomSheetSafeAreaSheetBody extends StatelessWidget {
  const _BottomSheetSafeAreaSheetBody({required this.title, this.tall = false});

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
            const _BottomSheetSafeAreaInsetReadout(),
            if (tall) ...<Widget>[
              const SizedBox(height: Spacing.medium),
              for (final String label in const <String>[
                'From · any date',
                'To · any date',
                'Status · all',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xSmall),
                  child: _BottomSheetSafeAreaFieldRow(label: label),
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
class _BottomSheetSafeAreaFieldRow extends StatelessWidget {
  const _BottomSheetSafeAreaFieldRow({required this.label});

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
/// The total comes from [BottomInsetX.sheetBottomInset] itself — the fixture
/// does not re-implement the formula, so if the helper changes this readout
class _BottomSheetSafeAreaInsetReadout extends StatelessWidget {
  const _BottomSheetSafeAreaInsetReadout();

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
