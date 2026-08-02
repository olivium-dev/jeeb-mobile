import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/mutual_rating_cubit.dart';
import '../application/mutual_rating_state.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/mutual_rating_screen_fixtures.dart';

class MutualRatingScreen extends StatelessWidget {
  const MutualRatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = PopScope(
      canPop: false,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.mutualRatingTitle,
          automaticallyImplyLeading: false,
        ),
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
    if (Router.maybeOf(context) == null) return scope;
    return BackButtonListener(
      onBackButtonPressed: () async => true,
      child: scope,
    );
  }

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
      case MutualRatingPhase.awaitingOther:
      case MutualRatingPhase.polling:
      case MutualRatingPhase.revealed:
      case MutualRatingPhase.autoRevealed:
        return _InputView(state: state);
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

class MutualRatingTag {
  const MutualRatingTag({required this.key, required this.label});
  final String key;
  final String label;
}

const kMutualRatingTags = <MutualRatingTag>[
  MutualRatingTag(key: 'punctuality', label: 'Punctual'),
  MutualRatingTag(key: 'communication', label: 'Communication'),
  MutualRatingTag(key: 'package_condition', label: 'Careful'),
  MutualRatingTag(key: 'courtesy', label: 'Friendly'),
  MutualRatingTag(key: 'navigation', label: 'Navigation'),
];

String _tagLabel(AppLocalizations l10n, MutualRatingTag tag) {
  switch (tag.key) {
    case 'punctuality':
      return l10n.mutualRatingTagPunctuality;
    case 'communication':
      return l10n.mutualRatingTagCommunication;
    case 'package_condition':
      return l10n.mutualRatingTagPackageCondition;
    case 'courtesy':
      return l10n.mutualRatingTagCourtesy;
    case 'navigation':
      return l10n.mutualRatingTagNavigation;
    default:
      return tag.label;
  }
}

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
          textDirection: Directionality.of(context),
          children: kMutualRatingTags
              .map(
                (t) => _TagChip(
                  tag: t,
                  label: _tagLabel(l10n, t),
                  selected: selectedTags.contains(t.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.label,
    required this.selected,
  });
  final MutualRatingTag tag;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'mutual_rating_tag_${tag.key}',
      container: true,
      button: true,
      selected: selected,
      child: OmdsChip(
        label: label,
        isSelected: selected,
        onTap: () => context.read<MutualRatingCubit>().toggleTag(tag.key),
      ),
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
// ============================== JEEB PREVIEWS ==============================

const Size _mutualRatingScreenPhoneBox = Size(390, 844);

final class MutualRatingScreenCaptions {
  MutualRatingScreenCaptions._();

  static const String fresh = 'preview · fresh · client rates jeeber';
  static const String jeeberSide = 'preview · fresh · jeeber rates client';
  static const String filled = 'preview · five stars · every tag';
  static const String submitting = 'preview · submit in flight';
  static const String submitFailed = 'preview · submit rejected';
  static const String awaitingOther = 'preview · stale awaitingOther phase';
}

class _MutualRatingScreenEdgeStandIn extends StatelessWidget {
  const _MutualRatingScreenEdgeStandIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic, not shipped copy.
          'role-aware shell',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _MutualRatingScreenHost extends StatefulWidget {
  const _MutualRatingScreenHost({
    required this.createCubit,
    required this.caption,
  });

  final MutualRatingCubit Function() createCubit;
  final String caption;

  @override
  State<_MutualRatingScreenHost> createState() =>
      _MutualRatingScreenHostState();
}

class _MutualRatingScreenHostState extends State<_MutualRatingScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/rate',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _MutualRatingScreenEdgeStandIn(),
      ),
      GoRoute(
        path: '/rate',
        builder: (_, _) => BlocProvider<MutualRatingCubit>(
          create: (_) => widget.createCubit(),
          child: const MutualRatingScreen(),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            widget.caption,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Router.withConfig(config: _router)),
      ],
    );
  }
}

Widget _mutualRatingScreenHosted(
  MutualRatingCubit Function() createCubit,
  String caption,
) =>
    _MutualRatingScreenHost(createCubit: createCubit, caption: caption);

@JeebPreview(
  group: 'rating',
  name: 'Fresh · client rates jeeber',
  size: _mutualRatingScreenPhoneBox,
  matrix: true,
)
Widget mutualRatingScreenFresh() => _mutualRatingScreenHosted(
      mutualRatingScreenFreshCubit,
      MutualRatingScreenCaptions.fresh,
    );

@JeebPreview(
  group: 'rating',
  name: 'Fresh · jeeber rates client',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenJeeberSide() => _mutualRatingScreenHosted(
      () => mutualRatingScreenFreshCubit(isClient: false),
      MutualRatingScreenCaptions.jeeberSide,
    );

@JeebPreview(
  group: 'rating',
  name: 'Filled · five stars, every tag',
  size: _mutualRatingScreenPhoneBox,
  matrix: true,
)
Widget mutualRatingScreenFilled() => _mutualRatingScreenHosted(
      mutualRatingScreenFilledCubit,
      MutualRatingScreenCaptions.filled,
    );

@JeebPreview(
  group: 'rating',
  name: 'Submitting · in flight',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenSubmitting() => _mutualRatingScreenHosted(
      mutualRatingScreenSubmittingCubit,
      MutualRatingScreenCaptions.submitting,
    );

@JeebPreview(
  group: 'rating',
  name: 'Error · submit rejected',
  size: _mutualRatingScreenPhoneBox,
  matrix: true,
)
Widget mutualRatingScreenSubmitFailed() => _mutualRatingScreenHosted(
      mutualRatingScreenErrorCubit,
      MutualRatingScreenCaptions.submitFailed,
    );

@JeebPreview(
  group: 'rating',
  name: 'Stale · awaitingOther phase',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenAwaitingOther() => _mutualRatingScreenHosted(
      mutualRatingScreenAwaitingOtherCubit,
      MutualRatingScreenCaptions.awaitingOther,
    );
