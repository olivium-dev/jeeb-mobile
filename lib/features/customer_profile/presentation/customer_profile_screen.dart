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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/customer_profile_screen_fixtures.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/customer_profile/customer_profile_screen_preview_test.dart
// ===========================================================================
//
// [CustomerProfileScreen] is one header over eight fixed navigation rows, and
// it BUILDS ITS OWN [CustomerProfileCubit] — there is no `cubit:` seam. So a
// state here is not a seeded cubit; it is a seed plus a scripted
// [CustomerProfileRepository], and the cubit walks itself into the status. The
// people and the three repositories are NOT declared here: they live in
// `lib/devtool/catalog/fixtures/customer_profile_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_02_entries.dart`), so the designer's browser
// and this canvas cannot drift into showing two different "Kamal Hajj". None of
// them can reach the gateway: `repository:` and `reviewLauncher:` are both
// passed explicitly, so `_resolveRepository`'s `sl<Dio>()` branch and
// `_resolveReviewLauncher`'s `sl<AppReviewLauncher>()` branch are never taken.
// The guard in [jeebPreviewHost] is the net here, not the plan.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + SafeArea + ListView` paints inside it. That is
//    the same nesting the Screen Catalog produces on the device.
//  * **The width is pinned in the TREE, not just in `size:`.** `size:` boxes
//    the canvas; [_customerProfileScreenHosted] pins the same width in the
//    widget tree, because the render tests pump onto a fixed 800 × 600 surface
//    and a 320 pt state that only asked for a 320 pt canvas would be laid out
//    at 800 pt under test — silently becoming the 390 pt state. Height is left
//    to the host: the body is a [ListView] and growing past the viewport is
//    normal here, not a defect.
//  * **Tapping is not previewing.** Seven of the eight rows call
//    `context.goNamed`/`pushNamed` and the eighth opens
//    [LogoutDeleteConfirmSheet], which resolves its session terminator from DI.
//    There is no [GoRouter] above a preview card, so those taps throw. Only the
//    Rate-app row is inert, and only because both dev surfaces pass
//    [CustomerProfileScreenInertReviewLauncher].
//
// Four things these previews surface, all in the screen rather than in the
// previews — see the notes on the individual states:
//
//  * **The seed is read exactly ONCE per element.** `data` goes to
//    `CustomerProfileCubit(seed: …)` inside `BlocProvider.create`, which
//    `provider` runs once per element and never re-runs on rebuild — and the
//    screen is a [StatelessWidget], so there is no `didUpdateWidget` to notice.
//    Rebuild this screen at the same position with a DIFFERENT
//    `CustomerProfileViewData` and the header goes on showing the old one,
//    silently and permanently. Nothing in the app does that today (the shell
//    always passes the same const empty seed, and both the route and the Screen
//    Catalog build a fresh element per navigation), which is why it has gone
//    unnoticed — the render tests here are the first surface that swaps `data`
//    in place, and it cost two red tests that looked like preview bugs and were
//    not. Every card below therefore carries its own key.
//  * **A failed read is invisible.** [CustomerProfileCubit] catches the typed
//    failure, keeps the seeded header and records it on `state.error` — which
//    NOTHING reads. `_Body` takes `state.data` and nothing else, so there is no
//    banner, no inline message and no retry affordance anywhere on the surface.
//  * **And it is unrecoverable in place.** `CustomerProfileCubit.refresh()` —
//    the method the cubit's own doc offers "for an optional inline retry" — has
//    no caller anywhere in `lib/`, and the body is a plain [ListView] with no
//    [RefreshIndicator], so there is no pull-to-refresh either. `load()` then
//    refuses to run again (`if (state.status != initial) return;`). Once the
//    read has failed, the mounted screen can never try again.
//  * **On the shell path the failure is also indistinguishable from the cold
//    start.** `shell_screen.dart` seeds the Profile tab with an EMPTY
//    [CustomerProfileViewData] on purpose, so a failed getMe leaves exactly the
//    frame the tab opened with: "?" avatar, blank name line, "No reviews yet".
//    Compare [customerProfileScreenColdStart] with
//    [customerProfileScreenFailedColdRead] — the two cards are pixel-identical,
//    and the only difference between them is that one of them will eventually
//    change. That is why the render test pins them on the cubit's status and
//    error rather than on their copy.

/// The phone this screen is designed against.
const double _customerProfileScreenPhoneWidth = 390;

/// The narrowest phone the app still supports (iPhone SE 1st gen and the small
/// Android estate). The header's 80 pt avatar and the register row's trailing
/// pill both take a fixed cut of it, so it is where this surface fails first.
const double _customerProfileScreenCompactWidth = 320;

/// A whole phone viewport — this is a full-screen tab body, so anything shorter
/// would hide the rows the header is competing with for space.
const Size _customerProfileScreenPhoneBox =
    Size(_customerProfileScreenPhoneWidth, 844);

/// The compact device, at its real height.
const Size _customerProfileScreenCompactBox =
    Size(_customerProfileScreenCompactWidth, 568);

/// One seated screen: a seed, a scripted repository, an inert review launcher.
///
/// [repository] is always supplied so `_resolveRepository()` never reaches for
/// `sl<Dio>()`, and [width] is pinned into the tree so the canvas and the
/// render tests lay the screen out identically.
///
/// [state] keys the screen, and it is NOT decoration. `CustomerProfileScreen`
/// hands `data` to `CustomerProfileCubit(seed: …)` inside `BlocProvider.create`,
/// which runs once per element and never again — so rebuilding this screen with
/// a DIFFERENT `data` leaves the previous profile on screen (see the section
/// note above). A render test that pumps two previews in a row replaces this
/// widget with another of the same type at the same position, which Flutter
/// treats as an update rather than a remount — so without a distinct key per
/// state the second card renders the FIRST card's customer under the second
/// card's name. The Screen Catalog is immune only because it pushes a route per
/// state (`catalog_screen.dart`), which builds a fresh element every time.
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

/// The reference reading, and the Screen Catalog's "Client — verified, rated":
/// a verified customer with a rating, an email and a photo on file, whose live
/// getMe returns the same read model it was seeded with.
///
/// The matrix is on because this is the state where the header and the rows are
/// both fully populated, and everything on the surface is directional chrome —
/// avatar then identity in the header, icon disc then label then chevron in
/// every row. Two things to read in **AR RTL dark**: the whole column mirrors
/// while the Latin email keeps its LTR run (that is what `AutoDirectionText` is
/// for), and the "Account"/"Support" section headers and the glyphs inside the
/// navy discs drop to roughly 2:1 and 1.4:1 — `secondaryContainer` used as ink
/// against a dark scheme generated by `ColorScheme.fromSeed`. The **200%** card
/// is where the header stops being a header: it grows until the register row is
/// the only account row left above the fold.
///
/// `avatarUrl` is a live CDN URL here, exactly as the catalog and the debug
/// `/profile/customer` capture route carry it. It resolves in the canvas, which
/// has a network; in the render tests it does not, and
/// `OmdsProfileAvatar._buildNetworkImage` falls back to the same initials
/// placeholder the other states show. Nothing else on this screen touches the
/// network.
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

/// The Screen Catalog's "Jeeber — no ratings yet": the account is already a
/// Jeeber, so the "Register as a delivery" row is gone (JM-035 AC2 / design
/// §8.2) and the Account section is one row shorter.
///
/// Also the unrated header: [CustomerProfileRating] swaps to the outlined star
/// and "No reviews yet" rather than disappearing, because the
/// `customer_profile_rating` identifier has to survive for the JM-035 Maestro
/// presence assertion. The failure mode this card guards is silent — the row is
/// behind a bare `if (showRegister)`, so a regression either leaves a Jeeber a
/// dead "Register" button or takes 56 pt of the Account section away from
/// everyone.
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

/// The empty state, and the true first frame of the Profile tab for every user:
/// an empty seed with `GET /user-management/users/me` still in flight.
///
/// `shell_screen.dart` mounts this screen as
/// `CustomerProfileScreen(data: CustomerProfileViewData())` deliberately — "the
/// profile should look incomplete rather than show a sample person and be
/// mistaken for real data" — so nothing here is synthetic. What the card shows
/// is what a user opening Profile sees until getMe lands: a "?" avatar, a name
/// line that is an EMPTY [Text] rather than a placeholder or a skeleton, no
/// email row at all (`_Identity` drops it when `email == null`), and the
/// unrated rating chip. `status` is `loading` and no widget reads it: the eight
/// rows are fully painted and fully tappable throughout, so a user can push
/// `password-security` before the screen knows who they are.
///
/// The empty name line is also an accessibility hole — `_NameText` builds
/// `Semantics(identifier: 'customer_profile_name', label: name ?? '')`, so a
/// screen reader lands on a node that announces nothing.
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

/// The error state on the path that actually reaches users: the shell's empty
/// seed, and a getMe that failed with [CustomerProfileFailure.network].
///
/// **Read it next to [customerProfileScreenColdStart].** The two are the same
/// pixels. The cubit caught the failure, emitted `loaded` and recorded
/// `error: network` — and `_Body` reads only `state.data`, so nothing on the
/// surface says the read failed, and nothing offers to retry it. The user is
/// left on a profile page that shows them nothing about themselves, with no way
/// to tell whether it is still working, and no gesture that can make it try
/// again (`refresh()` is uncalled anywhere in `lib/`, there is no
/// [RefreshIndicator], and `load()` will not re-enter).
///
/// This is the state to fix first. Everything else on this screen degrades
/// gracefully; this one degrades silently.
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

/// The other error path: a profile handed in through the route's typed `extra`
/// (`/profile/customer`), whose refresh came back
/// [CustomerProfileFailure.unauthorized].
///
/// The session is gone — 401 is the gateway saying the token no longer
/// identifies anyone — and the screen goes on rendering the previous read
/// model: name, email, verified badge, rating. Indistinguishable from a
/// successful refresh, indefinitely. Worth its own card precisely because it
/// looks correct: the graceful-degradation rule (40_GUARDRAILS §4) that keeps
/// the seeded header visible is right for a flaky network and wrong for a dead
/// session, and the screen cannot tell the two apart because it never looks at
/// `state.error`.
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

/// Layout ceiling: the longest plausible name and a long institutional email,
/// on the narrowest phone the app supports.
///
/// The header has no ellipsis budget — `_NameText` wraps its text in a
/// [Flexible] but passes no `maxLines`, so the name wraps and the header GROWS,
/// and because the header is the first child of the profile [ListView] it grows
/// at the rows' expense. On 320 pt the fixed costs are what hurt: 24 pt of
/// directional padding a side, an 80 pt avatar, a 12 pt gap, and a verified
/// badge that `_NameRow` centres against the whole wrapped block — so on a
/// multi-line name the badge floats beside a middle line rather than marking
/// the name.
///
/// The matrix is on for the same reason it is on for the reference card, but
/// read this one for the opposite failure: at **200%** the account rows are off
/// the bottom of a 568 pt device entirely, and the register row's label — the
/// only sentence that says what the row does — yields all of its width to the
/// intrinsically-sized "Register" pill (measured in
/// `customer_profile_rows.dart`, where the same row overflows outright at this
/// width and scale).
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
