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
    // dismissed without submitting. There is intentionally no leading/close
    // affordance.
    //
    // Run-22 replacement P1 (hardware BACK exited to the launcher here):
    // `PopScope(canPop: false)` alone only fires when the `Navigator` has
    // something to pop. This terminal is typically reached via
    // `context.goNamed('mutual-rating')` (receipt confirm / OTP handover),
    // which REPLACES the stack — the screen is then the lone root page,
    // go_router's `popRoute` sees nothing to pop, and the BACK event
    // propagated to the OS, backgrounding the app mid-mandatory-rating. The
    // `BackButtonListener` intercepts the system BACK BEFORE go_router's
    // delegate and consumes it unconditionally, suppressing BACK at BOTH
    // stack positions (same mechanism as RootAwareBackScope, but suppress
    // rather than reroute — routing home would defeat the mandatory rating).
    // The inner PopScope stays for predictive-back visuals and as a guard for
    // non-system pop paths.
    //
    // `BackButtonListener` requires a `Router` ancestor (production runs under
    // `MaterialApp.router`). In a plain-`Navigator` host (widget tests,
    // previews) `PopScope` alone already suppresses BACK correctly, so the
    // listener is added only when a Router exists.
    final scope = PopScope(
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
    if (Router.maybeOf(context) == null) return scope;
    return BackButtonListener(
      onBackButtonPressed: () async => true,
      child: scope,
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
      // The blind-reveal phases are server-owned (T-BE-025 cron) and are not
      // reached on the mandatory JM-034 path; fall back to the input view so a
      // stale state never strands the user without a submit affordance.
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

/// A selectable rating tag. [key] is the ON-THE-WIRE value sent to the gateway
/// and MUST be drawn from the gateway's Jeeb rating tag taxonomy
/// (`JeebRatingVocabulary.AllowedTags`: `punctuality`, `communication`,
/// `package_condition`, `courtesy`, `navigation`). [label] is a stable
/// English fallback — used by the JEBV4-297 wire-contract test below and as
/// the `_tagLabel` default for any future tag added here without a matching
/// ARB key. The actual ON-SCREEN label is localized via `_tagLabel`
/// (JEBV4-296), never this field directly.
///
/// JEBV4-297: previously the chips sent their DISPLAY LABELS
/// (`Punctual`/`Careful`/`Friendly`/`Fast`) as the wire value. The gateway
/// lowercases each tag and rejects anything outside the taxonomy with a 400
/// (`'<tag>' is not a recognised Jeeb rating tag.`), so selecting ANY tag made
/// `POST /v1/ratings/jeeb/submit` fail. The wire value is now the canonical key.
class MutualRatingTag {
  const MutualRatingTag({required this.key, required this.label});
  final String key;
  final String label;
}

/// Canonical Jeeb rating tags — [MutualRatingTag.key] values mirror the gateway
/// `JeebRatingVocabulary.AllowedTags` taxonomy and are the ON-THE-WIRE values.
/// Exposed for the JEBV4-297 wire-contract test.
const kMutualRatingTags = <MutualRatingTag>[
  MutualRatingTag(key: 'punctuality', label: 'Punctual'),
  MutualRatingTag(key: 'communication', label: 'Communication'),
  MutualRatingTag(key: 'package_condition', label: 'Careful'),
  MutualRatingTag(key: 'courtesy', label: 'Friendly'),
  MutualRatingTag(key: 'navigation', label: 'Navigation'),
];

/// JEBV4-296: maps a canonical wire key to its localized ARB label. Falls
/// back to [MutualRatingTag.label] for any future tag added to
/// `kMutualRatingTags` without a matching ARB key, so the screen never
/// renders blank.
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
        // JEBV4-296: `textDirection` is passed explicitly (rather than
        // relying on Wrap's implicit ambient-Directionality fallback) so the
        // chip order is provably RTL-safe under `ar` — logical order stays
        // punctuality→communication→package_condition→courtesy→navigation,
        // mirrored right-to-left on screen.
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
    // Dynamic per-tag id keyed on the canonical taxonomy key (stable across
    // i18n/RTL) — 41_GUARDRAILS_TESTING §1.1 dynamic-item form.
    return Semantics(
      identifier: 'mutual_rating_tag_${tag.key}',
      container: true,
      button: true,
      selected: selected,
      child: OmdsChip(
        label: label,
        isSelected: selected,
        // Send the canonical taxonomy KEY, not the display label (JEBV4-297).
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
