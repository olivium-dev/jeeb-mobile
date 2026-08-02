import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/wallet_charge_info_screen_fixtures.dart';

class WalletChargeInfoScreen extends StatelessWidget {
  const WalletChargeInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'charge_info_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.chargeInfoTitle,
          showBackButton: true,
          onBackPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('wallet'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            _Step(
              index: 1,
              id: 'charge_info_store_step',
              text: l10n.chargeInfoStoreStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 2,
              id: 'charge_info_identity_step',
              text: l10n.chargeInfoIdentityStep,
            ),
            const SizedBox(height: Spacing.medium),
            _Step(
              index: 3,
              id: 'charge_info_pay_cash_step',
              text: l10n.chargeInfoPayCashStep,
            ),
            const SizedBox(height: Spacing.xLarge),

            _Note(
              id: 'charge_info_auto_update_note',
              icon: Icons.sync_outlined,
              text: l10n.chargeInfoAutoUpdateNote,
            ),
            const SizedBox(height: Spacing.small),

            _Note(
              id: 'charge_info_fee_note',
              icon: Icons.percent_outlined,
              text: l10n.chargeInfoFeeNote,
            ),
            const SizedBox(height: Spacing.twoXLarge),

            Semantics(
              identifier: 'charge_info_back_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.chargeInfoBackCta,
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.goNamed('wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.id, required this.text});

  final int index;
  final String id;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: Sizes.xLarge,
            height: Sizes.xLarge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.id, required this.icon, required this.text});

  final String id;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      identifier: id,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Sizes.large, color: color),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size walletChargeInfoScreenPhoneBox = Size(390, 844);

/// The smallest phone the app supports (iPhone SE 1st gen / small Androids).
const Size walletChargeInfoScreenCompactBox = Size(320, 568);

/// Hosts the screen on the stack named by [entry], optionally at [textScale]
Widget _walletChargeInfoScreenHosted({
  WalletChargeInfoScreenEntry entry = WalletChargeInfoScreenEntry.standalone,
  double textScale = 1,
  bool arabic = false,
}) {
  final Widget hosted = WalletChargeInfoScreenHost(
    entry: entry,
    screen: const WalletChargeInfoScreen(),
  );
  final Widget scaled = textScale == 1
      ? hosted
      : Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: hosted,
          ),
        );
  if (!arabic) return scaled;
  return Builder(
    builder: (BuildContext context) => Localizations.override(
      context: context,
      locale: const Locale('ar'),
      child: Directionality(textDirection: TextDirection.rtl, child: scaled),
    ),
  );
}

/// The state every user actually reaches: the screen as the root of its own
@JeebPreview(
  group: 'wallet',
  name: 'Standalone · back → wallet-hub',
  size: walletChargeInfoScreenPhoneBox,
  matrix: true,
)
Widget walletChargeInfoScreenStandalone() => _walletChargeInfoScreenHosted();

/// The other half of the screen's written contract: pushed ON TOP of the
@JeebPreview(
  group: 'wallet',
  name: 'Pushed by a + Top up caller',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenPushedFromTopUp() => _walletChargeInfoScreenHosted(
      entry: WalletChargeInfoScreenEntry.pushedOnCaller,
    );

/// The floor: a 320x568 phone at normal text size, and the card that shows the
@JeebPreview(
  group: 'wallet',
  name: 'Compact 320x568',
  size: walletChargeInfoScreenCompactBox,
)
Widget walletChargeInfoScreenCompact() => _walletChargeInfoScreenHosted();

/// The accessibility ceiling: 200% text on a full-size phone.
@JeebPreview(
  group: 'wallet',
  name: 'EN · 200% text',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenLargeText() =>
    _walletChargeInfoScreenHosted(textScale: 2);

/// The combination the standard matrix cannot render: Arabic AND 200% text.
@JeebPreview(
  group: 'wallet',
  name: 'AR · 200% text',
  size: walletChargeInfoScreenPhoneBox,
)
Widget walletChargeInfoScreenArabicLargeText() =>
    _walletChargeInfoScreenHosted(textScale: 2, arabic: true);
