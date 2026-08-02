import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/notification_prefs_screen_fixtures.dart';
import '../domain/notification_prefs_repository.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _notificationPrefsScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _notificationPrefsScreenCompactCanvas = Size(332, 612);

/// Every state is the same screen behind the same app bar, differing only in
/// the fake repository its cubit is built on — so each one names itself.
Widget _notificationPrefsScreenHosted(
  NotificationPreferencesScreenFakeRepository repository, {
  required String caption,
  NotificationPreferencesScreenWindow window =
      NotificationPreferencesScreenWindows.phone,
}) =>
    NotificationPreferencesScreenPreviewHost(
      window: window,
      caption: caption,
      screen: notificationPrefsScreenSeeded(
        repository: repository,
        child: const NotificationPrefsScreen(),
      ),
    );

/// Cold start: `GET /v1/notifications/preferences` is on the wire.
/// The cubit is constructed in `NotificationPrefsLoading` and `initState` calls
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loading',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenLoading() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenPendingRepository(),
      caption: 'NotifPrefs · Loading · phone 390 × 844',
    );

/// The happy path, and the exact snapshot the Screen Catalog's `Loaded` state
/// has always shown: offers and order status on, wallet and marketing off,
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · catalog defaults',
  size: _notificationPrefsScreenPhoneCanvas,
  matrix: true,
)
Widget notificationPrefsScreenLoaded() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
      ),
      caption: 'NotifPrefs · Loaded · catalog defaults · phone 390 × 844',
    );

/// Everything the user is allowed to turn off, turned off.
/// The nearest thing this screen has to an EMPTY state — there is no list to be
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · everything off',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenAllOff() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenAllOffPrefs,
      ),
      caption: 'NotifPrefs · Everything off · phone 390 × 844',
    );

/// The initial fetch failed with a typed `network` failure.
/// The cubit classified it — `NotificationPrefsFailureView.network` — and
@JeebPreview(
  group: 'notification_prefs',
  name: 'Error · fetch failed',
  size: _notificationPrefsScreenPhoneCanvas,
  matrix: true,
)
Widget notificationPrefsScreenError() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        fetchFailure: NotificationPrefsFailure.network,
      ),
      caption: 'NotifPrefs · Error · fetch failed · phone 390 × 844',
    );

/// Loaded, but the next PATCH will fail — the D30 optimistic-revert path.
/// Identical to `Loaded · catalog defaults` until you touch it, which is the
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · the save will fail',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenSaveFails() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
        saveFailure: NotificationPrefsFailure.network,
      ),
      caption: 'NotifPrefs · Save will fail · phone 390 × 844',
    );

/// `transactionalLocked: false` — the branch `_PrefsBody` guards and the
/// gateway cannot currently produce.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · transactional unlocked',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenTransactionalUnlocked() =>
    _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenUnlockedPrefs,
      ),
      caption: 'NotifPrefs · Transactional unlocked · phone 390 × 844',
    );

/// The longest this screen's content ever gets: the smallest display AND the
/// largest text.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · compact · 200% text',
  size: _notificationPrefsScreenCompactCanvas,
)
Widget notificationPrefsScreenCompactLargeText() =>
    _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
      ),
      caption: 'NotifPrefs · Longest content · compact 320 × 568 · 200% text',
      window: NotificationPreferencesScreenWindows.compactLargeText,
    );
