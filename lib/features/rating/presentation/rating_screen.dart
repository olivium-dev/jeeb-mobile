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

/// Immutable bundle of everything the feedback content column renders, so the
/// state is threaded through one parameter instead of six (keeps every widget
/// build under the 20-line ceiling).
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

/// Legacy feedback/rating screen (`/orders/:id/feedback`, Figma 56614:20132).
///
/// JM-034 reconciliation (AC4): the canonical mandatory terminal is
/// [MutualRatingScreen] (`/orders/:id/mutual-rate`); this `/feedback` variant is
/// retained but made compliant with the same mandatory contract:
///   * AC1/D56: NO skip/dismiss control (the close X was removed) and the
///     system back gesture is suppressed (`PopScope(canPop: false)`).
///   * AC2/AC3: a successful submit persists via [RatingRepository] and routes
///     to the role-aware shell (`context.go('/')`) — customer →
///     customer-orders-home; jeeber → Dashboard tab.
///   * AC4: `rating_root` is the signature id present on both rating routes.
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.deliveryId,
    this.isClient = true,
    this.rateeName = '',
    this.rateeAvatarUrl,
    this.repository,
  });

  /// The delivery this feedback is attached to.
  final String deliveryId;

  /// True when a client is rating the delivery man; false when the delivery
  /// man is rating the client. Drives the subtitle copy and the rater role.
  final bool isClient;

  /// Display name of the person being rated (interpolated into "Rate {name}").
  final String rateeName;

  /// Optional avatar URL for the ratee; falls back to an initial.
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
      // Mandatory terminal: the rating is fire-and-forget; even a transient
      // failure must not strand the user on the un-dismissable screen, so we
      // still route home. The score-taking submit is idempotent server-side.
    }
    if (!context.mounted) return;
    // AC2/AC3: route to the role-aware shell (customer → customer-orders-home;
    // jeeber → Dashboard tab). `context.mounted` guards the async gap.
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

/// Fallback used only when no [RatingRepository] is registered (e.g. a widget
/// test that does not boot DI). Keeps the mandatory submit → home flow honest
/// without a network call; `fetchRatingStatus` is never called on this path.
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
      // `rating_root` is the signature id present on both rating routes
      // (JM-034 §2.14, AC4).
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
        color: theme.colorScheme.secondaryContainer,
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
      // `rating_submit_cta` is the W1 contract id (JM-034 §2.14). `container:
      // true` + `explicitChildNodes: true` make this an explicit Semantics
      // boundary so the id surfaces as its own queryable node (without it the
      // wrapper folds into the `rating_root` container, dropping the id).
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
