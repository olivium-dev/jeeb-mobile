import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../chat/domain/accepted_conversation.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'jeeber_active_deliveries_banner.dart';
import 'jeeber_no_requests_view.dart';

/// Banner shown 30 minutes before the 8h auto-offline kicks in.
///
/// Tapping the CTA fires [onExtend] which resets the idle timer in the
/// cubit; dismissing it does NOT extend (the warning re-appears next tick).
class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({super.key, required this.onExtend});

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    // Pre-auto-offline countdown is a warning state -> semantic warning role
    // (was the brand tertiary orange doing state duty).
    final roles = context.jeebRoles;
    return Container(
      key: rootKey,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: roles.warningContainer,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(color: roles.warning),
      ),
      child: _BannerBody(onExtend: onExtend),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BannerHeader(),
        const SizedBox(height: Spacing.xSmall),
        const _BannerDescription(),
        const SizedBox(height: Spacing.small),
        _BannerCta(onExtend: onExtend),
      ],
    );
  }
}

class _BannerHeader extends StatelessWidget {
  const _BannerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.access_time, color: context.jeebRoles.onWarningContainer),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            l10n.availabilityInactivityWarningTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.jeebRoles.onWarningContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerDescription extends StatelessWidget {
  const _BannerDescription();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityInactivityWarningBody,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: context.jeebRoles.onWarningContainer,
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        identifier: 'availability_inactivity_extend_cta',
        container: true,
        button: true,
        child: OmdsPrimaryButton(
          key: InactivityWarningBanner.ctaKey,
          text: l10n.availabilityInactivityWarningCta,
          onTap: onExtend,
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
// test/previews/jeeber_home/inactivity_warning_banner_preview_test.dart
// ===========================================================================
//
// Widget previews for [InactivityWarningBanner] — run with
// `flutter widget-preview start`.
//
// The banner takes one callback and no data: its three strings
// (`availabilityInactivityWarningTitle` / `…Body` / `…Cta`) are fixed, so
// there is no content state to vary. What CAN break it is the context it is
// dropped into — the WIDTH it is handed, the chrome stacked above it, and the
// vertical slot it has to share — so every preview below varies exactly that.
//
// Production placement is `jeeber_no_requests_view.dart`
// (`_NoRequestsColumn`), gated on `view.warningVisible`: greeting →
// `AvailabilityCard` → optional active-work disclosure → this banner →
// `OmdsEmptyState`. The composed previews therefore render the REAL
// [JeeberNoRequestsView] rather than the banner floating in a void, because
// the interesting questions here are relational: does the warning still read
// as the loudest thing on the dashboard once the availability card is above
// it, and does its CTA stay reachable.
//
// Reachability is taken from `AvailabilityCubit`: `_onIdleTick` emits
// `warningVisible: true` between the 7h30 warn threshold and the 8h
// auto-offline, and BOTH `toggle()` and the auto-offline branch clear it. So
// "banner + offline card" and "banner + auto-offline card" are NOT real states
// and are deliberately not previewed. One reachable state is also missing:
// `toggle()` keeps the warning up until the PUT returns, so the card's
// indeterminate `OmdsLoadingState` can coexist with this banner — but a
// never-settling spinner cannot be asserted by the shared render harness
// (`pumpAndSettle` times out), so that pairing belongs to the on-device Screen
// Catalog rather than here.
//
// Network-free by construction: no cubit, no gateway, no Dio. The composed
// states are plain [AvailabilityViewState] values, and the active-work state
// uses `_InactivityWarningBannerCannedConversations` — a local fake of the
// repository interface, which is the same seam
// `JeeberActiveDeliveriesBanner(repository: …)` exposes to widget tests.

/// Frozen "last activity" instant so the fixtures never drift between runs of
/// the canvas. Its absolute value is irrelevant — only `warningVisible` drives
/// this widget — but a fixed clock keeps the cards above it byte-identical.
final DateTime _inactivityWarningBannerLastActivityAt =
    DateTime(2026, 8, 2, 9, 30);

/// The dashboard snapshot that RAISES the banner: ready, online, warned.
///
/// `warningVisible: true` is the whole gate — without it `_NoRequestsColumn`
/// never builds an [InactivityWarningBanner] — so no composed preview omits it.
AvailabilityViewState _inactivityWarningBannerWarned() => AvailabilityViewState(
      loadPhase: AvailabilityLoadPhase.ready,
      status: AvailabilityStatus(
        state: AvailabilityState.online,
        activeDeliveryCount: 0,
        lastActivityAt: _inactivityWarningBannerLastActivityAt,
      ),
      warningVisible: true,
    );

/// Canned stand-in for `AcceptedConversationsRepository`. Returns a fixed list
/// and touches no transport, so the active-work preview cannot reach the
/// gateway even if the DI graph happens to be built.
class _InactivityWarningBannerCannedConversations
    implements AcceptedConversationsRepository {
  const _InactivityWarningBannerCannedConversations(this._rows);

  final List<AcceptedConversation> _rows;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => _rows;
}

/// The banner in its production composition, at an optional device [width] and
/// [height].
///
/// The canvas box alone cannot constrain the widget — the harness stretches it
/// to the host — so a bounded reading needs a real [SizedBox] under an [Align].
Widget _inactivityWarningBannerDashboard({
  required String profileName,
  Widget? activeDeliveriesBanner,
  double? width,
  double? height,
}) {
  final Widget body = JeeberNoRequestsView(
    view: _inactivityWarningBannerWarned(),
    profileName: profileName,
    activeDeliveriesBanner: activeDeliveriesBanner,
    onToggle: () {},
    onExtendActivity: () {},
  );
  if (width == null && height == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, height: height, child: body),
  );
}

/// The bare card, exactly as `_NoRequestsColumn` emits it —
/// `InactivityWarningBanner(onExtend: …)` with nothing around it.
///
/// This is the reading the 200% rendering of the matrix is for, and it is where
/// two things are visible that no composed state makes clearer:
///
/// * The card has no fixed height, so the two-line body wraps and pushes it
///   taller instead of clipping — correct.
/// * The CTA cannot do the same. `OmdsPrimaryButton` documents `width` as
///   "defaults to full width" and pins `height` to `Sizes.fourXLarge` (48 dp),
///   so the `Align(centerEnd)` around it is inert (measured: the pill spans the
///   full content width, 0 dp offset from the card centre in BOTH locales) and
///   at 200% the label needs 80 dp inside that 48 dp pill. Nothing throws — a
///   clamped paragraph is not an overflow — the second line is just cut off.
@JeebPreview(group: 'jeeber_home', name: 'Banner alone', size: Size(390, 320))
Widget inactivityWarningBannerAlone() =>
    InactivityWarningBanner(onExtend: () {});

/// Small-phone width (320 dp), the narrowest width the app ships to.
///
/// The title row is `Icon + Expanded(Text)` with the `Row` default
/// `crossAxisAlignment: center`, so this is the first width at which "Still
/// there?" can wrap and float the clock icon to the middle of the text block
/// instead of leaving it on the first line. It is also where the AR RTL
/// rendering has to prove the icon and the 16 dp margins really mirror — the
/// icon must keep the LEADING edge, which is the right-hand side in Arabic.
@JeebPreview(group: 'jeeber_home', name: 'Small phone 320dp', size: Size(320, 560))
Widget inactivityWarningBannerSmallPhone() =>
    _inactivityWarningBannerDashboard(profileName: 'Nadia', width: 320);

/// The real dashboard: greeting, the COMPACT online switch row, the banner, the
/// empty feed underneath.
///
/// This is the state a Jeeber actually sees at 7h30 idle, and the composition
/// the banner has to win against: the switch row above it says "You're online —
/// receiving requests" in plain body text while the banner says the opposite is
/// about to happen. The warning is the only element on this screen carrying the
/// semantic `warning` role (it used to borrow the brand tertiary orange), so
/// this is the preview that shows whether that role still reads as urgent
/// against the surface in BOTH brightnesses of the matrix.
@JeebPreview(group: 'jeeber_home', name: 'Online dashboard', size: Size(390, 620))
Widget inactivityWarningBannerOnlineDashboard() =>
    _inactivityWarningBannerDashboard(profileName: 'Sami');

/// The longest plausible stack: idle on the feed while holding accepted work.
///
/// A Jeeber can be idle and still owe two deliveries, so
/// `JeeberActiveDeliveriesBanner` renders a header plus one row per order
/// directly above the warning — which is where the banner sits furthest down
/// the column and, at 200% text, is most likely to fall below the fold. That
/// matters more here than anywhere else: ignoring this warning takes a Jeeber
/// with LIVE work offline. The second name is deliberately over-long so the
/// row's `maxLines: 1` ellipsis is exercised next to the "Open chat" button.
@JeebPreview(group: 'jeeber_home', name: 'Under active deliveries', size: Size(390, 760))
Widget inactivityWarningBannerUnderActiveDeliveries() =>
    _inactivityWarningBannerDashboard(
      profileName: 'Rana',
      activeDeliveriesBanner: JeeberActiveDeliveriesBanner(
        repository: const _InactivityWarningBannerCannedConversations(
          <AcceptedConversation>[
            AcceptedConversation(
              conversationId: 'conv-8821',
              requestId: 'req-8821',
              displayId: 'ORD-23748',
              counterpartName: 'Kamal Hajj',
            ),
            AcceptedConversation(
              conversationId: 'conv-8822',
              requestId: 'req-8822',
              displayId: 'ORD-23751',
              counterpartName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            ),
          ],
        ),
        onOpenChat: (_) {},
      ),
    );

/// A 260 dp tall slot — landscape, split view, or a small phone whose system
/// font is already enlarged.
///
/// The column is a `SingleChildScrollView`, so the correct degradation is a
/// SCROLL: the greeting and the switch row stay put and the banner moves below
/// the fold rather than being clipped. If the canvas ever shows a clipped card
/// or an overflow stripe here, that scroll view has regressed.
///
/// It is also the honest reading of the CTA's reachability. Measured in this
/// slot at ORDINARY text scale, the pill lands at y 313–361 against a 260 dp
/// viewport — entirely below the fold. "I'm still here" is only tappable if the
/// Jeeber scrolls, and nothing above the fold hints that there is anything to
/// scroll to.
@JeebPreview(group: 'jeeber_home', name: 'Short viewport 260dp', size: Size(390, 320))
Widget inactivityWarningBannerShortViewport() =>
    _inactivityWarningBannerDashboard(
      profileName: 'Layla',
      width: 390,
      height: 260,
    );
