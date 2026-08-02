import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({super.key, required this.onExtend});

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return Container(
      key: rootKey,
      margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: roles.warningContainer,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(color: roles.warning),
      ),
      child: _BannerBody(onExtend: onExtend),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BannerHeader(),
        const SizedBox(height: Spacing.xSmall),
        const _BannerDescription(),
        const SizedBox(height: Spacing.small),
        _BannerCta(onExtend: onExtend),
      ],
    );
  }
}

class _BannerHeader extends StatelessWidget {
  const _BannerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.access_time, color: context.jeebRoles.onWarningContainer),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            l10n.availabilityInactivityWarningTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.jeebRoles.onWarningContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerDescription extends StatelessWidget {
  const _BannerDescription();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityInactivityWarningBody,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: context.jeebRoles.onWarningContainer,
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({required this.onExtend});

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Semantics(
        identifier: 'availability_inactivity_extend_cta',
        container: true,
        button: true,
        child: OmdsPrimaryButton(
          key: InactivityWarningBanner.ctaKey,
          text: l10n.availabilityInactivityWarningCta,
          onTap: onExtend,
        ),
      ),
    );
  }
}
