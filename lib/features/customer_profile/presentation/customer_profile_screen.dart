import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../rate_app/domain/app_review_launcher.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/customer_profile_cubit.dart';
import '../application/customer_profile_state.dart';
import '../data/dio_customer_profile_repository.dart';
import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';
import 'widgets/customer_profile_header.dart';
import 'widgets/customer_profile_rows.dart';

/// Customer Profile tab body (JM-035). Tab surface shared by client+jeeber;
/// header actions (wallet chip, bell) and no app bar (is tab body, not route).
/// Data seeded from caller, then cubit refreshes via GET /user-management/users/me.
/// Some rows are guarded coming-soon (password-security, language-settings, etc).
/// Rate-app row launches OS store-review sheet via [AppReviewLauncher].
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({
    super.key,
    required this.data,
    this.repository,
    this.reviewLauncher,
  });

  static const Key rootKey = Key('customer-profile-screen-root');

  final CustomerProfileViewData data;

  final CustomerProfileRepository? repository;

  final AppReviewLauncher? reviewLauncher;

  CustomerProfileRepository? _resolveRepository() {
    if (repository != null) return repository;
    if (sl.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(sl<Dio>());
    }
    return null;
  }

  AppReviewLauncher _resolveReviewLauncher() {
    if (reviewLauncher != null) return reviewLauncher!;
    if (sl.isRegistered<AppReviewLauncher>()) {
      return sl<AppReviewLauncher>();
    }
    return const NoopAppReviewLauncher();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CustomerProfileCubit>(
      create: (_) => CustomerProfileCubit(
        seed: data,
        repository: _resolveRepository(),
      )..load(),
      child: _CustomerProfileView(reviewLauncher: _resolveReviewLauncher()),
    );
  }
}

class _CustomerProfileView extends StatelessWidget {
  const _CustomerProfileView({required this.reviewLauncher});

  final AppReviewLauncher reviewLauncher;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'customer_profile_root',
      container: true,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<CustomerProfileCubit, CustomerProfileState>(
            builder: (context, state) =>
                _Body(data: state.data, reviewLauncher: reviewLauncher),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.reviewLauncher});

  final CustomerProfileViewData data;
  final AppReviewLauncher reviewLauncher;

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
          rating: data.rating,
          ratingCount: data.ratingCount,
        ),
        CustomerProfileRows(
          showRegister: !data.isJeeber,
          onRegisterDelivery: () => context.goNamed('delivery-register-prompt'),
          onNotifications: () => context.pushNamed('settings-notifications'),
          onAddresses: () => context.pushNamed('settings-addresses'),
          onPassword: () => context.pushNamed('password-security'),
          onLanguage: () => context.pushNamed('language-settings'),
          onContact: () => context.pushNamed('support-ticket'),
          onRateApp: () => unawaited(reviewLauncher.requestReview()),
          onLogout: () => LogoutDeleteConfirmSheet.show(
            context,
            mode: LogoutDeleteMode.both,
          ),
        ),
      ],
    );
  }
}
