import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/directional_icons.dart';
import 'customer_profile_icon_disc.dart';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';
import 'customer_register_pill.dart';

class CustomerProfileRow extends StatelessWidget {
  const CustomerProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsId,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String semanticsId;
  final VoidCallback onTap;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsId,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.fiveXLarge),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.xLarge,
              vertical: Spacing.xSmall,
            ),
            child: _RowContent(icon: icon, label: label, trailing: trailing),
          ),
        ),
      ),
    );
  }
}

class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CustomerProfileIconDisc(icon: icon),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing ?? _Chevron(color: theme.colorScheme.outline),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      DirectionalIcons.disclosureIos(context),
      size: Sizes.medium,
      color: color,
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
const Size _customerProfileRowRowBox = Size(390, 88);

const Size _customerProfileRowNarrowBox = Size(320, 128);

const String _customerProfileRowNarrowPhoneCaption = 'Narrow phone · 320dp';

const String _customerProfileRowLongLabelText =
    'Password, security and two-factor authentication settings';

const String _customerProfileRowLongArabicLabelText =
    'إعدادات كلمة المرور والأمان والمصادقة الثنائية للحساب';

Widget _customerProfileRowHosted({
  required IconData icon,
  required String Function(AppLocalizations l10n) label,
  required String semanticsId,
  Widget? trailing,
  double? width,
}) {
  final Widget row = Builder(
    builder: (BuildContext context) => CustomerProfileRow(
      icon: icon,
      label: label(AppLocalizations.of(context)),
      semanticsId: semanticsId,
      onTap: () {},
      trailing: trailing,
    ),
  );
  if (width == null) return row;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: row),
  );
}

@JeebPreview(
  group: 'customer_profile',
  name: 'Chevron row · localized',
  size: _customerProfileRowRowBox,
)
Widget customerProfileRowDefault() => _customerProfileRowHosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations l10n) => l10n.customerProfilePasswordSecurity,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

@JeebPreview(
  group: 'customer_profile',
  name: 'Register pill trailing',
  size: _customerProfileRowRowBox,
)
Widget customerProfileRowRegisterPill() => _customerProfileRowHosted(
      icon: Icons.delivery_dining_outlined,
      label: (AppLocalizations l10n) => l10n.customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      trailing: CustomerRegisterPill(onTap: () {}),
      width: 390,
    );

@JeebPreview(
  group: 'customer_profile',
  name: 'Long label truncates',
  size: _customerProfileRowRowBox,
)
Widget customerProfileRowLongLabel() => _customerProfileRowHosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations _) => _customerProfileRowLongLabelText,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

@JeebPreview(
  group: 'customer_profile',
  name: 'Long Arabic label truncates',
  size: _customerProfileRowRowBox,
)
Widget customerProfileRowLongArabicLabel() => _customerProfileRowHosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations _) => _customerProfileRowLongArabicLabelText,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

@JeebPreview(
  group: 'customer_profile',
  name: 'Narrow phone · pill squeeze',
  size: _customerProfileRowNarrowBox,
)
Widget customerProfileRowNarrowPhone() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _customerProfileRowHosted(
          icon: Icons.delivery_dining_outlined,
          label: (AppLocalizations l10n) =>
              l10n.customerProfileRegisterAsDelivery,
          semanticsId: 'customer_profile_register_delivery_row',
          trailing: CustomerRegisterPill(onTap: () {}),
          width: 320,
        ),
        const SizedBox(height: Spacing.xSmall),
        Builder(
          builder: (BuildContext context) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.xLarge,
            ),
            child: Text(
              _customerProfileRowNarrowPhoneCaption,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );

@JeebPreview(
  group: 'customer_profile',
  name: 'Sign out · destructive',
  size: _customerProfileRowRowBox,
)
Widget customerProfileRowSignOut() => _customerProfileRowHosted(
      icon: Icons.logout_outlined,
      label: (AppLocalizations l10n) => l10n.appBarSignOut,
      semanticsId: 'customer_profile_logout_row',
      width: 390,
    );
