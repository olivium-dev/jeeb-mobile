import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: OmdsEmptyState(
        key: const Key('orders-tab-empty'),
        icon: Icons.receipt_long_outlined,
        title: l10n.ordersTitle,
        subtitle: l10n.ordersEmpty,
      ),
    );
  }
}
