import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
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
/// `orders_create_request_button`); jeeber → Dashboard tab (`shell_tab_dashboard`).
/// AC4: `rating_root` is the signature id present on this canonical terminal
/// (the legacy `/feedback` `RatingScreen` exposes the same id).
class MutualRatingScreen extends StatelessWidget {
  const MutualRatingScreen({super.key, this.rateeName = ''});

  /// Display name of the counterpart being rated, forwarded by the router from
  /// `?name=`. Empty is the supported default (no caller holds a display name
  /// today) — the headline, the avatar initial and the blind-reveal note each
  /// carry a finished role-aware fallback, so nothing is ever fabricated.
  final String rateeName;

  @override
  Widget build(BuildContext context) {
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
    //
    // redesign-24: the OMDSAppBar is gone — the board leads with the in-body
    // "How was <name>?" headline, and there was never a leading control to
    // lose, so removing it is D56-safe.
    final scope = PopScope(
      canPop: false,
      child: Scaffold(
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
        return _InputView(state: state, rateeName: rateeName);
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
        return _InputView(state: state, rateeName: rateeName);
    }
  }
}

class _InputView extends StatelessWidget {
  const _InputView({required this.state, required this.rateeName});
  final MutualRatingState state;
  final String rateeName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // R1: the board leaves the bottom ~40 % of this screen empty. That is
      // delivered by `Expanded` + a docked footer, never by a `Spacer` inside
      // the scroll column (which would overflow the 800×600 widget tests).
      child: Column(
        children: [
          Expanded(child: _InputScrollArea(state: state, rateeName: rateeName)),
          _SubmitButton(stars: state.stars),
        ],
      ),
    );
  }
}

class _InputScrollArea extends StatelessWidget {
  const _InputScrollArea({required this.state, required this.rateeName});
  final MutualRatingState state;
  final String rateeName;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RatingHeadline(rateeName: rateeName),
          const SizedBox(height: Spacing.large),
          _RateeIdentity(rateeName: rateeName),
          const SizedBox(height: Spacing.large),
          _StarSection(stars: state.stars),
          const SizedBox(height: Spacing.xSmall),
          _StarVerdict(stars: state.stars),
          const SizedBox(height: Spacing.xLarge),
          _TagsSection(selectedTags: state.tags),
          const SizedBox(height: Spacing.large),
          _CommentField(comment: state.comment),
          const SizedBox(height: Spacing.large),
          _BlindRevealNote(rateeName: rateeName),
        ],
      ),
    );
  }
}

/// The board's opening question — "How was Karim?" when the counterpart's
/// display name reached the route, otherwise the role-aware form.
class _RatingHeadline extends StatelessWidget {
  const _RatingHeadline({required this.rateeName});
  final String rateeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `isClient` is a public final on the cubit; read once, no subscription.
    final isClient = context.read<MutualRatingCubit>().isClient;
    final name = rateeName.trim();
    final headline = name.isNotEmpty
        ? l10n.mutualRatingHeadlineNamed(name)
        : (isClient
            ? l10n.mutualRatingHeadlineJeeber
            : l10n.mutualRatingHeadlineClient);
    // A plain `Text` is bidi-correct for a Latin name inside an Arabic
    // sentence — `MixedDirectionText` is for name-ONLY lines.
    return Text(headline, style: context.jeebText.h2);
  }
}

/// Ø74 disc + the Ø26 corner mark, centred under the headline.
class _RateeIdentity extends StatelessWidget {
  const _RateeIdentity({required this.rateeName});
  final String rateeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = rateeName.trim();
    // `JeebAvatar` normalises the initial itself (trimmed first character,
    // uppercased, `?` when empty) and emits the
    // `Semantics(identifier:, label:, image: true)` node for us — no second
    // wrapper, which would double the node.
    //
    // The badge is a COMPLETION mark, never "verified": on the `?mode=jeeber`
    // leg the ratee is a customer with no KYC.
    //
    // TODO(redesign-24): the board prints a recap line directly below this
    // disc (item · duration · fare). It needs a delivery summary on the rating
    // surface, which neither MutualRatingState nor RatingRepository carries —
    // omitted, not faked, and deliberately not smuggled through query params.
    return Center(
      child: JeebAvatar.hero(
        initial: name,
        badge: JeebAvatarBadge.completed,
        identifier: 'mutual_rating_ratee_avatar',
        semanticLabel: name.isEmpty ? l10n.mutualRatingTitle : name,
      ),
    );
  }
}

class _StarSection extends StatelessWidget {
  const _StarSection({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      // QA: addressable handle for the star-rating input. `container: true`
      // surfaces the id as its own node even though OmdsStarRating renders
      // multiple tappable stars (CAP-1).
      identifier: 'mutual_rating_stars',
      container: true,
      label: l10n.mutualRatingStarsA11yLabel(stars),
      child: Center(
        // The active star colour is deliberately NOT passed: the app-wide
        // `OmdsColorTokens.starRatingColor` is already the redesign's amber
        // (`app.dart:623`). A plain `Row` under the hood mirrors in `ar`, so
        // star 1 lands at the right edge and the fill grows leftward.
        //
        // TODO(redesign-24): the board draws the EMPTY star FILLED grey; OMDS
        // draws `Icons.star_border`. Swaps to `JeebStarInput` (wiring request
        // `kit`) when the kit lane lands it, which also brings the per-star
        // ids jm-034 needs.
        child: OmdsStarRating(
          key: const Key('mutualRating.stars'),
          rating: stars,
          starSize: Sizes.threeXLarge,
          spacing: Spacing.xSmall,
          inactiveColor: scheme.surfaceContainerHighest,
          onRatingChanged: (v) => context.read<MutualRatingCubit>().setStars(v),
        ),
      ),
    );
  }
}

/// The one-word verdict the board prints under the stars ("Great" at 4).
class _StarVerdict extends StatelessWidget {
  const _StarVerdict({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    // `SizedBox.shrink`, not `Text('')` — an empty Text still occupies a line
    // box and would open a gap before the section label.
    if (stars == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Text(
      _starVerdict(l10n, stars),
      textAlign: TextAlign.center,
      style: context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// Maps a 1..5 selection to its localized verdict word. Mirrors the `_tagLabel`
/// idiom: a pure switch with a safe default, so an out-of-range value from a
/// stale state renders nothing rather than throwing.
String _starVerdict(AppLocalizations l10n, int stars) {
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

/// Same cap the removed `maxLength: 500` enforced — kept as a named constant so
/// the swap to a formatter is provably lossless.
const int _commentMaxLength = 500;

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
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: Sizes.medium,
        minLines: 3,
        maxLines: 4,
        // Same 500-character cap as before, enforced by a formatter instead of
        // `maxLength:` so the `0/500` counter chrome disappears — the board
        // draws a bare note box.
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(_commentMaxLength),
        ],
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
///
/// The render's chip order is a `flex-wrap` artefact of the design tool — this
/// list's order is the wire contract and is NOT reordered to match it.
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
        // The kit uppercases internally and skips the transform for caseless
        // scripts — never pass `.toUpperCase()` from here.
        JeebSectionLabel(l10n.mutualRatingTagsLabel),
        const SizedBox(height: Spacing.small),
        // JEBV4-296: `textDirection` is passed explicitly (rather than
        // relying on Wrap's implicit ambient-Directionality fallback) so the
        // chip order is provably RTL-safe under `ar` — logical order stays
        // punctuality→communication→package_condition→courtesy→navigation,
        // mirrored right-to-left on screen.
        Wrap(
          spacing: Spacing.xSmall,
          runSpacing: Spacing.xSmall,
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
    // i18n/RTL) — 41_GUARDRAILS_TESTING §1.1 dynamic-item form. The kit chip
    // is given no identifier of its own: this wrapper is the frozen node and
    // it also carries `selected:`, which the kit chip's wrapper does not.
    return Semantics(
      identifier: 'mutual_rating_tag_${tag.key}',
      container: true,
      button: true,
      selected: selected,
      child: JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: label,
        selected: selected,
        // Send the canonical taxonomy KEY, not the display label (JEBV4-297).
        onTap: () => context.read<MutualRatingCubit>().toggleTag(tag.key),
      ),
    );
  }
}

/// The board's blind-reveal reassurance strip: outlined, eye glyph, muted ink.
class _BlindRevealNote extends StatelessWidget {
  const _BlindRevealNote({required this.rateeName});
  final String rateeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = rateeName.trim();
    // Own the node here rather than passing the kit's `identifier:`: the kit
    // wrapper sets `explicitChildNodes`, which would stop the body text from
    // merging into the identified node and leave it unlabelled.
    return Semantics(
      identifier: 'mutual_rating_blind_note',
      container: true,
      child: JeebInfoNote.outlined(
        icon: Icons.visibility,
        text: name.isNotEmpty
            ? l10n.mutualRatingBlindNoteNamed(name)
            : l10n.mutualRatingSubtitle,
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
    return JeebCtaFooter.single(
      // `rating_submit_cta` is the W1 contract id (JM-034 §2.14). No
      // `button: true` — JeebCtaButton's InkWell already exposes the button
      // role; `container: true` keeps this identifier its own queryable node.
      child: Semantics(
        identifier: 'rating_submit_cta',
        container: true,
        child: JeebCtaButton.primary(
          key: const Key('mutualRating.submit'),
          label: l10n.mutualRatingSubmit,
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
