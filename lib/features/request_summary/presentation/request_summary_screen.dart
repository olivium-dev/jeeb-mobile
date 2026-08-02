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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _requestSummaryScreenPhoneBox = Size(390, 844);

/// Mounts the screen exactly as `/request-summary` mounts it — a
/// `BlocProvider<RequestSummaryCubit>` seeded with [draft] — plus the stand-in
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
@JeebPreview(
  group: 'request_summary',
  name: 'Full draft · every section',
  size: _requestSummaryScreenPhoneBox,
  matrix: true,
)
Widget requestSummaryScreenFullDraft() =>
    _requestSummaryScreenHosted(draft: RequestSummaryScreenDrafts.full);

/// The floor: a description and nothing else.
/// Every card except the first is behind its own `if`, so this is the closest
@JeebPreview(
  group: 'request_summary',
  name: 'Description only · optionals absent',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenDescriptionOnly() => _requestSummaryScreenHosted(
      draft: RequestSummaryScreenDrafts.descriptionOnly,
    );

/// What a tier-CARD tap really produces — `app_router.dart:1107` verbatim.
/// Two defects in one card list, both described in the section header: the
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
@JeebPreview(
  group: 'request_summary',
  name: 'Longest content',
  size: _requestSummaryScreenPhoneBox,
  matrix: true,
)
Widget requestSummaryScreenLongest() =>
    _requestSummaryScreenHosted(draft: RequestSummaryScreenDrafts.longest);

/// The in-flight state: `POST /requests` has been sent and has not answered.
/// Reached by driving a real `submit()` against a service that never resolves.
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
@JeebPreview(
  group: 'request_summary',
  name: 'No draft · bare spinner',
  size: _requestSummaryScreenPhoneBox,
)
Widget requestSummaryScreenNoDraft() => _requestSummaryScreenHosted(draft: null);
