import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../mixed_direction/presentation/mixed_direction_text.dart';
import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';
import 'mutual_rating_screen.dart' show MutualRatingTag, kMutualRatingTags;
import 'widgets/feedback_avatar.dart';
import 'widgets/feedback_header.dart';
import 'widgets/feedback_star_input.dart';

/// Immutable bundle of everything the feedback content column renders, so the
/// state is threaded through one parameter instead of eight.
@immutable
class FeedbackContentData {
  const FeedbackContentData({
    required this.isClient,
    required this.rateeName,
    required this.rateeAvatarUrl,
    required this.stars,
    required this.tags,
    required this.commentController,
    required this.onStarsChanged,
    required this.onTagToggled,
  });

  final bool isClient;
  final String rateeName;
  final String? rateeAvatarUrl;
  final int stars;
  final Set<String> tags;
  final TextEditingController commentController;
  final ValueChanged<int> onStarsChanged;
  final ValueChanged<String> onTagToggled;
}

/// Legacy single-sided feedback terminal (`/orders/:id/feedback`, JM-034).
///
/// AC1/D56: mandatory — no skip/close control and `PopScope(canPop: false)`.
/// AC2/AC3: submit persists via [RatingRepository] then routes to the
/// role-aware shell (`context.go('/')`). AC4: `rating_root` is the signature id
/// present on both rating routes.
///
/// MIDNIGHT (M3-09): derived from R15, the sibling terminal's tile — same
/// field, star row, chip band and orange CTA as [MutualRatingScreen].
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.deliveryId,
    this.isClient = true,
    this.rateeName = '',
    this.rateeAvatarUrl,
    this.repository,
    this.initialStars = 0,
    this.initialTags = const <String>[],
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

  /// Harness seam (catalog captures / tests) for the picked-score frame; the
  /// live route never passes it. Same shape as R2's cubit `initialState`.
  final int initialStars;

  /// Harness seam for the selected-chip frame. See [initialStars].
  final List<String> initialTags;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  late int _stars = widget.initialStars;
  late final Set<String> _tags = <String>{...widget.initialTags};
  bool _submitting = false;
  final TextEditingController _commentController = TextEditingController();

  RatingRepository get _repository =>
      widget.repository ??
      (sl.isRegistered<RatingRepository>() ? sl<RatingRepository>() : null) ??
      _NoopRatingRepository();

  FeedbackContentData get _data => FeedbackContentData(
        isClient: widget.isClient,
        rateeName: widget.rateeName,
        rateeAvatarUrl: widget.rateeAvatarUrl,
        stars: _stars,
        tags: _tags,
        commentController: _commentController,
        onStarsChanged: _onStarsChanged,
        onTagToggled: _onTagToggled,
      );

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onStarsChanged(int value) => setState(() => _stars = value);

  void _onTagToggled(String key) => setState(() {
        if (!_tags.remove(key)) _tags.add(key);
      });

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
        tags: _tags.isEmpty ? null : _tags.toList(),
      );
    } catch (_) {
      // Mandatory terminal: even a transient failure must not strand the user
      // on the un-dismissable screen, so we still route home (AC2).
    }
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // D56: mandatory — system back suppressed, no leading/close affordance.
    // R15 draws the base wash with one quiet glow low on the field, under the
    // orange CTA. No rings, no twinkles, nothing that ticks.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.bottom,
          animateDecor: false,
          // `rating_root` is the signature id present on both rating routes
          // (JM-034 §2.14, AC4) — outside the state switch so it never drops.
          child: Semantics(
            identifier: 'rating_root',
            container: true,
            child: _submitting
                ? const _FeedbackSubmittingView()
                : _FeedbackBody(data: _data, onSubmit: _onSubmit),
          ),
        ),
      ),
    );
  }
}

/// Fallback used only when no [RatingRepository] is registered (e.g. a widget
/// test that does not boot DI).
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
  const _FeedbackBody({required this.data, required this.onSubmit});

  final FeedbackContentData data;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // R15 leaves the bottom of the screen empty: `Expanded` + a docked
      // footer, never a `Spacer` inside the scroll column.
      child: Column(
        children: [
          Expanded(child: _FeedbackScrollArea(data: data)),
          _FeedbackFooter(stars: data.stars, onSubmit: onSubmit),
        ],
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
      // 24px board gutters, directional so `ar` mirrors.
      padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
      child: _FeedbackContent(data: data),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({required this.data});

  final FeedbackContentData data;

  @override
  Widget build(BuildContext context) {
    // R15's reading order: headline → identity hero → the prompt and its stars
    // → the verdict → what stood out → the optional note.
    //
    // TODO(midnight): omitted — R15 prints a recap line under the disc (item ·
    // duration · fare). `RatingScreen` receives only a delivery id, and
    // `RatingRepository` exposes no delivery summary, so the slot stays empty
    // rather than faked.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedbackHeader(isClient: data.isClient),
        const SizedBox(height: Spacing.xLarge),
        FeedbackAvatar(name: data.rateeName, avatarUrl: data.rateeAvatarUrl),
        const SizedBox(height: Spacing.large),
        _FeedbackRateName(name: data.rateeName),
        FeedbackStarInput(stars: data.stars, onChanged: data.onStarsChanged),
        const SizedBox(height: Spacing.xSmall),
        _FeedbackVerdict(stars: data.stars),
        const SizedBox(height: Spacing.xLarge),
        _FeedbackTags(selected: data.tags, onToggled: data.onTagToggled),
        const SizedBox(height: Spacing.large),
        _FeedbackCommentField(controller: data.commentController),
      ],
    );
  }
}

/// Same cap the removed `maxLength: 1000` enforced — kept as a named constant
/// so the swap to a formatter is provably lossless.
const int _commentMaxLength = 1000;

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
        // Fill/border/hint ink come from the Midnight OMDS token set
        // (`glassFill` + 1px `glassBorder` + `inkMuted`) — the measured recipe.
        borderRadius: JeebRadii.lg,
        minLines: 3,
        maxLines: 4,
        // The cap is enforced by a formatter so the `0/1000` counter chrome
        // disappears — R15 draws a bare note box.
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(_commentMaxLength),
        ],
      ),
    );
  }
}

class _FeedbackRateName extends StatelessWidget {
  const _FeedbackRateName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // Nameless ratee: the line would read "Rate " with a dangling space, so it
    // is dropped — the header already carries the role-aware framing.
    if (name.trim().isEmpty) return const SizedBox(height: Spacing.xSmall);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: MixedDirectionText(
        AppLocalizations.of(context).feedbackRateName(name),
        textAlign: TextAlign.center,
        style: context.jeebText.titleProminent.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// The one-word verdict R15 prints under the stars ("Great" at 4).
class _FeedbackVerdict extends StatelessWidget {
  const _FeedbackVerdict({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    // `SizedBox.shrink`, not `Text('')` — an empty Text still occupies a line
    // box and would open a gap before the section label.
    if (stars < 1 || stars > FeedbackStarInput.starCount) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Text(
      _verdictLabel(l10n, stars),
      textAlign: TextAlign.center,
      style: context.jeebText.bodySmall.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Reuses the screen-15 verdict vocabulary: one score scale, one word set.
String _verdictLabel(AppLocalizations l10n, int stars) {
  switch (stars) {
    case 1:
      return l10n.mutualRatingStarLabel1;
    case 2:
      return l10n.mutualRatingStarLabel2;
    case 3:
      return l10n.mutualRatingStarLabel3;
    case 4:
      return l10n.mutualRatingStarLabel4;
    case 5:
      return l10n.mutualRatingStarLabel5;
    default:
      return '';
  }
}

/// JEBV4-296 twin of `MutualRatingScreen._tagLabel` (that one is private and
/// its screen is frozen this wave — dedupe queued as an open question).
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

/// R15's "WHAT STOOD OUT?" band. The keys are the gateway taxonomy
/// (JEBV4-297) and reach the same `/v1/ratings/jeeb/submit` `tags` field.
class _FeedbackTags extends StatelessWidget {
  const _FeedbackTags({required this.selected, required this.onToggled});

  final Set<String> selected;
  final ValueChanged<String> onToggled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The kit uppercases internally and skips the transform for caseless
        // scripts — never pass `.toUpperCase()` from here.
        JeebSectionLabel(l10n.mutualRatingTagsLabel),
        const SizedBox(height: Spacing.small),
        // Measured: 12dp between pills, 8dp between runs — the gap that makes
        // the board wrap 3 + 2.
        Wrap(
          spacing: Spacing.small,
          runSpacing: Spacing.xSmall,
          textDirection: Directionality.of(context),
          children: kMutualRatingTags
              .map(
                (t) => _FeedbackTagChip(
                  tag: t,
                  label: _tagLabel(l10n, t),
                  selected: selected.contains(t.key),
                  onToggled: onToggled,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _FeedbackTagChip extends StatelessWidget {
  const _FeedbackTagChip({
    required this.tag,
    required this.label,
    required this.selected,
    required this.onToggled,
  });

  final MutualRatingTag tag;
  final String label;
  final bool selected;
  final ValueChanged<String> onToggled;

  @override
  Widget build(BuildContext context) {
    // Dynamic per-tag id keyed on the canonical taxonomy key (stable across
    // i18n/RTL); this wrapper carries `selected:`, which the kit chip does not.
    return Semantics(
      identifier: 'feedback_tag_${tag.key}',
      container: true,
      button: true,
      selected: selected,
      child: JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: label,
        selected: selected,
        onTap: () => onToggled(tag.key),
      ),
    );
  }
}

class _FeedbackFooter extends StatelessWidget {
  const _FeedbackFooter({required this.stars, required this.onSubmit});

  final int stars;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebCtaFooter.single(
      // `rating_submit_cta` is the W1 contract id (JM-034 §2.14). No
      // `button: true` — JeebCtaButton's InkWell already exposes that role.
      child: Semantics(
        identifier: 'rating_submit_cta',
        container: true,
        // R15 draws this act ORANGE (`#D73B00` + ctaOrange lift) — the
        // tile-sanctioned accent spend on this screen.
        child: JeebCtaButton.accent(
          label: l10n.feedbackSubmit,
          isEnabled: stars > 0,
          onTap: onSubmit,
        ),
      ),
    );
  }
}

/// `POST /v1/ratings/jeeb/submit` in flight. R15 draws no in-flight frame, so
/// this is the ratified loading member of the empty-state family.
class _FeedbackSubmittingView extends StatelessWidget {
  const _FeedbackSubmittingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: JeebEmptyState.compact(
            status: JeebEmptyStateStatus.loading,
            headline: l10n.mutualRatingSubmittingHeadline,
            identifier: 'feedback_submit_loading',
          ),
        ),
      ),
    );
  }
}
