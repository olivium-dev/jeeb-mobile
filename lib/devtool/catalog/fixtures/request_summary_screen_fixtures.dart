// Shared dev-only fixtures for `RequestSummaryScreen` — the last surface a

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// The local [RequestSubmissionService] every state is driven through.
/// Extracted verbatim from the Screen Catalog's `_FakeRequestSubmissionService`.
/// Three behaviours, one class:
class RequestSummaryScreenFakeSubmissionService
    implements RequestSubmissionService {
  const RequestSummaryScreenFakeSubmissionService({
    this.failure,
    this.pending = false,
  });

  /// The typed failure to complete with, or `null` to succeed.
  final RequestSubmissionFailure? failure;

  /// Never resolves — pins the screen on the in-flight button state.
  final bool pending;

  /// The id a successful create returns. The gateway mints it and
  /// [RequestSummaryState.requestId] stores it; nothing in the presentation
  static const String mintedRequestId = 'REQ-9001';

  @override
  Future<String> submit(RequestDraft draft) {
    if (pending) return Completer<String>().future;
    final RequestSubmissionFailure? f = failure;
    if (f != null) return Future<String>.error(RequestSubmissionException(f));
    return Future<String>.value(mintedRequestId);
  }
}

/// The [RequestDraft] payloads this screen is reviewed with.
/// Every one is a shape an upstream step can really hand to
final class RequestSummaryScreenDrafts {
  RequestSummaryScreenDrafts._();

  /// The reference reading, and the draft the Screen Catalog's three states
  /// have always been built with: every optional field populated, so all six
  static const RequestDraft full = RequestDraft(
    description: 'Pick up my prescription from Pharmacie Beshara.',
    transcription: 'Please pick up my prescription and bring it home.',
    // The board's R12 is a VOICE ticket; without this the capture badge read
    // TYPED. The replay band still needs a local clip, which no fixture has.
    audioUrl: 'https://cdn.jeeb.app/requests/9f3c/clip.m4a',
    photoUrls: <String>['https://example.com/photo1.jpg'],
    tierId: 'express',
    tierName: 'Express',
    pickupAddress: 'Pharmacie Beshara, Hamra, Beirut',
    dropoffAddress: 'Achrafieh, Beirut',
    recipientPhone: '+96170123456',
  );

  /// What a tier-CARD tap actually produces, copied field for field from
  /// `app_router.dart:1107`:
  static const RequestDraft tierCardEntry = RequestDraft(
    description: '',
    tierId: 'express',
    tierName: 'express',
  );

  /// The floor: a description and nothing else.
  /// Every optional field on [RequestDraft] is optional in practice too — no
  static const RequestDraft descriptionOnly = RequestDraft(
    description: 'Two bags of ice from the corner shop, please.',
  );

  /// The longest plausible payload: a spoken request with a full transcription,
  /// a batch of photos, a scheduled tier, and two landmark-shaped addresses.
  static const RequestDraft longest = RequestDraft(
    description:
        '2 kg Turkish coffee, extra fine grind, from the roastery beside the '
        'gold souq — plus 3 boxes of Ceylon tea if they have the green tin, a '
        'litre of laban, and a box of the small cardamom. Please check the '
        'roast date before you pay, and call me if the tea is out of stock '
        'instead of picking a substitute.',
    transcription:
        'Hi, so I need two kilos of the Turkish coffee, the extra fine one, '
        'from the roastery next to the gold souq, and if they have the Ceylon '
        'tea in the green tin then three boxes of that as well, plus a litre '
        'of laban and the small cardamom, and please look at the roast date '
        'before you pay for the coffee.',
    photoUrls: <String>[
      'https://cdn.jeeb.app/requests/9f3c/1.jpg',
      'https://cdn.jeeb.app/requests/9f3c/2.jpg',
      'https://cdn.jeeb.app/requests/9f3c/3.jpg',
      'https://cdn.jeeb.app/requests/9f3c/4.jpg',
      'https://cdn.jeeb.app/requests/9f3c/5.jpg',
      'https://cdn.jeeb.app/requests/9f3c/6.jpg',
      'https://cdn.jeeb.app/requests/9f3c/7.jpg',
      'https://cdn.jeeb.app/requests/9f3c/8.jpg',
      'https://cdn.jeeb.app/requests/9f3c/9.jpg',
      'https://cdn.jeeb.app/requests/9f3c/10.jpg',
      'https://cdn.jeeb.app/requests/9f3c/11.jpg',
      'https://cdn.jeeb.app/requests/9f3c/12.jpg',
    ],
    tierId: 'scheduled',
    tierName: 'Scheduled — tomorrow, before 9:00 am',
    pickupAddress:
        'Souq Waqif — gold souq entrance, beside the roastery with the green '
        'awning, Doha 30215',
    dropoffAddress:
        'Building 12, 4th floor, apartment 41, Rue Abdel Wahab El Inglizi, '
        'Achrafieh, Beirut 1100 2070',
    recipientPhone: '+96171234567',
  );
}

/// Mounts `RequestSummaryScreen` the way `/request-summary` mounts it: a
/// `BlocProvider<RequestSummaryCubit>` over a cubit seeded with [draft].
/// The screen is passed IN rather than constructed here, for two reasons: it
class RequestSummaryScreenPreviewHost extends StatefulWidget {
  const RequestSummaryScreenPreviewHost({
    required this.screen,
    required this.service,
    super.key,
    this.draft,
    this.drive = false,
    this.standInRouter = false,
  });

  /// The screen under review — `const RequestSummaryScreen()`.
  final Widget screen;

  /// The submission seam the cubit is built on.
  final RequestSubmissionService service;

  /// The draft to seed, or `null` to leave the cubit at its initial state.
  final RequestDraft? draft;

  /// Start a `submit()` as the cubit is created.
  final bool drive;

  /// Put a local [GoRouter] above the screen so its post-submit `context.go`
  /// has somewhere to land.
  final bool standInRouter;

  /// The path the real route uses, reused so a preview and the app agree.
  static const String summaryPath = '/request-summary';

  /// What the stand-in destination renders, and what a render test pins to
  /// prove the submit really navigated away from the screen.
  static const String requestsTabCaption = 'Requests tab (preview stand-in)';

  @override
  State<RequestSummaryScreenPreviewHost> createState() =>
      _RequestSummaryScreenPreviewHostState();
}

class _RequestSummaryScreenPreviewHostState
    extends State<RequestSummaryScreenPreviewHost> {
  /// Built once and disposed with the host: a [GoRouter] rebuilt every frame
  /// would drop the navigation state, and the whole point of the stand-in is
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (!widget.standInRouter) return;
    _router = GoRouter(
      initialLocation: RequestSummaryScreenPreviewHost.summaryPath,
      routes: <RouteBase>[
        // Where a successful submit goes: `context.go('/')`, the client shell's
        GoRoute(
          path: '/',
          builder: (_, _) => const _RequestSummaryScreenRequestsTabStandIn(),
        ),
        GoRoute(
          path: RequestSummaryScreenPreviewHost.summaryPath,
          name: 'request-summary',
          builder: (_, _) => _seeded(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  /// The provider the shipped route builds, with the local service in place of
  /// `sl<RequestSubmissionService>()`.
  Widget _seeded() => BlocProvider<RequestSummaryCubit>(
        create: (_) {
          final RequestSummaryCubit cubit =
              RequestSummaryCubit(widget.service);
          final RequestDraft? draft = widget.draft;
          if (draft != null) cubit.setDraft(draft);
          if (widget.drive) unawaited(cubit.submit());
          return cubit;
        },
        child: widget.screen,
      );

  @override
  Widget build(BuildContext context) {
    final GoRouter? router = _router;
    if (router == null) return _seeded();
    // `Router.withConfig` is exactly what `MaterialApp.router` does internally,
    return Router.withConfig(config: router);
  }
}

/// Stand-in for the client shell's Requests tab, the destination a successful
/// submit is sent to.
class _RequestSummaryScreenRequestsTabStandIn extends StatelessWidget {
  const _RequestSummaryScreenRequestsTabStandIn();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            // Forced LTR: a diagnostic, not shipped copy.
            RequestSummaryScreenPreviewHost.requestsTabCaption,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
