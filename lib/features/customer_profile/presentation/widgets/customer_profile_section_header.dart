import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';

/// Section header ("Account" / "Support"): navy, title-medium, guttered.
class CustomerProfileSectionHeader extends StatelessWidget {
  const CustomerProfileSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        Spacing.xSmall,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// The canvas box for one section header: phone width, one line of title plus
/// its 20/8 padding. Roomy enough that the `EN 200% text` rendering (which
const Size _customerProfileSectionHeaderHeaderBox = Size(390, 96);

/// Taller box: the states whose title wraps, and the multi-widget boundary.
const Size _customerProfileSectionHeaderTallBox = Size(390, 220);

/// The Account → Support boundary needs room for two rows plus the header.
const Size _customerProfileSectionHeaderBoundaryBox = Size(390, 260);

/// The narrowest device the app still supports.
/// Applied as a real [SizedBox] rather than by shrinking the canvas box,
const double _customerProfileSectionHeaderCompactPhoneWidth = 320;

/// Hosts [header] the way `CustomerProfileRows` really does — a [Column] with
/// `crossAxisAlignment.stretch`.
Widget _customerProfileSectionHeaderStretched(Widget header) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[header],
    );

/// The header, with its title resolved from the real ARB at build time.
Widget _customerProfileSectionHeaderHosted(
  String Function(AppLocalizations) title,
) =>
    _customerProfileSectionHeaderStretched(
      Builder(
        builder: (BuildContext context) => CustomerProfileSectionHeader(
          title: title(AppLocalizations.of(context)),
        ),
      ),
    );

/// The first of the two strings this widget ships with.
/// The `Account` header opens the profile's navigation list, so it is the
@JeebPreview(
  group: 'customer_profile',
  name: 'Account (production)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderAccount() =>
    _customerProfileSectionHeaderHosted(
      (AppLocalizations l10n) => l10n.customerProfileSectionAccount,
    );

/// The second shipping string, and the only other real caller.
/// Worth its own preview rather than being assumed identical to `Account`:
@JeebPreview(
  group: 'customer_profile',
  name: 'Support (production)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderSupport() =>
    _customerProfileSectionHeaderHosted(
      (AppLocalizations l10n) => l10n.customerProfileSectionSupport,
    );

/// The header in the only place it actually appears: the Account → Support
/// boundary of `CustomerProfileRows`, reproduced row for row.
@JeebPreview(
  group: 'customer_profile',
  name: 'Account → Support boundary',
  size: _customerProfileSectionHeaderBoundaryBox,
)
Widget customerProfileSectionHeaderBoundary() => Builder(
      builder: (BuildContext context) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The last row of the Account section.
            CustomerProfileRow(
              icon: Icons.location_on_outlined,
              label: l10n.savedAddressesTitle,
              semanticsId: 'customer_profile_addresses_row',
              onTap: () {},
            ),
            CustomerProfileSectionHeader(
              title: l10n.customerProfileSectionSupport,
            ),
            // The first row of the Support section.
            CustomerProfileRow(
              icon: Icons.call_outlined,
              label: l10n.customerProfileContactUs,
              semanticsId: 'customer_profile_contact_row',
              onTap: () {},
            ),
          ],
        );
      },
    );

/// The layout ceiling, built from real copy rather than an invented string.
/// `jeeberRequestDetailSectionDescription` ("What the client says" /
@JeebPreview(
  group: 'customer_profile',
  name: 'Longest ARB title, 320pt device',
  size: _customerProfileSectionHeaderTallBox,
)
Widget customerProfileSectionHeaderLongestTitleCompact() => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _customerProfileSectionHeaderCompactPhoneWidth,
        child: _customerProfileSectionHeaderHosted(
          (AppLocalizations l10n) => l10n.jeeberRequestDetailSectionDescription,
        ),
      ),
    );

/// The degenerate input: a title that is present but empty.
/// `title` is `required`, which only means "supplied" — nothing asserts it is
@JeebPreview(
  group: 'customer_profile',
  name: 'Empty title (invisible, still spaced)',
  size: _customerProfileSectionHeaderHeaderBox,
)
Widget customerProfileSectionHeaderEmptyTitle() =>
    _customerProfileSectionHeaderStretched(
      const CustomerProfileSectionHeader(title: ''),
    );
