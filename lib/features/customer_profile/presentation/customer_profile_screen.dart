import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/customer_profile_view_data.dart';
import 'widgets/customer_account_section.dart';
import 'widgets/customer_profile_header.dart';
import 'widgets/customer_support_section.dart';

/// Customer Profile screen (Figma 56581:1910, screen 18).
///
/// Reuse posture: this is a parity surface over the existing profile/settings
/// data (user-management + remote-user-preferences via the gateway) — see
/// reuse-table.md "Profile / Settings". It composes OMDS primitives
/// ([OMDSAppBar], settings rows, [OmdsProfileAvatar], [OmdsPrimaryButton])
/// rather than rebuilding anything raw.
///
/// Navigation callbacks default to gateway-backed routes that already exist
/// (`/register`, `/settings/notifications`, `/location`); the support rows are
/// no-ops until those destinations land (parity capture only — backend
/// posture is documented in the evidence pack).
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key, required this.data});

  static const Key rootKey = Key('customer-profile-screen-root');

  final CustomerProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.customerProfileTitle,
        showBackButton: true,
        onBackPressed: () => _back(context),
      ),
      body: _CustomerProfileBody(data: data),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _CustomerProfileBody extends StatelessWidget {
  const _CustomerProfileBody({required this.data});

  final CustomerProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: CustomerProfileScreen.rootKey,
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xLarge),
      children: [
        CustomerProfileHeader(
          name: data.name,
          email: data.email,
          avatarUrl: data.avatarUrl,
          isVerified: data.isVerified,
        ),
        CustomerAccountSection(
          showRegister: !data.isJeeber,
          onRegister: () => _go(context, '/register'),
          onPasswordSecurity: () => _go(context, '/settings'),
          onNotification: () => _go(context, '/settings/notifications'),
          onResetLocation: () => _go(context, '/location'),
        ),
        CustomerSupportSection(onContactUs: () {}, onRateApp: () {}),
      ],
    );
  }

  void _go(BuildContext context, String location) => context.go(location);
}
