import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/mutual_rating_cubit.dart';
import '../application/mutual_rating_state.dart';

/// Mutual blind rating screen (T-MOB-020).
///
/// Shown after delivery completion (status=done). Both parties rate
/// independently; neither sees the other's rating until both submit or
/// 7 days elapse (auto-reveal via T-BE-025 cron).
class MutualRatingScreen extends StatelessWidget {
  const MutualRatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.mutualRatingTitle),
      body: BlocBuilder<MutualRatingCubit, MutualRatingState>(
        builder: _buildBody,
      ),
    );
  }

  Widget _buildBody(BuildContext context, MutualRatingState state) {
    switch (state.phase) {
      case MutualRatingPhase.inputting:
        return _InputView(state: state);
      case MutualRatingPhase.submitting:
        return const Center(child: OmdsLoadingState());
      case MutualRatingPhase.awaitingOther:
      case MutualRatingPhase.polling:
        return _AwaitingView(state: state);
      case MutualRatingPhase.revealed:
        return _RevealedView(state: state, isAutoReveal: false);
      case MutualRatingPhase.autoRevealed:
        return _RevealedView(state: state, isAutoReveal: true);
      case MutualRatingPhase.error:
        return _ErrorView(state: state);
    }
  }
}

class _InputView extends StatelessWidget {
  const _InputView({required this.state});
  final MutualRatingState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _InputScrollArea(state: state)),
          _SubmitButton(stars: state.stars),
        ],
      ),
    );
  }
}

class _InputScrollArea extends StatelessWidget {
  const _InputScrollArea({required this.state});
  final MutualRatingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mutualRatingSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Spacing.xLarge),
          _StarSection(stars: state.stars),
          const SizedBox(height: Spacing.xLarge),
          _CommentField(comment: state.comment),
          const SizedBox(height: Spacing.medium),
          _TagsSection(selectedTags: state.tags),
        ],
      ),
    );
  }
}

class _StarSection extends StatelessWidget {
  const _StarSection({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars stars selected',
      child: OmdsStarRating(
        rating: stars,
        onRatingChanged: (v) => context.read<MutualRatingCubit>().setStars(v),
      ),
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField({required this.comment});
  final String comment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsTextField(
      hintText: l10n.ratingCommentHint,
      maxLines: 4,
      maxLength: 500,
      onChanged: (v) => context.read<MutualRatingCubit>().setComment(v),
    );
  }
}

const _kAvailableTags = ['Punctual', 'Careful', 'Friendly', 'Fast'];

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.selectedTags});
  final List<String> selectedTags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mutualRatingTagsLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Wrap(
          spacing: Spacing.xSmall,
          children: _kAvailableTags
              .map((t) => _TagChip(tag: t, selected: selectedTags.contains(t)))
              .toList(),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.selected});
  final String tag;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return OmdsChip(
      label: tag,
      isSelected: selected,
      onTap: () => context.read<MutualRatingCubit>().toggleTag(tag),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: OmdsPrimaryButton(
        text: l10n.mutualRatingSubmit,
        isEnabled: stars > 0,
        onTap: () => context.read<MutualRatingCubit>().submit(),
      ),
    );
  }
}

class _AwaitingView extends StatelessWidget {
  const _AwaitingView({required this.state});
  final MutualRatingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmdsLoadingState(),
            const SizedBox(height: Spacing.xLarge),
            Text(
              l10n.mutualRatingAwaitingTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.mutualRatingAwaitingBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealedView extends StatelessWidget {
  const _RevealedView({required this.state, required this.isAutoReveal});
  final MutualRatingState state;
  final bool isAutoReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = isAutoReveal
        ? l10n.mutualRatingAutoRevealedTitle
        : l10n.mutualRatingRevealedTitle;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.large),
            _CounterpartRatingDisplay(state: state, isAutoReveal: isAutoReveal),
            const SizedBox(height: Spacing.xLarge),
            OmdsPrimaryButton(
              text: l10n.mutualRatingDone,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterpartRatingDisplay extends StatelessWidget {
  const _CounterpartRatingDisplay({
    required this.state,
    required this.isAutoReveal,
  });
  final MutualRatingState state;
  final bool isAutoReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counterpart = state.counterpartRating;
    if (counterpart == null) {
      return Text(l10n.mutualRatingNoCounterRating);
    }
    return Column(
      children: [
        Text(
          l10n.mutualRatingTheirStars(counterpart.stars),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (counterpart.comment != null) ...[
          const SizedBox(height: Spacing.small),
          Text(
            counterpart.comment!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state});
  final MutualRatingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      message: l10n.mutualRatingError,
      onRetry: () => context.read<MutualRatingCubit>().submit(),
    );
  }
}
