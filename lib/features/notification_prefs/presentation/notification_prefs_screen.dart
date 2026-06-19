import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

/// Notification Preferences (JM-058, blueprint `notification-prefs`).
///
/// Categories (D64): offers / order-status / wallet / marketing — each a
/// debounced PUT toggle. The transactional class is locked (always-on, shown as
/// a disabled row). A push-only note (R2) clarifies these are push-channel
/// preferences. Back → `customer-profile`.
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
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.notificationPreferencesTitle,
          leading: Semantics(
            identifier: 'notif_prefs_back',
            button: true,
            container: true,
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.kycWizardBack,
              onPressed: _onBack,
            ),
          ),
        ),
        body: BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
          listenWhen: _shouldListen,
          listener: _onSaveError,
          builder: _buildBody,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.notificationPrefsLoadError),
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'notif_prefs_retry_cta',
            button: true,
            container: true,
            child: OMDSOutlinedButton(
              text: l10n.notificationPrefsRetry,
              onTap: onRetry,
            ),
          ),
        ],
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      children: [
        const _PushOnlyNote(),
        _CategoriesSection(prefs: prefs, cubit: cubit),
        if (prefs.transactionalLocked) const _TransactionalLockedSection(),
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
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'notif_prefs_push_only_note',
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: Spacing.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: Sizes.medium,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              // l10n reuse (CTO-D R-F): generic "manage what you get notified
              // about" stands in for the push-only note until the dedicated key
              // lands (50_ROUTE_REQUESTS JM-058).
              child: Text(
                l10n.notificationPreferencesRowSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesCategoriesSection,
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
          // l10n reuse (CTO-D R-F): wallet title + generic subtitle until the
          // dedicated `notifPrefsWallet*` keys land (50_ROUTE_REQUESTS JM-058).
          title: l10n.walletHubTitle,
          subtitle: l10n.notificationPreferencesRowSubtitle,
          value: c.wallet,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.wallet, v),
        ),
        _CategoryRow(
          identifier: 'notif_prefs_marketing_toggle',
          // l10n reuse (CTO-D R-F): the offers-subtitle ("Discounts and seasonal
          // promotions") is the closest marketing copy; the offers row already
          // owns its title, so marketing reuses the rating-reminders title
          // getter as a neutral placeholder until the dedicated key lands.
          title: l10n.notificationCategoryRatingReminders,
          subtitle: l10n.notificationCategoryOffersSubtitle,
          value: c.marketing,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.marketing, v),
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
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesSecuritySection,
      children: [
        Semantics(
          // JM-058 AC2: the locked-transactional indicator. The flow asserts
          // `notif_prefs_transactional_lock_icon` (67_W34_TEST_PLAN coined id).
          identifier: 'notif_prefs_transactional_lock_icon',
          container: true,
          child: OmdsSettingsSwitchRow(
            // l10n reuse (CTO-D R-F): the OTP/security-codes row copy stands in
            // for the transactional-locked label until the dedicated key lands.
            title: l10n.notificationCategoryOtp,
            subtitle: l10n.notificationCategoryOtpAlwaysOn,
            value: true,
            enabled: false,
            // Disabled — the transactional class cannot be toggled off (D64).
            onChanged: null,
          ),
        ),
      ],
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
    return Semantics(
      identifier: identifier,
      toggled: value,
      container: true,
      child: OmdsSettingsSwitchRow(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
