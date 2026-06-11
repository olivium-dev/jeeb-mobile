import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'widgets/delivery_man_profile_header.dart';
import 'widgets/delivery_reviews_header.dart';
import 'widgets/delivery_reviews_list.dart';

/// Delivery Man public profile (Figma 56580:2697, screen 27).
///
/// A read-only profile of a Jeeber as seen by a client, presented modally
/// (close "X", no bottom nav). Identity header + a "Reviews" section.
/// Reuse posture: identity composes OMDS primitives; review cards reuse
/// [OmdsReviewCard] (reuse-table.md Ratings/Feedback → feedback-service).
/// Data is supplied by the caller (gateway aggregate); actions are wired but
/// no-op on the dev/mock backend (documented in the evidence pack).
class DeliveryManProfileScreen extends StatelessWidget {
  const DeliveryManProfileScreen({super.key, required this.data});

  static const Key rootKey = Key('delivery-man-profile-screen-root');

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: '',
        automaticallyImplyLeading: false,
        actions: [_CloseButton(label: l10n.deliveryManProfileCloseLabel)],
      ),
      body: _DeliveryManProfileBody(data: data),
    );
  }
}

class _DeliveryManProfileBody extends StatelessWidget {
  const _DeliveryManProfileBody({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: DeliveryManProfileScreen.rootKey,
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      children: [
        _Header(data: data),
        const SizedBox(height: Spacing.large),
        DeliveryReviewsHeader(reviewCount: data.reviewCount, onViewAll: () {}),
        DeliveryReviewsList(
          reviews: data.reviews,
          onHelpful: (_) {},
          onReply: (_) {},
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    return DeliveryManProfileHeader(
      name: data.name,
      avatarUrl: data.avatarUrl,
      isVerified: data.isVerified,
      rating: data.rating,
      reviewCount: data.reviewCount,
      location: data.location,
      isAvailable: data.isAvailable,
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delivery_man_profile_close',
      button: true,
      label: label,
      child: IconButton(
        key: const Key('delivery-man-profile-close'),
        icon: const Icon(Icons.close),
        tooltip: label,
        color: Theme.of(context).colorScheme.secondaryContainer,
        onPressed: () => _close(context),
      ),
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}
