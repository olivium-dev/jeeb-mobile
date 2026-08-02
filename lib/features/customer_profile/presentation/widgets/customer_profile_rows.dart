import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';
import 'customer_register_pill.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class CustomerProfileRows extends StatelessWidget {
  const CustomerProfileRows({
    super.key,
    required this.showRegister,
    required this.onRegisterDelivery,
    required this.onPassword,
    required this.onNotifications,
    required this.onLanguage,
    required this.onAddresses,
    required this.onContact,
    required this.onRateApp,
    required this.onLogout,
  });

  final bool showRegister;
  final VoidCallback onRegisterDelivery;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;
  final VoidCallback onLanguage;
  final VoidCallback onAddresses;
  final VoidCallback onContact;
  final VoidCallback onRateApp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionAccount),
        if (showRegister)
          CustomerProfileRow(
            icon: Icons.delivery_dining_outlined,
            label: l10n.customerProfileRegisterAsDelivery,
            semanticsId: 'customer_profile_register_delivery_row',
            onTap: onRegisterDelivery,
            trailing: CustomerRegisterPill(onTap: onRegisterDelivery),
          ),
        CustomerProfileRow(
          icon: Icons.lock_outline,
          label: l10n.customerProfilePasswordSecurity,
          semanticsId: 'customer_profile_password_row',
          onTap: onPassword,
        ),
        CustomerProfileRow(
          icon: Icons.notifications_none,
          label: l10n.customerProfileNotification,
          semanticsId: 'customer_profile_notifications_row',
          onTap: onNotifications,
        ),
        CustomerProfileRow(
          icon: Icons.language_outlined,
          label: l10n.settingsLanguage,
          semanticsId: 'customer_profile_language_row',
          onTap: onLanguage,
        ),
        CustomerProfileRow(
          icon: Icons.location_on_outlined,
          label: l10n.savedAddressesTitle,
          semanticsId: 'customer_profile_addresses_row',
          onTap: onAddresses,
        ),
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionSupport),
        CustomerProfileRow(
          icon: Icons.call_outlined,
          label: l10n.customerProfileContactUs,
          semanticsId: 'customer_profile_contact_row',
          onTap: onContact,
        ),
        CustomerProfileRow(
          icon: Icons.star_outline,
          label: l10n.customerProfileRateApp,
          semanticsId: 'customer_profile_rate_app_row',
          onTap: onRateApp,
        ),
        CustomerProfileRow(
          icon: Icons.logout_outlined,
          label: l10n.appBarSignOut,
          semanticsId: 'customer_profile_logout_row',
          onTap: onLogout,
        ),
      ],
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [CustomerProfileRows] — run with

/// A typical phone — the width the profile rows are designed against.
const double _customerProfileRowsPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen and the
/// small Android estate). The register row's label is what pays for it.
const double _customerProfileRowsNarrowPhoneWidth = 320;

/// Canvas boxes. Tall enough to show the whole column without scrolling at the
/// scale each state pins.
const Size _customerProfileRowsPhoneBox =
    Size(_customerProfileRowsPhoneWidth, 600);
const Size _customerProfileRowsJeeberBox =
    Size(_customerProfileRowsPhoneWidth, 540);
const Size _customerProfileRowsNarrowBox =
    Size(_customerProfileRowsNarrowPhoneWidth, 600);
const Size _customerProfileRowsLargeTextBox =
    Size(_customerProfileRowsPhoneWidth, 640);
const Size _customerProfileRowsNarrowLargeTextBox =
    Size(_customerProfileRowsNarrowPhoneWidth, 600);

/// One set of rows, wired the way `CustomerProfileScreen._Body` wires it.
/// The eight callbacks are deliberately inert: navigation belongs to the
Widget _customerProfileRowsHosted({
  required bool showRegister,
  double width = _customerProfileRowsPhoneWidth,
  double? textScale,
}) {
  final Widget rows = CustomerProfileRows(
    showRegister: showRegister,
    onRegisterDelivery: () {},
    onPassword: () {},
    onNotifications: () {},
    onLanguage: () {},
    onAddresses: () {},
    onContact: () {},
    onRateApp: () {},
    onLogout: () {},
  );

  final Widget sized = Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      // Mirrors the live ListView parent: vertical growth scrolls, it does not
      child: SingleChildScrollView(child: rows),
    ),
  );

  if (textScale == null) return sized;
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: sized,
    ),
  );
}

/// The default surface: a customer who is not yet a Jeeber.
/// Eight rows under two section headers, and the only state in which the
@JeebPreview(
  group: 'customer_profile',
  name: 'Client · 390',
  size: _customerProfileRowsPhoneBox,
)
Widget customerProfileRowsClient() =>
    _customerProfileRowsHosted(showRegister: true);

/// JM-035 AC2 / design §8.2, made visible: once the account is already a
/// Jeeber, the register row must disappear **entirely** — not grey out, not
@JeebPreview(
  group: 'customer_profile',
  name: 'Jeeber · register hidden',
  size: _customerProfileRowsJeeberBox,
)
Widget customerProfileRowsJeeber() =>
    _customerProfileRowsHosted(showRegister: false);

/// Layout ceiling, part 1: the same client rows on a 320 pt phone.
/// The row spends a fixed 24 pt of padding per side, a 32 pt icon disc and an
@JeebPreview(
  group: 'customer_profile',
  name: 'Narrow 320',
  size: _customerProfileRowsNarrowBox,
)
Widget customerProfileRowsNarrowPhone() => _customerProfileRowsHosted(
      showRegister: true,
      width: _customerProfileRowsNarrowPhoneWidth,
    );

/// Layout ceiling, part 2: phone width at the 200% accessibility ceiling, with
/// the scale pinned so a widget test reproduces it.
@JeebPreview(
  group: 'customer_profile',
  name: '200% text · 390',
  size: _customerProfileRowsLargeTextBox,
)
Widget customerProfileRowsLargeText() =>
    _customerProfileRowsHosted(showRegister: true, textScale: 2.0);

/// The control for [customerProfileRowsNarrowPhone]: worst width AND worst text
/// scale, but for a Jeeber.
@JeebPreview(
  group: 'customer_profile',
  name: 'Jeeber narrow · 200% text',
  size: _customerProfileRowsNarrowLargeTextBox,
)
Widget customerProfileRowsJeeberNarrowLargeText() => _customerProfileRowsHosted(
      showRegister: false,
      width: _customerProfileRowsNarrowPhoneWidth,
      textScale: 2.0,
    );
