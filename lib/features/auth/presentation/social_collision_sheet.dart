import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// `social-collision-prompt` (JM-019, D22) — the email/method collision prompt.
///
/// Shown when an email is already registered via a *different* method than the
/// one the user just attempted: the sign-up flow gets a **409 `email_collision`**
/// from `POST /v1/auth/signup` (JM-008), or the social flow gets a 409 from
/// `POST /v1/auth/social` (JM-018). Per the verified W-1 FLOOR contract
/// (42_GUARDRAILS_MOCK), that 409 carries `{ email }`. This sheet is purely a
/// router/UX prompt — it has **no async surface of its own**, so it carries no
/// cubit/repository; the 409 detection that *triggers* it belongs to the
/// JM-008 / JM-018 cubits, which call [SocialCollisionSheet.show] on that path.
///
/// It is a **sheet, not a route** (40_GUARDRAILS_ARCH §5 — sheets are
/// `showModalBottomSheet`, not `GoRoute`s). Two exits, both per D22 +
/// 60_W0_TEST_PLAN §2.8 / Navigation Matrix:
///   - [continue (use password)] → `/login`  (the email exists; sign in with it)
///   - [use other email]         → sign-up   (`/sign-up`, start over with a
///                                             different email)
///
/// Semantics identifiers exposed (EXACT, 60_W0_TEST_PLAN §2.8):
///   - `social_collision_sheet`            — bottom-sheet root
///   - `social_collision_continue_cta`     — Continue (use password) → /login
///   - `social_collision_other_email_cta`  — Use other email → sign-up
class SocialCollisionSheet extends StatelessWidget {
  const SocialCollisionSheet({
    super.key,
    required this.onContinue,
    required this.onUseOtherEmail,
    this.email,
  });

  /// Fired when the user chooses to sign in with the existing email.
  final VoidCallback onContinue;

  /// Fired when the user chooses to start over with a different email.
  final VoidCallback onUseOtherEmail;

  /// The colliding email (from the 409 body), if the caller has it. Currently
  /// surfaced only to the body copy via the shared collision string; reserved
  /// for a future per-email message (key-polish request filed in
  /// 50_ROUTE_REQUESTS.md).
  final String? email;

  /// Opens the collision prompt over the current route with a dimmed scrim and
  /// the standard OMDS top-rounded sheet shape (matches
  /// `ConfirmDeliveryActionSheet`). The `continue`/`other-email` callbacks are
  /// wired by [show] so a single call site (the JM-008 / JM-018 cubit listener)
  /// gets the D22 navigation for free.
  ///
  /// Each handler pops the sheet FIRST, then navigates, so the destination's
  /// signature field (`login_email_field` / `signup_name_field`) is the only
  /// thing the Maestro flow (`jm-019-collision-prompt.yaml`) can see — the sheet
  /// never lingers over the target screen.
  static Future<void> show(BuildContext context, {String? email}) {
    final rootContext = context;
    final scrim = Theme.of(context)
        .colorScheme
        .onSecondaryContainer
        .withValues(alpha: UIConstants.opacityHigh);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => SocialCollisionSheet(
        email: email,
        // EDGE (21_NAV_PLAN §C, JM-019, D22): social_collision_continue_cta →
        // /login. Pop the sheet, then navigate on the originating route's
        // navigator so we land on the registered `login` route.
        onContinue: () {
          Navigator.of(sheetContext).pop();
          rootContext.goNamed('login');
        },
        // EDGE (21_NAV_PLAN §C, JM-019, D22): social_collision_other_email_cta →
        // sign-up (`/sign-up`).
        onUseOtherEmail: () {
          Navigator.of(sheetContext).pop();
          rootContext.goNamed('sign-up');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'social_collision_sheet',
      // explicitChildNodes keeps the drag handle, copy, and both CTAs as
      // independent, id-addressable semantics nodes instead of letting the
      // framework collapse them into this container node (matches the proven
      // ConfirmDeliveryActionSheet shape so Maestro can tap each CTA).
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
              const SizedBox(height: Spacing.twoXLarge),
              _CollisionMessage(message: l10n.signupEmailCollision),
              const SizedBox(height: Spacing.twoXLarge),
              // PRIMARY: Continue with this email → sign in (/login). Reuses the
              // login submit copy ("Sign in"); a dedicated string is requested
              // in 50_ROUTE_REQUESTS.md (KEY-REQUEST JM-019).
              _CollisionContinueCta(
                label: l10n.loginContinueCta,
                onTap: onContinue,
              ),
              const SizedBox(height: Spacing.small),
              // SECONDARY: Use a different email → sign-up. Reuses the
              // "Create an account" copy (`recoverSignupLink`) as the "start
              // over" action — same reuse the W0-B JM-008 engineer recorded in
              // 50_ROUTE_REQUESTS.md; a dedicated `socialCollisionOtherEmailCta`
              // string is requested there.
              _CollisionOtherEmailCta(
                label: l10n.recoverSignupLink,
                onTap: onUseOtherEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered M3 drag handle (32×4 pill) tinted with the brand primary — matches
/// the shared sheet handle styling used across the app's bottom sheets.
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

/// The collision explanation copy (D22): the email is already registered via a
/// different method.
class _CollisionMessage extends StatelessWidget {
  const _CollisionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Full-width primary CTA → /login. The `Semantics` node owns the tap action and
/// is an explicit `container`/`button` boundary (the proven
/// `confirm_delivery_confirm_button` shape) so Maestro taps a standalone,
/// id-addressable node rather than the inner button's bare gesture semantics.
class _CollisionContinueCta extends StatelessWidget {
  const _CollisionContinueCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'social_collision_continue_cta',
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          key: const Key('social-collision-continue-cta'),
          text: label,
          isLoading: false,
          onTap: onTap,
          backgroundColor: colorScheme.secondaryContainer,
          textColor: colorScheme.onPrimary,
          borderRadius: OmdsBorderRadius.uiSmall,
        ),
      ),
    );
  }
}

/// Full-width secondary CTA → sign-up. Outlined variant to read as the
/// lower-emphasis "start over" action next to the navy primary.
class _CollisionOtherEmailCta extends StatelessWidget {
  const _CollisionOtherEmailCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'social_collision_other_email_cta',
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: OMDSOutlinedButton(
          key: const Key('social-collision-other-email-cta'),
          text: label,
          onTap: onTap,
        ),
      ),
    );
  }
}
