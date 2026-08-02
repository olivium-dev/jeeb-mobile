import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/mutual_rating_cubit.dart';
import '../application/mutual_rating_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/rating/mutual_rating_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_mutualRatingScreenPhoneBox], 390x844) rather than the harness's default
//    390x200 — a scrolling form with a pinned footer button cannot be judged in
//    a 200 pt strip.
//
// 2. It is not merely un-tappable without a `Router` — it is un-SURVIVABLE.
//    `rating_submit_cta` reaches `context.go('/')` through the phase listener
//    the moment a submit succeeds, and the fixture repository succeeds. A
//    router-less host would throw on the one tap the whole screen exists for.
//    [_MutualRatingScreenHost] supplies a local [GoRouter] whose LONE ROOT page
//    is the rating terminal — the exact stack shape the run-22 P1 regression
//    was found in (reached via `goNamed`, nothing to pop) — plus a stand-in for
//    the role-aware shell that `context.go('/')` lands on. That also means the
//    previews exercise the real `BackButtonListener` branch rather than the
//    router-less `PopScope`-only fallback.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy. This
//    screen renders the SAME strings in every input state — the phase, the
//    star count, the selected tags and the audience (`isClient`) change
//    nothing that `find.text` can tell apart — so a caption is the only thing
//    that distinguishes one rendering from another, in the canvas and in the
//    render test's `expectedText`. Same device as
//    `KycStatusScreenWindow.label`. The render test additionally asserts the
//    real state behind each caption (submit enabled/disabled, chip selection,
//    which body branch built) so the caption cannot be the whole proof.
//
// State is driven the only way this screen allows: through the ambient
// [MutualRatingCubit], with the fakes and seeded cubits shared verbatim with
// the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/mutual_rating_screen_fixtures.dart`). No
// preview builds a `DioRatingRepository` and nothing here resolves GetIt —
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// One state is deliberately absent: `MutualRatingPhase.submitted`. It renders
// the same bare spinner as `submitting` and exists only to fire `context.go`,
// so it is a transition, not a picture. Reach it in the canvas by tapping
// through `Filled · five stars, every tag`.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * `_ErrorView` REPLACES the whole body, and nothing can put the input form
//    back. The cubit's only exits from `error` are `submitting` and then
//    `error` or `submitted`, so a permanent rejection (403 "not a party to
//    this delivery" — the `RatingFailure.unknown` this fixture uses) leaves
//    the user on a screen with one button that fails again. Back is suppressed
//    twice over (`PopScope(canPop: false)` plus a `BackButtonListener` that
//    consumes BACK unconditionally), so on that path the app is a dead end.
//  * the retry button on that dead end says `Retry` in Arabic too:
//    `OmdsErrorState.retryLabel` defaults to the hardcoded English literal and
//    `_ErrorView` never passes one. Exactly the defect class JEBV4-296 fixed
//    for the tag chips, still live one branch away. Visible in the AR RTL card
//    of `Error · submit rejected`.
//  * `_CommentField` takes `comment` and never reads it — no `controller`, no
//    `initialValue`. `Filled · five stars, every tag` seeds a 254-character
//    comment into cubit state and the field renders empty with its hint
//    showing.
//  * the blind-reveal phases fall through to `_InputView`, so
//    `Stale · awaitingOther phase` is a rating that was already submitted,
//    presented as a blank re-submittable form. Six ARB keys shipped in both
//    locales for those phases (`mutualRatingAwaitingTitle`,
//    `mutualRatingRevealedTitle`, `mutualRatingAutoRevealedTitle`,
//    `mutualRatingNoCounterRating`, `mutualRatingTheirStars`,
//    `mutualRatingDone`) are never rendered by this screen.
//  * `_StarSection`'s semantics label is a hardcoded, unpluralized English
//    `'$stars stars selected'`. An Arabic screen-reader user hears English on
//    the one control this mandatory screen requires, and one star reads
//    "1 stars selected".
//  * the quick-tag `Wrap` never wraps. Measured on the 390 pt phone these
//    previews declare, every chip is 350 pt wide — the full content width — so
//    the five tags stack as five full-width bars, one per run, in EN and AR
//    alike and at 100% text as much as at 200%. `OmdsChip` does not shrink to
//    its label, and the `Wrap` sets `spacing` but no `runSpacing`, so the bars
//    sit edge to edge: 48 pt of chip on a 48 pt pitch, zero gap. The compact
//    pill row that `Wrap(spacing:)` implies does not exist at any width the
//    app ships on. See the pinned measurement in the render test.
//  * inside those full-width chips the AR label still overflows at the
//    accessibility ceiling: at 200% text, `mutualRatingTagPunctuality`
//    ("دقيق بالمواعيد") measures 336 pt against a 350 pt chip and the chip's
//    internal Row overflows by 12 pt. EN survives because its widest label
//    ("Communication") measures 319 pt. Nothing wraps or ellipsizes it. This
//    is the one defect on the screen that ONLY the AR 200% card shows, which
//    is why `Fresh · client rates jeeber` is matrixed.
//  * `Fresh · jeeber rates client` is pixel-identical to `Fresh · client rates
//    jeeber`. `mode=jeeber` flips the audience on the wire and nothing on
//    screen: no ratee name, no "rate your customer" copy, no avatar. The two
//    previews exist side by side to make that visible rather than assumed.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _mutualRatingScreenPhoneBox = Size(390, 844);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class MutualRatingScreenCaptions {
  MutualRatingScreenCaptions._();

  /// Zero stars, no tags — the state every user opens the terminal in.
  static const String fresh = 'preview · fresh · client rates jeeber';

  /// The same screen with `isClient: false`. See the prose: identical.
  static const String jeeberSide = 'preview · fresh · jeeber rates client';

  /// Five stars, all five tags, a long comment in cubit state.
  static const String filled = 'preview · five stars · every tag';

  /// `POST /v1/ratings/jeeb/submit` in flight.
  static const String submitting = 'preview · submit in flight';

  /// The rejected submit, and the dead end it leaves behind.
  static const String submitFailed = 'preview · submit rejected';

  /// A server-owned blind-reveal phase restored onto the mandatory terminal.
  static const String awaitingOther = 'preview · stale awaitingOther phase';
}

/// The role-aware shell `context.go('/')` lands on after a successful submit.
///
/// The real destination is chosen by session role (customer → Requests tab,
/// jeeber → Dashboard tab); here it only has to exist, so a tap on
/// `rating_submit_cta` lands somewhere and shows that the mandatory terminal
/// released the user instead of throwing.
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

/// Puts a real `Router` above [MutualRatingScreen] and captions the state.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt every frame would drop the navigation state
/// `go`/`canPop` depend on. The rating terminal is the LONE ROOT page
/// (`initialLocation: '/rate'`, a sibling of `/` rather than a child), which is
/// the stack shape the run-22 P1 BACK escape was found in and the one
/// `BackButtonListener` exists for.
class _MutualRatingScreenHost extends StatefulWidget {
  const _MutualRatingScreenHost({
    required this.createCubit,
    required this.caption,
  });

  /// Built inside `BlocProvider.create`, so each mount gets its own cubit and
  /// the provider closes it on dispose.
  final MutualRatingCubit Function() createCubit;

  /// The line painted above the device frame — see note 3 in the prose.
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
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
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

/// The state every user opens the mandatory terminal in: nothing rated yet.
///
/// `rating_submit_cta` is DISABLED at zero stars, which is the only thing
/// standing between the user and an empty rating — and the only difference
/// between this and `Filled · five stars, every tag` that survives a
/// screenshot.
///
/// Matrixed because the quick tags are where this screen actually breaks, and
/// only one of the three cards shows it. The EN light card looks unremarkable.
/// The AR RTL card shows the chips mirrored in the logical order
/// `punctuality → communication → package_condition → courtesy → navigation`
/// (JEBV4-296 passes `textDirection` explicitly for exactly this). The EN 200%
/// card shows the same five full-width bars, still touching. The AR 200% card
/// is the one that overflows: `دقيق بالمواعيد` is 336 pt of text in a 350 pt
/// chip, 12 pt over, with no wrap and no ellipsis.
///
/// Note what NONE of the three cards shows: a wrapped row of compact pills.
/// Every chip takes the full 350 pt content width at every scale, so the five
/// tags are five stacked bars with zero gap between them.
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

/// The same screen with `isClient: false` — the `mode=jeeber` half of the
/// canonical terminal.
///
/// Read it next to `Fresh · client rates jeeber`: they are identical. The flag
/// changes the audience on the wire and nothing at all on screen — no ratee
/// name, no avatar, no "rate your customer" copy. A jeeber closing out a
/// delivery and a customer receiving one are shown the same eleven strings.
@JeebPreview(
  group: 'rating',
  name: 'Fresh · jeeber rates client',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenJeeberSide() => _mutualRatingScreenHosted(
      () => mutualRatingScreenFreshCubit(isClient: false),
      MutualRatingScreenCaptions.jeeberSide,
    );

/// The tallest input the screen can hold: five stars, every quick tag
/// selected, and a 254-character comment in cubit state.
///
/// The comment is the thing to look for, because it is NOT there.
/// `_CommentField` receives `state.comment` and never reads it — the field has
/// no `controller` and no `initialValue` — so the seeded comment renders as an
/// empty box with the hint showing. Anything that restores a draft, or that
/// wants to show what was typed after a failed submit, is silently a no-op
/// today.
///
/// Matrixed because this is the longest-content state: five SELECTED bars plus
/// five filled stars plus the pinned footer button, competing for the 844 pt
/// this box declares. The AR 200% card overflows the `punctuality` chip by
/// 10 pt here — 2 pt less than the fresh state, because a selected chip is
/// drawn slightly differently, which is itself worth knowing: the margin is
/// thin enough that selection moves it.
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

/// The submit is in flight, held open by a write that never lands.
///
/// The whole body is replaced by a bare centred spinner: no copy, no "sending
/// your rating", and no sign of the five stars just picked. `submitted`
/// renders the identical frame before `context.go('/')` fires, so the last
/// thing a user sees of a rating they were REQUIRED to give is an
/// unlabelled spinner.
@JeebPreview(
  group: 'rating',
  name: 'Submitting · in flight',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenSubmitting() => _mutualRatingScreenHosted(
      mutualRatingScreenSubmittingCubit,
      MutualRatingScreenCaptions.submitting,
    );

/// The submit was rejected — and this is where the screen stops.
///
/// `_ErrorView` replaces the entire body, and no phase leads back to
/// `_InputView`: from `error` the cubit can only reach `submitting`, then
/// `error` or `submitted`. The fixture behind this preview keeps rejecting
/// (`RatingFailure.unknown` — the 403 "not a party to this delivery"), which is
/// what a permanent failure looks like: one button, and it fails again. With
/// `PopScope(canPop: false)` and a `BackButtonListener` that consumes BACK
/// unconditionally, there is no way off this screen at all.
///
/// Look at the AR card: the retry button reads `Retry` in English.
/// `OmdsErrorState.retryLabel` defaults to that literal and `_ErrorView` never
/// passes a localized one.
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

/// A server-owned blind-reveal phase restored onto the mandatory terminal.
///
/// `MutualRatingCubit` never emits `awaitingOther` on the JM-034 path, but
/// `_buildBody` still has a branch for it — documented as falling back to the
/// input view "so a stale state never strands the user without a submit
/// affordance". This is that fallback: a rating already submitted (five stars,
/// `courtesy` tagged), shown as a blank form with an ENABLED submit button.
/// The six ARB keys written for these phases —
/// `mutualRatingAwaitingTitle`/`RevealedTitle`/`AutoRevealedTitle`/
/// `NoCounterRating`/`TheirStars`/`Done` — are shipped in EN and AR and are
/// never rendered by this screen.
@JeebPreview(
  group: 'rating',
  name: 'Stale · awaitingOther phase',
  size: _mutualRatingScreenPhoneBox,
)
Widget mutualRatingScreenAwaitingOther() => _mutualRatingScreenHosted(
      mutualRatingScreenAwaitingOtherCubit,
      MutualRatingScreenCaptions.awaitingOther,
    );
