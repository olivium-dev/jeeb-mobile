import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'customer_profile_row.dart';

class CustomerRegisterPill extends StatelessWidget {
  const CustomerRegisterPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: OmdsPrimaryButton(
        key: const Key('customer-profile-register-button'),
        text: AppLocalizations.of(context).customerProfileRegisterCta,
        onTap: onTap,
        height: Sizes.threeXLarge,
        borderRadius: OmdsBorderRadius.pill,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

const Size _customerRegisterPillRowBox = Size(390, 170);
const Size _customerRegisterPillNarrowRowBox = Size(320, 170);
const Size _customerRegisterPillTwoRowBox = Size(390, 230);
const double _customerRegisterPillPhoneWidth = 390;
const double _customerRegisterPillNarrowWidth = 320;

void _customerRegisterPillNoop() {}

Widget _customerRegisterPillHosted({
  required String caption,
  required Widget child,
  double width = _customerRegisterPillPhoneWidth,
}) =>
    _CustomerRegisterPillSpecimen(
      caption: caption,
      width: width,
      child: child,
    );

class _CustomerRegisterPillRegisterRow extends StatelessWidget {
  const _CustomerRegisterPillRegisterRow();

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.delivery_dining_outlined,
      label: AppLocalizations.of(context).customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      onTap: _customerRegisterPillNoop,
      trailing: const CustomerRegisterPill(onTap: _customerRegisterPillNoop),
    );
  }
}

class _CustomerRegisterPillPasswordRow extends StatelessWidget {
  const _CustomerRegisterPillPasswordRow();

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.lock_outline,
      label: AppLocalizations.of(context).customerProfilePasswordSecurity,
      semanticsId: 'customer_profile_password_row',
      onTap: _customerRegisterPillNoop,
    );
  }
}

class _CustomerRegisterPillSpecimen extends StatelessWidget {
  const _CustomerRegisterPillSpecimen({
    required this.caption,
    required this.width,
    required this.child,
  });

  final String caption;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: child,
              ),
              const SizedBox(height: Spacing.xSmall),
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill alone: intrinsic size (144.8 × 40 dp).
@JeebPreview(
  group: 'customer_profile',
  name: 'Pill alone',
  size: _customerRegisterPillRowBox,
)
Widget customerRegisterPillAlone() => _customerRegisterPillHosted(
      caption: 'Pill alone · hugs its label, 40 dp tall',
      child: const Padding(
        padding: EdgeInsets.all(Spacing.xSmall),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CustomerRegisterPill(onTap: _customerRegisterPillNoop),
          ],
        ),
      ),
    );

/// Production: Register as a delivery row.
@JeebPreview(
  group: 'customer_profile',
  name: 'In profile row',
  size: _customerRegisterPillRowBox,
)
Widget customerRegisterPillInRow() => _customerRegisterPillHosted(
      caption: 'In profile row · 390 dp',
      child: const _CustomerRegisterPillRegisterRow(),
    );

/// Narrowest phone: label ellipsizes first (320 dp).
@JeebPreview(
  group: 'customer_profile',
  name: 'Narrow phone',
  size: _customerRegisterPillNarrowRowBox,
)
Widget customerRegisterPillNarrowRow() => _customerRegisterPillHosted(
      caption: 'Narrow phone · 320 dp',
      width: _customerRegisterPillNarrowWidth,
      child: const _CustomerRegisterPillRegisterRow(),
    );

/// Beside chevron rows: alignment and visual weight.
@JeebPreview(
  group: 'customer_profile',
  name: 'Beside chevron rows',
  size: _customerRegisterPillTwoRowBox,
)
Widget customerRegisterPillBesideChevronRows() => _customerRegisterPillHosted(
      caption: 'Beside chevron rows · alignment + weight',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CustomerRegisterPillRegisterRow(),
          _CustomerRegisterPillPasswordRow(),
        ],
      ),
    );

/// Ceiling: 200% text, label fills pill (0 dp headroom).
@JeebPreview(
  group: 'customer_profile',
  name: 'Row at 200% text',
  size: _customerRegisterPillRowBox,
)
Widget customerRegisterPillRowAtLargeText() => _customerRegisterPillHosted(
      caption: 'Row at 200% text · pill stays 40 dp',
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 2.0,
        maxScaleFactor: 2.0,
        child: const _CustomerRegisterPillRegisterRow(),
      ),
    );

/// Defect: bounded parent expands pill to full width.
@JeebPreview(
  group: 'customer_profile',
  name: 'Bounded parent',
  size: _customerRegisterPillRowBox,
)
Widget customerRegisterPillInBoundedParent() => _customerRegisterPillHosted(
      caption: 'Bounded parent · stretches, no longer a pill',
      child: const Padding(
        padding: EdgeInsets.all(Spacing.xSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CustomerRegisterPill(onTap: _customerRegisterPillNoop),
          ],
        ),
      ),
    );
