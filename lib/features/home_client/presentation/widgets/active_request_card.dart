import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_tier_colors.dart';
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsProfileAvatar(
      initial: initial,
      size: Sizes.threeXLarge,
      backgroundColor: colorScheme.surfaceContainerHigh,
      initialColor: colorScheme.primary,
    );
  }
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
      s != ClientRequestStatus.delivered &&
      s != ClientRequestStatus.cancelled;

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
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
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
    final color = _colorFor(tokens) ?? theme.colorScheme.tertiary;
    final label = _labelFor(l10n);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
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
      style: theme.textTheme.labelSmall?.copyWith(
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
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: OmdsBorderRadius.twoXSmall,
      child: LinearProgressIndicator(
        value: _progressFor(progressStep),
        minHeight: Sizes.twoXSmall,
        backgroundColor: colorScheme.outlineVariant,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
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
        _ProgressStepLabel(text: l10n.homeStageOrdered),
        _ProgressStepLabel(text: l10n.homeStagePicked),
        _ProgressStepLabel(text: l10n.homeStageInTransit),
      ],
    );
  }
}

class _ProgressStepLabel extends StatelessWidget {
  const _ProgressStepLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
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
    final theme = Theme.of(context);
    final onOpenChat = this.onOpenChat;
    final onTrack = this.onTrack;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.small),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onOpenChat != null) ...[
            Semantics(
              identifier: 'orders_open_chat_button_$requestId',
              button: true,
              child: OMDSOutlinedButton(
                key: Key('active-open-chat-$requestId'),
                text: AppLocalizations.of(context).orderSummaryOpenChat,
                onTap: onOpenChat,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                textColor: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: Spacing.small),
          ],
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
    return IntrinsicWidth(
      child: Semantics(
        identifier: 'orders_track_order_button_$requestId',
        button: true,
        child: OmdsPrimaryButton(
          key: Key('active-track-order-$requestId'),
          text: AppLocalizations.of(context).homeTrackOrderCta,
          onTap: onTap,
          borderRadius: OmdsBorderRadius.pill,
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
// Render tests: test/previews/home_client/active_order_card_preview_test.dart ·
// test/previews/home_client/client_home_tier_badge_preview_test.dart
// ===========================================================================
//
// This file declares TWO previewed widgets, so the section carries two
// families. Every name below is prefixed with the widget it belongs to
// (`activeOrderCard…` / `_ActiveOrderCard…`, `clientHomeTierBadge…` /
// `_ClientHomeTierBadge…`) — the fixtures would otherwise collide outright.
//
// ---------------------------------------------------------------------------
// ActiveOrderCard
// ---------------------------------------------------------------------------
//
// [ActiveOrderCard] is a pure view over one [ClientHomeRequest]: no cubit, no
// repository, no image fetch (the avatar is an OMDS profile avatar driven by
// the title's first letter, never a URL). Every fixture below is a plain value
// object and both callbacks are no-ops, so these previews are network-free by
// construction, not merely by the guard in [jeebPreviewHost].
//
// Fixture values reuse `test/features/home_client/in_progress_tab_test.dart`
// (`_activeRequest`: "Pharmacy run" / "Ashrafieh, Beirut" / Flash) so the
// canvas and the widget tests describe the same card.
//
// ## The two CTA gates are the first thing to read this canvas for
//
// Production (`in_progress_tab.dart` `_ActiveList`) ALWAYS passes a non-null
// `onOpenChat`, so which pills appear is decided entirely inside the card:
//
// ```dart
// _canTrack(s)  => s != delivered && s != cancelled      // Q-085: nearly always
// _hasJeeber(s) => s == accepted || atPickup || enRoute  // JM-025: chat re-entry
// ```
//
// Every fixture therefore passes `onOpenChat` exactly as production does, and
// the *status* is what varies. A canvas where "Open chat" shows up on the
// `Searching` card is the phantom-chat regression those two gates were split
// apart to prevent.
//
// ## Read the canvas knowing this: two rows overflow at real phone width
//
// The body column gets `390 − 32` (card padding) `− 40` (avatar) `− 4` (gap)
// **= 314 pt**. Measured at that width, not guessed:
//
// | row                        | EN light | AR RTL dark | EN 200% text |
// |----------------------------|---------:|------------:|-------------:|
// | actions (chat + track)     |   384 pt |      354 pt |       706 pt |
// | actions (track only)       |   229 pt |      158 pt |       425 pt |
// | stage labels (3 × label)   |   265 pt |  **330 pt** |       518 pt |
//
// Against 314 pt of room that is: the two-pill action row **overflows in every
// rendering** (EN 70 px, AR 40 px, 200% 392 px); the stage-label row overflows
// in **Arabic on every card** (16 px) and at 200% text (204 px) even on a card
// with no buttons at all.
//
// Nothing under `test/` sees either one: widget tests pump into an 800×600
// viewport where the same body column has 724 pt and everything fits with
// room to spare. That gap — real device width vs test viewport — is the whole
// reason these previews are worth opening, so the `size:` boxes below are real
// phone widths rather than something roomy enough to look clean. The preview
// render tests inherit the same 800 pt viewport and stay green; the stripes
// are a canvas finding, not a test failure.
//
// ---------------------------------------------------------------------------
// ClientHomeTierBadge
// ---------------------------------------------------------------------------
//
// The badge takes no repository, no cubit and no async input: everything it
// draws is a function of one enum ([ClientRequestTier]), the ambient
// [JeebTierColors] theme extension, and the [AppLocalizations] of the host. So
// these previews are network-free because there is nothing to fetch, not
// merely because [jeebPreviewHost] guards the wire — and "empty / loading /
// error" do not exist. Its states are the four enum values plus the pressure
// its three shipping hosts put on it.
//
// **Why every state is a header row rather than a bare chip.** The badge is the
// trailing child of a title row in all three call sites — `_ActiveOrderHeader`
// here in `active_request_card.dart`, `_PendingHeader` in
// `pending_request_card.dart` and `_PendingCardHeader` in
// `pending_requests_tab.dart`. Reviewed on its own it is one word on an empty
// page and every state looks fine; reviewed in the row it competes with an
// ellipsizing title for a fixed width, which is where a tier badge can actually
// go wrong. Those rows are reproduced below rather than reused, because the
// production ones are private to their own libraries and because building the
// whole card would make this a preview of the card. If either header changes
// its geometry, these previews are wrong and say nothing — the same trade
// `JeebVerifiedBadge`'s previews make.
//
// Three things the matrix surfaces, all in the widget rather than in the
// previews — see the notes on the individual states:
//
//  * [ClientRequestTier.unknown] resolves to the empty string, so the
//    "neutral chip" the domain enum promises for a tier the backend adds
//    mid-deploy is in fact NOTHING: a zero-width [Text] and a stray 8pt gap;
//  * the tier inks are three fixed hexes registered identically in
//    `AppTheme.light()` and `AppTheme.dark()`, painted as 11pt text straight
//    onto `surface` — on the light scheme's white none of the three clears
//    WCAG AA (Flash 4.23:1, Express 2.37:1, Standard 3.68:1), and the AR RTL
//    dark rendering reuses those same hexes on a near-black surface, where the
//    ranking inverts (Express 7.81:1, Standard 5.03:1, Flash still 4.38:1);
//  * the badge is nothing but a [Text], so the two production header shapes
//    align it differently — centred against the title here, top-aligned in
//    both pending headers.

// --- ActiveOrderCard -------------------------------------------------------

/// A phone-width card box. The full card lays out at **181 pt** tall at 390 pt
/// (249 pt at 200% text), so 200 pt frames it with the divider visible.
const Size _activeOrderCardCardBox = Size(390, 200);

/// A card whose gates are both closed loses the whole action row: **121 pt**
/// instead of 181.
const Size _activeOrderCardShortCardBox = Size(390, 140);

/// Builds the card exactly the way `in_progress_tab.dart` `_ActiveList` does:
/// `onTap` = Track, and `onOpenChat` ALWAYS non-null.
///
/// The card's own status gates are what decide which pills render, so no
/// preview here may pass `onOpenChat: null` — doing so would fake a hidden chat
/// pill that production can never produce.
Widget _activeOrderCardHosted({
  required String id,
  required String title,
  required ClientRequestStatus status,
  required int progressStep,
  ClientRequestTier tier = ClientRequestTier.flash,
  String destinationLabel = 'Ashrafieh, Beirut',
  String? itemsSummary,
}) =>
    ActiveOrderCard(
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
///
/// This is the reference rendering every other state is read against, and the
/// only shape where two pills compete for one row — 384 pt of button in 314 pt
/// of column, so the trailing edge of "Track my order" is cut off on a 390 pt
/// phone. The AR rendering mirrors the overflow to the left edge, which clips
/// the *secondary* pill instead; at 200% text both pills are unreachable.
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
///
/// The regression guard, made visible. `onOpenChat` is non-null here exactly as
/// production passes it, so the "Open chat" pill must be suppressed by
/// `_hasJeeber` alone; "Track my order" must still render, because Q-085
/// (option A, ratified) puts the Track CTA on EVERY In-Progress card — even one
/// with no delivery row yet. If this card ever shows "Open chat", widening the
/// Track gate has leaked into the chat gate and clients get a pill that opens
/// an empty conversation.
///
/// It is also the only *fitting* action row: alone, the Track pill is 229 pt
/// and clears 314 pt comfortably. Everything the two-pill card suffers from is
/// the second pill.
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
///
/// Delivered rows are filtered out of In Progress upstream, so this is the
/// defensive shape — and the most useful one in the canvas, because it strips
/// the buttons away and leaves the *stage-label row overflowing on its own* in
/// the AR RTL rendering (330 pt of Arabic labels in 314 pt). A buttonless card
/// that still shows overflow stripes proves that overflow is a localization
/// bug, not a CTA-layout bug.
///
/// Note also what the bar says here: `progressStep: 3` is documented as
/// "AtDoor/Done" and fills the bar completely, while the legend underneath
/// stops at "In Transit". The indicator tops out one stage past its own labels.
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
/// [ClientHomeRequest.summaryLine]).
///
/// The title is `Flexible` + `maxLines: 1` + ellipsis, so it must truncate
/// rather than push the tier badge off the trailing edge; the summary line is
/// `maxLines: 1` + ellipsis too. Put this card next to `En route` in the
/// canvas: they are **exactly the same height** (181 pt). Nothing on this card
/// wraps, so a real 6-item order shows the client "1 kilo potato, water gallon,
/// coff…" and no way to see the rest — the card cannot grow, only clip. In the
/// AR RTL rendering both ellipses have to land on the *left*.
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
      itemsSummary: '1 kilo potato, water gallon, coffee blend, two loaves of '
          'brown bread, a bag of ice and paracetamol',
    );

/// Degraded payload: no title and a tier the app does not know.
///
/// Two fallbacks fire at once. `_initial('')` gives the avatar a literal "?"
/// (the deliberate "we know nothing" glyph), and [ClientRequestTier.unknown]
/// resolves to an EMPTY badge label — a 0 pt `Text('')` that still carries its
/// 8 pt leading gap. The header row is therefore blank on both ends and the
/// card's only identifying text is the destination line, while the action row
/// below it is fully armed (`atPickup` opens both gates). A tier the backend
/// adds mid-deploy lands here, so it must degrade rather than crash — but an
/// unlabelled card with live CTAs is worth a design decision, not just a
/// null-safety one.
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
/// its `Spacing.twoXSmall` gap. `390 - 16 - 16 - 40 - 4 = 314`.
///
/// Pinned in the fixture rather than left to the canvas [Size] on purpose. The
/// canvas honours `size`, but the render tests pump onto a fixed 800 × 600
/// surface — a row left to fill its host would squeeze the badge on the phone
/// and not squeeze it under test, so the state that breaks would only break in
/// one of the two places it is looked at.
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
}) =>
    Center(
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
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
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
///
/// The only difference from [_ClientHomeTierBadgeActiveHeader] that matters is
/// the cross-axis alignment, and it is the badge that pays for it — see
/// [clientHomeTierBadgeExpressPending].
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
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w400,
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
///
/// The enum name is preview scaffolding, not widget output. It exists because
/// the `unknown` swatch renders nothing at all — without a caption underneath,
/// that cell is indistinguishable from a rendering bug.
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
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      );
}

/// The state that ships on an in-progress card: Flash, in the header row the
/// card really gives it.
///
/// This is the one a designer signs off, and the rendering to compare across the
/// matrix rather than to admire in EN light:
///
///  * **AR RTL dark** — the row mirrors correctly (a [Row] is order-based and
///    `Spacing.xSmall` is a symmetric [SizedBox], so there is no
///    `EdgeInsets.only` to get wrong) and the label is localized ("سريع", not
///    "Flash"). What does not change is the ink: `JeebTierColors.standard()` is
///    registered with the SAME three hexes in `AppTheme.light()` and
///    `AppTheme.dark()`, so the `#E53935` that reads at 4.23:1 on white is asked
///    to read on the near-black dark surface too, where it manages 4.38:1.
///    Flash is the one tier that misses the 4.5:1 WCAG AA asks of 11pt text at
///    BOTH ends of the theme — the price of a single fixed hex serving two
///    schemes.
///  * **EN 200% text** — the badge does scale with the text scaler (it is a
///    [Text], and nothing overrides `textScaler`), which is the right behaviour
///    and worth confirming against the fixed-size seal on `JeebVerifiedBadge`.
///    Both texts double, but the `Spacing.xSmall` between them does not: even
///    this short name has to ellipsize at 200%, and 8 unscaled points are then
///    all that separate it from the tier label.
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
///
/// Visually this should be the same badge in the same place, and it is not. The
/// in-progress header centres its children, so the badge sits against the
/// optical middle of the title; the two pending headers top-align them, so the
/// same 11pt label rides up against the title's ascender. One widget, two
/// vertical positions relative to the line it labels — pinned in the render test
/// because it is a few pixels, and a few pixels is exactly what nobody catches
/// by scrolling the canvas.
///
/// Express is also the worst of the three inks in the scheme users actually
/// ship on: `#FB8C00` on white is 2.37:1, barely half of AA. Flip to the AR RTL
/// dark rendering and the same hex is 7.81:1 — the best of the three. One token
/// serving two surfaces cannot be tuned for either.
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
///
/// `#1E88E5` on white is 3.68:1 — above the 3:1 asked of a graphical object,
/// below the 4.5:1 asked of the small text this actually is. Worth looking at
/// beside [clientHomeTierBadgeFlash]: the tiers are told apart ONLY by hue, at
/// 11pt, with no fill, no border and no icon, so a red/green-blind reader (and
/// anyone on a sun-washed screen) is distinguishing Flash from Standard by two
/// mid-tone colours of near-identical lightness.
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
///
/// `ClientRequestTier.parse` maps every unrecognised string to `unknown`, and
/// the enum's own doc comment says that "falls back to a neutral chip so the
/// screen never crashes". It does not crash — but there is no chip. `_labelFor`
/// returns `''`, so the badge is a zero-width [Text] carrying a carefully chosen
/// `colorScheme.tertiary` that inks nothing, and the `Spacing.xSmall` gap before
/// it becomes a stray 8pt of trailing air. The order silently loses its tier
/// rather than showing an unstyled one.
///
/// Nothing in the canvas can distinguish this from a correct render, which is
/// why the render test measures the badge box instead of looking at it.
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
///
/// The good news, and the failure this preview was written to look for: the
/// badge is never pushed off the trailing edge. [Flexible] hands the title only
/// the leftovers, so the label and its 8pt gap are always reserved and the title
/// ellipsizes instead. Compare the EN 200% rendering, where the title is reduced
/// to about two words and an ellipsis while the tier survives intact — the
/// priority is right, and it is worth having a preview that proves it rather
/// than assuming it.
///
/// The bad news is legibility, not layout: at the width left over the ellipsized
/// title and the badge sit 8 unscaled points apart, and the badge's
/// `letterSpacing: 0.5` is applied to the Arabic label too, where letter
/// spacing pulls apart a cursive script that is meant to join.
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
///
/// Two things only show up here. First, `unknown` is a hole: three labels and a
/// gap. Second, the **AR RTL dark** rendering paints the same three
/// light-scheme hexes on a near-black surface — nothing re-tunes them — where
/// Flash and Standard sit at 0.20 and 0.23 relative luminance. The strip that
/// reads as three distinct tiers in EN light reads as one tone family there,
/// and in both schemes hue is the ONLY channel carrying the distinction: no
/// fill, no border, no icon, 11pt.
///
/// A [Wrap] rather than a [Row] so the 200% rendering reflows instead of
/// reporting a fixture overflow that says nothing about the badge.
@JeebPreview(
  group: 'home_client',
  name: 'All four tiers · strip',
  size: _clientHomeTierBadgeStripBox,
)
Widget clientHomeTierBadgeStrip() => _clientHomeTierBadgeHosted(
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
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
          SizedBox(height: Spacing.small),
          Text(
            'Every ClientRequestTier value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      width: _clientHomeTierBadgePendingHeaderWidth,
    );
