import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/wallet_charge_info_screen_fixtures.dart';

/// wallet-charge-info (JM-054). Static, NO-payment instructional screen
/// (D92/D93): the Jeeber charges the wallet at an authorized store, gives a
/// phone number / ID, pays cash, the balance auto-updates, and the 10% platform
/// fee per accepted offer comes from that pre-charged balance — there is NO
/// in-app payment, NO card input, NO amount field, NO store directory. The
/// three forbidden affordances (`charge_info_card_input`,
/// `charge_info_amount_field`, `charge_info_store_directory`) are intentionally
/// absent and `assertNotVisible` in the JM-054 Maestro flow; do NOT add any
/// payment/amount widget here.
///
/// This screen makes NO network call (JM-054 AC: "No network call. Mock: —").
///
/// It is the honest target of every "+ Top up" CTA across the app: wallet-hub
/// `wallet_topup_cta` (JM-053), onboarding-funding `funding_topup_cta` (JM-041),
/// kyc-pending `kyc_status_topup_cta` (JM-042), insufficient-balance
/// `insufficient_topup_cta` (JM-046). When reached standalone the back CTA
/// returns to wallet-hub; when pushed from one of those callers it pops back to
/// the caller (canPop) — the JM-054 flow asserts back → `wallet_available_balance`.
///
/// Identifier contract: 65_W2_TEST_PLAN §2/§4 JM-054. Every id below is exact.
class WalletChargeInfoScreen extends StatelessWidget {
  const WalletChargeInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'charge_info_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.chargeInfoTitle,
          showBackButton: true,
          // Mirror the body `charge_info_back_cta` destination contract: pop to
          // the caller when pushed (+Top up flows), else go to wallet-hub when
          // launched standalone. Never pop the last page (empty Navigator →
          // black surface).
          onBackPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('wallet'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            // Numbered, ordered instruction steps (D92/D93 charge-at-store flow).
            _Step(
              index: 1,
              id: 'charge_info_store_step',
              text: l10n.chargeInfoStoreStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 2,
              id: 'charge_info_identity_step',
              text: l10n.chargeInfoIdentityStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 3,
              id: 'charge_info_pay_cash_step',
              text: l10n.chargeInfoPayCashStep,
            ),
            const SizedBox(height: Spacing.xLarge),

            // Note 1 — balance auto-updates, no in-app payment (D92/D93).
            _Note(
              id: 'charge_info_auto_update_note',
              icon: Icons.sync_outlined,
              text: l10n.chargeInfoAutoUpdateNote,
            ),
            const SizedBox(height: Spacing.small),

            // Note 2 — 10% platform fee comes from the pre-charged balance
            // (D1 reserve-per-offer / D41 fee-only economics).
            _Note(
              id: 'charge_info_fee_note',
              icon: Icons.percent_outlined,
              text: l10n.chargeInfoFeeNote,
            ),
            const SizedBox(height: Spacing.twoXLarge),

            // EDGE: wallet-charge-info → wallet-hub (21_NAV_PLAN §C JM-054).
            // Standalone launch has nothing to pop → goNamed('wallet'); when
            // pushed by a +Top up caller (funding/kyc-pending/insufficient) it
            // pops back to that caller.
            Semantics(
              identifier: 'charge_info_back_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.chargeInfoBackCta,
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.goNamed('wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single ordered instruction step: a numbered badge + the step copy.
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.id, required this.text});

  final int index;
  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered badge.
          Container(
            width: Sizes.xLarge,
            height: Sizes.xLarge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

/// An informational note row (auto-update / fee), icon + supporting copy.
class _Note extends StatelessWidget {
  const _Note({required this.id, required this.icon, required this.text});

  final String id;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Sizes.large, color: color),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
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
// Render tests: test/previews/wallet/wallet_charge_info_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, and a static one, so it previews differently twice over.
//
// 1. It owns its own `Scaffold` (app bar + list) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([walletChargeInfoScreenPhoneBox], 390x844, and the smallest phone the app
//    supports, [walletChargeInfoScreenCompactBox], 320x568) rather than the
//    harness's default 390x200 — three steps, two notes and a bottom CTA cannot
//    be judged in a 200 pt strip.
//
// 2. It has NO data state to seed. JM-054 makes no network call, takes no
//    constructor parameters and builds no cubit, so there is no empty / loading
//    / error triple to draw. What it does have is a NAVIGATION state and a
//    TYPOGRAPHY ceiling, and those are the axes these previews cover:
//
//      * which stack it sits on — `charge_info_back_cta` and the app bar arrow
//        both branch on `context.canPop()`, so the same button has two
//        destinations (`WalletChargeInfoScreenEntry`);
//      * how the copy behaves at the 200% accessibility ceiling, on a 320 pt
//        phone, and in Arabic — the only things that make this screen's layout
//        move at all.
//
// The router that supplies the navigation state is the fixture, shared with the
// Screen Catalog entry
// (`lib/devtool/catalog/fixtures/wallet_charge_info_screen_fixtures.dart`) so
// the two dev surfaces cannot drift. It is a local [GoRouter] over two stand-in
// destinations — no DI, no Dio, nothing for [jeebPreviewHost]'s guard to catch.
// Without it these previews would not merely be unrealistic, they would be
// untappable: the canvas provides no `Router`, so `context.canPop()` throws the
// moment either back affordance is used.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * the `Standalone` and `Pushed` previews are pixel-identical at rest and
//    send the same button to two different screens — and in the app only the
//    first is reachable. `/wallet/charge-info` is declared FLAT (a top-level
//    route beside `/wallet`, not a child of it) and all four `+ Top up` CTAs
//    reach it with `goNamed`, which REPLACES the stack. Driving the real
//    `AppRouter` confirms it: after `goNamed('wallet-charge-info')` the match
//    list is one page, `canPop()` is false, and back lands on `/wallet`. So the
//    `context.pop()` half of both affordances is dead code, this file's own
//    doc comment ("when pushed from one of those callers it pops back to the
//    caller") describes a path that does not exist, and the reason
//    `offer_submission_screen.dart` gives for popping its sheet first ("so a
//    back from charge-info returns to the composer with the draft intact") does
//    not hold — back returns to the wallet hub, not the composer;
//  * the step badge is a fixed `Sizes.xLarge` (24 pt) circle wrapping a `Text`
//    that scales with the user's text size. At 200% the digit lays out 40 pt
//    tall inside a 24 pt circle and paints straight through it — see
//    `EN · 200% text`. It is a `Container(alignment:)`, i.e. an `Align`, so
//    nothing clips and nothing throws; it just looks broken and there is no
//    test that would notice;
//  * `charge_info_back_cta` is the last child of a `ListView`, and it is below
//    the fold far earlier than the screen's "static instructional page" framing
//    suggests. On the smallest supported phone at NORMAL text size the content
//    already runs 192 pt past the viewport (`Compact 320x568`); at 200% it runs
//    1198 pt past it — one and a half screens of scrolling between the last
//    step and the only way out — and in Arabic at 200%, 922 pt. A reader who
//    treats this page as a poster never sees the button.

/// The canvas box for a whole screen: a real phone, not the harness default.
///
/// Public so the render test can reproduce the canvas box with
/// `setSurfaceSize` — a preview whose state is a DEVICE SIZE is not reproduced
/// by calling its function alone.
const Size walletChargeInfoScreenPhoneBox = Size(390, 844);

/// The smallest phone the app supports (iPhone SE 1st gen / small Androids).
///
/// Worth its own card because this screen is a single unscrollable-looking
/// column: the CTA sitting below the fold here is the difference between "the
/// instructions end in a button" and "the instructions end".
const Size walletChargeInfoScreenCompactBox = Size(320, 568);

/// Hosts the screen on the stack named by [entry], optionally at [textScale]
/// and in [arabic].
///
/// The locale/text-scale overrides are applied HERE rather than left to the
/// `matrix:` flag on purpose: the matrix renders AR at 100% and 200% in EN, so
/// the combination that actually breaks Arabic copy — RTL *and* 200% together —
/// is the one reading the canvas cannot give you.
Widget _walletChargeInfoScreenHosted({
  WalletChargeInfoScreenEntry entry = WalletChargeInfoScreenEntry.standalone,
  double textScale = 1,
  bool arabic = false,
}) {
  final Widget hosted = WalletChargeInfoScreenHost(
    entry: entry,
    screen: const WalletChargeInfoScreen(),
  );
  final Widget scaled = textScale == 1
      ? hosted
      : Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: hosted,
          ),
        );
  if (!arabic) return scaled;
  return Builder(
    builder: (BuildContext context) => Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: Directionality(textDirection: TextDirection.rtl, child: scaled),
    ),
  );
}

/// The state every user actually reaches: the screen as the root of its own
/// stack, which is what `goNamed('wallet-charge-info')` leaves behind.
///
/// `context.canPop()` is false here, so both back affordances resolve to
/// `goNamed('wallet')` — tap either one in the canvas and the wallet-hub
/// stand-in comes up.
///
/// Matrixed because RTL is the only thing that moves this layout without
/// changing the text size: every row is a leading badge/icon plus copy, laid
/// out with `EdgeInsetsDirectional` and `Row`, and the numbered badges must end
/// up on the right in Arabic.
@JeebPreview(
  group: 'wallet',
  name: 'Standalone · back → wallet-hub',
  size: walletChargeInfoScreenPhoneBox,
  matrix: true,
)
Widget walletChargeInfoScreenStandalone() => _walletChargeInfoScreenHosted();

/// The other half of the screen's written contract: pushed ON TOP of the
/// `+ Top up` caller that sent the user here.
///
/// `context.canPop()` is true, so back POPS — tap it in the canvas and the
/// caller stand-in comes up, not the wallet. The button still reads "Back to
/// wallet".
///
/// Two things worth knowing about this card. It is pixel-identical to the one
/// above (the screen renders nothing that depends on where it came from), so
/// the difference is only visible when you tap. And in the app today it is
/// unreachable: all four `+ Top up` CTAs use `goNamed`, and charge-info is a
/// flat top-level route, so the stack is always one page deep. It is kept
/// because the screen and its callers are written as though this were the
/// normal case.
@JeebPreview(
  group: 'wallet',
  name: 'Pushed by a + Top up caller',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenPushedFromTopUp() => _walletChargeInfoScreenHosted(
      entry: WalletChargeInfoScreenEntry.pushedOnCaller,
    );

/// The floor: a 320x568 phone at normal text size, and the card that shows the
/// screen is not the poster it reads as.
///
/// Nothing about the copy changes here — but the fold does. The content runs
/// 192 pt past the viewport at 100% text, so `charge_info_back_cta` is off
/// screen (in fact not even built) while all three steps and both notes are up.
/// The page ends, visually, on the fee note; the only way out is a scroll the
/// layout gives no hint of. On a 390x844 phone (the two previews above) the
/// same content needs no scrolling at all, which is why this is a card and not
/// a footnote: whether this screen has a visible way out depends entirely on
/// the device it is read on.
@JeebPreview(
  group: 'wallet',
  name: 'Compact 320x568',
  size: walletChargeInfoScreenCompactBox,
)
Widget walletChargeInfoScreenCompact() => _walletChargeInfoScreenHosted();

/// The accessibility ceiling: 200% text on a full-size phone.
///
/// Read the numbered badges. Each is a `Container` fixed at `Sizes.xLarge`
/// (24 pt) square holding a `labelLarge` digit, and the digit — but not the
/// circle — follows the user's text scale: the same digit lays out 20 pt tall
/// at 100% and 40 pt tall here, inside a circle that stayed 24. It paints
/// straight through the badge. `Container(alignment:)` is an `Align`, so there
/// is no clip and no overflow exception; nothing fails, it just looks wrong,
/// which is why no existing test catches it.
///
/// The reading order breaks too. The three steps alone now run to 888 pt on an
/// 844 pt phone — step 3 is already cut — and the content in total is 1198 pt
/// longer than the viewport, so the user is one and a half screens of scrolling
/// away from `charge_info_back_cta`. At normal text size this same screen needs
/// no scrolling at all.
@JeebPreview(
  group: 'wallet',
  name: 'EN · 200% text',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenLargeText() =>
    _walletChargeInfoScreenHosted(textScale: 2);

/// The combination the standard matrix cannot render: Arabic AND 200% text.
///
/// RTL mirrors every row — the numbered badges move to the trailing (right)
/// edge while their digits stay latin, so the 1-2-3 reading order survives —
/// and the `EdgeInsetsDirectional` padding follows. This is also the pass that
/// shows the AR copy is SHORTER than the English: the same content overruns the
/// viewport by 922 pt here against 1198 pt in English, so an English-only
/// review of the 200% state is the pessimistic one, not the optimistic one.
@JeebPreview(
  group: 'wallet',
  name: 'AR · 200% text',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenArabicLargeText() =>
    _walletChargeInfoScreenHosted(textScale: 2, arabic: true);
