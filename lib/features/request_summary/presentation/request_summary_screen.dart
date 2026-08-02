import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/request_summary_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_summary_screen_fixtures.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

class RequestSummaryScreen extends StatelessWidget {
  const RequestSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          listenWhen: (p, c) => !p.isSubmitted && c.isSubmitted,
          listener: (context, state) => context.go('/'),
        ),
        BlocListener<RequestSummaryCubit, RequestSummaryState>(
          listenWhen: (p, c) => p.error == null && c.error != null,
          listener: (context, state) =>
              showOmdsErrorSnackbar(context, message: state.error!),
        ),
      ],
      child: BlocBuilder<RequestSummaryCubit, RequestSummaryState>(
        builder: (context, state) {
          final draft = state.draft;
          if (draft == null) return const OmdsLoadingState();
          return Scaffold(
            appBar: OMDSAppBar(title: AppLocalizations.of(context).requestSummaryTitle),
            body: _RequestSummaryBody(state: state),
          );
        },
      ),
    );
  }
}

class _RequestSummaryBody extends StatelessWidget {
  const _RequestSummaryBody({required this.state});

  final RequestSummaryState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        _SectionCard(
          title: l10n.requestSummarySectionDescription,
          child: Text(draft.description),
        ),
        if (draft.transcription != null)
          _SectionCard(
            title: l10n.requestSummarySectionTranscription,
            child: Text(draft.transcription!),
          ),
        if (draft.photoUrls.isNotEmpty)
          _SectionCard(
            title: l10n.requestSummarySectionPhotos,
            child: Text(l10n.requestSummaryPhotosAttached(draft.photoUrls.length)),
          ),
        if (draft.tierName != null)
          _SectionCard(
            title: l10n.requestSummarySectionTier,
            child: Text(draft.tierName!),
          ),
        if (draft.pickupAddress != null)
          _SectionCard(
            title: l10n.requestSummarySectionPickup,
            child: Text(draft.pickupAddress!),
          ),
        if (draft.dropoffAddress != null)
          _SectionCard(
            title: l10n.requestSummarySectionDropoff,
            child: Text(draft.dropoffAddress!),
          ),
        const SizedBox(height: Spacing.xLarge),
        _SubmitButton(isSubmitting: state.isSubmitting),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isSubmitting});

  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_summary_submit',
      button: true,
      child: OmdsLoadingButton(
        key: const Key('request_summary.submit'),
        text: AppLocalizations.of(context).requestSummarySubmit,
        isLoading: isSubmitting,
        onTap: () => context.read<RequestSummaryCubit>().submit(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: _SectionCardContent(title: title, child: child),
        ),
      ),
    );
  }
}

class _SectionCardContent extends StatelessWidget {
  const _SectionCardContent({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xSmall),
        child,
      ],
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
// Render tests:
// test/previews/request_summary/request_summary_screen_preview_test.dart
// ===========================================================================
//
// [RequestSummaryScreen] is the last thing a client reads before a request
// exists. It has exactly one input — the [RequestDraft] the route hands the
// cubit through `extra` — and one action, so the axes below are the draft
// (which of the six optional cards are present, and how long they are) and the
// submit lifecycle (idle → in flight → failed, or → gone).
//
// Three things differ from a widget preview, all of them because this is a
// SCREEN:
//
//  1. It owns its own `Scaffold` and [jeebPreviewHost] wraps every child in one
//     as well, so the canvas shows two nested Scaffolds. The inner one is the
//     real surface; the outer contributes a background and a `SafeArea`. The
//     canvas box is therefore a real device
//     ([_requestSummaryScreenPhoneBox], 390x844) rather than the harness's
//     390x200 default — a list of cards under an app bar cannot be judged in a
//     200 pt strip.
//  2. It is not mountable without a `BlocProvider<RequestSummaryCubit>` and not
//     SUBMITTABLE without a `Router`: a successful submit calls
//     `context.go('/')`, which throws under the bare `MaterialApp` the canvas
//     and the render harness provide. Both come from
//     [RequestSummaryScreenPreviewHost] in
//     `lib/devtool/catalog/fixtures/request_summary_screen_fixtures.dart`,
//     shared with the Screen Catalog entry in
//     `lib/devtool/catalog/entries/batch_10_entries.dart` — the three states a
//     designer signs off against ("Loaded" / "Submitting" / "Error — Network")
//     are built from the same draft and the same fake service as the cards
//     here, so the two surfaces cannot drift.
//  3. There is no `cubit:` seam and no state constructor to hand a designed
//     state to. Every non-idle state below is reached the way a user reaches
//     it — by starting a real `submit()` against a fake service that stalls,
//     fails, or succeeds. That is what `drive: true` means on the host.
//
// Network-free by construction, not by the guard: the only collaborator is
// [RequestSummaryScreenFakeSubmissionService], and
// `DioRequestSubmissionService` — what `sl<RequestSubmissionService>()` returns
// in the shipped route — is never built here.
//
// WHAT THESE PREVIEWS SHOW THAT THE EXISTING TESTS DO NOT. The cubit tests
// (`test/features/request_summary/request_summary_cubit_test.dart`) assert the
// state machine and the route test asserts the happy path renders; neither
// looks at the surface, and the surface is where these live. Each is pinned as
// an assertion in the render test:
//
//  * **A tier-card tap arrives here with an EMPTY description and no way to
//    fix it.** `app_router.dart:1107` builds `RequestDraft(description: '',
//    …)` for `onTierSelected`, with the comment "the user fills it on the
//    summary screen". This screen has no input control of any kind — every
//    value is a read-only `Text` — so the Description card renders as a title
//    over a blank line and `Send request` submits the empty string. The ARB
//    even carries the placeholder for it: `requestSummaryDescriptionEmpty`
//    ("No description provided") exists in EN and AR, is described as
//    "Placeholder body shown when the description is empty on the summary
//    screen", and is referenced by no Dart file at all. Same for
//    `requestSummaryPhotosEmpty` (`Tier-card entry · empty description`).
//  * **The same tap shows the raw enum id as the speed.** `tierName:
//    tier.id.name` puts `express` — lowercase, untranslated — in the Speed
//    card, where the localized tier label belongs. The AR rendering of that
//    card is latin text in an RTL paragraph.
//  * **The failure surface is a snackbar and nothing else, and its copy is
//    hardcoded English.** `RequestSummaryCubit._messageFor` returns literals
//    ("No connection. Check your network and try again."), so the AR card shows
//    English on a red bar; `requestSummaryErrorNetwork` and
//    `requestSummaryErrorGeneric` are translated in both ARBs and are used by
//    three OTHER screens. The bar is also the only trace: `state.error` stays
//    set but is never rendered in the body, `requestSummaryRetry` ("Retry CTA
//    shown after a submit failure") is unused here, and after four seconds the
//    screen is indistinguishable from one that was never submitted
//    (`Error · network`).
//  * **Success leaves nothing behind either.** `context.go('/')` replaces the
//    screen with the Requests tab, and `RequestSummaryState.requestId` — the
//    id the gateway just minted — is read by no widget in the app. The client
//    is returned to a list with no confirmation that anything was created
//    (`Submitted · navigates away`).
//  * **The photo card counts files it never shows, in copy that never
//    pluralizes.** `requestSummaryPhotosAttached` is a plain `{count}`
//    placeholder, not an ICU plural, so EN reads "1 photo(s) attached" and AR
//    uses the singular "صورة" for twelve. No thumbnail is rendered, so a client
//    reviewing a request cannot check WHICH photos are attached
//    (`Longest content`).
//  * **`recipientPhone` is on the draft and off the screen.** It is the number
//    the at-door handover OTP is dispatched to (T-BE-019 / JEB-55) and the one
//    field on this review screen a client would most want to check. Nothing
//    renders it.
//  * **The `draft == null` branch has no chrome at all.** It returns a bare
//    `OmdsLoadingState` — no `Scaffold`, no app bar, no title, no back — from
//    ABOVE the `Scaffold` the rest of the screen builds. Through the shipped
//    route it is unreachable (`app_router.dart:1328` substitutes
//    `RequestSummaryUnavailableScreen` when `extra` is not a `RequestDraft`,
//    and the provider calls `setDraft` before the screen builds), so this is a
//    defensive branch — but it is the initial state of the cubit, and anything
//    that ever mounts this screen without seeding one strands the user
//    (`No draft · bare spinner`).

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _requestSummaryScreenPhoneBox = Size(390, 844);

/// Mounts the screen exactly as `/request-summary` mounts it — a
/// `BlocProvider<RequestSummaryCubit>` seeded with [draft] — plus the stand-in
/// router the canvas needs for `context.go('/')` (see note 2 above).
///
/// [drive] starts a `submit()` as the cubit is created: the submitting, failed
/// and submitted states have no other door.
Widget _requestSummaryScreenHosted({
  required RequestDraft? draft,
  RequestSummaryScreenFakeSubmissionService service =
      const RequestSummaryScreenFakeSubmissionService(),
  bool drive = false,
}) =>
    RequestSummaryScreenPreviewHost(
      screen: const RequestSummaryScreen(),
      service: service,
      draft: draft,
      drive: drive,
      standInRouter: true,
    );

/// The reference reading, and the draft the Screen Catalog's "Loaded" state is
/// built from: every optional field populated, so all six cards render.
///
/// Matrixed because this is where the card list says different things in each
/// rendering — the AR card translates and right-aligns the six titles while the
/// two addresses stay latin inside an RTL paragraph, and the 200% card is where
/// six stacked cards stop fitting: measured on the box below, the CTA occupies
/// y 748–796 of 844 at 100% and is not on the screen AT ALL at 200%, so the
/// button that commits the request has to be scrolled to. Both are pinned in
/// the render test.
@JeebPreview(
  group: 'request_summary',
  name: 'Full draft · every section',
  size: _requestSummaryScreenPhoneBox,
  matrix: true,
)
Widget requestSummaryScreenFullDraft() =>
    _requestSummaryScreenHosted(draft: RequestSummaryScreenDrafts.full);

/// The floor: a description and nothing else.
///
/// Every card except the first is behind its own `if`, so this is the closest
/// thing the screen has to an empty state — one card, then 700 pt of surface,
/// then the CTA. Worth looking at beside the state above for how little of
/// this screen is guaranteed to be there.
@JeebPreview(
  group: 'request_summary',
  name: 'Description only · optionals absent',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenDescriptionOnly() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.descriptionOnly,
    );

/// What a tier-CARD tap really produces — `app_router.dart:1107` verbatim.
///
/// Two defects in one card list, both described in the section header: the
/// Description card is a title over a BLANK line (with `Send request` live
/// beside it and no way to type anything), and the Speed card reads `express`,
/// the raw `TierId` enum name, in both locales.
@JeebPreview(
  group: 'request_summary',
  name: 'Tier-card entry · empty description',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenTierCardEntry() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.tierCardEntry,
    );

/// The layout ceiling: a spoken request with its full transcription, twelve
/// photos, a scheduled tier and two landmark-shaped addresses.
///
/// Nothing here truncates — every value is a bare `Text` with no `maxLines` —
/// so the review simply grows and the `ListView` scrolls. That is the right
/// behaviour and it hides two things worth seeing: "12 photo(s) attached" is
/// the whole of what the client is told about twelve images they cannot look
/// at, and the CTA is now several screens below the content it commits.
/// Matrixed because length is exactly what swings by locale and by scaler.
@JeebPreview(
  group: 'request_summary',
  name: 'Longest content',
  size: _requestSummaryScreenPhoneBox,
  matrix: true,
)
Widget requestSummaryScreenLongest() =>
    _requestSummaryScreenHosted(draft: RequestSummaryScreenDrafts.longest);

/// The in-flight state: `POST /requests` has been sent and has not answered.
///
/// Reached by driving a real `submit()` against a service that never resolves.
/// The CTA is the ONLY thing that changes — `OmdsLoadingButton` swaps its label
/// for a spinner and drops its `onTap` — so the cards above stay at full
/// contrast and nothing else on the screen says a request is being created.
@JeebPreview(
  group: 'request_summary',
  name: 'Submitting · in flight',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenSubmitting() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.full,
      service: const RequestSummaryScreenFakeSubmissionService(pending: true),
      drive: true,
    );

/// The Screen Catalog's "Error — Network" state: the submit came back
/// `RequestSubmissionFailure.network`.
///
/// The card list returns to exactly its idle rendering and a red snackbar
/// carries the whole of the failure — in English, in both locales, from a
/// literal in `RequestSummaryCubit._messageFor`. Note where the bar draws: the
/// nearest `ScaffoldMessenger` is the canvas's own `MaterialApp`, not this
/// screen's `Scaffold`, so it lands at the bottom of the PAGE rather than
/// inside the card. Four seconds later there is nothing left to see.
@JeebPreview(
  group: 'request_summary',
  name: 'Error · network',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenErrorNetwork() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.full,
      service: const RequestSummaryScreenFakeSubmissionService(
        failure: RequestSubmissionFailure.network,
      ),
      drive: true,
    );

/// Success, which is the state with no design: `context.go('/')` fires on the
/// `isSubmitted` edge and the screen is gone.
///
/// The card shows where the client lands — the stand-in for the shell's
/// Requests tab — because that is the honest rendering of this state. Nothing
/// confirms the request was created, and `RequestSummaryState.requestId`, the
/// id the gateway minted, is read by no widget in the app.
@JeebPreview(
  group: 'request_summary',
  name: 'Submitted · navigates away',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenSubmitted() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.full,
      drive: true,
    );

/// The cubit's initial state, rendered: no draft, so `build` returns a bare
/// `OmdsLoadingState` from above the `Scaffold`.
///
/// No app bar, no title, no back — a spinner on an empty surface with no way
/// off it. The shipped route cannot produce this (it falls back to
/// `RequestSummaryUnavailableScreen` on a bad `extra`, and seeds the draft
/// inside the provider), so this is a defensive branch; it is also the state
/// every future caller of this screen gets for free if it forgets `setDraft`.
@JeebPreview(
  group: 'request_summary',
  name: 'No draft · bare spinner',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenNoDraft() => _requestSummaryScreenHosted(draft: null);
