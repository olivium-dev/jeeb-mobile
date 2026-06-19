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

/// Customer Profile tab body (JM-035, blueprint `customer-profile`, Figma
/// 56581:1910 screen 18).
///
/// This is the REAL Profile tab surface — the shell swaps it in for both the
/// client and jeeber roles (`shell_screen.dart`, integrator-owned) and overlays
/// the persistent `customer_profile_wallet_chip` + `customer_profile_bell`
/// header actions on top of it via `ShellHeaderActions`. This screen therefore
/// deliberately does **not** render those two ids (they would duplicate) and
/// renders **no app bar / back button** (it is a tab body, not a pushed route).
///
/// Data: seeded from the caller-supplied [data] (the shell hands the dev
/// fixture; the `/profile/customer` route hands the real `extra`) so the header
/// renders on the first frame, then [CustomerProfileCubit.load] refreshes it
/// from the live `GET /user-management/users/me` (the JM-035 AC's named
/// endpoint) via `sl<Dio>()` — no `injection_container.dart` edit (the repo is
/// self-provided here, per 40_GUARDRAILS §5.4).
///
/// Row navigation (JM-035 AC2): rows whose target route is registered navigate
/// honestly; rows whose target lands in a later wave (password-security/
/// language-settings/support-ticket/logout-confirm, all W4) are GUARDED
/// coming-soon (AP-9: tap accepted, the tab root survives) — they must NOT
/// `goNamed` an unregistered name (navigation honesty, CTO brief §6.7). Each is
/// tagged `// TODO(JM-0NN)` for swap-in when its route lands.
///
/// The Rate-app row (JM-064) is NOT a route — it raises the OS store-review
/// sheet via the [AppReviewLauncher] port (`lib/features/rate_app/`) and returns
/// to Profile. The screen self-provides the launcher (default
/// [NoopAppReviewLauncher] until the `in_app_review` dep + DI land — see
/// `50_ROUTE_REQUESTS.md`), with a constructor test seam.
class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({
    super.key,
    required this.data,
    this.repository,
    this.reviewLauncher,
  });

  static const Key rootKey = Key('customer-profile-screen-root');

  /// Seed header data (shell fixture / route `extra`).
  final CustomerProfileViewData data;

  /// Test seam: a scripted repository. When null the screen resolves a
  /// Dio-backed repo from `sl<Dio>()` if GetIt is configured, else runs in
  /// fixture-only mode (no network) so widget tests pump cleanly.
  final CustomerProfileRepository? repository;

  /// Test seam: the native store-review launcher (JM-064). When null the screen
  /// self-provides a default (see [_resolveReviewLauncher]); tests inject a
  /// recording double to assert the row invoked it without touching a plugin.
  final AppReviewLauncher? reviewLauncher;

  CustomerProfileRepository? _resolveRepository() {
    if (repository != null) return repository;
    // Self-provide over the shared Dio (MockGatewayClient → :4010) without a DI
    // registration. `sl<Dio>()` is registered in `configureDependencies()`; in
    // a bare widget test (no DI) we fall back to fixture-only (null repo).
    if (sl.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(sl<Dio>());
    }
    return null;
  }

  /// Self-provide the JM-064 store-review launcher. Resolves from GetIt if the
  /// integrator has registered an [AppReviewLauncher] (the `in_app_review`-backed
  /// adapter, see `50_ROUTE_REQUESTS.md`); otherwise the dependency-free
  /// [NoopAppReviewLauncher] (tap accepted, returns to Profile — AP-9 honest, no
  /// `injection_container.dart` edit needed today).
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
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<CustomerProfileCubit, CustomerProfileState>(
          builder: (context, state) =>
              _Body(data: state.data, reviewLauncher: reviewLauncher),
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
          // AC2 / R-3 (jm-035): register-as-delivery → the standalone
          // delivery-register prompt (`delivery_register_prompt`), NOT
          // `/register` and NOT straight into the onboarding wizard. The
          // `delivery-register-prompt` route renders DeliveryRegisterPromptScreen
          // unconditionally and is the same destination the offer-KYC gate's
          // `gate_register_link` reaches (66 RD-1); from there the user starts
          // the onboarding wizard. Honest leg — the route is registered.
          onRegisterDelivery: () => context.goNamed('delivery-register-prompt'),
          // AC2: notifications → notification-prefs. `push` so `notif_prefs_back`
          // pops back to this shell Profile tab (where `customer_profile_wallet_chip`
          // shows), JM-058 AC4.
          onNotifications: () => context.pushNamed('settings-notifications'),
          // AC2: addresses → saved-addresses. `settings-addresses` is the
          // registered real `SavedLocationsScreen` (`saved_address_add_cta`).
          onAddresses: () => context.goNamed('settings-addresses'),
          // ── W4 targets — now registered, wired honestly ──────────────────
          // JM-061: password-security. `push` so back (`password_back`) pops
          // back to this profile tab, where `customer_profile_wallet_chip`
          // (the shell header overlay) is shown.
          onPassword: () => context.pushNamed('password-security'),
          // JM-059: language-settings. `push` so `language_back` pops back here.
          onLanguage: () => context.pushNamed('language-settings'),
          // JM-063: support-ticket. `push` so its back returns to the profile.
          onContact: () => context.pushNamed('support-ticket'),
          // JM-064: raise the native OS store-review sheet, then stay on
          // Profile. No route, no network — the OS owns the sheet (and
          // rate-limits it). Fire-and-forget so the tap returns immediately.
          onRateApp: () => unawaited(reviewLauncher.requestReview()),
          // JM-062: open the logout/delete confirm sheet (`logout_delete_sheet`,
          // both actions) → on confirm the session clears → splash → /login (D5).
          onLogout: () => LogoutDeleteConfirmSheet.show(
            context,
            mode: LogoutDeleteMode.both,
          ),
        ),
      ],
    );
  }
}
