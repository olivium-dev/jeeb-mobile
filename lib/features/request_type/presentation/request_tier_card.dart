import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import 'selectable_radio_glyph.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../l10n/app_localizations.dart';
import '../../location/presentation/widgets/delivery_create_layout.dart';
import '../../tier_selection/domain/tier.dart';
import 'request_type_radio_id.dart';

class RequestTierCard extends StatelessWidget {
  const RequestTierCard({
    super.key,
    required this.icon,
    required this.title,
    required this.speed,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.semanticIdentifier,
    required this.semanticLabel,
    required this.selectedHint,
  });

  final IconData icon;
  final String title;
  final String speed;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final String semanticIdentifier;
  final String semanticLabel;
  final String selectedHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: semanticIdentifier,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: semanticLabel,
      hint: selected ? selectedHint : null,
      button: true,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: OmdsBorderRadius.uiLarge,
          child: InkWell(
            borderRadius: OmdsBorderRadius.uiLarge,
            onTap: onTap,
            child: _body(scheme),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    final border = selected ? scheme.primary : scheme.outlineVariant;
    return Container(
      padding: const EdgeInsetsDirectional.all(Spacing.medium),
      decoration: BoxDecoration(
        borderRadius: OmdsBorderRadius.uiLarge,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(child: _TierCopy(card: this)),
          const SizedBox(width: Spacing.medium),
          SelectableRadioGlyph(selected: selected),
        ],
      ),
    );
  }
}

class _TierCopy extends StatelessWidget {
  const _TierCopy({required this.card});

  final RequestTierCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final descColor =
        card.selected ? scheme.onPrimary : scheme.onSecondaryContainer;
    final titleColor = card.selected ? scheme.onPrimary : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(card.icon, size: Sizes.large, color: titleColor),
            const SizedBox(width: Spacing.twoXSmall),
            Flexible(child: Text(card.title, style: _titleStyle(text, scheme))),
          ],
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(card.speed, style: text.bodySmall?.copyWith(color: descColor)),
        Text(card.value, style: _valueStyle(text, descColor)),
      ],
    );
  }

  TextStyle? _titleStyle(TextTheme text, ColorScheme scheme) =>
      text.labelLarge?.copyWith(
        color: card.selected ? scheme.onPrimary : scheme.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle? _valueStyle(TextTheme text, Color color) =>
      text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700);
}
// ============================== JEEB PREVIEWS ==============================
const Size _requestTierCardShortCopyBox = Size(390, 370);
const Size _requestTierCardLongestShippingCopyBox = Size(390, 440);
const Size _requestTierCardLongCopyBox = Size(390, 720);

/// What surrounds ONE card in the tier list: the page's horizontal inset
/// ([DeliveryCreateLayout.pagePadding] is 20 dp each side) and, vertically, the
const EdgeInsetsDirectional _requestTierCardPageInset =
    EdgeInsetsDirectional.symmetric(
  horizontal: Spacing.large,
  vertical: Spacing.small,
);

/// Mounts the card the way `_TierList` does: the page inset, full-bleed width,
/// and a shrink-wrapping column.
Widget _requestTierCardHosted({
  required IconData icon,
  required String title,
  required String speed,
  required String value,
  required bool selected,
  required String semanticIdentifier,
  required String semanticLabel,
  required String selectedHint,
}) {
  return Padding(
    padding: _requestTierCardPageInset,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RequestTierCard(
          icon: icon,
          title: title,
          speed: speed,
          value: value,
          selected: selected,
          semanticIdentifier: semanticIdentifier,
          semanticLabel: semanticLabel,
          selectedHint: selectedHint,
          // Selection is the screen's cubit to own; the card only reports the
          onTap: () {},
        ),
      ],
    ),
  );
}

/// Reads the ARB the way `_TierEntry` does, so a localized state's AR rendering
/// is a real review of the Arabic copy.
Widget _requestTierCardLocalized(
  Widget Function(AppLocalizations l10n) build,
) =>
    Builder(builder: (BuildContext ctx) => build(AppLocalizations.of(ctx)));

/// Builds a shipping tier from its ARB copy, id and semantics, exactly as
/// `_TierEntry` assembles it — including [requestTypeRadioId], so the ids the
Widget _requestTierCardTier(
  AppLocalizations l10n, {
  required TierId id,
  required IconData icon,
  required String title,
  required String speed,
  required String value,
  required bool selected,
}) =>
    _requestTierCardHosted(
      icon: icon,
      title: title,
      speed: speed,
      value: value,
      selected: selected,
      semanticIdentifier: requestTypeRadioId(id),
      semanticLabel: l10n.requestTypeTierSemanticLabel(
        title: title,
        speed: speed,
        value: value,
      ),
      selectedHint: l10n.requestTypeTierSelectedHint,
    );

@JeebPreview(
  group: 'request_type',
  name: 'Unselected · Standard',
  size: _requestTierCardShortCopyBox,
)
Widget requestTierCardUnselected() => _requestTierCardLocalized(
      (AppLocalizations l10n) => _requestTierCardTier(
        l10n,
        id: TierId.standard,
        icon: Icons.balance_outlined,
        title: l10n.tierStandardTitle,
        speed: l10n.tierStandardSpeed,
        value: l10n.tierStandardValue,
        selected: false,
      ),
    );

@JeebPreview(
  group: 'request_type',
  name: 'Selected · Flash',
  size: _requestTierCardShortCopyBox,
)
Widget requestTierCardSelected() => _requestTierCardLocalized(
      (AppLocalizations l10n) => _requestTierCardTier(
        l10n,
        id: TierId.flash,
        icon: Icons.bolt_outlined,
        title: l10n.tierFlashTitle,
        speed: l10n.tierFlashSpeed,
        value: l10n.tierFlashValue,
        selected: true,
      ),
    );

@JeebPreview(
  group: 'request_type',
  name: 'Longest shipping copy · On-the-Way',
  size: _requestTierCardLongestShippingCopyBox,
)
Widget requestTierCardLongestShippingCopy() => _requestTierCardLocalized(
      (AppLocalizations l10n) => _requestTierCardTier(
        l10n,
        id: TierId.onTheWay,
        icon: Icons.handshake_outlined,
        title: l10n.tierOnTheWayTitle,
        speed: l10n.tierOnTheWaySpeed,
        value: l10n.tierOnTheWayValue,
        selected: false,
      ),
    );

@JeebPreview(
  group: 'request_type',
  name: 'Selected · Eco (digit range)',
  size: _requestTierCardShortCopyBox,
)
Widget requestTierCardDigitRange() => _requestTierCardLocalized(
      (AppLocalizations l10n) => _requestTierCardTier(
        l10n,
        id: TierId.eco,
        icon: Icons.eco_outlined,
        title: l10n.tierEcoTitle,
        speed: l10n.tierEcoSpeed,
        value: l10n.tierEcoValue,
        selected: true,
      ),
    );

@JeebPreview(
  group: 'request_type',
  name: 'Longest plausible copy · unreleased tier',
  size: _requestTierCardLongCopyBox,
)
Widget requestTierCardLongCopy() => _requestTierCardHosted(
      icon: Icons.local_shipping_outlined,
      title: 'Scheduled Overnight Freight',
      speed: 'Collected after 8 PM and delivered before the shops open '
          'tomorrow morning.',
      value: 'Lowest price per kilogram • Ground-floor drop-off required',
      selected: false,
      semanticIdentifier: 'request_type_overnight_radio',
      semanticLabel: 'Scheduled Overnight Freight. Collected after 8 PM and '
          'delivered before the shops open tomorrow morning. Lowest price per '
          'kilogram • Ground-floor drop-off required.',
      selectedHint: 'Selected',
    );
