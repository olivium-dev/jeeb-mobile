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

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/customer_profile_screen_fixtures.dart';

/// Customer Profile tab body (JM-035). Tab surface shared by cl
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
      // redesign-2026-08: the board's 24px side gutter, owned once by the list
      // instead of by each band. The top inset clears the shell-overlaid header
      // actions (wallet chip + bell) so the identity card never sits under them;
      // Spacing tops out at fourXLarge, so the 56 comes from the Sizes ramp.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Sizes.fiveXLarge,
        Spacing.xLarge,
        Spacing.twoXLarge,
      ),
      children: [
        CustomerProfileHeader(
          name: data.name,
          email: data.email,
          avatarUrl: data.avatarUrl,
          isVerified: data.isVerified,
          rating: data.rating,
          ratingCount: data.ratingCount,
        ),
        const SizedBox(height: Spacing.small),
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
// ============================== JEEB PREVIEWS ==============================
const double _customerProfileScreenPhoneWidth = 390;

/// The narrowest phone the app still supports (iPhone SE 1st ge
const double _customerProfileScreenCompactWidth = 320;

/// A whole phone viewport — this is a full-screen tab body, so 
const Size _customerProfileScreenPhoneBox =
    Size(_customerProfileScreenPhoneWidth, 844);

/// The compact device, at its real height.
const Size _customerProfileScreenCompactBox =
    Size(_customerProfileScreenCompactWidth, 568);

/// One seated screen: a seed, a scripted repository, an inert r
Widget _customerProfileScreenHosted({
  required String state,
  required CustomerProfileViewData data,
  required CustomerProfileRepository repository,
  double width = _customerProfileScreenPhoneWidth,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: width,
      child: CustomerProfileScreen(
        key: ValueKey<String>('customer-profile-screen-preview-$state'),
        data: data,
        repository: repository,
        reviewLauncher: const CustomerProfileScreenInertReviewLauncher(),
      ),
    ),
  );
}

/// The reference reading, and the Screen Catalog's "Client — ve
@JeebPreview(
  group: 'customer_profile',
  name: 'Client · verified + rated',
  size: _customerProfileScreenPhoneBox,
  matrix: true,
)
Widget customerProfileScreenClient() => _customerProfileScreenHosted(
      state: 'client',
      data: CustomerProfileScreenPreviewFixtures.ratedClient,
      repository: const CustomerProfileScreenStaticRepository(
        CustomerProfileScreenPreviewFixtures.ratedClient,
      ),
    );

/// The Screen Catalog's "Jeeber — no ratings yet": the account 
@JeebPreview(
  group: 'customer_profile',
  name: 'Jeeber · register row hidden',
  size: _customerProfileScreenPhoneBox,
)
Widget customerProfileScreenJeeber() => _customerProfileScreenHosted(
      state: 'jeeber',
      data: CustomerProfileScreenPreviewFixtures.jeeber,
      repository: const CustomerProfileScreenStaticRepository(
        CustomerProfileScreenPreviewFixtures.jeeber,
      ),
    );

/// The empty state, and the true first frame of the Profile tab
@JeebPreview(
  group: 'customer_profile',
  name: 'Cold start · getMe in flight',
  size: _customerProfileScreenPhoneBox,
)
Widget customerProfileScreenColdStart() => _customerProfileScreenHosted(
      state: 'cold-start',
      data: CustomerProfileScreenPreviewFixtures.coldStart,
      repository: const CustomerProfileScreenPendingRepository(),
    );

/// The error state on the path that actually reaches users: the
@JeebPreview(
  group: 'customer_profile',
  name: 'Failed read · network, empty seed',
  size: _customerProfileScreenPhoneBox,
)
Widget customerProfileScreenFailedColdRead() => _customerProfileScreenHosted(
      state: 'failed-cold-read',
      data: CustomerProfileScreenPreviewFixtures.coldStart,
      repository: const CustomerProfileScreenFailingRepository(
        CustomerProfileFailure.network,
      ),
    );

/// The other error path: a profile handed in through the route'
@JeebPreview(
  group: 'customer_profile',
  name: 'Stale after 401 · route extra',
  size: _customerProfileScreenPhoneBox,
)
Widget customerProfileScreenStaleAfterUnauthorized() =>
    _customerProfileScreenHosted(
      state: 'stale-after-401',
      data: CustomerProfileScreenPreviewFixtures.routeExtra,
      repository: const CustomerProfileScreenFailingRepository(
        CustomerProfileFailure.unauthorized,
      ),
    );

/// Layout ceiling: the longest plausible name and a long instit
@JeebPreview(
  group: 'customer_profile',
  name: 'Longest content · compact 320',
  size: _customerProfileScreenCompactBox,
  matrix: true,
)
Widget customerProfileScreenLongestContent() => _customerProfileScreenHosted(
      state: 'longest-content',
      data: CustomerProfileScreenPreviewFixtures.longestContent,
      repository: const CustomerProfileScreenStaticRepository(
        CustomerProfileScreenPreviewFixtures.longestContent,
      ),
      width: _customerProfileScreenCompactWidth,
    );
