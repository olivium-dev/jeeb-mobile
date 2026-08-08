import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/role/role_availability_cubit.dart';
import '../../../../core/role/role_cubit.dart';
import '../../../../core/role/role_sync.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_cubit.dart';
import 'unregister_jeeber_confirm_sheet.dart';

/// F3: the role-gated sibling of [SettingsBecomeJeeberCard] — shown only to
/// an already-registered jeeber (see `_SettingsBody`'s role gate), never
/// both at once.
///
/// After a successful (or already-not-a-jeeber) unregister, fires the same
/// [RoleSync] reconciliation `kyc_status_view.dart`'s post-activation refresh
/// does, so `RoleAvailabilityCubit`/`RoleCubit` — and the FCM background
/// isolate's persisted audience snapshot — catch up with no re-login.
class SettingsUnregisterJeeberRow extends StatelessWidget {
  const SettingsUnregisterJeeberRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebListRow(
      key: const Key('settings-row-unregister-jeeber'),
      identifier: 'settings_unregister_jeeber',
      icon: Icons.person_remove,
      title: l10n.settingsUnregisterJeeberTitle,
      titleStyle: context.jeebText.body.copyWith(fontWeight: FontWeight.w600),
      onTap: () => _openConfirm(context),
    );
  }

  Future<void> _openConfirm(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final roleCubit = context.read<RoleCubit?>();
    final availabilityCubit = context.read<RoleAvailabilityCubit?>();
    await UnregisterJeeberConfirmSheet.show(context, cubit: cubit);
    if (!cubit.state.jeeberUnregistered) return;
    if (roleCubit == null || availabilityCubit == null) return;
    unawaited(
      RoleSync(roleCubit: roleCubit, availabilityCubit: availabilityCubit)
          .sync(),
    );
  }
}
