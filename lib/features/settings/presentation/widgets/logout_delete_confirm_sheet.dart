import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/dio_account_session_terminator.dart';
import '../../domain/account_deletion_policy.dart';
import '../../domain/account_session_terminator.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';

import '../../../../core/previews/jeeb_preview.dart';

/// Which terminal action the [LogoutDeleteConfirmSheet] confirms.
enum LogoutDeleteMode {
  /// Sign out — revoke the gateway session + clear the local keystore.
  logout,

  /// Delete account — queue `status → deleted` (D5) + clear the local keystore.
  delete,

  /// Both terminal actions on one sheet (the JM-062 profile-row + account-status
  /// entry): renders BOTH `logout_confirm_cta` and `delete_confirm_cta`. The
  /// flow (jm-062 AC1) asserts both are present, then taps one.
  both,
}

/// `logout-delete-account` (JM-062, blueprint `logout-delete-account`).
///
/// The confirm surface for both terminal account actions. It is a **sheet, not
/// a route** (40_GUARDRAILS_ARCH §5 — sheets are `showModalBottomSheet`, mirrors
/// `CancelRequestSheet` / `OfferAcceptSheet`). It is hosted by
/// `SettingsScreen._AccountSection` (the JM-062 target) and is reachable from
/// `account-status` (JM-066) — the `account_status_signout_cta` routes to
/// `/settings`, whose Account section opens this sheet.
///
/// On confirm both modes converge on the SAME load-bearing outcome the JM-062 AC
/// requires: the local session is cleared (keystore tokens dropped via
/// [AccountSessionTerminator]) so the router's first-run gate flips to
/// unauthenticated, then `context.go('/')` lands on splash → `/login` (D5).
/// The gateway calls (`POST /v1/auth/logout`, `POST /v1/devices/unregister`,
/// delete) are best-effort inside the terminator — they never block the clear.
///
/// Semantics identifiers exposed (EXACT, 30_BACKLOG JM-062 AC):
///   - `logout_delete_confirm_sheet` — bottom-sheet root (signature id)
///   - `logout_confirm_cta`          — confirm the logout (logout mode)
///   - `delete_confirm_cta`          — confirm the deletion (delete mode)
///   - `logout_delete_cancel_cta`    — dismiss the sheet (keep the session)
class LogoutDeleteConfirmSheet extends StatefulWidget {
  const LogoutDeleteConfirmSheet({
    super.key,
    required this.mode,
    this.terminator,
    this.onCompleted,
    this.onCancelled,
  });

  /// Which terminal action this sheet confirms (logout vs delete).
  final LogoutDeleteMode mode;

  /// Optional terminator override. Production builds leave this null and the
  /// sheet self-provides a [DioAccountSessionTerminator] over `sl<Dio>()` +
  /// `sl<AuthTokenStore>()` (40_GUARDRAILS_ARCH §5.4 — screen self-provides;
  /// no `injection_container.dart` edit). Widget tests inject a scripted fake.
  final AccountSessionTerminator? terminator;

  /// Fired after the session has been cleared. [show] wires the default
  /// (`pop` the sheet + `context.go('/')` → splash); an explicit callback is for
  /// tests so they can assert the side effect without a router.
  final VoidCallback? onCompleted;

  /// Fired when the user dismisses without confirming. [show] wires `pop`.
  final VoidCallback? onCancelled;

  /// Opens the confirm sheet over the current route with the standard OMDS
  /// top-rounded shape + dimmed scrim. Returns `true` once the session is
  /// cleared (the caller's route is torn down by `go('/')`), `false`/`null` when
  /// dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required LogoutDeleteMode mode,
    AccountSessionTerminator? terminator,
  }) {
    final rootContext = context;
    // Capture the session cubit BEFORE the sheet's own context: it lives at the
    // app root (provided by `app.dart`), and reading it after `go('/')` (which
    // tears the sheet down) would be unsafe.
    final session = rootContext.read<SessionCubit?>();
    final scrim = Theme.of(context)
        .colorScheme
        .onSecondaryContainer
        .withValues(alpha: UIConstants.opacityHigh);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => LogoutDeleteConfirmSheet(
        mode: mode,
        terminator: terminator,
        // EDGE (JM-062 AC, D5): on confirm the local session is already cleared
        // by the time this fires; refresh the SessionCubit so the router gate
        // re-reads the (now empty) keystore, then `go('/')` → first-run gate →
        // splash → `/login`. Pop the sheet FIRST so the destination's id is the
        // only thing on screen for Maestro.
        onCompleted: () async {
          Navigator.of(sheetContext).pop(true);
          await session?.refresh();
          if (rootContext.mounted) rootContext.go('/');
        },
        onCancelled: () => Navigator.of(sheetContext).pop(false),
      ),
    );
  }

  @override
  State<LogoutDeleteConfirmSheet> createState() =>
      _LogoutDeleteConfirmSheetState();
}

class _LogoutDeleteConfirmSheetState extends State<LogoutDeleteConfirmSheet> {
  late final AccountSessionTerminator _terminator = _resolveTerminator();
  bool _inFlight = false;

  AccountSessionTerminator _resolveTerminator() {
    final explicit = widget.terminator;
    if (explicit != null) return explicit;
    // S6 Stream C: prefer the DI-registered terminator (the canonical release
    // default) when DI is configured; the self-provide below is the no-DI seam.
    if (sl.isRegistered<AccountSessionTerminator>()) {
      return sl<AccountSessionTerminator>();
    }
    // Self-provide over the shared gateway Dio + keystore. resolveGatewayDio()
    // returns the registered singleton when DI is configured and otherwise
    // mirrors the AppConfig selection (a dev-seam / deep-link entry before the
    // DI batch lands) so the sheet never crashes.
    final dio = resolveGatewayDio();
    final tokenStore =
        sl.isRegistered<AuthTokenStore>() ? sl<AuthTokenStore>() : AuthTokenStore();
    return DioAccountSessionTerminator(dio, tokenStore);
  }

  Future<void> _run(LogoutDeleteMode action) async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    // The terminator is fail-safe (never throws): the gateway calls are
    // best-effort and the local keystore clear always runs (D5).
    switch (action) {
      case LogoutDeleteMode.delete:
        await _terminator.deleteAccount();
      case LogoutDeleteMode.logout:
      case LogoutDeleteMode.both:
        await _terminator.logout();
    }
    if (!mounted) return;
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDelete = widget.mode == LogoutDeleteMode.delete;
    final isBoth = widget.mode == LogoutDeleteMode.both;

    final title =
        isDelete ? l10n.accountDeleteDialogTitle : l10n.signOutDialogTitle;
    final body = isDelete
        ? l10n.accountDeleteDialogBody(kAccountPurgeGraceDays)
        : l10n.signOutDialogBody;

    // Build the confirm CTA(s). For [both] we render the logout CTA then the
    // delete CTA so the flow can assert (and tap) either by id.
    final confirmCtas = <Widget>[
      if (!isDelete)
        _confirmCta(
          theme,
          id: 'logout_confirm_cta',
          buttonKey: const Key('logout-confirm-cta'),
          text: l10n.appBarSignOut,
          onTap: () => _run(LogoutDeleteMode.logout),
        ),
      if (isBoth) const SizedBox(height: Spacing.small),
      if (isDelete || isBoth)
        _confirmCta(
          theme,
          id: 'delete_confirm_cta',
          buttonKey: const Key('delete-confirm-cta'),
          text: l10n.accountDeleteConfirm,
          onTap: () => _run(LogoutDeleteMode.delete),
        ),
    ];

    return Semantics(
      // JM-062/066 flows assert `logout_delete_sheet`; the unit test asserts the
      // legacy `logout_delete_confirm_sheet`. Nest both so neither regresses.
      identifier: 'logout_delete_sheet',
      explicitChildNodes: true,
      child: Semantics(
        identifier: 'logout_delete_confirm_sheet',
        explicitChildNodes: true,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.small,
              Spacing.xLarge,
              Spacing.xLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetDragHandle(),
                const SizedBox(height: Spacing.large),
                Icon(
                  isDelete ? Icons.delete_outline : Icons.logout,
                  size: Sizes.sixXLarge,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: Spacing.medium),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.medium),
                // Warning copy (lofiOutline: "irreversibility / role suspension
                // implications" for delete; "sign in again" for logout).
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.twoXLarge),
                ...confirmCtas,
                const SizedBox(height: Spacing.small),
                // logout_delete_cancel_cta — dismiss, keep the session. Inert
                // while a confirm is in flight so it can't tear down mid-clear.
                Semantics(
                  identifier: 'logout_delete_cancel_cta',
                  container: true,
                  button: true,
                  enabled: !_inFlight,
                  label: l10n.actionCancel,
                  onTap: _inFlight ? null : widget.onCancelled,
                  child: ExcludeSemantics(
                    child: OMDSOutlinedButton(
                      key: const Key('logout-delete-cancel-cta'),
                      text: l10n.actionCancel,
                      enabled: !_inFlight,
                      onTap: () => widget.onCancelled?.call(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A confirm CTA — confirm → session cleared → splash (D5). Disabled + spinner
  /// while in flight so it can't double-fire the clear.
  Widget _confirmCta(
    ThemeData theme, {
    required String id,
    required Key buttonKey,
    required String text,
    required VoidCallback onTap,
  }) {
    return Semantics(
      identifier: id,
      container: true,
      button: true,
      enabled: !_inFlight,
      label: text,
      onTap: _inFlight ? null : onTap,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          key: buttonKey,
          text: text,
          isLoading: _inFlight,
          isEnabled: !_inFlight,
          onTap: onTap,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
          borderRadius: OmdsBorderRadius.uiSmall,
        ),
      ),
    );
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary — matches
/// the shared sheet handle styling used across the app's bottom sheets
/// (mirrors `CancelRequestSheet._SheetDragHandle`).
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
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
// Render tests:
// test/previews/settings/logout_delete_confirm_sheet_preview_test.dart
// ===========================================================================
//
// Widget previews for [LogoutDeleteConfirmSheet] — run with
// `flutter widget-preview start`.
//
// JM-062 `logout-delete-account` is the last surface between a signed-in user
// and two terminal acts that are not symmetric: signing out costs an OTP, and
// deleting flips the account to `deleted` and queues a permanent purge
// ([kAccountPurgeGraceDays] days, E20/JEBV4-215). Everything that decides
// whether the user picks the right one is *copy and state* — which title, which
// body, which CTA is spinning — so it is exactly the kind of surface a preview
// canvas reviews better than an assertion.
//
// **Network-free by construction.** The sheet takes an
// [AccountSessionTerminator] seam, and every preview passes one explicitly.
// That matters more here than usual: left null, `_resolveTerminator()` reaches
// for `sl<AccountSessionTerminator>()` and otherwise self-provides a
// `DioAccountSessionTerminator(resolveGatewayDio(), AuthTokenStore())` — a
// preview must never depend on whether the canvas happened to build the DI
// graph, and a *real* terminator on this sheet would revoke a session and clear
// a keystore. [_LogoutDeleteConfirmSheetInertTerminator] and
// [_LogoutDeleteConfirmSheetHangingTerminator] below have no transport and no
// keystore of any kind.
//
// **What the matrix shows that
// `test/features/settings/logout_delete_confirm_sheet_test.dart` does not.**
// That file asserts the four semantics ids and the two callbacks; it never
// looks at the sheet. Measured heights at 390 pt wide, EN / AR:
//
// | mode   | 100%      | 200%        |
// |--------|-----------|-------------|
// | logout | 368 / 392 | 640 / 736   |
// | both   | 428 / 452 | 700 / 796   |
// | delete | 512 / 452 | **1168** / 928 |
//
// The delete column is the finding. The body is a plain [Column] with
// `mainAxisSize.min` and no scroll fallback, and `showModalBottomSheet(
// isScrollControlled: true)` grants height — it does not add scrolling. 1168 pt
// against an 844 pt phone is `A RenderFlex overflowed by ~324 pixels on the
// bottom`, and what is below the fold is the bottom of the stack: the
// `delete_confirm_cta` and the `logout_delete_cancel_cta`. A user at the
// accessibility ceiling is shown a deletion warning with neither button.
//
// All numbers come from `flutter test`, whose substituted font is materially
// wider and taller than the production Inter face, so read them as the
// pessimistic bound — except the 320 pt figures (delete reaches 1416 pt in a
// 568 pt phone), which are far past any font-metric slack.
//
// **Tapping in the canvas.** `_inFlight` is latched and never reset —
// production relies on `onCompleted` popping the sheet — so a confirm tap here
// leaves the sheet spinning with the cancel CTA disabled. Hot-restart to get it
// back.

/// Phone width with room for the logout stack (handle → 64 pt icon → title →
/// one-sentence body → 48 pt confirm → 48 pt cancel), measured at 368 pt EN /
/// 392 pt AR.
const Size _logoutDeleteConfirmSheetBox = Size(390, 460);

/// The JM-062 profile-row sheet, which carries a second 48 pt CTA — 428 pt EN /
/// 452 pt AR.
const Size _logoutDeleteConfirmSheetBothBox = Size(390, 500);

/// The delete stack, whose three-sentence purge warning is the longest copy this
/// widget can be asked to lay out — 512 pt EN.
///
/// Deliberately NOT sized for the matrix's 200% rendering (1168 pt): no
/// phone-shaped box contains that, and the stripes it paints belong to the
/// widget, not to the canvas.
const Size _logoutDeleteConfirmSheetDeleteBox = Size(390, 560);

/// The narrowest phone the app supports, and the taller box its extra wrapping
/// needs — `both` reaches 472 pt at 100% here.
const Size _logoutDeleteConfirmSheetNarrowBox = Size(320, 520);

/// Width of the smallest supported phone (iPhone SE 1st gen class).
const double _logoutDeleteConfirmSheetSmallPhoneWidth = 320;

/// A terminator with no transport, no keystore and no side effect.
///
/// Both methods resolve immediately, which is what the real one does after a
/// successful clear — so a confirm tap in the canvas runs the same code path
/// production runs, minus the gateway calls the [AccountSessionTerminator]
/// contract already describes as best-effort.
class _LogoutDeleteConfirmSheetInertTerminator
    implements AccountSessionTerminator {
  const _LogoutDeleteConfirmSheetInertTerminator();

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
/// `OfferAcceptSheet`), so [_LogoutDeleteConfirmSheetAutoConfirm] drives the
/// real CTA and this class keeps the resulting state pinned.
class _LogoutDeleteConfirmSheetHangingTerminator
    implements AccountSessionTerminator {
  const _LogoutDeleteConfirmSheetHangingTerminator();

  @override
  Future<void> logout() => Completer<void>().future;

  @override
  Future<void> deleteAccount() => Completer<void>().future;
}

/// Fires a confirm CTA on the first frame, so a state that only exists *after* a
/// tap can be reviewed as a static preview.
///
/// It walks the element tree for the [OmdsLoadingButton] carrying [buttonKey]
/// and invokes its `onTap` — the same callback a real tap runs. Reaching into
/// the tree is deliberate: the alternative would be a production `initialState:`
/// seam added for the canvas's benefit, and a preview does not get to change the
/// widget it reviews.
class _LogoutDeleteConfirmSheetAutoConfirm extends StatefulWidget {
  const _LogoutDeleteConfirmSheetAutoConfirm({
    required this.buttonKey,
    required this.child,
  });

  /// Key of the [OmdsLoadingButton] to fire (`logout-confirm-cta` /
  /// `delete-confirm-cta`).
  final Key buttonKey;

  final Widget child;

  @override
  State<_LogoutDeleteConfirmSheetAutoConfirm> createState() =>
      _LogoutDeleteConfirmSheetAutoConfirmState();
}

class _LogoutDeleteConfirmSheetAutoConfirmState
    extends State<_LogoutDeleteConfirmSheetAutoConfirm> {
  @override
  void initState() {
    super.initState();
    // Post-frame, because the button has to exist before it can be found — the
    // same sequencing the modal previews in the sibling widgets use.
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

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// The width pin is load-bearing: the render tests pump an 800 px viewport and
/// ignore [JeebPreview.size], so without it CI would be reviewing a bottom sheet
/// at a width no phone has. Bottom anchoring reproduces the real geometry: the
/// sheet grows upward from the bottom edge and, past the box, overflows at the
/// bottom of its own [Column] exactly as it does on a phone.
Widget _logoutDeleteConfirmSheetHosted(
  LogoutDeleteMode mode, {
  double width = 390,
  AccountSessionTerminator terminator =
      const _LogoutDeleteConfirmSheetInertTerminator(),
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
  return _LogoutDeleteConfirmSheetAutoConfirm(
    buttonKey: confirmKey,
    child: sheet,
  );
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
@JeebPreview(
  group: 'settings',
  name: 'Sign out',
  size: _logoutDeleteConfirmSheetBox,
)
Widget logoutDeleteConfirmSheetLogout() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.logout);

/// `LogoutDeleteMode.delete` — the irreversible half, and the longest copy the
/// sheet can render.
///
/// This body is the E20 / JEBV4-215 contract in prose: the account is
/// deactivated *now*, purged after [kAccountPurgeGraceDays] days, active orders
/// must be completed first, and signing in again before the purge reverses it.
/// Three sentences, 176 characters, and the reason the delete column of the
/// table above is the one that overflows. If the grace window ever drifts from
/// the gateway purge-worker SLA, this is where a reviewer sees the wrong number.
@JeebPreview(
  group: 'settings',
  name: 'Delete account',
  size: _logoutDeleteConfirmSheetDeleteBox,
)
Widget logoutDeleteConfirmSheetDelete() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.delete);

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
@JeebPreview(
  group: 'settings',
  name: 'Sign out + delete',
  size: _logoutDeleteConfirmSheetBothBox,
)
Widget logoutDeleteConfirmSheetBoth() =>
    _logoutDeleteConfirmSheetHosted(LogoutDeleteMode.both);

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
/// Reached by [_LogoutDeleteConfirmSheetAutoConfirm] firing the real
/// `logout-confirm-cta` on the first frame against
/// [_LogoutDeleteConfirmSheetHangingTerminator]; no production code is touched
/// to get here.
@JeebPreview(
  group: 'settings',
  name: 'Clearing session',
  size: _logoutDeleteConfirmSheetBothBox,
)
Widget logoutDeleteConfirmSheetInFlight() => _logoutDeleteConfirmSheetHosted(
      LogoutDeleteMode.both,
      terminator: const _LogoutDeleteConfirmSheetHangingTerminator(),
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
@JeebPreview(
  group: 'settings',
  name: 'Narrow phone · 320 pt',
  size: _logoutDeleteConfirmSheetNarrowBox,
)
Widget logoutDeleteConfirmSheetNarrowPhone() => _logoutDeleteConfirmSheetHosted(
      LogoutDeleteMode.both,
      width: _logoutDeleteConfirmSheetSmallPhoneWidth,
    );
