import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'widgets/delivery_man_profile_header.dart';
import 'widgets/delivery_reviews_header.dart';
import 'widgets/delivery_reviews_list.dart';


















class DeliveryManProfileScreen extends StatelessWidget {
  const DeliveryManProfileScreen({super.key, required this.data});

  
  
  static const String rootId = 'delivery_man_profile_screen_root';

  
  
  static const Key rootKey = Key('delivery-man-profile-screen-root');

  final DeliveryManProfileViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: rootId,
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: '',
          automaticallyImplyLeading: false,
          actions: [_CloseButton(label: l10n.deliveryManProfileCloseLabel)],
        ),
        body: _DeliveryManProfileBody(data: data),
      ),
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
        DeliveryReviewsHeader(
          reviewCount: data.reviewCount,
          onViewAll: () => _openAllReviews(context),
        ),
        
        DeliveryReviewsList(reviews: data.reviews),
      ],
    );
  }

  
  
  
  
  
  void _openAllReviews(BuildContext context) {
    final jeeberId = data.jeeberId;
    context.pushNamed(
      'reviews-list',
      queryParameters: {
        if (jeeberId != null && jeeberId.isNotEmpty) 'jeeberId': jeeberId,
      },
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
      isColdStart: data.isColdStart, 
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    
    return Semantics(
      identifier: 'profile_close',
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
