import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

/// Notification Preferences screen (JM-058).
/// Categories: offers, order-status, wallet, marketing (debounced PUT toggles).
/// Transactional class locked (always-on). Push-channel preferences only.
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
        appBar: OMDSAppBar(
          title: l10n.notificationPreferencesTitle,
          leading: Semantics(
            identifier: 'notif_prefs_back',
            button: true,
            container: true,
            child: IconButton(
              icon: Icon(DirectionalIcons.back(context)),
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

/// Push-only note (R2).
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
          title: l10n.notificationCategoryWallet,
          subtitle: l10n.notificationCategoryWalletSubtitle,
          value: c.wallet,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.wallet, v),
        ),
        _CategoryRow(
          identifier: 'notif_prefs_marketing_toggle',
          title: l10n.notificationCategoryRatingReminders,
          subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
          value: c.marketing,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.marketing, v),
        ),
      ],
    );
  }
}

/// Locked transactional class (D64): always-on, cannot be disabled.
class _TransactionalLockedSection extends StatelessWidget {
  const _TransactionalLockedSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesSecuritySection,
      children: [
        Semantics(
          identifier: 'notif_prefs_transactional_lock_icon',
          container: true,
          child: OmdsSettingsSwitchRow(
            title: l10n.notificationCategoryOtp,
            subtitle: l10n.notificationCategoryOtpAlwaysOn,
            value: true,
            enabled: false,
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
