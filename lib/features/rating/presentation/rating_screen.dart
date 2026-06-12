import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../mixed_direction/presentation/mixed_direction_text.dart';
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

/// Feedback / rating screen shared by both audiences (Figma 56614:20132).
///
/// A client rating the delivery man, or the delivery man rating the client —
/// same layout, audience-parameterised copy. Returns the chosen `stars` +
/// `comment` to the caller on submit (the upstream flow owns persistence via
/// the feedback-service through the gateway).
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.deliveryId,
    this.isClient = true,
    this.rateeName = '',
    this.rateeAvatarUrl,
  });

  /// The delivery this feedback is attached to.
  final String deliveryId;

  /// True when a client is rating the delivery man; false when the delivery
  /// man is rating the client. Drives the subtitle copy.
  final bool isClient;

  /// Display name of the person being rated (interpolated into "Rate {name}").
  final String rateeName;

  /// Optional avatar URL for the ratee; falls back to an initial.
  final String? rateeAvatarUrl;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onStarsChanged(int value) => setState(() => _stars = value);

  void _onSubmit() {
    setState(() => _submitting = true);
    Navigator.of(context).pop(<String, Object?>{
      'stars': _stars,
      'comment': _commentController.text,
    });
  }

  void _onClose() => Navigator.of(context).maybePop();

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
    return Scaffold(
      appBar: _FeedbackAppBar(onClose: _onClose),
      body: _FeedbackBody(
        data: _data,
        submitting: _submitting,
        onSubmit: _onSubmit,
      ),
    );
  }
}

class _FeedbackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FeedbackAppBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Titleless close-only variant: OMDSAppBar centralizes the surface theming,
    // zero elevation, and RTL-correct action placement.
    return OMDSAppBar(
      title: '',
      backgroundColor: Theme.of(context).colorScheme.surface,
      automaticallyImplyLeading: false,
      actions: [_FeedbackCloseAction(onClose: onClose)],
    );
  }
}

class _FeedbackCloseAction extends StatelessWidget {
  const _FeedbackCloseAction({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `container: true` + `explicitChildNodes: true` keep `feedback_close_button`
    // a distinct boundary node so its identifier survives the IconButton's own
    // button/InkWell semantics (same latent merge pattern as the submit button).
    return Semantics(
      identifier: 'feedback_close_button',
      button: true,
      container: true,
      explicitChildNodes: true,
      label: l10n.feedbackCloseLabel,
      child: IconButton(
        icon: const Icon(Icons.close),
        color: Theme.of(context).colorScheme.secondaryContainer,
        tooltip: l10n.feedbackCloseLabel,
        onPressed: onClose,
      ),
    );
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
        identifier: 'feedback_screen',
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
      // `container: true` + `explicitChildNodes: true` make this an explicit
      // Semantics boundary so `feedback_submit_button` surfaces as its own
      // queryable node. Without it the wrapper's button-semantics collides
      // with OmdsLoadingButton's own inner button node and the identifier is
      // folded up into the ancestor `feedback_screen` container (the screen
      // node absorbs the button flag + label and drops this id).
      child: Semantics(
        identifier: 'feedback_submit_button',
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
