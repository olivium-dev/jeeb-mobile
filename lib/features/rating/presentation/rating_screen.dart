import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../mixed_direction/presentation/mixed_direction_text.dart';
import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';
import 'widgets/feedback_avatar.dart';
import 'widgets/feedback_header.dart';
import 'widgets/feedback_star_input.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/rating_screen_fixtures.dart';

/// Bundles feedback content state: reduces parameters and keeps widgets compact.
@immutable
class FeedbackContentData {
  const FeedbackContentData({
    required this.isClient,
    required this.rateeName,
    required this.rateeAvatarUrl,
    required this.stars,
    required this.commentController,
    required this.onStarsChanged,
  });

  final bool isClient;
  final String rateeName;
  final String? rateeAvatarUrl;
  final int stars;
  final TextEditingController commentController;
  final ValueChanged<int> onStarsChanged;
}

/// Legacy feedback screen: PopScope(canPop: false), no dismiss, mandatory route home (JM-034).
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.deliveryId,
    this.isClient = true,
    this.rateeName = '',
    this.rateeAvatarUrl,
    this.repository,
  });

  final String deliveryId;
  final bool isClient;
  final String rateeName;
  final String? rateeAvatarUrl;
  /// Test seam — defaults to `sl<RatingRepository>()` at runtime.
  final RatingRepository? repository;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  RatingRepository get _repository =>
      widget.repository ??
      (sl.isRegistered<RatingRepository>() ? sl<RatingRepository>() : null) ??
      _NoopRatingRepository();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onStarsChanged(int value) => setState(() => _stars = value);

  Future<void> _onSubmit() async {
    if (_stars == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _repository.submitRating(
        deliveryId: widget.deliveryId,
        stars: _stars,
        isClient: widget.isClient,
        comment: _commentController.text.isEmpty
            ? null
            : _commentController.text,
      );
    } catch (_) {
      // Fire-and-forget: transient failure routes home anyway to avoid stranding.
    }
    if (!mounted) return;
    context.go('/');
  }

  FeedbackContentData get _data => FeedbackContentData(
        isClient: widget.isClient,
        rateeName: widget.rateeName,
        rateeAvatarUrl: widget.rateeAvatarUrl,
        stars: _stars,
        commentController: _commentController,
        onStarsChanged: _onStarsChanged,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // D56: mandatory — suppress system back; no leading/close affordance.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.mutualRatingTitle,
          backgroundColor: Theme.of(context).colorScheme.surface,
          automaticallyImplyLeading: false,
        ),
        body: _FeedbackBody(
          data: _data,
          submitting: _submitting,
          onSubmit: _onSubmit,
        ),
      ),
    );
  }
}

/// Fallback when no DI: keeps submit → home honest without network calls.
class _NoopRatingRepository implements RatingRepository {
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) {
    throw UnimplementedError();
  }
}

class _FeedbackBody extends StatelessWidget {
  const _FeedbackBody({
    required this.data,
    required this.submitting,
    required this.onSubmit,
  });

  final FeedbackContentData data;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        identifier: 'rating_root',
        container: true,
        child: Column(
          children: [
            Expanded(child: _FeedbackScrollArea(data: data)),
            _FeedbackFooter(submitting: submitting, onSubmit: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _FeedbackScrollArea extends StatelessWidget {
  const _FeedbackScrollArea({required this.data});

  final FeedbackContentData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.large,
        vertical: Spacing.medium,
      ),
      child: _FeedbackContent(data: data),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({required this.data});

  final FeedbackContentData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.large),
        FeedbackAvatar(name: data.rateeName, avatarUrl: data.rateeAvatarUrl),
        const SizedBox(height: Spacing.xLarge),
        FeedbackHeader(isClient: data.isClient),
        const SizedBox(height: Spacing.xLarge),
        _FeedbackCommentField(controller: data.commentController),
        const SizedBox(height: Spacing.xLarge),
        _FeedbackRateName(name: data.rateeName),
        const SizedBox(height: Spacing.medium),
        FeedbackStarInput(stars: data.stars, onChanged: data.onStarsChanged),
      ],
    );
  }
}

class _FeedbackCommentField extends StatelessWidget {
  const _FeedbackCommentField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'feedback_comment_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        hintText: l10n.feedbackCommentHint,
        maxLines: 4,
        maxLength: 1000,
      ),
    );
  }
}

class _FeedbackRateName extends StatelessWidget {
  const _FeedbackRateName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MixedDirectionText(
      AppLocalizations.of(context).feedbackRateName(name),
      textAlign: TextAlign.center,
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FeedbackFooter extends StatelessWidget {
  const _FeedbackFooter({required this.submitting, required this.onSubmit});

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      // Semantics boundary: keeps CTA queryable (folds into rating_root without it).
      child: Semantics(
        identifier: 'rating_submit_cta',
        button: true,
        container: true,
        explicitChildNodes: true,
        child: OmdsLoadingButton(
          text: l10n.feedbackSubmit,
          isLoading: submitting,
          onTap: onSubmit,
        ),
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
// Render tests: test/previews/rating/rating_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (the `OMDSAppBar` surface) and [jeebPreviewHost]
//    wraps every child in one as well, so the canvas shows two nested
//    Scaffolds. The inner one is the real surface; the outer contributes only a
//    background. The canvas box is therefore a real device
//    ([_ratingScreenPhoneBox], 390x844) rather than the harness's default
//    390x200 — an avatar, a two-paragraph header, a four-line comment box, a
//    star row and a footer CTA cannot be judged in a 200 pt strip.
//
// 2. It cannot be TAPPED without a `Router`. A successful submit ends in
//    `context.go('/')` (AC2/AC3), which throws under the bare `MaterialApp` the
//    canvas host and the render harness provide.
//    [_RatingScreenHost] supplies a local [GoRouter] whose `/` is a stand-in
//    naming the edge, so every card here is explorable — pick stars, type a
//    comment, submit, and land somewhere legible instead of crashing the card.
//    The screen is mounted at the REAL route path (`/orders/:id/feedback`,
//    `app_router.dart:1433`) so `go('/')` is a genuine transition rather than a
//    rebuild of the same page.
//
// 3. The screen keeps its two interesting states — the picked star count and
//    the in-flight submit — in PRIVATE `State` fields with no seam of any kind:
//    `_stars` moves only through `FeedbackStarInput.onChanged` and `_submitting`
//    only through a tap on the footer CTA. [_RatingScreenDriver] therefore
//    reaches those states the way a user does: it walks its own subtree once,
//    after the first frame, and invokes the very callbacks the widgets were
//    handed. No production seam was added for this, and the `repository:` seam
//    the screen already has is what keeps every state network-free by
//    construction rather than by the guard in [jeebPreviewHost].
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * **The submit CTA is live at zero stars and silently does nothing.**
//    `_FeedbackFooter` builds `OmdsLoadingButton` with `isEnabled` left at its
//    `true` default, so the CTA paints at full opacity with a live
//    `GestureDetector` from the first frame, and `_onSubmit` opens with
//    `if (_stars == 0 || _submitting) return;`. Tapping it produces no toast, no
//    inline error and no scroll-to-the-stars. That is a dead end and not a
//    cosmetic one: the screen is `PopScope(canPop: false)` with
//    `automaticallyImplyLeading: false` and no close X (D56), so picking a star
//    is the ONLY exit from it and nothing on screen says so
//    (`Client rates the jeeber`, and [ratingScreenStarsSelected] for the
//    contrast).
//
//  * **The shipped route can render "Rate " with no one in it.** The only
//    builder for this screen reads `state.uri.queryParameters['name'] ?? ''`
//    (`app_router.dart:1441`) and nothing in `lib/` navigates here — the route
//    is reachable only by deep link — so an incoming link without `?name=`
//    lands on `feedbackRateName('')`, i.e. the bare verb and a dangling space,
//    over `FeedbackAvatar`'s "?" placeholder. [ratingScreenNoRateeName] is that
//    state, and it is the DEFAULT of the widget's own constructor
//    (`rateeName = ''`), not a contrived one.
//
//  * **A failed submit is indistinguishable from a successful one.**
//    `_onSubmit` catches every error, drops the stars and the typed comment on
//    the floor, and routes home anyway — deliberately, per its own comment, so
//    a transient failure cannot strand a user on an un-dismissable screen. The
//    cost is that this screen has NO error state to preview:
//    [ratingScreenSubmitFailed] renders the home stand-in, exactly as the happy
//    path would, and the user is never told their rating was lost.
//
//  * **Nothing is disabled while the submit is in flight.** [ratingScreenSubmitting]
//    holds the CTA spinner open, and behind it the star row is still tappable
//    and the comment field still editable — so a rating can be changed after the
//    value has already gone to the gateway. `_onSubmit`'s `_submitting` guard
//    blocks a second SUBMIT, but nothing blocks the edits, and `_submitting` is
//    never reset (the screen always navigates away instead).
//
//  * **`MixedDirectionText` is a no-op at this call site.** `_FeedbackRateName`
//    hands it the whole localized sentence, and `detectDirection` keys off the
//    FIRST character — which is always the localized verb ("Rate" / "قيّم"),
//    never the name. The widget's stated purpose is to give a name its own
//    direction inside a differently-directed line; here it can only ever echo
//    the locale. The `AR RTL dark` cards of the matrixed states are where that
//    is visible. (`mixed_direction_text.dart` also still carries an
//    `ORPHAN … zero refs` marker from JEBV4-227, which this call site disproves.)

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _ratingScreenPhoneBox = Size(390, 844);

/// Where `context.go('/')` lands in the canvas.
///
/// The real destination is the role-aware shell (customer → orders home;
/// jeeber → Dashboard tab), which builds its own cubits off DI. Here the route
/// only has to exist and say that the screen left, so a submit is reviewable
/// instead of fatal — and, for [ratingScreenSubmitFailed], so that "the rating
/// was dropped and you were sent home anyway" is something a reviewer can
/// actually see happen.
class _RatingScreenHomeStandIn extends StatelessWidget {
  const _RatingScreenHomeStandIn();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy.
          'Home shell (preview stand-in)',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Drives the screen's two private `State` fields by invoking the callbacks its
/// own children were handed, once, after the first frame.
///
/// `_stars` and `_submitting` have no constructor seam, no cubit and no key —
/// the only way in is `FeedbackStarInput.onChanged` and the footer CTA's
/// `onTap`, both of which are closures over `_RatingScreenState`. So this walks
/// its subtree for those two widgets and calls them. It is deliberately NOT a
/// synthetic pointer event: what a real tap adds over this is the
/// `GestureDetector` hit-test and `OmdsLoadingButton`'s `canTap` gate, and both
/// are open in every state driven here (`isEnabled` defaults to true and
/// `isLoading` is false until the first submit), so the two paths do the same
/// thing while this one does not depend on where the widgets happen to land.
///
/// Drives at most once — [_done] guards the rebuild that `onChanged`'s own
/// `setState` provokes.
class _RatingScreenDriver extends StatefulWidget {
  const _RatingScreenDriver({
    required this.child,
    this.stars = 0,
    this.submit = false,
  });

  /// The subtree to drive — a [RatingScreen].
  final Widget child;

  /// Star count to pick, or 0 to leave the screen untouched.
  final int stars;

  /// Whether to also tap the footer CTA after picking.
  final bool submit;

  @override
  State<_RatingScreenDriver> createState() => _RatingScreenDriverState();
}

class _RatingScreenDriverState extends State<_RatingScreenDriver> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.stars == 0 && !widget.submit) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  void _drive() {
    if (_done || !mounted) return;
    _done = true;
    if (widget.stars > 0) {
      // Synchronous: `_onStarsChanged` calls `setState`, so `_stars` is already
      // the picked value by the time the CTA below reads it.
      _findInSubtree<FeedbackStarInput>()?.onChanged(widget.stars);
    }
    if (widget.submit) _findInSubtree<OmdsLoadingButton>()?.onTap();
  }

  /// First widget of type [T] below this element, in depth-first order.
  T? _findInSubtree<T extends Widget>() {
    T? found;
    void visit(Element element) {
      if (found != null) return;
      final Widget candidate = element.widget;
      if (candidate is T) {
        found = candidate;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Mounts [RatingScreen] at its real route path under a local [GoRouter].
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state. The
/// initial location is the REAL `/orders/:id/feedback` path, so the screen's
/// `context.go('/')` is a transition to the stand-in rather than a rebuild of
/// this same page. `Router.withConfig` is exactly what `MaterialApp.router` does
/// internally, so this adds a Router and nothing else — theme, locale and text
/// scale still come from the preview host above it.
class _RatingScreenHost extends StatefulWidget {
  const _RatingScreenHost({
    required this.rateeName,
    this.isClient = true,
    this.repository = const RatingScreenFakeRepository(),
    this.stars = 0,
    this.submit = false,
  });

  final String rateeName;
  final bool isClient;
  final RatingRepository repository;
  final int stars;
  final bool submit;

  @override
  State<_RatingScreenHost> createState() => _RatingScreenHostState();
}

class _RatingScreenHostState extends State<_RatingScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/orders/$ratingScreenDeliveryId/feedback',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _RatingScreenHomeStandIn(),
      ),
      GoRoute(
        path: '/orders/:id/feedback',
        name: 'feedback',
        builder: (_, GoRouterState state) => _RatingScreenDriver(
          stars: widget.stars,
          submit: widget.submit,
          child: RatingScreen(
            deliveryId: state.pathParameters['id'] ?? '',
            isClient: widget.isClient,
            rateeName: widget.rateeName,
            repository: widget.repository,
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _ratingScreenHosted({
  required String rateeName,
  bool isClient = true,
  RatingRepository repository = const RatingScreenFakeRepository(),
  int stars = 0,
  bool submit = false,
}) =>
    _RatingScreenHost(
      rateeName: rateeName,
      isClient: isClient,
      repository: repository,
      stars: stars,
      submit: submit,
    );

/// The first of the two states the Screen Catalog signs off
/// ("Feedback — Client Rates Jeeber"), and the cold entry every other state
/// passes through: zero stars, empty comment.
///
/// It is also the dead end. The footer CTA is fully inked and tappable here and
/// `_onSubmit` returns on the spot, while `PopScope(canPop: false)` and the
/// absent close X mean picking a star is the only way off this screen — see the
/// section header.
///
/// Matrixed because this is the reading a reviewer signs off, and everything
/// that gives way on it gives way somewhere other than EN light: the header's
/// two centred paragraphs, the 4-line comment box with its `0/1000` counter,
/// and a star row that does NOT grow with the text scaler.
@JeebPreview(
  group: 'rating',
  name: 'Client rates the jeeber',
  size: _ratingScreenPhoneBox,
  matrix: true,
)
Widget ratingScreenClientRatesJeeber() =>
    _ratingScreenHosted(rateeName: ratingScreenJeeberRatee);

/// The other signed-off state ("Feedback — Jeeber Rates Client"): the same
/// screen with `isClient: false`, which swaps ONE string — `FeedbackHeader`'s
/// subtitle, from "evaluate the delivery man" to "evaluate the client".
///
/// Worth its own card because that single word is the whole of this screen's
/// audience awareness: the title, the CTA, the comment hint and the star row are
/// identical for both sides, and `isClient` is otherwise only a flag forwarded
/// to the repository.
@JeebPreview(
  group: 'rating',
  name: 'Jeeber rates the client',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenJeeberRatesClient() => _ratingScreenHosted(
      rateeName: ratingScreenClientRatee,
      isClient: false,
    );

/// The empty state — and the one the shipped route actually produces.
///
/// `rateeName` defaults to `''` and the only builder for this screen fills it
/// from an optional query parameter, so a deep link without `?name=` renders
/// "Rate " over a "?" avatar: an un-dismissable screen asking for a rating of
/// nobody. Nothing in `lib/` navigates to this route, which is precisely why
/// the parameter cannot be assumed present.
@JeebPreview(
  group: 'rating',
  name: 'Deep link · no ratee name',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenNoRateeName() => _ratingScreenHosted(rateeName: '');

/// The layout ceiling: a full unabbreviated name in the one line that
/// interpolates it.
///
/// `_FeedbackRateName` sets no `maxLines` and no `overflow`, so this degrades by
/// wrapping — good behaviour that is one `maxLines:` away from an ellipsis
/// through the middle of the only name on the screen. Matrixed because the
/// `EN 200% text` card is where the wrapped line starts pushing the star row
/// toward the fold, and the `AR RTL dark` card is where a latin name sits inside
/// a mirrored sentence — the case `MixedDirectionText` is nominally here for and
/// demonstrably does nothing about (section header).
@JeebPreview(
  group: 'rating',
  name: 'Long ratee name',
  size: _ratingScreenPhoneBox,
  matrix: true,
)
Widget ratingScreenLongName() =>
    _ratingScreenHosted(rateeName: ratingScreenLongRatee);

/// Four stars picked, nothing submitted — the state a user is in immediately
/// before the CTA becomes meaningful.
///
/// Put this beside [ratingScreenClientRatesJeeber]: the footer is pixel-for-pixel
/// identical in both, which is the point. Nothing about the CTA changes when the
/// tap stops being a no-op, so the control gives the user no signal about the
/// only precondition it has.
@JeebPreview(
  group: 'rating',
  name: 'Four stars picked',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenStarsSelected() => _ratingScreenHosted(
      rateeName: ratingScreenRatedRatee,
      stars: 4,
    );

/// The in-flight submit, held open by a write that never lands.
///
/// `_submitting` is set and then only ever left by navigating away, so an
/// unsettleable [Completer] is the only way to inspect the CTA spinner. Note
/// what is NOT blocked behind it: the star row is still tappable and the comment
/// field still editable, so the rating on screen can drift away from the one
/// already sent. There is also no way out — the mandatory contract holds while
/// the request hangs.
@JeebPreview(
  group: 'rating',
  name: 'Submitting · CTA spinner',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenSubmitting() => _ratingScreenHosted(
      rateeName: ratingScreenSubmittingRatee,
      repository: const RatingScreenStalledRepository(),
      stars: 4,
      submit: true,
    );

/// A submit the gateway rejected — and this screen's whole error vocabulary.
///
/// `_onSubmit` swallows the typed [RatingRepositoryException], discards the
/// stars and the comment, and routes home exactly as a success would, so this
/// card renders the home stand-in and NOT an error surface. Deliberate (the
/// mandatory terminal must not strand anyone), but the user is never told the
/// rating was lost and cannot get back to re-enter it: the route is gone from
/// the stack and nothing in the app navigates to it.
@JeebPreview(
  group: 'rating',
  name: 'Submit failed · silently routed home',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenSubmitFailed() => _ratingScreenHosted(
      rateeName: ratingScreenFailedRatee,
      repository: const RatingScreenFakeRepository(throwOnSubmit: true),
      stars: 4,
      submit: true,
    );
