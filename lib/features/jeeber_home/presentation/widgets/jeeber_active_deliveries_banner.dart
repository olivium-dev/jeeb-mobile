import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/data/dio_accepted_conversations_repository.dart';
import '../../../chat/domain/accepted_conversation.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';

import '../../../../core/previews/jeeb_preview.dart';

/// S007-P1B — Jeeber in-app re-entry to ACCEPTED (won) order chats.
///
/// The jeeber's request feed only lists OPEN requests; once an offer is
/// accepted the order drops off the feed and was reachable only by tapping a
/// push. This banner surfaces the jeeber's accepted orders at the top of the
/// Dashboard's no-requests state and routes each into the order chat
/// (`/chat/:id`, role-aware → "Start delivery").
///
/// Self-contained + DI-safe: it resolves an [AcceptedConversationsRepository]
/// from the injected seam or `sl<Dio>()`; when neither is available (bare
/// widget tests) it fetches nothing and renders [SizedBox.shrink]. It also
/// renders nothing while loading, on error, or when there are no accepted
/// orders — so it is purely additive and never disturbs the existing layout.
class JeeberActiveDeliveriesBanner extends StatefulWidget {
  const JeeberActiveDeliveriesBanner({
    super.key,
    this.repository,
    this.onOpenChat,
  });

  /// Test seam — when null, resolved from `sl<Dio>()` (or no-op without DI).
  final AcceptedConversationsRepository? repository;

  /// Tap handler for a row; defaults to a `chat-detail` GoRouter push.
  final void Function(String routeId)? onOpenChat;

  @override
  State<JeeberActiveDeliveriesBanner> createState() =>
      _JeeberActiveDeliveriesBannerState();
}

class _JeeberActiveDeliveriesBannerState
    extends State<JeeberActiveDeliveriesBanner> {
  List<AcceptedConversation> _accepted = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = _resolveRepository();
    if (repository == null) {
      setState(() => _loaded = true);
      return;
    }
    final accepted = await repository.fetchAccepted();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _loaded = true;
    });
  }

  AcceptedConversationsRepository? _resolveRepository() {
    if (widget.repository != null) return widget.repository;
    if (sl.isRegistered<Dio>()) {
      // Jeeber-scoped: GET /requests?role=jeeber returns the jeeber's won
      // (accepted) orders, each with the conversationId for chat re-entry.
      return DioAcceptedConversationsRepository(sl<Dio>(), role: 'jeeber');
    }
    return null;
  }

  void _open(String routeId) {
    final handler = widget.onOpenChat;
    if (handler != null) {
      handler(routeId);
      return;
    }
    GoRouter.of(context).pushNamed(
      'chat-detail',
      pathParameters: {'id': routeId},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _accepted.isEmpty) return const SizedBox.shrink();
    return _ActiveDeliveriesSection(accepted: _accepted, onOpen: _open);
  }
}

class _ActiveDeliveriesSection extends StatelessWidget {
  const _ActiveDeliveriesSection({required this.accepted, required this.onOpen});

  final List<AcceptedConversation> accepted;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_active_deliveries_section',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.xSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: l10n.availabilityActiveDeliveries(accepted.length)),
            const SizedBox(height: Spacing.xSmall),
            for (final c in accepted)
              _ActiveDeliveryRow(conversation: c, onOpen: onOpen),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActiveDeliveryRow extends StatelessWidget {
  const _ActiveDeliveryRow({required this.conversation, required this.onOpen});

  final AcceptedConversation conversation;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'jeeber_active_delivery_card_${conversation.routeId}',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
        child: Row(
          children: [
            _RowAvatar(initial: _initial),
            const SizedBox(width: Spacing.small),
            Expanded(child: _RowLabel(text: _title(l10n), theme: theme)),
            const SizedBox(width: Spacing.small),
            _OpenChatButton(
              routeId: conversation.routeId,
              label: l10n.orderSummaryOpenChat,
              onOpen: onOpen,
            ),
          ],
        ),
      ),
    );
  }

  String get _initial {
    final name = conversation.counterpartName ?? conversation.title ?? '?';
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  String _title(AppLocalizations l10n) {
    return conversation.counterpartName ??
        conversation.title ??
        conversation.displayId ??
        'Order ${conversation.routeId}';
  }
}

class _RowAvatar extends StatelessWidget {
  const _RowAvatar({required this.initial});

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

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _OpenChatButton extends StatelessWidget {
  const _OpenChatButton({
    required this.routeId,
    required this.label,
    required this.onOpen,
  });

  final String routeId;
  final String label;
  final void Function(String routeId) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Sizes.twoXLarge,
      child: Semantics(
        identifier: 'jeeber_active_delivery_open_chat_$routeId',
        button: true,
        child: OMDSOutlinedButton(
          key: Key('jeeber-active-open-chat-$routeId'),
          text: label,
          onTap: () => onOpen(routeId),
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
// Render tests:
// test/previews/jeeber_home/jeeber_active_deliveries_banner_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeeberActiveDeliveriesBanner] — run with
// `flutter widget-preview start`.
//
// The banner is the jeeber's only in-app door back into an ACCEPTED (won)
// order: the request feed lists OPEN requests only, so once an offer is
// accepted the order drops off the feed and — before S007-P1B — was reachable
// solely by tapping a push. Everything it can show comes from one read, so its
// states are exactly the outcomes of that read: rows, no rows, or not answered
// yet.
//
// Every state below is driven the way production drives it — through the
// widget's own `repository` seam, here a LOCAL fake that answers from canned
// data or never answers. No Dio, no DI graph, no network; the guard in
// [jeebPreviewHost] is the net, not the plan. `onOpenChat` is always supplied
// because the default tap handler reaches for `GoRouter.of(context)`, and
// there is no router in a preview.
//
// Two things the previews reproduce on purpose:
//
//  * **The host is a scroll view.** In production the banner is a child of
//    `JeeberNoRequestsView`'s `SingleChildScrollView` column, so its `Column`
//    of rows builds under an UNBOUNDED vertical constraint and cannot
//    overflow. Previewing it in a bare fixed box would invent a failure the
//    app cannot have — and would hide the failure it CAN have, which is
//    consuming the first viewport (that is what
//    `test/features/shell/jeeber_dashboard_overflow_test.dart` (b) records for
//    the sibling banner). So `_jeeberActiveDeliveriesBannerHosted` supplies the
//    same scrolling host and each `size` below is the real estate the state
//    actually claims.
//  * **A row is a Row.** avatar + `Expanded(title)` + a NON-flexible
//    "Open chat" button whose label neither wraps nor ellipsizes, inside a
//    fixed 32 px-tall box. That is the exact shape whose sibling
//    right-overflowed on real devices twice (39 px on SM-S921B, 27 px on
//    S908B), so the long-content and fallback-title states below exist to be
//    read in the AR RTL and 200%-text renderings, not the English one — see
//    the measurements on `jeeberActiveDeliveriesBannerLongName`, which still
//    reproduce it here.
//
// Fixture values (`r1`/`c1`/`Pharmacy run`, `ORD-23748`, the `f2244baa…`
// request id) are lifted from
// `test/features/chat/dio_accepted_conversations_repository_test.dart`,
// the [AcceptedConversation] doc comments and the live-gateway body pinned in
// `test/jeeber_active_deliveries_test.dart`, so the canvas and the assertions
// describe the same rows.

/// Phone width; the height varies per state because a self-hidden banner and a
/// three-row banner differ by ~150 logical pixels.
const double _jeeberActiveDeliveriesBannerPhoneWidth = 390;

/// Answers one canned snapshot. Nothing else — no latency, no second read.
class _JeeberActiveDeliveriesBannerCannedRepository
    implements AcceptedConversationsRepository {
  const _JeeberActiveDeliveriesBannerCannedRepository(this.accepted);

  final List<AcceptedConversation> accepted;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => accepted;
}

/// Never answers, so the banner stays in its pre-load state forever.
/// A pending [Completer] is the whole implementation: no timer to leak and no
/// socket to open.
class _JeeberActiveDeliveriesBannerStalledRepository
    implements AcceptedConversationsRepository {
  const _JeeberActiveDeliveriesBannerStalledRepository();

  @override
  Future<List<AcceptedConversation>> fetchAccepted() =>
      Completer<List<AcceptedConversation>>().future;
}

Widget _jeeberActiveDeliveriesBannerHosted(
  AcceptedConversationsRepository repository,
) {
  return SingleChildScrollView(
    child: JeeberActiveDeliveriesBanner(
      repository: repository,
      // Production pushes the `chat-detail` route; a preview has no router.
      onOpenChat: (_) {},
    ),
  );
}

Widget _jeeberActiveDeliveriesBannerWithAccepted(
  List<AcceptedConversation> accepted,
) =>
    _jeeberActiveDeliveriesBannerHosted(
      _JeeberActiveDeliveriesBannerCannedRepository(accepted),
    );

/// One won order, the shape the gateway returns it in: a request id (the
/// `chat-detail` route key), a conversation id, a title and the customer's
/// name.
///
/// The single-row state is the one a jeeber sees in practice — most jeebers
/// carry one accepted order at a time — and it is the one that proves the
/// header pluralizes ("1 active delivery", not "1 active deliveries").
///
/// With one row and nothing else on the canvas it is also the clearest place to
/// read the CTA's vertical behaviour: `_OpenChatButton` pins the button to
/// `SizedBox(height: Sizes.twoXLarge)` = 32 px, so at 200% text the label — a
/// 28 px font that needs ~32 px of line box — is measured into a 16 px-high
/// slot and paints outside its own rounded background instead of growing it.
/// Compare the EN light and EN 200% renderings of this preview side by side.
@JeebPreview(
  group: 'jeeber_home',
  name: 'One accepted order',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerSingle() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c1',
        requestId: 'r1',
        title: 'Pharmacy run',
        counterpartName: 'Rami Haddad',
      ),
    ]);

/// Three won orders, each resolving its title from a DIFFERENT branch of the
/// row's fallback chain: counterpart name, then order title, then order ref.
///
/// One row can never show this. The chain is
/// `counterpartName ?? title ?? displayId ?? 'Order id'`, and a fixture that
/// happens to carry all three fields exercises only the first link — so a
/// regression in the other two
/// would render a plausible-looking banner. Stacking three also shows what the
/// rows look like with no separator between them (they are bare `Row`s with
/// 8 px of trailing padding), and puts the plural header under load.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Three accepted orders',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 220),
)
Widget jeeberActiveDeliveriesBannerThree() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-201',
        requestId: 'r-201',
        title: 'Grocery run',
        counterpartName: 'Nadia Khoury',
      ),
      AcceptedConversation(
        conversationId: 'c-202',
        requestId: 'r-202',
        title: 'Pharmacy run',
      ),
      AcceptedConversation(
        conversationId: 'c-203',
        requestId: 'r-203',
        displayId: 'ORD-23748',
      ),
    ]);

/// Layout ceiling: the longest plausible counterpart name. **This preview
/// currently shows a defect — read the note before "fixing" the fixture.**
///
/// The row is `avatar + Expanded(title) + "Open chat"`, and the button is NOT
/// flexible: its label is a plain `Text` with no `maxLines`/`overflow`, so it
/// claims its full intrinsic width and the `Expanded` title absorbs every
/// shortfall. Measured on this fixture at 390 logical px:
///
/// | rendering            | CTA width | title width | result           |
/// |----------------------|-----------|-------------|------------------|
/// | EN, 100%             | 127 px    | 151 px      | ellipsized, fine |
/// | EN, 200%             | 253 px    |  25 px      | title gone       |
/// | AR, 200%             | 336 px    |   0 px      | overflow, 58 px  |
///
/// (and EN at 200% on a 320 px-wide phone overflows by 45 px). The title is
/// starved to nothing before the row overflows, so the failure reads as "the
/// customer's name vanished", not as a yellow overflow banner.
///
/// This is the same defect JEBV4-286 fixed on the SIBLING banner by making the
/// button label `Flexible` + ellipsizing (`_ButtonLabel` in
/// `features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart`);
/// this widget never received that fix. The EN 100% rendering stays plausible
/// long after the other two have broken, which is exactly why the matrix
/// renders all three.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Longest counterpart name',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerLongName() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-long',
        requestId: 'r-long',
        counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      ),
    ]);

/// The last link of the fallback chain: a row carrying NO human label at all.
///
/// The live `GET /requests?role=jeeber` envelope pinned in
/// `test/jeeber_active_deliveries_test.dart` shows this is reachable — rows
/// arrive with an id and a status and nothing else. The row then labels itself
/// `Order <requestId>`, i.e. a raw 36-character UUID, which is both the widest
/// possible title and (see `_ActiveDeliveryRow._title`) the one string in the
/// banner that is NOT localized: the method takes an `AppLocalizations` and
/// never uses it. Switch this preview to AR RTL and the row still reads
/// "Order f2244baa-…" in English.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Untitled order · id fallback',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 120),
)
Widget jeeberActiveDeliveriesBannerUntitled() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[
      AcceptedConversation(
        conversationId: 'c-77',
        requestId: 'f2244baa-ff25-4316-b723-c08a80cd3da9',
      ),
    ]);

/// No accepted orders — the state EVERY jeeber is in most of the time.
///
/// Renders `SizedBox.shrink`, deliberately: the banner is additive to the
/// dashboard's no-requests surface and must leave that layout byte-identical
/// when there is nothing to re-enter. An empty canvas here is the pass
/// condition, not a broken preview — which is also why its render test pins the
/// ABSENCE of the header and the CTA rather than a string.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Empty · self-hidden',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 80),
)
Widget jeeberActiveDeliveriesBannerEmpty() =>
    _jeeberActiveDeliveriesBannerWithAccepted(const <AcceptedConversation>[]);

/// The read is still in flight — same `SizedBox.shrink`, different reason.
///
/// Worth its own preview because the two indistinguishable states have very
/// different failure modes: "loading" is what a jeeber sees for the whole
/// round trip after a cold start or a push-driven refetch, and the banner
/// offers no skeleton, no spinner and no reserved space. So an accepted order
/// does not fade in, it POPS in and shoves the availability card down the
/// screen — the jump is only visible by flipping between this preview and
/// `One accepted order`.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Loading · self-hidden',
  size: Size(_jeeberActiveDeliveriesBannerPhoneWidth, 80),
)
Widget jeeberActiveDeliveriesBannerLoading() =>
    _jeeberActiveDeliveriesBannerHosted(
      const _JeeberActiveDeliveriesBannerStalledRepository(),
    );
