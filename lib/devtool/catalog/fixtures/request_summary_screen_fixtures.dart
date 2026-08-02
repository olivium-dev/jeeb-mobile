// Shared dev-only fixtures for `RequestSummaryScreen` — the last surface a
// client reads before a request is created, at `/request-summary`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_10_entries.dart`, feature
//     `request_summary`, states "Loaded" / "Submitting" / "Error — Network"),
//     and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/request_summary/presentation/request_summary_screen.dart`.
//
// The catalog entry DID have fixtures and they are extracted here verbatim:
// [RequestSummaryScreenDrafts.full] is byte-for-byte the draft its three states
// were hand-built with (`_sampleRequestDraft()`), and
// [RequestSummaryScreenFakeSubmissionService] is its `_FakeRequestSubmissionService`
// with the privacy underscore removed. The other three drafts are new, and each
// one is a shape the SHIPPED compose flow really produces — see their dartdoc.
//
// ## Network-free by construction
//
// The only collaborator [RequestSummaryCubit] takes is a
// [RequestSubmissionService], and the sole implementation this file constructs
// is the local fake below. `DioRequestSubmissionService` — the one
// `injection_container.dart` registers and `app_router.dart:1333` resolves via
// `sl<RequestSubmissionService>()` — is never built and never reached, so
// nothing here can `POST /requests`. The `CatalogNetworkGuard` that both dev
// hosts install is the net, not the plan.
//
// ## Why the HOST is a fixture too
//
// `RequestSummaryScreen` takes no constructor seam at all: it reads
// `RequestSummaryCubit` off the ambient `BlocProvider` and its state machine is
// driven by `submit()`, not by a parameter. So *how* a state is reached — seed
// the draft, then let a submit run or not — is the whole of the fixture, and two
// surfaces each deciding that for themselves would be two different screens
// wearing the same name. [RequestSummaryScreenPreviewHost] owns that decision
// once.
//
// It also owns one thing the catalog does not need and the canvas cannot do
// without: an optional stand-in [GoRouter]. On a successful submit the screen
// calls `context.go('/')` (`request_summary_screen.dart:29`), which throws under
// the bare `MaterialApp` the preview canvas and the render harness provide. On
// the device the catalog runs on there is already a real router above the
// screen, so the catalog keeps `standInRouter: false` and its behaviour is
// unchanged by this extraction.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// The local [RequestSubmissionService] every state is driven through.
///
/// Extracted verbatim from the Screen Catalog's `_FakeRequestSubmissionService`.
/// Three behaviours, one class:
///
///   * default — succeeds on the next microtask with [mintedRequestId];
///   * `pending: true` — never resolves, which is the only way to hold the
///     screen on its submitting state (the cubit clears `isSubmitting` the
///     moment the future lands);
///   * `failure:` — completes with a [RequestSubmissionException], which the
///     cubit turns into a user-facing string in `_messageFor`.
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
  /// layer ever reads it back (see the preview section).
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
///
/// Every one is a shape an upstream step can really hand to
/// `/request-summary` via `extra` — the route is the only way in
/// (`app_router.dart:1326`) and it type-checks the payload, so the draft IS the
/// screen's entire input.
final class RequestSummaryScreenDrafts {
  RequestSummaryScreenDrafts._();

  /// The reference reading, and the draft the Screen Catalog's three states
  /// have always been built with: every optional field populated, so all six
  /// section cards render.
  ///
  /// Kept byte-for-byte identical to the catalog's `_sampleRequestDraft()` so
  /// the state a designer signed off against and the card an engineer opens in
  /// the canvas are the same object.
  static const RequestDraft full = RequestDraft(
    description: 'Pick up my prescription from Pharmacie Beshara.',
    transcription: 'Please pick up my prescription and bring it home.',
    photoUrls: <String>['https://example.com/photo1.jpg'],
    tierId: 'express',
    tierName: 'Express',
    pickupAddress: 'Pharmacie Beshara, Hamra, Beirut',
    dropoffAddress: 'Achrafieh, Beirut',
    recipientPhone: '+96170123456',
  );

  /// What a tier-CARD tap actually produces, copied field for field from
  /// `app_router.dart:1107`:
  ///
  /// ```dart
  /// onTierSelected: (tier) => context.push(
  ///   '/request-summary',
  ///   extra: RequestDraft(
  ///     description: '',
  ///     tierId: tier.id.name,
  ///     tierName: tier.id.name,
  ///   ),
  /// ),
  /// ```
  ///
  /// Two things follow, and both are visible the moment this renders: the
  /// description is EMPTY (the router's own comment says "the user fills it on
  /// the summary screen", which has no input control), and `tierName` is the
  /// raw `TierId` enum name rather than the localized tier label, so the Speed
  /// card reads `express` in both locales.
  static const RequestDraft tierCardEntry = RequestDraft(
    description: '',
    tierId: 'express',
    tierName: 'express',
  );

  /// The floor: a description and nothing else.
  ///
  /// Every optional field on [RequestDraft] is optional in practice too — no
  /// transcription (typed, not spoken), no photos, no tier, and no addresses
  /// (the compose flow can reach the summary before a pin is confirmed). Each
  /// section card is behind its own `if`, so this is the closest thing the
  /// screen has to an empty state: one card and the CTA.
  static const RequestDraft descriptionOnly = RequestDraft(
    description: 'Two bags of ice from the corner shop, please.',
  );

  /// The longest plausible payload: a spoken request with a full transcription,
  /// a batch of photos, a scheduled tier, and two landmark-shaped addresses.
  ///
  /// Nothing on this screen truncates — every value is a bare `Text` with no
  /// `maxLines` — so this is the payload that decides whether the review a
  /// client is asked to make fits on a phone or turns into scrolling.
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
///
/// The screen is passed IN rather than constructed here, for two reasons: it
/// keeps this library free of a circular import back into the feature, and —
/// the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget its previews are named after,
/// so `RequestSummaryScreen(...)` has to appear below the banner in the
/// screen's own file.
///
/// Three knobs, one per axis the screen actually has:
///
///  * [draft] — the payload, or `null` to leave the cubit on its initial state
///    (the screen's `draft == null` branch);
///  * [drive] — whether a `submit()` is started as the screen mounts, which is
///    the ONLY way to reach the submitting / error / submitted states: there is
///    no seam to hand the cubit a pre-made state;
///  * [standInRouter] — see the file header. `false` (the catalog, which runs
///    inside the app and already has a router) keeps the pre-extraction
///    behaviour exactly; `true` (the canvas and the render tests) supplies a
///    local one so `context.go('/')` lands on [requestsTabCaption] instead of
///    throwing.
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
  /// that a submit can move the stack.
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (!widget.standInRouter) return;
    _router = GoRouter(
      initialLocation: RequestSummaryScreenPreviewHost.summaryPath,
      routes: <RouteBase>[
        // Where a successful submit goes: `context.go('/')`, the client shell's
        // Requests tab. The real destination builds its own cubits off DI, so
        // the stand-in only has to exist and say which edge was taken.
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
  ///
  /// `create` is where the seeding happens on purpose. `setDraft` emits, and a
  /// driven `submit()` emits again on the next microtask — after this build
  /// pass has mounted the screen's `MultiBlocListener`, so the error and
  /// navigation listeners are subscribed in time to see the transition. Seeding
  /// from `initState` above the provider would race that.
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
    // so this adds a Router and nothing else — the ambient theme, locale and
    // text scale still come from the host above it.
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
