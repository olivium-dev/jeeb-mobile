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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _ratingScreenPhoneBox = Size(390, 844);

/// Where `context.go('/')` lands in the canvas.
/// The real destination is the role-aware shell (customer → orders home;
/// jeeber → Dashboard tab), which builds its own cubits off DI. Here the route
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
/// `_stars` and `_submitting` have no constructor seam, no cubit and no key —
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
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state. The
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
/// `rateeName` defaults to `''` and the only builder for this screen fills it
@JeebPreview(
  group: 'rating',
  name: 'Deep link · no ratee name',
  size: _ratingScreenPhoneBox,
)
Widget ratingScreenNoRateeName() => _ratingScreenHosted(rateeName: '');

/// The layout ceiling: a full unabbreviated name in the one line that
/// interpolates it.
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
/// `_submitting` is set and then only ever left by navigating away, so an
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
/// `_onSubmit` swallows the typed [RatingRepositoryException], discards the
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
