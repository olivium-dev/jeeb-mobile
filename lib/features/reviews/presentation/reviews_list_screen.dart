import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/widgets/directional_icons.dart';
import '../application/reviews_cubit.dart';
import '../application/reviews_state.dart';
import '../data/empty_reviews_repository.dart';
import '../domain/reviews_repository.dart';
import 'reviews_l10n.dart';
import 'widgets/review_row.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/reviews_list_screen_fixtures.dart';
import '../data/stub_reviews_repository.dart';

class ReviewsListScreen extends StatelessWidget {
  const ReviewsListScreen({
    super.key,
    this.jeeberId,
    this.repository,
    this.authTokenStore,
  });

  final String? jeeberId;

  final ReviewsRepository? repository;

  final AuthTokenStore? authTokenStore;

  ReviewsRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<ReviewsRepository>()) {
      return sl<ReviewsRepository>();
    }
    return const EmptyReviewsRepository();
  }

  Widget _buildFor(String resolvedJeeberId) => BlocProvider<ReviewsCubit>(
        create: (_) => ReviewsCubit(
          repository: _resolveRepository(),
          jeeberId: resolvedJeeberId,
        )..load(),
        child: const _ReviewsView(),
      );

  @override
  Widget build(BuildContext context) {
    final explicit = jeeberId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return _buildFor(explicit);
    }
    return FutureBuilder<String?>(
      future: (authTokenStore ?? AuthTokenStore()).userId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: OmdsLoadingState()));
        }
        return _buildFor((snapshot.data ?? '').trim());
      },
    );
  }
}

class _ReviewsView extends StatelessWidget {
  const _ReviewsView();

  @override
  Widget build(BuildContext context) {
    final copy = ReviewsL10n.of(context);
    return Semantics(
      identifier: 'reviews_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          leading: Semantics(
            identifier: 'reviews_back',
            button: true,
            child: IconButton(
              icon: Icon(DirectionalIcons.back(context)),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
        body: BlocConsumer<ReviewsCubit, ReviewsState>(
          listenWhen: (p, n) =>
              p.reportStatus != n.reportStatus &&
              (n.reportStatus == ReportStatus.succeeded ||
                  n.reportStatus == ReportStatus.failed),
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  state.reportStatus == ReportStatus.succeeded
                      ? copy.reportSuccess
                      : copy.reportFailure,
                ),
              ),
            );
            context.read<ReviewsCubit>().acknowledgeReport();
          },
          builder: (context, state) {
            switch (state.status) {
              case ReviewsStatus.initial:
              case ReviewsStatus.loading:
                return _LoadingSkeletons(copy: copy);
              case ReviewsStatus.failed:
                return _ErrorBody(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () => context.read<ReviewsCubit>().refresh(),
                );
              case ReviewsStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<ReviewsCubit>().refresh(),
                  child: !state.hasReviews
                      ? _EmptyBody(copy: copy)
                      : _LoadedList(state: state, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(ReviewsL10n copy, ReviewsFailure? f) {
    switch (f) {
      case ReviewsFailure.network:
        return copy.networkError;
      case ReviewsFailure.notFound:
      case ReviewsFailure.unauthorized:
      case ReviewsFailure.unknown:
      case null:
        return copy.loadError;
    }
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'reviews_error',
              container: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'reviews_retry_cta',
              button: true,
              container: true,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeletons extends StatelessWidget {
  const _LoadingSkeletons({required this.copy});

  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'reviews_loading',
      container: true,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
        itemCount: 6,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: Spacing.medium,
          endIndent: Spacing.medium,
        ),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: OmdsListItemShimmer(hasTrailing: false),
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.copy});

  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Semantics(
          identifier: 'reviews_empty',
          container: true,
          child: OmdsEmptyState(
            icon: Icons.reviews_outlined,
            title: copy.emptyTitle,
            subtitle: copy.emptyBody,
          ),
        ),
      ],
    );
  }
}

class _AggregateHeader extends StatelessWidget {
  const _AggregateHeader({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.coldStart || state.averageScore == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium,
          Spacing.medium,
          Spacing.medium,
          Spacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'reviews_new_badge',
              child: OmdsChip(
                label: copy.newBadge,
                icon: Icon(
                  Icons.auto_awesome,
                  size: Sizes.small,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'reviews_hidden_score_note',
              child: Text(
                copy.hiddenScoreNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.medium,
        Spacing.medium,
        Spacing.small,
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Semantics(
            identifier: 'reviews_aggregate',
            child: Text(
              copy.aggregate(state.averageScore!, state.reviewCount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedList extends StatefulWidget {
  const _LoadedList({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  State<_LoadedList> createState() => _LoadedListState();
}

class _LoadedListState extends State<_LoadedList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<ReviewsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final copy = widget.copy;
    final reviews = state.reviews;
    final showFooter =
        state.loadingMore || state.loadMoreError || state.hasMore;
    const headerCount = 1;
    final itemCount = headerCount + reviews.length + (showFooter ? 1 : 0);

    return ListView.separated(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        if (index < headerCount) return const SizedBox.shrink();
        if (index >= headerCount + reviews.length - 1) {
          return const SizedBox.shrink();
        }
        return const Divider(
          height: 1,
          indent: Spacing.medium,
          endIndent: Spacing.medium,
        );
      },
      itemBuilder: (context, index) {
        if (index < headerCount) {
          return _AggregateHeader(state: state, copy: copy);
        }
        final rowIndex = index - headerCount;
        if (rowIndex >= reviews.length) {
          return _Footer(state: state, copy: copy);
        }
        final review = reviews[rowIndex];
        return ReviewRow(
          review: review,
          copy: copy,
          onReport: () => _confirmReport(context, review.id),
        );
      },
    );
  }

  Future<void> _confirmReport(BuildContext context, String reviewId) async {
    if (reviewId.isEmpty) return;
    final copy = widget.copy;
    final cubit = context.read<ReviewsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => OmdsConfirmationDialog(
        title: copy.reportConfirmTitle,
        content: copy.reportConfirmBody,
        confirmText: copy.reportConfirmCta,
        cancelText: copy.reportCancelCta,
      ),
    );
    if (confirmed == true) {
      await cubit.reportReview(reviewId);
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.copy});

  final ReviewsState state;
  final ReviewsL10n copy;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.medium,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                copy.loadMoreError,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: Spacing.small),
            Semantics(
              identifier: 'reviews_load_more_retry',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () => context.read<ReviewsCubit>().retryLoadMore(),
                child: Text(copy.retry),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      identifier: 'reviews_load_more',
      container: true,
      child: const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: OmdsListItemShimmer(hasTrailing: false),
      ),
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
// Render tests: test/previews/reviews/reviews_list_screen_preview_test.dart
// ===========================================================================
//
// [ReviewsListScreen] renders no data of its own: it builds a [ReviewsCubit]
// over whatever [ReviewsRepository] it is handed and calls `load()` in the
// provider's `create`. Both `jeeberId` and `repository` are existing
// constructor seams, so every state below is one local repository away — no DI,
// no Dio, and the real cold-load path runs the way it does on a device.
//
// The fakes and the casts are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/reviews_list_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_10_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a const page, throw, or never complete.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **This screen OWNS a Scaffold, and [jeebPreviewHost] wraps it in another.**
//    The host's `Scaffold + SafeArea` is what every preview gets; `_ReviewsView`
//    then builds its own for the [OMDSAppBar]. The nesting is harmless (the
//    inner one paints the surface and the app bar, the outer one contributes a
//    background and the safe-area inset) but it is real, and it is why nothing
//    below adds a third.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_reviewsListScreenFramed] pins the box in the widget tree so the render
//    tests measure a phone rather than the 800x600 test surface, where every
//    squeeze under review disappears. Height is pinned too, but the render
//    surface is 800x600, so a `SizedBox` asking for 844 is enforced down to
//    what the host has; the COMPACT box (320x568) fits and is exact.
//  * **Two states mute the ticker.** The skeletons and the load-more footer are
//    `OmdsListItemShimmer`, i.e. `Shimmer.fromColors`, and the session-resolving
//    state is a [CircularProgressIndicator]; all three schedule frames forever
//    and `pumpAndSettle` would hang on them. Muting still paints the placeholder
//    — it just stops it moving, which is what a static canvas wanted anyway.
//
// Two hazards the previews expose rather than hide:
//
//  * **The report flow is not previewable.** `_confirmReport` opens an
//    [OmdsConfirmationDialog] and the outcome is a SnackBar driven by
//    `reportStatus`; both are transitions, not still frames. The Report button
//    on every row is real and tappable in the canvas, and tapping it does open
//    the dialog — but neither the in-flight nor the succeeded/failed surface has
//    a card of its own.
//  * **The back button is not tappable.** Its `onPressed` is
//    `context.canPop() ? context.pop() : context.go('/')`, which resolves a
//    [GoRouter] that exists above neither a preview card nor a catalog state.
//    Tapping throws. It is built lazily, so merely rendering is fine.
//
// The states are the five the Screen Catalog names plus three it does not, and
// all three extras are states that break:
//
//   * **Score withheld.** An established jeeber the header calls "New".
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone.
//   * **Resolving session id.** The pre-cubit surface on a cold deep-link.
//
// What the canvas shows that no test asserted before this section landed. Every
// number is measured off the render tree through the REAL Inter and Noto Arabic
// faces — under Flutter's 1-em test face Latin measures ~2x too wide and Arabic
// ~2.4x, so widths taken there report breakages that exist on no device.
//
// * **A null `averageScore` is rendered as "New Jeeber", whatever the review
//   count.** `_AggregateHeader` branches on
//   `state.coldStart || state.averageScore == null`, so the D59 cold-start
//   header — the "New" chip plus "overall score appears after a few completed
//   deliveries" — is what a jeeber with 42 ratings sees the moment the gateway
//   omits the score. The two fields are independent on the wire
//   (`ReviewsPage.coldStart` and `ReviewsPage.averageScore` are separate, and
//   `ReviewsCubit.load` copies both through verbatim), and only one of them
//   means "new". See [reviewsListScreenScoreWithheld], where the badge sits
//   directly over 42 reviews' worth of list.
// * **Resolving the session id has NO app bar.** Opened without a `jeeberId`
//   the screen renders `Scaffold(body: Center(OmdsLoadingState()))` while
//   `AuthTokenStore.userId` is in flight — a bare spinner with no title and, more
//   to the point, no back button. `ReviewsStatus.loading` one frame later is a
//   different surface entirely (app bar + six skeleton rows). A secure-storage
//   read after a device reboot is a keychain unlock, so this is not a
//   single-frame flash; while it lasts, the only way off the screen is the
//   system gesture. See [reviewsListScreenResolvingSession].
// * **An unresolved session id becomes an EMPTY id, not an error.** The same
//   branch ends in `_buildFor((snapshot.data ?? '').trim())`, so a signed-out or
//   token-less user builds a [ReviewsCubit] on `jeeberId: ''` and issues a real
//   read for nobody. What that renders is whatever the gateway answers for an
//   empty path segment, i.e. the generic "Could not load reviews." — the screen
//   never distinguishes "you are not signed in" from "the server is down". Not
//   previewable as a still frame (it depends on the live response), which is
//   exactly why it is written down here.
// * **Retry gives no feedback.** `_ErrorBody`'s button calls
//   `ReviewsCubit.refresh()`, which — unlike `load()` — never emits a loading
//   state. The error surface stays on screen, unchanged, for as long as the
//   request takes, and a user who taps twice has fired two reads with nothing on
//   screen to say so.
// * **Nothing in the aggregate header flexes.** The score line is a bare [Text]
//   in a [Row] after a fixed-size star, with no `Flexible` and no `maxLines`.
//   Measured on the 320 pt compact frame at 200% text with the real faces:
//   "3.9 · 128 reviews" wants 228.1 dp of the 264.0 the padded Row can give it,
//   and the Arabic "3.9 · 128 تقييمات" wants 214.1 — so it clears, but the
//   margin is a property of the copy rather than of the layout, and a five-digit
//   count or a longer localization would spend it. The AR RTL and 200% cards of
//   [reviewsListScreenLongestContent] are where to watch it.
// * **Nothing on a review row clamps, and the list is what pays.** On the 320 pt
//   frame the ceiling review measures 341 dp — of 464 dp of list area — so the
//   NEXT review starts at 446 and is cut by the fold at 568: its comment, its
//   stars and its Report button are all below it. The row does not ellipsize
//   because neither the attribution nor the body sets `maxLines`; the list
//   scrolls, so nothing errors, and one angry review is simply the whole first
//   screen. See [reviewsListScreenLongestContent].
// * **The skeletons ignore the page they stand in for.** `_LoadingSkeletons`
//   always draws SIX rows, whatever `pageSize` the cubit asked for (20), and it
//   takes a [ReviewsL10n] it never reads — the `copy` parameter is dead. The
//   placeholder is also nothing like the thing it replaces: a shimmer row is a
//   one-line list item, a real review row is 194 dp of name, card and CTA, so
//   the list visibly jumps on first paint.

/// The phone this screen is designed against. Taller than the 800x600 render
/// surface on purpose: the canvas honours it, the render tests get what the
/// host allows, and both are a phone rather than a desktop-width slab.
const Size _reviewsListScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _reviewsListScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _reviewsListScreenFramed(
  Widget screen, {
  Size box = _reviewsListScreenPhoneBox,
  bool muteTicker = false,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: muteTicker ? TickerMode(enabled: false, child: screen) : screen,
    ),
  );
}

/// Builds the screen the way the router builds it — one explicit `jeeberId`,
/// one injected repository, no DI — pinned to a device frame.
///
/// Passing `jeeberId` is what keeps every state below off the [AuthTokenStore]
/// path; the one preview that wants that path
/// ([reviewsListScreenResolvingSession]) omits it deliberately.
Widget _reviewsListScreenHosted(
  ReviewsRepository repository, {
  Size box = _reviewsListScreenPhoneBox,
  bool muteTicker = false,
}) {
  return _reviewsListScreenFramed(
    ReviewsListScreen(
      jeeberId: reviewsListScreenJeeberId,
      repository: repository,
    ),
    box: box,
    muteTicker: muteTicker,
  );
}

/// The reference reading: a rated jeeber, seven reviews deep, under the "4.6 ·
/// 10 reviews" aggregate.
///
/// Served by the shipping [StubReviewsRepository] rather than a fixture, so this
/// card, the Screen Catalog's "Populated" state and the surface you get from
/// `jeeb.seam.journey` are one designed state with one owner.
///
/// This is the one the matrix is for, and there are three things to look at in
/// it. The header Row mirrors in AR — star, score, count — which only works
/// because its padding is [EdgeInsetsDirectional]. The 200% rendering is where
/// the fixed-size star stops lining up with the score beside it. And the rows
/// themselves are [ReviewRow], which prints each reviewer's first name TWICE
/// (its own D58 attribution node, then again as `OmdsReviewCard.userName`) — a
/// duplication that is invisible to the semantics tests and impossible to miss
/// here.
///
/// `totalPages` is 2 in this cast, so the load-more footer is real; it sits
/// below seven full rows, well past the fold, and is not what this card is for.
@JeebPreview(
  group: 'reviews',
  name: 'Loaded · rated jeeber',
  size: _reviewsListScreenPhoneBox,
  matrix: true,
)
Widget reviewsListScreenRated() => _reviewsListScreenHosted(
      const StubReviewsRepository(),
      muteTicker: true,
    );

/// The first page is still in flight: six shimmer rows under a live app bar.
///
/// Every jeeber who opens their own reviews sees this — `load()` is called in
/// the provider's `create` and the first frame is painted before it can return.
/// Note what it does NOT adapt to: the count is hardcoded at six regardless of
/// the twenty-item page the cubit asked for, so a full page arrives and the list
/// jumps. Note also what stays up: unlike the session-resolving state below,
/// this one has the app bar and its back button.
///
/// The ticker is muted so a static canvas (and `pumpAndSettle`) has something to
/// settle on; see [_reviewsListScreenFramed].
@JeebPreview(
  group: 'reviews',
  name: 'Loading · first page',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenLoadingFirstPage() => _reviewsListScreenHosted(
      const ReviewsListScreenPendingRepository(),
      muteTicker: true,
    );

/// A read that SUCCEEDED and came back with zero rows.
///
/// The branch is `state.hasReviews`, not the status, so this is also what a
/// jeeber whose reviews were all removed sees, and what a wrongly-scoped id
/// resolves to. The copy is reassuring either way.
///
/// Worth reading for one structural detail: `_EmptyBody` offsets the empty state
/// by `MediaQuery.of(context).size.height * 0.18` — a fraction of the WINDOW,
/// not of the body it sits in. It looks centred on a phone and drifts on
/// anything else. It keeps the pull gesture (`RefreshIndicator` wraps both
/// loaded branches), which is the one recovery affordance the error state's
/// button is a substitute for.
@JeebPreview(
  group: 'reviews',
  name: 'Empty · no reviews yet',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenEmpty() =>
    _reviewsListScreenHosted(const EmptyReviewsRepository());

/// The cold read failed with [ReviewsFailure.network]: the offline copy, an
/// error glyph and a Retry.
///
/// Only a COLD load reaches this surface — a failed refresh keeps whatever is on
/// screen and only swaps `state.error`, which has no still frame of its own.
///
/// The Retry is the state's only affordance and it is silent: it calls
/// `refresh()`, which emits nothing until the request resolves, so a slow retry
/// is indistinguishable from a dead button. `notFound` and `unauthorized`
/// collapse into the same generic "Could not load reviews." as `unknown`, so
/// this network card and that generic one are the only two renderings the
/// four-value failure enum produces.
@JeebPreview(
  group: 'reviews',
  name: 'Error · offline',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenErrorNetwork() => _reviewsListScreenHosted(
      const ReviewsListScreenFailingRepository(ReviewsFailure.network),
    );

/// D59 cold start: a jeeber with one rating, whose aggregate score is withheld
/// behind the "New" chip while the review itself renders in full.
///
/// This is the posture working as designed — one delivery is not a score — and
/// it is the card to compare [reviewsListScreenScoreWithheld] against, because
/// the two render the SAME header from opposite facts.
@JeebPreview(
  group: 'reviews',
  name: 'Cold start · New Jeeber',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenColdStart() => _reviewsListScreenHosted(
      const ReviewsListScreenColdStartRepository(),
    );

/// The regression this preview exists for: an ESTABLISHED jeeber — 42 completed
/// ratings — whose `averageScore` came back null.
///
/// `_AggregateHeader`'s `state.coldStart || state.averageScore == null` cannot
/// tell "we are not scoring you yet" from "the score is missing from this
/// response", so the surface tells a jeeber with 42 ratings that he is new and
/// that his score will appear "after a few completed deliveries". `coldStart` is
/// FALSE in this cast; the header is reached entirely through the null score.
///
/// Read it beside [reviewsListScreenColdStart]: identical chip, identical
/// sentence, and the only thing distinguishing them is the list underneath.
@JeebPreview(
  group: 'reviews',
  name: 'Score withheld · 42 ratings',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenScoreWithheld() => _reviewsListScreenHosted(
      const ReviewsListScreenStaticRepository(
        ReviewsListScreenPages.scoreWithheld,
      ),
    );

/// The layout ceiling on the narrowest phone the app supports.
///
/// A compound reviewer name and the longest comment a reviewer plausibly types,
/// on a 320 pt frame. Nothing on the row clamps — no `maxLines` on the
/// attribution, none on the body — so the row does not ellipsize, it GROWS: 341
/// dp of the 464 dp of list area, which leaves the second review starting at 446
/// and cut by the fold at 568. That is the list working (it scrolls); what it
/// costs is that a single angry review is the entire first screen of a jeeber's
/// reviews.
///
/// **Matrixed because the aggregate header is where 320 pt bites.** "3.9 · 128
/// reviews" is a bare [Text] in a [Row] with no `Flexible` and no `maxLines`,
/// sitting after a fixed-size star. At 200% text it wants 228.1 dp of the 264.0
/// the padded Row can give it (Arabic: 214.1), so it clears — but by copy, not
/// by construction, and a five-digit count or a longer localization would not.
@JeebPreview(
  group: 'reviews',
  name: 'Longest content · compact 320',
  size: _reviewsListScreenCompactBox,
  matrix: true,
)
Widget reviewsListScreenLongestContent() => _reviewsListScreenHosted(
      const ReviewsListScreenStaticRepository(
        ReviewsListScreenPages.longestContent,
      ),
      box: _reviewsListScreenCompactBox,
    );

/// The surface a cold deep-link shows BEFORE the cubit exists: a bare
/// `Scaffold` with a centred spinner, no app bar and no back button.
///
/// Opened without a `jeeberId` (`/reviews` with no query), the screen must first
/// resolve the authenticated user's own id out of [AuthTokenStore] — the
/// S0-OAD-03 fix pinned by
/// `test/features/reviews/reviews_list_session_id_test.dart`. Until that read
/// returns there is no `ReviewsCubit` and nothing to show, and the placeholder
/// the [FutureBuilder] returns has no chrome at all.
///
/// It is not a single-frame flash: the read is `FlutterSecureStorage`, which on
/// a cold start after a reboot is a keychain unlock. While it lasts, the system
/// back gesture is the only way off this screen — and if the read resolves to
/// nothing, the empty string it yields is handed to the cubit as a jeeber id
/// rather than being treated as "not signed in".
///
/// The token store here never resolves, which is what holds the state still.
@JeebPreview(
  group: 'reviews',
  name: 'Resolving session id',
  size: _reviewsListScreenPhoneBox,
)
Widget reviewsListScreenResolvingSession() => _reviewsListScreenFramed(
      ReviewsListScreen(
        repository: const ReviewsListScreenPendingRepository(),
        authTokenStore: ReviewsListScreenStalledTokenStore(),
      ),
      muteTicker: true,
    );
