import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

/// Trailing padlock on the locked transactional row — the neighbour screen 20
/// draws the same glyph at 17px on its always-on line (`tpl 1212`).
const double _kLockGlyphSize = 17;

/// Notification Preferences (JM-058, blueprint `notification-prefs`).
///
/// Categories (D64): offers / order-status / wallet / marketing — each a
/// debounced PUT toggle. The transactional class is locked (always-on, shown as
/// a non-interactive padlock row). A push-only note (R2) clarifies these are
/// push-channel preferences. Back → `customer-profile`.
///
/// redesign-2026-08: re-skinned onto the Jeeb design system against its
/// neighbour, screen 20 (Settings). Structure is unchanged — in-body
/// [JeebTopBar] instead of a Material app bar, [JeebInfoNote] for the note,
/// [JeebSectionLabel] + [JeebOutlinedCard.grouped] for each band, 24px gutters.
///
/// Exposed Semantics identifiers (JM-058 AC):
///   notif_prefs_root            — screen host (nav-honesty re-assert)
///   notif_prefs_offers_toggle
///   notif_prefs_order_status_toggle
///   notif_prefs_wallet_toggle
///   notif_prefs_marketing_toggle
///   notif_prefs_transactional_lock_icon — the locked always-on row indicator
///   notif_prefs_push_only_note  — the push-only channel note (R2)
///   notif_prefs_back            — app-bar back control → customer-profile
///
/// l10n NOTE (CTO-D R-F, requested in 50_ROUTE_REQUESTS.md JM-058): dedicated
/// copy for the wallet/marketing categories, the transactional-locked row, and
/// the push-only note does not exist in the ARB yet (ARB is integrator-owned).
/// This screen ships reusing the closest EXISTING locale-safe getters; Maestro
/// asserts on the identifiers above (never visible text), so this is copy-polish
/// only and the AC stays green.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationPrefsCubit>().load();
  }

  /// Back → customer-profile. Real entry is `goNamed('settings-notifications')`
  /// from the Profile tab (poppable → returns there); the named fallback only
  /// fires on a cold deep-link (mirrors `wallet_charge_info_screen` pattern).
  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('customer-profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'notif_prefs_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        // The redesign's header is a body row, not a Material app bar (§5 #1):
        // no elevation, no surface tint, Ø40 back circle + 20/w700 title.
        body: SafeArea(
          // The list reserves the nav-bar inset itself so the last row scrolls
          // clear of the soft buttons in edge-to-edge mode.
          bottom: false,
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.notificationPreferencesTitle,
                // FROZEN: the leading circle carries `notif_prefs_back`.
                identifier: 'notif_prefs_back',
                leadingTooltip: l10n.kycWizardBack,
                onLeadingPressed: _onBack,
              ),
              Expanded(
                child:
                    BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
                  listenWhen: _shouldListen,
                  listener: _onSaveError,
                  builder: _buildBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldListen(
    NotificationPrefsState prev,
    NotificationPrefsState curr,
  ) {
    return curr is NotificationPrefsLoaded &&
        curr.saveError &&
        (prev is! NotificationPrefsLoaded || !prev.saveError);
  }

  void _onSaveError(BuildContext context, NotificationPrefsState state) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.notificationPrefsSaveError);
    context.read<NotificationPrefsCubit>().acknowledgeError();
  }

  Widget _buildBody(BuildContext context, NotificationPrefsState state) {
    switch (state) {
      case NotificationPrefsLoading():
        return const Center(child: OmdsLoadingState());
      case NotificationPrefsError():
        return _ErrorView(onRetry: context.read<NotificationPrefsCubit>().load);
      case NotificationPrefsLoaded(:final prefs):
        return _PrefsBody(prefs: prefs);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.notificationPrefsLoadError,
              textAlign: TextAlign.center,
              style: context.jeebText.body.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'notif_prefs_retry_cta',
              button: true,
              container: true,
              child: JeebCtaButton.outline(
                label: l10n.notificationPrefsRetry,
                onTap: onRetry,
                expand: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefsBody extends StatelessWidget {
  const _PrefsBody({required this.prefs});

  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationPrefsCubit>();
    return ListView(
      // The board's 24px gutter, and the nav-bar inset so the last row clears
      // the soft buttons (see [BottomInsetX.scrollBodyBottomInset]).
      padding: EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        context.scrollBodyBottomInset,
      ),
      children: [
        const _PushOnlyNote(),
        const SizedBox(height: Spacing.medium),
        _CategoriesSection(prefs: prefs, cubit: cubit),
        if (prefs.transactionalLocked) ...[
          const SizedBox(height: Spacing.medium),
          const _TransactionalLockedSection(),
        ],
      ],
    );
  }
}

/// Push-only note (R2): every category here is a *push* preference.
class _PushOnlyNote extends StatelessWidget {
  const _PushOnlyNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebInfoNote.muted(
      icon: Icons.info,
      // l10n reuse (CTO-D R-F): generic "manage what you get notified about"
      // stands in for the push-only note until the dedicated key lands
      // (50_ROUTE_REQUESTS JM-058).
      text: l10n.notificationPreferencesRowSubtitle,
      identifier: 'notif_prefs_push_only_note',
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.prefs, required this.cubit});

  final NotificationPrefs prefs;
  final NotificationPrefsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = prefs.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.notificationPreferencesCategoriesSection),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            _CategoryRow(
              identifier: 'notif_prefs_offers_toggle',
              title: l10n.notificationCategoryOffers,
              subtitle: l10n.notificationCategoryOffersSubtitle,
              value: c.offers,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.offers, v),
            ),
            _CategoryRow(
              identifier: 'notif_prefs_order_status_toggle',
              title: l10n.notificationCategoryStatus,
              subtitle: l10n.notificationCategoryStatusSubtitle,
              value: c.orderStatus,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.orderStatus, v),
            ),
            _CategoryRow(
              identifier: 'notif_prefs_wallet_toggle',
              // Dedicated wallet-notification copy (F9): title + a wallet-specific
              // subtitle, not the page-header "manage what you get notified about".
              title: l10n.notificationCategoryWallet,
              subtitle: l10n.notificationCategoryWalletSubtitle,
              value: c.wallet,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.wallet, v),
            ),
            _CategoryRow(
              identifier: 'notif_prefs_marketing_toggle',
              // Surfaced as the rating-reminders category (D64 mapping): use the
              // dedicated rating-reminders subtitle, not the duplicated offers copy
              // ("Discounts and seasonal promotions") — F9.
              title: l10n.notificationCategoryRatingReminders,
              subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
              value: c.marketing,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.marketing, v),
            ),
          ],
        ),
      ],
    );
  }
}

/// The locked transactional class (D64) — always on, cannot be disabled.
class _TransactionalLockedSection extends StatelessWidget {
  const _TransactionalLockedSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.notificationPreferencesSecuritySection),
        const SizedBox(height: Spacing.xSmall),
        const JeebOutlinedCard.grouped(
          children: [_TransactionalLockedRow()],
        ),
      ],
    );
  }
}

/// The always-on transactional line. It is a *fact*, not a control, so — like
/// its neighbour on screen 20 — it renders as a plain row with a trailing
/// padlock rather than a switch nobody can move. Non-interactive by
/// construction: there is no `onTap` and no toggle to actuate.
class _TransactionalLockedRow extends StatelessWidget {
  const _TransactionalLockedRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = theme.extension<JeebSemanticColors>()!.mutedText;

    return Semantics(
      // JM-058 AC2: the locked-transactional indicator. The flow asserts
      // `notif_prefs_transactional_lock_icon` (67_W34_TEST_PLAN coined id).
      identifier: 'notif_prefs_transactional_lock_icon',
      container: true,
      child: Padding(
        padding: JeebOutlinedCard.defaultPadding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // l10n reuse (CTO-D R-F): the OTP/security-codes row copy
                  // stands in for the transactional-locked label until the
                  // dedicated key lands.
                  Text(
                    l10n.notificationCategoryOtp,
                    style: context.jeebText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: Spacing.twoXSmall),
                  Text(
                    l10n.notificationCategoryOtpAlwaysOn,
                    style: context.jeebText.bodySmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.small),
            // Periwinkle is decorative here (a glyph, not body ink) — the same
            // treatment screen 20 gives its always-on padlock.
            Icon(Icons.lock, size: _kLockGlyphSize, color: muted),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.identifier,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String identifier;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: identifier,
      toggled: value,
      container: true,
      // `SwitchListTile` paints its ink on the nearest Material ancestor and
      // asserts when a coloured box sits between the two — which the card's
      // fill does. A transparent Material inside the card is the documented fix.
      child: Material(
        type: MaterialType.transparency,
        child: OmdsSettingsSwitchRow(
          title: title,
          subtitle: subtitle,
          value: value,
          // OMDS defaults the knob to `colorScheme.primary` — i.e. a navy thumb
          // on a navy track. The board's knob is white (20 `tpl 1197`).
          activeColor: colorScheme.onPrimary,
          titleStyle: context.jeebText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          subtitleStyle: context.jeebText.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          // OMDS takes a non-directional inset; symmetric, so it mirrors as a
          // no-op under RTL. The grouped card draws the dividers.
          contentPadding:
              const EdgeInsets.symmetric(horizontal: Spacing.medium),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
