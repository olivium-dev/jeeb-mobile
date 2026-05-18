import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../application/notification_prefs_cubit.dart';
import '../domain/notification_prefs_model.dart';

/// Notification preferences screen.
///
/// Reads/writes [NotificationPrefs] from the screen-scoped
/// [NotificationPrefsCubit]. The two semantic groups — *Channels* (delivery
/// medium) and *Categories* (content type) — render as [OmdsSettingsSection]
/// blocks so they pick up the canonical OMDS section spacing, divider
/// behavior, and dark-mode parity.
class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(
        title: 'Notification Preferences',
        showBackButton: true,
      ),
      body: BlocBuilder<NotificationPrefsCubit, NotificationPrefs>(
        builder: (context, prefs) {
          final cubit = context.read<NotificationPrefsCubit>();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
            children: [
              _ChannelsSection(prefs: prefs, cubit: cubit),
              _CategoriesSection(prefs: prefs, cubit: cubit),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelsSection extends StatelessWidget {
  const _ChannelsSection({required this.prefs, required this.cubit});

  final NotificationPrefs prefs;
  final NotificationPrefsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return OmdsSettingsSection(
      title: 'Channels',
      children: [
        OmdsSettingsSwitchRow(
          title: 'Push Notifications',
          subtitle: 'Receive push notifications on this device',
          value: prefs.pushEnabled,
          onChanged: cubit.togglePush,
        ),
        OmdsSettingsSwitchRow(
          title: 'SMS',
          subtitle: 'Receive SMS notifications',
          value: prefs.smsEnabled,
          onChanged: cubit.toggleSms,
        ),
        OmdsSettingsSwitchRow(
          title: 'Email',
          subtitle: 'Receive email notifications',
          value: prefs.emailEnabled,
          onChanged: cubit.toggleEmail,
        ),
      ],
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.prefs, required this.cubit});

  final NotificationPrefs prefs;
  final NotificationPrefsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return OmdsSettingsSection(
      title: 'Categories',
      children: [
        OmdsSettingsSwitchRow(
          title: 'Delivery Updates',
          subtitle: 'Status changes for your deliveries',
          value: prefs.deliveryUpdates,
          onChanged: cubit.toggleDeliveryUpdates,
        ),
        OmdsSettingsSwitchRow(
          title: 'New Offers',
          subtitle: 'Get notified when offers arrive',
          value: prefs.offers,
          onChanged: cubit.toggleOffers,
        ),
        OmdsSettingsSwitchRow(
          title: 'Promotions',
          subtitle: 'Special offers and marketing updates',
          value: prefs.promotions,
          onChanged: cubit.togglePromotions,
        ),
      ],
    );
  }
}
