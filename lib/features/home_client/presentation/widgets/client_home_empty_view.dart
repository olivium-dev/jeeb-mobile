import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key, this.onNewOrder});

  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: '_request_empty_state_root',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsEmptyState(
              illustration: const _ApplicationIllustration(),
              title: AppLocalizations.of(context).homeEmptyTitle,
              subtitle: AppLocalizations.of(context).homePendingEmpty,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.medium,
              ),
            ),
            _NewOrderButton(onPressed: onNewOrder),
          ],
        ),
      ),
    );
  }
}

class _ApplicationIllustration extends StatelessWidget {
  const _ApplicationIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/illustrations/empty_orders.png',
        width: Sizes.twoHundredLarge,
        height: Sizes.twoHundredLarge,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_request_empty_state_new_order_button',
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.homeEmptyCta,
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: () => onPressed?.call(),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone the Requests screen is designed against.
const double _clientHomeEmptyViewPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _clientHomeEmptyViewCompactPhoneWidth = 320;

/// What the Requests ListView actually leaves the pending tab on a 390 × 844
/// phone: 844 − 47 pt top safe area − 90 pt shell nav bar (`Sizes.fiveXLarge` +
const double _clientHomeEmptyViewRequestsSlotHeight = 547;

/// The same arithmetic on a 320 × 568 phone: 568 − 20 − 56 = 492 pt of
/// viewport, minus the same 160 pt of chrome.
const double _clientHomeEmptyViewCompactSlotHeight = 332;

/// Canvas boxes: the framed slot plus a line for the caption.
const Size _clientHomeEmptyViewPhoneBox = Size(
  _clientHomeEmptyViewPhoneWidth,
  _clientHomeEmptyViewRequestsSlotHeight + 40,
);
const Size _clientHomeEmptyViewCompactBox = Size(
  _clientHomeEmptyViewCompactPhoneWidth,
  _clientHomeEmptyViewCompactSlotHeight + 40,
);

/// One state: the empty view inside a fixed slot, hosted the way
/// `ClientHomeScreen._ReadyLayout` hosts it.
Widget _clientHomeEmptyViewHosted({
  required String caption,
  double width = _clientHomeEmptyViewPhoneWidth,
  double slotHeight = _clientHomeEmptyViewRequestsSlotHeight,
  double? textScale,
  bool wired = true,
}) {
  Widget slot = SizedBox(
    width: width,
    height: slotHeight,
    child: SingleChildScrollView(
      child: ClientHomeEmptyView(onNewOrder: wired ? () {} : null),
    ),
  );

  if (textScale != null) {
    final Widget scaled = slot;
    slot = Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: scaled,
      ),
    );
  }

  return Align(
    alignment: AlignmentDirectional.topStart,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ClientHomeEmptyViewCaption(caption),
        _ClientHomeEmptyViewFoldFrame(child: slot),
      ],
    ),
  );
}

/// The production geometry: the pending tab's slot on a 390 pt phone at default
/// text size.
@JeebPreview(
  group: 'home_client',
  name: 'Requests slot · 390',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewRequestsSlot() =>
    _clientHomeEmptyViewHosted(caption: 'Requests slot: 390 x 547');

/// The same content on the narrowest supported phone.
/// Two things change, and only one of them is visible in a screenshot. The
@JeebPreview(
  group: 'home_client',
  name: 'Compact phone · 320',
  size: _clientHomeEmptyViewCompactBox,
)
Widget clientHomeEmptyViewCompactPhone() => _clientHomeEmptyViewHosted(
      caption: 'Compact phone: 320 x 332',
      width: _clientHomeEmptyViewCompactPhoneWidth,
      slotHeight: _clientHomeEmptyViewCompactSlotHeight,
    );

/// The 200 % accessibility ceiling, with the scale pinned so a widget test
/// reproduces it. **This is the preview to open first.**
@JeebPreview(
  group: 'home_client',
  name: '200% text · 390',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewLargeText() => _clientHomeEmptyViewHosted(
      caption: '200% text: 390 x 547',
      textScale: 2,
    );

/// Layout ceiling: the smallest supported phone at the accessibility ceiling.
/// The compound of the two states above, and the worst the surface ever gets:
@JeebPreview(
  group: 'home_client',
  name: '200% text · 320',
  size: _clientHomeEmptyViewCompactBox,
)
Widget clientHomeEmptyViewCompactLargeText() => _clientHomeEmptyViewHosted(
      caption: '200% text: 320 x 332',
      width: _clientHomeEmptyViewCompactPhoneWidth,
      slotHeight: _clientHomeEmptyViewCompactSlotHeight,
      textScale: 2,
    );

/// What a host that forgets the callback renders — `ClientHomeEmptyView()` with
/// `onNewOrder` left at its default `null`.
@JeebPreview(
  group: 'home_client',
  name: 'CTA not wired',
  size: _clientHomeEmptyViewPhoneBox,
)
Widget clientHomeEmptyViewUnwiredCta() => _clientHomeEmptyViewHosted(
      caption: 'CTA not wired: onNewOrder null',
      wired: false,
    );

// ---------------------------------------------------------------------------

/// Names the frame the state under it is being reviewed in.
/// Preview scaffolding — see the banner above. Deliberately small and 1×-only
/// so the `EN 200% text` rendering of the matrix still shows the widget rather
class _ClientHomeEmptyViewCaption extends StatelessWidget {
  const _ClientHomeEmptyViewCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: Spacing.twoXSmall,
        bottom: Spacing.twoXSmall,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Draws the slot's edge so the fold is visible in the canvas.
/// [DecorationPosition.foreground] paints over the child and never affects
/// layout, so the framed box is exactly the slot the arithmetic above describes
class _ClientHomeEmptyViewFoldFrame extends StatelessWidget {
  const _ClientHomeEmptyViewFoldFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
