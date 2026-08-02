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

/// Bundles all feedback content data into one parameter.
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

/// Mandatory contract: no skip/dismiss, submit persists via RatingRepository, routes to role-aware shell.
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
      // Fire-and-forget; transient failure must not strand user.
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

/// Fallback for unregistered RatingRepository.
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
