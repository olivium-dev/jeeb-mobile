import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/theme/jeeb_tier_colors.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/client_home_request.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({
    super.key,
    required this.request,
    required this.onTap,
    this.onOpenChat,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;

  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'orders_active_card_${request.id}',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        key: Key('active-request-card-${request.id}'),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.xSmall,
        ),
        child: _ActiveOrderColumn(
          request: request,
          onTap: onTap,
          onOpenChat: onOpenChat,
          divider: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class _ActiveOrderColumn extends StatelessWidget {
  const _ActiveOrderColumn({
    required this.request,
    required this.onTap,
    required this.divider,
    this.onOpenChat,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;
  final Widget divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActiveOrderRow(request: request, onTap: onTap, onOpenChat: onOpenChat),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Spacing.xSmall),
          child: divider,
        ),
      ],
    );
  }
}

class _ActiveOrderRow extends StatelessWidget {
  const _ActiveOrderRow({
    required this.request,
    required this.onTap,
    this.onOpenChat,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveOrderAvatar(initial: _initial(request.title)),
        const SizedBox(width: Spacing.twoXSmall),
        Expanded(
          child: _ActiveOrderBody(
            request: request,
            onTap: onTap,
            onOpenChat: onOpenChat,
          ),
        ),
      ],
    );
  }

  static String _initial(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '?' : trimmed[0];
  }
}

class _ActiveOrderAvatar extends StatelessWidget {
  const _ActiveOrderAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) => JeebAvatar.thread(initial: initial);
}

class _ActiveOrderBody extends StatelessWidget {
  const _ActiveOrderBody({
    required this.request,
    required this.onTap,
    this.onOpenChat,
  });

  final ClientHomeRequest request;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final onOpenChat = this.onOpenChat;
    final showChat = _hasJeeber(request.status) && onOpenChat != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveOrderHeader(title: request.title, tier: request.tier),
        const SizedBox(height: Spacing.twoXSmall),
        _ActiveOrderDestination(label: request.summaryLine),
        const SizedBox(height: Spacing.medium),
        _ActiveOrderProgressBar(progressStep: request.progressStep),
        const SizedBox(height: Spacing.small),
        const _ActiveOrderProgressLabels(),
        if (_canTrack(request.status) || showChat)
          _ActiveOrderActions(
            requestId: request.id,
            onTrack: _canTrack(request.status) ? onTap : null,
            onOpenChat: showChat ? onOpenChat : null,
          ),
      ],
    );
  }

  static bool _canTrack(ClientRequestStatus s) =>
      s != ClientRequestStatus.delivered && s != ClientRequestStatus.cancelled;

  static bool _hasJeeber(ClientRequestStatus s) =>
      s == ClientRequestStatus.accepted ||
      s == ClientRequestStatus.atPickup ||
      s == ClientRequestStatus.enRoute;
}

class _ActiveOrderHeader extends StatelessWidget {
  const _ActiveOrderHeader({required this.title, required this.tier});

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

class ClientHomeTierBadge extends StatelessWidget {
  const ClientHomeTierBadge({super.key, required this.tier});

  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tokens = theme.extension<JeebTierColors>();
    final semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    // An UNKNOWN tier is not the accent — it falls back to muted ink, the same
    // "no fact on file" convention as `JeebAvatarFill.dormant`.
    final color = _colorFor(tokens) ?? semantics.mutedText;
    final label = _labelFor(l10n);
    return Text(
      label,
      style: context.jeebText.label.copyWith(color: color, letterSpacing: 0.5),
    );
  }

  Color? _colorFor(JeebTierColors? tokens) {
    if (tokens == null) return null;
    switch (tier) {
      case ClientRequestTier.flash:
        return tokens.flash;
      case ClientRequestTier.express:
        return tokens.express;
      case ClientRequestTier.standard:
        return tokens.standard;
      case ClientRequestTier.onTheWay:
        return tokens.onTheWay;
      case ClientRequestTier.eco:
        return tokens.eco;
      case ClientRequestTier.unknown:
        return null;
    }
  }

  String _labelFor(AppLocalizations l10n) {
    switch (tier) {
      case ClientRequestTier.flash:
        return l10n.tierSelectionTierFlash;
      case ClientRequestTier.express:
        return l10n.tierSelectionTierExpress;
      case ClientRequestTier.standard:
        return l10n.tierSelectionTierStandard;
      case ClientRequestTier.onTheWay:
        return l10n.tierSelectionTierOnTheWay;
      case ClientRequestTier.eco:
        return l10n.tierSelectionTierEco;
      case ClientRequestTier.unknown:
        return '';
    }
  }
}

class _ActiveOrderDestination extends StatelessWidget {
  const _ActiveOrderDestination({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: context.jeebText.caption.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ActiveOrderProgressBar extends StatelessWidget {
  const _ActiveOrderProgressBar({required this.progressStep});

  final int progressStep;

  @override
  Widget build(BuildContext context) {
    // No ink override: `progressIndicatorTheme` already paints the bar
    // periwinkle over a `glassBorder` track. An override here spent orange.
    return ClipRRect(
      borderRadius: OmdsBorderRadius.twoXSmall,
      child: LinearProgressIndicator(
        value: _progressFor(progressStep),
        minHeight: Sizes.twoXSmall,
      ),
    );
  }

  static double _progressFor(int step) {
    final clamped = step.clamp(0, 3).toDouble();
    return clamped / 3.0;
  }
}

class _ActiveOrderProgressLabels extends StatelessWidget {
  const _ActiveOrderProgressLabels();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _ProgressStepLabel(text: l10n.homeStageOrdered)),
        Flexible(
          child: _ProgressStepLabel(
            text: l10n.homeStagePicked,
            textAlign: TextAlign.center,
          ),
        ),
        Flexible(
          child: _ProgressStepLabel(
            text: l10n.homeStageInTransit,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _ProgressStepLabel extends StatelessWidget {
  const _ProgressStepLabel({
    required this.text,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: context.jeebText.caption.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ActiveOrderActions extends StatelessWidget {
  const _ActiveOrderActions({
    required this.requestId,
    this.onTrack,
    this.onOpenChat,
  });

  final String requestId;
  final VoidCallback? onTrack;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final onOpenChat = this.onOpenChat;
    final onTrack = this.onTrack;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      // Keep the compact row when it fits, but let larger labels move to
      // separate lines instead of overflowing the card's available width.
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: Spacing.small,
        overflowSpacing: Spacing.small,
        children: [
          if (onOpenChat != null)
            IntrinsicWidth(
              child: Semantics(
                identifier: 'orders_open_chat_button_$requestId',
                button: true,
                child: JeebCtaButton(
                  key: Key('active-open-chat-$requestId'),
                  label: AppLocalizations.of(context).orderSummaryOpenChat,
                  variant: JeebCtaVariant.outline,
                  expand: false,
                  onTap: onOpenChat,
                ),
              ),
            ),
          if (onTrack != null)
            _TrackOrderButton(requestId: requestId, onTap: onTrack),
        ],
      ),
    );
  }
}

class _TrackOrderButton extends StatelessWidget {
  const _TrackOrderButton({required this.requestId, required this.onTap});

  final String requestId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Periwinkle, not accent: navigating to tracking is not the tile's orange
    // act, and `OmdsPrimaryButton`'s bare default IS `colorScheme.primary`.
    return IntrinsicWidth(
      child: Semantics(
        identifier: 'orders_track_order_button_$requestId',
        button: true,
        child: JeebCtaButton.primary(
          key: Key('active-track-order-$requestId'),
          label: AppLocalizations.of(context).homeTrackOrderCta,
          expand: false,
          onTap: onTap,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// --- ActiveOrderCard -------------------------------------------------------

/// A phone-width card box. The full card lays out at **181 pt** tall at 390 pt
/// (249 pt at 200% text), so 200 pt frames it with the divider visible.
const Size _activeOrderCardCardBox = Size(390, 200);

/// A card whose gates are both closed loses the whole action row: **121 pt**
/// instead of 181.
const Size _activeOrderCardShortCardBox = Size(390, 140);

/// Builds the card exactly the way `in_progress_tab.dart` `_ActiveList` does:
/// `onTap` = Track, and `onOpenChat` ALWAYS non-null.
Widget _activeOrderCardHosted({
  required String id,
  required String title,
  required ClientRequestStatus status,
  required int progressStep,
  ClientRequestTier tier = ClientRequestTier.flash,
  String destinationLabel = 'Ashrafieh, Beirut',
  String? itemsSummary,
}) => ActiveOrderCard(
  request: ClientHomeRequest(
    id: id,
    title: title,
    status: status,
    destinationLabel: destinationLabel,
    itemsSummary: itemsSummary,
    progressStep: progressStep,
    tier: tier,
  ),
  onTap: () {},
  onOpenChat: () {},
);

/// The fullest card: a Jeeber is on the road, so BOTH gates are open and the
/// action row carries "Open chat" + "Track my order".
@JeebPreview(
  group: 'home_client',
  name: 'En route · chat + track',
  size: _activeOrderCardCardBox,
)
Widget activeOrderCardEnRoute() => _activeOrderCardHosted(
  id: 'preview-en-route',
  title: 'Pharmacy run',
  status: ClientRequestStatus.enRoute,
  progressStep: 2,
);

/// Still searching: the auction is open and NO Jeeber is engaged yet.
/// The regression guard, made visible. `onOpenChat` is non-null here exactly as
@JeebPreview(
  group: 'home_client',
  name: 'Searching · track only',
  size: _activeOrderCardCardBox,
)
Widget activeOrderCardSearching() => _activeOrderCardHosted(
  id: 'preview-searching',
  title: 'Grocery run',
  status: ClientRequestStatus.searching,
  progressStep: 0,
  tier: ClientRequestTier.standard,
);

/// Terminal state: delivered. Both gates close, so the card renders with NO
/// action row at all.
@JeebPreview(
  group: 'home_client',
  name: 'Delivered · no actions',
  size: _activeOrderCardShortCardBox,
)
Widget activeOrderCardDelivered() => _activeOrderCardHosted(
  id: 'preview-delivered',
  title: 'Bakery order',
  status: ClientRequestStatus.delivered,
  progressStep: 3,
  tier: ClientRequestTier.express,
);

/// Content ceiling: the longest plausible title next to the longest plausible
/// items summary (the multi-item `description` G1 now routes into
@JeebPreview(
  group: 'home_client',
  name: 'Long title + long summary',
  size: _activeOrderCardCardBox,
)
Widget activeOrderCardLongContent() => _activeOrderCardHosted(
  id: 'preview-long',
  title: 'Pharmacy pickup for Mrs. Haddad on Rue Sursock',
  status: ClientRequestStatus.accepted,
  progressStep: 0,
  itemsSummary:
      '1 kilo potato, water gallon, coffee blend, two loaves of '
      'brown bread, a bag of ice and paracetamol',
);

/// Degraded payload: no title and a tier the app does not know.
/// Two fallbacks fire at once. `_initial('')` gives the avatar a literal "?"
@JeebPreview(
  group: 'home_client',
  name: 'Untitled · unknown tier',
  size: _activeOrderCardCardBox,
)
Widget activeOrderCardUntitledUnknownTier() => _activeOrderCardHosted(
  id: 'preview-untitled',
  title: '',
  status: ClientRequestStatus.atPickup,
  progressStep: 1,
  tier: ClientRequestTier.unknown,
  destinationLabel: 'Mar Mikhael, Beirut',
);

// --- ClientHomeTierBadge ---------------------------------------------------

/// The width the in-progress header row really gets: a 390pt phone, the card's
/// `Spacing.medium` gutters on both sides, the `Sizes.threeXLarge` avatar and
const double _clientHomeTierBadgeActiveHeaderWidth = 314;

/// The width the pending header row gets: same phone, same gutters, no avatar.
/// `390 - 16 - 16 = 358`.
const double _clientHomeTierBadgePendingHeaderWidth = 358;

/// Canvas box for a header row. Tall enough that the 200% rendering (a 22pt
/// title at 44pt) still has air around it.
const Size _clientHomeTierBadgeHeaderBox = Size(390, 120);

/// Canvas box for the four-value strip, which wraps at 200%.
const Size _clientHomeTierBadgeStripBox = Size(390, 260);

/// Puts [child] at the width its production row really has, centred in the
/// canvas.
Widget _clientHomeTierBadgeHosted(
  Widget child, {
  double width = _clientHomeTierBadgeActiveHeaderWidth,
}) => Center(
  child: SizedBox(width: width, child: child),
);

/// Reproduces `_ActiveOrderHeader` from `active_request_card.dart`: a
/// [Flexible] ellipsizing title, `Spacing.xSmall`, the badge, spread apart and
/// vertically centred.
class _ClientHomeTierBadgeActiveHeader extends StatelessWidget {
  const _ClientHomeTierBadgeActiveHeader({
    required this.title,
    required this.tier,
  });

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            title,
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

/// Reproduces `_PendingCardHeader` from `pending_requests_tab.dart` (and its
/// twin `_PendingHeader` in `pending_request_card.dart`): an [Expanded] title
/// and `CrossAxisAlignment.start`.
class _ClientHomeTierBadgePendingHeader extends StatelessWidget {
  const _ClientHomeTierBadgePendingHeader({
    required this.title,
    required this.tier,
  });

  final String title;
  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: context.jeebText.cardTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xSmall),
        ClientHomeTierBadge(tier: tier),
      ],
    );
  }
}

/// One cell of the comparison strip: the badge over the enum value that
/// produced it.
/// The enum name is preview scaffolding, not widget output. It exists because
class _ClientHomeTierBadgeTierSwatch extends StatelessWidget {
  const _ClientHomeTierBadgeTierSwatch(this.tier);

  final ClientRequestTier tier;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        height: Sizes.large,
        child: Center(child: ClientHomeTierBadge(tier: tier)),
      ),
      const SizedBox(height: Spacing.twoXSmall),
      Text(
        tier.name,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
    ],
  );
}

/// The state that ships on an in-progress card: Flash, in the header row the
/// card really gives it.
@JeebPreview(
  group: 'home_client',
  name: 'Flash · in-progress header',
  size: _clientHomeTierBadgeHeaderBox,
)
Widget clientHomeTierBadgeFlash() => _clientHomeTierBadgeHosted(
  const _ClientHomeTierBadgeActiveHeader(
    title: 'Kamal Hajj',
    tier: ClientRequestTier.flash,
  ),
);

/// The state that ships on a pending card: Express, in the OTHER production
/// header — `Expanded` title, `CrossAxisAlignment.start`.
@JeebPreview(
  group: 'home_client',
  name: 'Express · pending header',
  size: _clientHomeTierBadgeHeaderBox,
)
Widget clientHomeTierBadgeExpressPending() => _clientHomeTierBadgeHosted(
  const _ClientHomeTierBadgePendingHeader(
    title: 'ORD-23470',
    tier: ClientRequestTier.express,
  ),
  width: _clientHomeTierBadgePendingHeaderWidth,
);

/// Standard, the default tier and the quietest of the three.
/// `#1E88E5` on white is 3.68:1 — above the 3:1 asked of a graphical object,
@JeebPreview(
  group: 'home_client',
  name: 'Standard · in-progress header',
  size: _clientHomeTierBadgeHeaderBox,
)
Widget clientHomeTierBadgeStandard() => _clientHomeTierBadgeHosted(
  const _ClientHomeTierBadgeActiveHeader(
    title: 'Pharmacy run',
    tier: ClientRequestTier.standard,
  ),
);

/// The state that breaks, and the reason this widget has a fallback branch at
/// all: a tier the backend introduced mid-deploy.
@JeebPreview(
  group: 'home_client',
  name: 'Unknown tier · nothing renders',
  size: _clientHomeTierBadgeHeaderBox,
)
Widget clientHomeTierBadgeUnknown() => _clientHomeTierBadgeHosted(
  const _ClientHomeTierBadgeActiveHeader(
    title: 'ORD-88213',
    tier: ClientRequestTier.unknown,
  ),
);

/// Longest plausible content: a title that cannot fit, pressing on the badge.
/// The good news, and the failure this preview was written to look for: the
@JeebPreview(
  group: 'home_client',
  name: 'Long title · badge holds its place',
  size: _clientHomeTierBadgeHeaderBox,
)
Widget clientHomeTierBadgeLongTitle() => _clientHomeTierBadgeHosted(
  const _ClientHomeTierBadgeActiveHeader(
    title: 'Pharmacy run — Ashrafieh to Hamra, ring the second bell',
    tier: ClientRequestTier.flash,
  ),
);

/// All four enum values side by side, which is the only way to see the palette
/// as a palette.
@JeebPreview(
  group: 'home_client',
  name: 'All four tiers · strip',
  size: _clientHomeTierBadgeStripBox,
)
Widget clientHomeTierBadgeStrip() => _clientHomeTierBadgeHosted(
  Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const Wrap(
        spacing: Spacing.large,
        runSpacing: Spacing.small,
        alignment: WrapAlignment.center,
        children: <Widget>[
          _ClientHomeTierBadgeTierSwatch(ClientRequestTier.flash),
          _ClientHomeTierBadgeTierSwatch(ClientRequestTier.express),
          _ClientHomeTierBadgeTierSwatch(ClientRequestTier.standard),
          _ClientHomeTierBadgeTierSwatch(ClientRequestTier.unknown),
        ],
      ),
      const SizedBox(height: Spacing.small),
      Builder(
        builder: (BuildContext context) => Text(
          'Every ClientRequestTier value',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ],
  ),
  width: _clientHomeTierBadgePendingHeaderWidth,
);
