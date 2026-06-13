import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

/// Notification preferences screen — profile → notifications.
///
/// Lists per-topic toggles (offers, chat, status-changes, rating-reminders).
/// Each toggle optimistically updates then debounced-PATCHes the gateway.
/// On PATCH failure the toggle reverts and a snackbar is shown (AC2).
/// AlwaysOn topics (otp, system_critical) are shown as disabled rows (AC3).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(
        title: AppLocalizations.of(context).notificationPreferencesTitle,
        showBackButton: true,
      ),
      body: BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
        listenWhen: _shouldListen,
        listener: _onSaveError,
        builder: _buildBody,
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
    if (state is NotificationPrefsLoading) {
      return const Center(child: OmdsLoadingState());
    }
    if (state is NotificationPrefsError) {
      return _ErrorView(onRetry: context.read<NotificationPrefsCubit>().load);
    }
    if (state is NotificationPrefsLoaded) {
      return _PrefsBody(prefs: state.prefs);
    }
    return const SizedBox.shrink();
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
          OMDSOutlinedButton(
            text: l10n.notificationPrefsRetry,
            onTap: onRetry,
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      children: [
        _TopicsSection(prefs: prefs, cubit: cubit),
        _AlwaysOnSection(alwaysOn: prefs.alwaysOn),
      ],
    );
  }
}

class _TopicsSection extends StatelessWidget {
  const _TopicsSection({required this.prefs, required this.cubit});

  final NotificationPrefs prefs;
  final NotificationPrefsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesCategoriesSection,
      children: [
        _TopicRow(
          semanticLabel: l10n.notificationTopicOffersSemanticLabel,
          title: l10n.notificationCategoryOffers,
          subtitle: l10n.notificationCategoryOffersSubtitle,
          value: prefs.preferences.offers,
          onChanged: (v) => cubit.toggleTopic('offers', v),
        ),
        _TopicRow(
          semanticLabel: l10n.notificationTopicChatSemanticLabel,
          title: l10n.notificationCategoryChat,
          subtitle: l10n.notificationCategoryChatSubtitle,
          value: prefs.preferences.chat,
          onChanged: (v) => cubit.toggleTopic('chat', v),
        ),
        _TopicRow(
          semanticLabel: l10n.notificationTopicStatusChangesSemanticLabel,
          title: l10n.notificationCategoryStatus,
          subtitle: l10n.notificationCategoryStatusSubtitle,
          value: prefs.preferences.statusChanges,
          onChanged: (v) => cubit.toggleTopic('statusChanges', v),
        ),
        _TopicRow(
          semanticLabel: l10n.notificationTopicRatingRemindersSemanticLabel,
          title: l10n.notificationCategoryRatingReminders,
          subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
          value: prefs.preferences.ratingReminders,
          onChanged: (v) => cubit.toggleTopic('ratingReminders', v),
        ),
      ],
    );
  }
}

class _AlwaysOnSection extends StatelessWidget {
  const _AlwaysOnSection({required this.alwaysOn});

  final List<String> alwaysOn;

  @override
  Widget build(BuildContext context) {
    if (alwaysOn.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesSecuritySection,
      children: [
        OmdsSettingsSwitchRow(
          title: l10n.notificationCategoryOtp,
          subtitle: l10n.notificationCategoryOtpAlwaysOn,
          value: true,
          // Disabled — always on per gateway contract.
          onChanged: null,
        ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.semanticLabel,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String semanticLabel;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: OmdsSettingsSwitchRow(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
