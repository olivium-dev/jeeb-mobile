import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/role/role_cubit.dart';
import '../../../../core/role/user_role.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/role_switch_cubit.dart';

/// T-MOB-028: Settings section that surfaces the Active Role segmented toggle.
///
/// Visible only when both Client AND Jeeber roles appear in [availableRoles].
/// Calls [RoleSwitchCubit.switchTo] on selection change, then mirrors the
/// result to [RoleCubit] so the shell rebuilds to the correct home.
///
/// AC2: When the gateway returns 403 (KYC gate), shows an [OmdsDialog]
///   explaining the requirement and offering a "Start verification" CTA.
/// AC3: The toggle container is wrapped in a [Semantics] node announcing
///   'Active role: (role)'.
class RoleToggleSetting extends StatelessWidget {
  const RoleToggleSetting({
    super.key,
    required this.availableRoles,
    required this.cubit,
  });

  static const Key rootKey = Key('role-toggle-setting-root');
  static const Key clientSegmentKey = Key('role-toggle-setting-client');
  static const Key jeeberSegmentKey = Key('role-toggle-setting-jeeber');

  /// Available role identifiers for this user. When the list contains both
  /// 'client' and 'jeeber', the toggle is rendered; otherwise hidden.
  final List<String> availableRoles;

  /// Pre-wired cubit. Callers inject so widget tests can drive it without DI.
  final RoleSwitchCubit cubit;

  bool get _hasBothRoles =>
      availableRoles.contains('client') &&
      availableRoles.contains('jeeber');

  @override
  Widget build(BuildContext context) {
    if (!_hasBothRoles) return const SizedBox.shrink();
    return BlocProvider<RoleSwitchCubit>.value(
      value: cubit,
      child: const _RoleToggleSettingBody(),
    );
  }
}

class _RoleToggleSettingBody extends StatelessWidget {
  const _RoleToggleSettingBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoleSwitchCubit, RoleSwitchState>(
      listenWhen: _shouldListen,
      listener: _onStateChange,
      builder: _build,
    );
  }

  bool _shouldListen(RoleSwitchState prev, RoleSwitchState curr) =>
      prev.kycGated != curr.kycGated || prev.hasError != curr.hasError;

  Future<void> _onStateChange(
    BuildContext context,
    RoleSwitchState state,
  ) async {
    if (state.hasError) _showErrorSnackbar(context);
    if (state.kycGated) await _showKycDialog(context);
  }

  Widget _build(BuildContext context, RoleSwitchState state) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      key: RoleToggleSetting.rootKey,
      title: l10n.roleSettingTitle,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: _SegmentedToggle(state: state),
        ),
      ],
    );
  }

  Future<void> _showKycDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RoleSwitchCubit>();
    final router = GoRouter.maybeOf(context);
    final confirmed = await OmdsConfirmationDialog.show(
      context: context,
      title: l10n.roleSettingKycGateTitle,
      content: l10n.roleSettingKycGateBody,
      confirmText: l10n.roleSettingKycGateCta,
      cancelText: l10n.roleSettingKycGateDismiss,
      isDestructive: false,
    );
    cubit.clearKycGate();
    if (confirmed) router?.goNamed('kyc-status');
  }

  void _showErrorSnackbar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.roleSettingSwitchError);
    context.read<RoleSwitchCubit>().clearError();
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.state});

  final RoleSwitchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeRole = state.activeRole;
    return Semantics(
      label: l10n.roleSettingSemanticLabel(activeRole),
      container: true,
      child: _ToggleRow(state: state, l10n: l10n),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.state, required this.l10n});

  final RoleSwitchState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return OmdsFilterChips<String>(
      filters: [
        OmdsFilterOption<String>(
          label: l10n.roleSettingClient,
          value: 'client',
        ),
        OmdsFilterOption<String>(
          label: l10n.roleSettingJeeber,
          value: 'jeeber',
        ),
      ],
      selectedValue: state.activeRole,
      onFilterChanged: (role) {
        if (state.isInFlight) return;
        _onChanged(context, role);
      },
      showCounts: false,
    );
  }

  void _onChanged(BuildContext context, String? role) {
    if (role == null) return;
    final cubit = context.read<RoleSwitchCubit>();
    final roleCubit = context.read<RoleCubit>();
    _switchRole(cubit, roleCubit, role);
  }

  Future<void> _switchRole(
    RoleSwitchCubit cubit,
    RoleCubit roleCubit,
    String role,
  ) async {
    await cubit.switchTo(role);
    if (cubit.state.activeRole == role) {
      final userRole = role == 'jeeber' ? UserRole.jeeber : UserRole.client;
      await roleCubit.setRole(userRole);
    }
  }
}
