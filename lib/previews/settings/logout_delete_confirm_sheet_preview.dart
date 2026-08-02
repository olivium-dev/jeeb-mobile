/// Widget previews for [LogoutDeleteConfirmSheet] — run with
/// `flutter widget-preview start`.
///
/// JM-062 `logout-delete-account` is the last surface between a signed-in user
/// and two terminal acts that are not symmetric: signing out costs an OTP, and
/// deleting flips the account to `deleted` and queues a permanent purge
/// ([kAccountPurgeGraceDays] days, E20/JEBV4-215). Everything that decides
/// whether the user picks the right one is *copy and state* — which title, which
/// body, which CTA is spinning — so it is exactly the kind of surface a preview
/// canvas reviews better than an assertion.
///
/// **Network-free by construction.** The sheet takes an
/// [AccountSessionTerminator] seam, and every preview passes one explicitly.
/// That matters more here than usual: left null, `_resolveTerminator()` reaches
/// for `sl<AccountSessionTerminator>()` and otherwise self-provides a
/// `DioAccountSessionTerminator(resolveGatewayDio(), AuthTokenStore())` — a
/// preview must never depend on whether the canvas happened to build the DI
/// graph, and a *real* terminator on this sheet would revoke a session and clear
/// a keystore. [_InertTerminator] and [_HangingTerminator] below have no
/// transport and no keystore of any kind.
///
/// **What the matrix shows that `test/features/settings/logout_delete_confirm_sheet_test.dart`
/// does not.** That file asserts the four semantics ids and the two callbacks;
/// it never looks at the sheet. Measured heights at 390 pt wide, EN / AR:
///
/// | mode   | 100%      | 200%        |
/// |--------|-----------|-------------|
/// | logout | 368 / 392 | 640 / 736   |
/// | both   | 428 / 452 | 700 / 796   |
/// | delete | 512 / 452 | **1168** / 928 |
///
/// The delete column is the finding. The body is a plain [Column] with
/// `mainAxisSize.min` and no scroll fallback, and `showModalBottomSheet(
/// isScrollControlled: true)` grants height — it does not add scrolling. 1168 pt
/// against an 844 pt phone is `A RenderFlex overflowed by ~324 pixels on the
/// bottom`, and what is below the fold is the bottom of the stack: the
/// `delete_confirm_cta` and the `logout_delete_cancel_cta`. A user at the
/// accessibility ceiling is shown a deletion warning with neither button.
///
/// All numbers come from `flutter test`, whose substituted font is materially
/// wider and taller than the production Inter face, so read them as the
/// pessimistic bound — except the 320 pt figures (delete reaches 1416 pt in a
/// 568 pt phone), which are far past any font-metric slack.
///
/// **Tapping in the canvas.** `_inFlight` is latched and never reset — production
/// relies on `onCompleted` popping the sheet — so a confirm tap here leaves the
/// sheet spinning with the cancel CTA disabled. Hot-restart to get it back.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/settings/domain/account_deletion_policy.dart';
import '../../features/settings/domain/account_session_terminator.dart';
import '../../features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../harness/jeeb_preview.dart';

/// Phone width with room for the logout stack (handle → 64 pt icon → title →
/// one-sentence body → 48 pt confirm → 48 pt cancel), measured at 368 pt EN /
/// 392 pt AR.
const Size _sheetBox = Size(390, 460);

/// The JM-062 profile-row sheet, which carries a second 48 pt CTA — 428 pt EN /
/// 452 pt AR.
const Size _bothBox = Size(390, 500);

/// The delete stack, whose three-sentence purge warning is the longest copy this
/// widget can be asked to lay out — 512 pt EN.
///
/// Deliberately NOT sized for the matrix's 200% rendering (1168 pt): no
/// phone-shaped box contains that, and the stripes it paints belong to the
/// widget, not to the canvas.
const Size _deleteBox = Size(390, 560);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs — `both` reaches 472 pt at 100% here.
const Size _narrowBox = Size(320, 520);

/// Width of the smallest supported phone (iPhone SE 1st gen class).
const double _smallPhoneWidth = 320;

/// A terminator with no transport, no keystore and no side effect.
///
/// Both methods resolve immediately, which is what the real one does after a
/// successful clear — so a confirm tap in the canvas runs the same code path
/// production runs, minus the gateway calls the [AccountSessionTerminator]
/// contract already describes as best-effort.
class _InertTerminator implements AccountSessionTerminator {
  const _InertTerminator();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// A terminator whose calls never resolve, so the sheet stays `_inFlight`
/// forever and the spinner state can be *looked at* instead of caught in a
/// single frame.
///
/// This is the only honest way to reach that state from outside: `_inFlight` is
/// private and there is no `initialState:` seam on this widget (unlike
/// `OfferAcceptSheet`), so [_AutoConfirm] drives the real CTA and this class
/// keeps the resulting state pinned.
class _HangingTerminator implements AccountSessionTerminator {
  const _HangingTerminator();

  @override
  Future<void> logout() => Completer<void>().future;

  @override
  Future<void> deleteAccount() => Completer<void>().future;
}

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// The width pin is load-bearing: the render tests pump an 800 px viewport and
/// ignore [JeebPreview.size], so without it CI would be reviewing a bottom sheet
/// at a width no phone has. Bottom anchoring reproduces the real geometry: the
/// sheet grows upward from the bottom edge and, past the box, overflows at the
/// bottom of its own [Column] exactly as it does on a phone.
Widget _hosted(
  LogoutDeleteMode mode, {
  double width = 390,
  AccountSessionTerminator terminator = const _InertTerminator(),
  Key? confirmKey,
}) {
  final Widget sheet = Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      width: width,
      child: LogoutDeleteConfirmSheet(
        mode: mode,
        terminator: terminator,
        // No-ops on purpose. Production pops the sheet, refreshes SessionCubit
        // and `go('/')`s to splash → /login (D5); none of that belongs in a
        // canvas, and `go` without a GoRouter ancestor would throw.
        onCompleted: () {},
        onCancelled: () {},
      ),
    ),
  );
  if (confirmKey == null) return sheet;
  return _AutoConfirm(buttonKey: confirmKey, child: sheet);
}

/// The default reading: `LogoutDeleteMode.logout`, the sheet the Settings
/// Account section opens and the one `account_status_signout_cta` (JM-066)
/// lands on.
///
/// The pair to check is the icon and the title. The icon is
/// `colorScheme.error`-tinted at 64 pt for BOTH modes — the only thing telling a
/// reversible sign-out apart from an irreversible delete is `Icons.logout`
/// vs `Icons.delete_outline` at a glance, and the title underneath it. In the
/// **AR RTL dark** rendering `Icons.logout` is the one glyph here with a
/// direction: it keeps its LTR arrow while every other element mirrors.
@JeebPreview(group: 'settings', name: 'Sign out', size: _sheetBox)
Widget logoutDeleteConfirmSheetLogout() => _hosted(LogoutDeleteMode.logout);

/// `LogoutDeleteMode.delete` — the irreversible half, and the longest copy the
/// sheet can render.
///
/// This body is the E20 / JEBV4-215 contract in prose: the account is
/// deactivated *now*, purged after [kAccountPurgeGraceDays] days, active orders
/// must be completed first, and signing in again before the purge reverses it.
/// Three sentences, 176 characters, and the reason the delete column of the
/// table above is the one that overflows. If the grace window ever drifts from
/// the gateway purge-worker SLA, this is where a reviewer sees the wrong number.
@JeebPreview(group: 'settings', name: 'Delete account', size: _deleteBox)
Widget logoutDeleteConfirmSheetDelete() => _hosted(LogoutDeleteMode.delete);

/// `LogoutDeleteMode.both` — the JM-062 profile-row entry, which puts both
/// terminal actions on one sheet.
///
/// Two CTAs stacked 12 pt apart, both filled `colorScheme.error`, differing only
/// in their label — and the destructive one is the SECOND, directly above a
/// `Cancel` that is the same size and one row further down. This is the state to
/// judge for mis-tap risk, and the **EN 200% text** rendering is where it gets
/// worse: "Delete account" wraps to two lines and fills the 48 pt pill edge to
/// edge (measured 342 × 48 in a 48 pt button), while the copy above it still
/// says "You'll need to sign in again", because `both` shows the *sign-out*
/// title and body over a delete button.
@JeebPreview(group: 'settings', name: 'Sign out + delete', size: _bothBox)
Widget logoutDeleteConfirmSheetBoth() => _hosted(LogoutDeleteMode.both);

/// The clear in flight — the double-fire guard, made visible, and the one state
/// no widget test in this repo renders.
///
/// Confirming latches `_inFlight`: both CTAs go inert (`enabled: !_inFlight`,
/// `onTap: null` on the semantics node) and `logout_delete_cancel_cta` is
/// disabled too, so the sheet cannot be torn down mid-clear.
///
/// **What this rendering shows: `both` mode spins BOTH buttons.** `_confirmCta`
/// passes `isLoading: _inFlight` to every CTA it builds, so tapping "Sign out"
/// starts a spinner on "Delete account" as well — on the one sheet where the two
/// actions are "log me out" and "erase my account", the surface reports that the
/// action the user did *not* choose is also running. `OmdsLoadingButton` swaps
/// `text` for the spinner, so the labels are gone while it happens: there is
/// nothing on screen naming which act is in flight.
///
/// Reached by [_AutoConfirm] firing the real `logout-confirm-cta` on the first
/// frame against [_HangingTerminator]; no production code is touched to get
/// here.
@JeebPreview(group: 'settings', name: 'Clearing session', size: _bothBox)
Widget logoutDeleteConfirmSheetInFlight() => _hosted(
      LogoutDeleteMode.both,
      terminator: const _HangingTerminator(),
      confirmKey: const Key('logout-confirm-cta'),
    );

/// `both` at 320 pt — the narrowest phone, and the width ceiling for the CTAs.
///
/// The `OmdsLoadingButton` pill is a FIXED 48 pt (`Sizes.fourXLarge`) at every
/// text scale and its label sits in a `Center` with no ellipsis, so a wrapped
/// label does not grow the button — it is clamped and painted over the pill
/// edge. At 200% both "Delete account" and (in AR) "تسجيل الخروج" measure
/// 272 × 48 inside a 48 pt pill: zero padding, and one more line would spill.
///
/// Height is the other half: 472 pt at 100% of a 568 pt phone leaves 96 pt of
/// scrim, and 740 pt EN / 876 pt AR at 200% is past the whole screen with no
/// scroll fallback under it.
@JeebPreview(group: 'settings', name: 'Narrow phone · 320 pt', size: _narrowBox)
Widget logoutDeleteConfirmSheetNarrowPhone() => _hosted(
      LogoutDeleteMode.both,
      width: _smallPhoneWidth,
    );

/// Fires a confirm CTA on the first frame, so a state that only exists *after* a
/// tap can be reviewed as a static preview.
///
/// It walks the element tree for the [OmdsLoadingButton] carrying [buttonKey]
/// and invokes its `onTap` — the same callback a real tap runs. Reaching into
/// the tree is deliberate: the alternative would be a production `initialState:`
/// seam added for the canvas's benefit, and a preview does not get to change the
/// widget it reviews.
class _AutoConfirm extends StatefulWidget {
  const _AutoConfirm({required this.buttonKey, required this.child});

  /// Key of the [OmdsLoadingButton] to fire (`logout-confirm-cta` /
  /// `delete-confirm-cta`).
  final Key buttonKey;

  final Widget child;

  @override
  State<_AutoConfirm> createState() => _AutoConfirmState();
}

class _AutoConfirmState extends State<_AutoConfirm> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because the button has to exist before it can be found — the
    // same sequencing the modal previews in this folder's siblings use.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fire());
  }

  void _fire() {
    if (!mounted) return;
    OmdsLoadingButton? target;
    void visit(Element element) {
      if (target != null) return;
      final Widget widget = element.widget;
      if (widget is OmdsLoadingButton && widget.key == this.widget.buttonKey) {
        target = widget;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    target?.onTap();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
