import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/mutual_rating_cubit.dart';
import '../application/mutual_rating_state.dart';

/// Mandatory post-delivery rating screen (JM-034) — the canonical rating
/// terminal (`/orders/:id/mutual-rate`, `mode=jeeber` flips audience).
///
/// AC1 (D56): the rating is MANDATORY — there is no skip/dismiss control and
/// the system back gesture is suppressed (`PopScope(canPop: false)`).
/// AC2/AC3: a successful submit navigates to the role-aware shell
/// (`context.go('/')`) — customer → customer-orders-home (Requests tab,
/// `orders_home_new_order_fab`); jeeber → Dashboard tab (`shell_tab_dashboard`).
/// AC4: `rating_root` is the signature id present on this canonical terminal
/// (the legacy `/feedback` `RatingScreen` exposes the same id).
class MutualRatingScreen extends StatelessWidget {
  const MutualRatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // D56: suppress the system back gesture so the mandatory rating cannot be
    // dismissed without submitting. `canPop: false` blocks both the OS back and
    // any predictive-back; there is intentionally no leading/close affordance.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.mutualRatingTitle,
          automaticallyImplyLeading: false,
        ),
        // `rating_root` is the screen signature id (JM-034 §2.14, AC4). A
        // boundary container so the id surfaces as its own queryable node.
        body: Semantics(
          identifier: 'rating_root',
          container: true,
          child: BlocConsumer<MutualRatingCubit, MutualRatingState>(
            listenWhen: (p, n) => p.phase != n.phase,
            listener: _onPhaseChanged,
            builder: _buildBody,
          ),
        ),
      ),
    );
  }

  /// Nav side-effects live in the listener, never the builder (a `context.go`
  /// in `build` would fire every rebuild). On the mandatory terminal phase we
  /// route to the role-aware shell, which selects the correct landing tab from
  /// the session role (customer → Requests; jeeber → Dashboard).
  void _onPhaseChanged(BuildContext context, MutualRatingState state) {
    if (state.phase == MutualRatingPhase.submitted) {
      context.go('/');
    }
  }

  Widget _buildBody(BuildContext context, MutualRatingState state) {
    switch (state.phase) {
      case MutualRatingPhase.inputting:
        return _InputView(state: state);
      case MutualRatingPhase.submitting:
      case MutualRatingPhase.submitted:
        return const Center(child: OmdsLoadingState());
      case MutualRatingPhase.error:
        return const _ErrorView();
      // feedback-double-blind-reveal (SC-043/SC-093): the blind-reveal phases
      // are reached only on the standalone reveal path (revealMode=true). The
      // mandatory JM-034 path never enters them (submit → submitted → shell).
      // The counterpart's rating is rendered ONLY once the SERVER reports
      // revealed / autoRevealed — never inferred client-side.
      case MutualRatingPhase.awaitingOther:
      case MutualRatingPhase.polling:
        return const _AwaitingRevealView();
      case MutualRatingPhase.revealed:
      case MutualRatingPhase.autoRevealed:
        return _RevealedView(state: state);
    }
  }
}

/// Shown after the user has rated but the server has NOT yet revealed both
/// sides (double-blind). The counterpart's rating stays hidden here.
class _AwaitingRevealView extends StatelessWidget {
  const _AwaitingRevealView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top,
              size: Sizes.twoXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.mutualRatingAwaitingTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              l10n.mutualRatingAwaitingBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once the SERVER reveals both ratings (or the 7-day auto-reveal fired).
/// The counterpart's stars become visible here for the first time.
class _RevealedView extends StatelessWidget {
  const _RevealedView({required this.state});

  final MutualRatingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counterpart = state.counterpartRating;
    final isAuto = state.phase == MutualRatingPhase.autoRevealed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility,
              size: Sizes.twoXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            Text(
              isAuto
                  ? l10n.mutualRatingAutoRevealedTitle
                  : l10n.mutualRatingRevealedTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              counterpart == null
                  ? l10n.mutualRatingNoCounterRating
                  : l10n.mutualRatingTheirStars(counterpart.stars),
              key: const Key('mutual-rating-counterpart'),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (counterpart?.comment != null &&
                counterpart!.comment!.isNotEmpty) ...[
              const SizedBox(height: Spacing.small),
              Text(
                counterpart.comment!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
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
      // QA: addressable handle for the star-rating input. `container: true`
      // surfaces the id as its own node even though OmdsStarRating renders
      // multiple tappable stars (CAP-1).
      identifier: 'mutual_rating_stars',
      container: true,
      label: '$stars stars selected',
      child: OmdsStarRating(
        key: const Key('mutualRating.stars'),
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
    return Semantics(
      // QA: addressable handle for the optional comment field.
      identifier: 'mutual_rating_comment',
      textField: true,
      label: l10n.ratingCommentHint,
      child: OmdsTextField(
        key: const Key('mutualRating.comment'),
        hintText: l10n.ratingCommentHint,
        maxLines: 4,
        maxLength: 500,
        onChanged: (v) => context.read<MutualRatingCubit>().setComment(v),
      ),
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
      // `rating_submit_cta` is the W1 contract id (JM-034 §2.14). No
      // `button: true` — OmdsPrimaryButton already exposes the button role;
      // `container: true` keeps this identifier its own queryable node.
      child: Semantics(
        identifier: 'rating_submit_cta',
        container: true,
        child: OmdsPrimaryButton(
          key: const Key('mutualRating.submit'),
          text: l10n.mutualRatingSubmit,
          isEnabled: stars > 0,
          onTap: () => context.read<MutualRatingCubit>().submit(),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      message: l10n.mutualRatingError,
      onRetry: () => context.read<MutualRatingCubit>().submit(),
    );
  }
}
