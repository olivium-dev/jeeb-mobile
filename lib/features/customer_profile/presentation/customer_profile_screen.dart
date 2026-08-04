import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/layout/bottom_inset.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../rate_app/domain/app_review_launcher.dart';
import '../../settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../application/customer_profile_cubit.dart';
import '../application/customer_profile_state.dart';
import '../data/dio_customer_profile_repository.dart';
import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';
import 'widgets/customer_profile_header.dart';
import 'widgets/customer_profile_rows.dart';
import 'widgets/customer_profile_status_block.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/customer_profile_screen_fixtures.dart';

/// Customer Profile tab body (JM-035). Tab surface shared by cl
///
/// MIDNIGHT M3-07 — the board never drew this screen, so it is derived from its
/// nearest tile, **R22 Settings** (`22-r22-settings.png`): identity card →
/// one lit orange frame → periwinkle section labels over grouped glass row
/// cards → a detached sign-out card. Both screens already cite the same board
/// template run, and `settings_screen.dart` is the measured twin.
///
/// Field: `content` variant, ORANGE glow `topEnd` — R22 declares
/// `radial-gradient(480px 380px at 88% -6%)` and **no periwinkle wash**
/// (study notes, wave-C/D). `animateDecor: false`: R22 is board-still, and an
/// M3 row earns no motion the board never drew. The shell paints no field of
/// its own (`shell_screen.dart`), so every tab body mounts one.
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
      child: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: BlocBuilder<CustomerProfileCubit, CustomerProfileState>(
              builder: (context, state) =>
                  _Body(state: state, reviewLauncher: reviewLauncher),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.reviewLauncher});

  final CustomerProfileState state;
  final AppReviewLauncher reviewLauncher;

  @override
  Widget build(BuildContext context) {
    final CustomerProfileViewData data = state.data;
    return ListView(
      key: CustomerProfileScreen.rootKey,
      // The board's 24px side gutter, owned once by the list instead of by each
      // band. The top inset clears the shell-overlaid header actions; the bottom
      // one reserves the floating pill nav this tab scrolls under.
      padding: EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Sizes.fiveXLarge,
        Spacing.xLarge,
        Spacing.twoXLarge + context.scrollBodyBottomInset,
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
        if (CustomerProfileStatusBlock.showsFor(state)) ...[
          const SizedBox(height: Spacing.small),
          CustomerProfileStatusBlock(
            state: state,
            onRetry: () =>
                unawaited(context.read<CustomerProfileCubit>().refresh()),
          ),
        ],
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
