import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../role_cubit.dart';
import '../role_eligibility.dart';
import '../role_eligibility_cubit.dart';
import '../user_role.dart';

/// Segmented Client ↔ Jeeber pill, shown in the home header.
///
/// Behavior:
/// - Tapping the segment opposite the active role asks the [RoleCubit] to
///   switch, which causes the shell to rebuild its tab-set. The visual thumb
///   animates between segments in ~220 ms — well inside the AC budget of
///   "rebuild navigation in < 1 second".
/// - If [RoleEligibility.hasActiveDelivery] is true, the switch is blocked
///   and a snackbar explains why; the role does not change.
/// - If the user is on [UserRole.client] and KYC is not approved, tapping
///   Jeeber pops a dialog with an onboarding CTA that routes to the KYC
///   status screen instead of switching roles.
class RoleToggle extends StatelessWidget {
  const RoleToggle({super.key});

  static const Key rootKey = Key('role-toggle-root');
  static const Key clientSegmentKey = Key('role-toggle-segment-client');
  static const Key jeeberSegmentKey = Key('role-toggle-segment-jeeber');
  static const Key thumbKey = Key('role-toggle-thumb');
  static const Key kycDialogKey = Key('role-toggle-kyc-dialog');
  static const Key kycCtaKey = Key('role-toggle-kyc-cta');
  static const Key activeDeliverySnackbarKey =
      Key('role-toggle-active-delivery-snackbar');

  static const Duration _animDuration = Duration(milliseconds: 220);
  static const Curve _animCurve = Curves.easeInOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = context.watch<RoleCubit>().state;
    final eligibility = context.watch<RoleEligibilityCubit>().state;

    return Padding(
      key: rootKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.small,
      ),
      child: Semantics(
        container: true,
        label: l10n.roleToggleSemanticLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final segmentWidth = width / 2;
            return _Pill(
              animDuration: _animDuration,
              animCurve: _animCurve,
              thumbAlignment: role == UserRole.client
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              segmentWidth: segmentWidth,
              children: [
                _Segment(
                  key: clientSegmentKey,
                  label: l10n.settingsRoleClient,
                  selected: role == UserRole.client,
                  onTap: () => _onSegmentTap(
                    context,
                    target: UserRole.client,
                    current: role,
                    eligibility: eligibility,
                  ),
                ),
                _Segment(
                  key: jeeberSegmentKey,
                  label: l10n.settingsRoleJeeber,
                  selected: role == UserRole.jeeber,
                  onTap: () => _onSegmentTap(
                    context,
                    target: UserRole.jeeber,
                    current: role,
                    eligibility: eligibility,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onSegmentTap(
    BuildContext context, {
    required UserRole target,
    required UserRole current,
    required RoleEligibility eligibility,
  }) async {
    if (target == current) return;

    if (eligibility.hasActiveDelivery) {
      _showActiveDeliveryBlocked(context);
      return;
    }

    if (target == UserRole.jeeber && !eligibility.isJeeberKycApproved) {
      await _showKycPrompt(context);
      return;
    }

    await context.read<RoleCubit>().setRole(target);
  }

  void _showActiveDeliveryBlocked(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: activeDeliverySnackbarKey,
          content: Text(l10n.roleToggleActiveDeliveryBlocked),
        ),
      );
  }

  Future<void> _showKycPrompt(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.maybeOf(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: kycDialogKey,
          title: Text(l10n.roleToggleKycLockedTitle),
          content: Text(l10n.roleToggleKycLockedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.roleToggleKycLockedDismiss),
            ),
            FilledButton(
              key: kycCtaKey,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // GoRouter is the production navigator; widget tests that
                // mount RoleToggle without it still see the dialog and CTA.
                router?.goNamed('kyc-status');
              },
              child: Text(l10n.roleToggleKycLockedCta),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.animDuration,
    required this.animCurve,
    required this.thumbAlignment,
    required this.segmentWidth,
    required this.children,
  });

  final Duration animDuration;
  final Curve animCurve;
  final AlignmentGeometry thumbAlignment;
  final double segmentWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.large,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.twoXSmall),
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              AnimatedAlign(
                key: RoleToggle.thumbKey,
                alignment: thumbAlignment,
                duration: animDuration,
                curve: animCurve,
                child: Container(
                  width: segmentWidth - Spacing.twoXSmall * 2,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: OmdsBorderRadius.large,
                  ),
                ),
              ),
              Row(
                children: [for (final c in children) Expanded(child: c)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fg = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.large,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: RoleToggle._animDuration,
            curve: RoleToggle._animCurve,
            style: theme.textTheme.labelLarge!.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
