import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';
import 'cubit/cancellation_cubit.dart';
import 'cubit/cancellation_state.dart';
import 'widgets/cancellation_reason_group.dart';
import 'widgets/cancellation_success_sheet.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/cancellation_screen_fixtures.dart';

/// Cancellation reason-picker and submission screen (T-MOB-024).
///
/// Accessible from the active delivery menu for both client and Jeeber roles.
/// Emits [onCancelled] with the result when the gateway returns 200.
class CancellationScreen extends StatelessWidget {
  const CancellationScreen({
    super.key,
    required this.deliveryId,
    required this.isJeeber,
    this.repository,
    this.initialState,
  });

  final String deliveryId;
  final bool isJeeber;

  /// Injectable for widget tests; production resolves via DI.
  final CancellationRepository? repository;

  /// DT-04 screen-catalog / test seam: preset the cubit's initial state (e.g.
  /// [CancellationLoading]) so the screen can be previewed mid-submit. Null
  /// (default, production) starts idle exactly as before.
  final CancellationState? initialState;

  /// Resolves the repo: an explicit override (tests) → the GetIt-registered
  /// [DioCancellationRepository]. The `/orders/:id/cancel` route builder passes
  /// no `repository` and no `Provider<CancellationRepository>` exists in the
  /// widget tree (it lives only in GetIt), so reading it from `context`
  /// threw ProviderNotFoundException on every open (P0-CANCEL-CRASH). Resolve
  /// via `sl` — the same pattern SearchResultsScreen/NotificationsListScreen
  /// use for a DI-only repository.
  CancellationRepository _resolveRepository() =>
      repository ?? sl<CancellationRepository>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CancellationCubit(
        _resolveRepository(),
        initialState: initialState,
      ),
      child: _CancellationView(
        deliveryId: deliveryId,
        isJeeber: isJeeber,
      ),
    );
  }
}

class _CancellationView extends StatefulWidget {
  const _CancellationView({
    required this.deliveryId,
    required this.isJeeber,
  });

  final String deliveryId;
  final bool isJeeber;

  @override
  State<_CancellationView> createState() => _CancellationViewState();
}

class _CancellationViewState extends State<_CancellationView> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  List<String> _reasons(AppLocalizations l10n) {
    if (widget.isJeeber) {
      return [
        'cannot_complete',
        'vehicle_issue',
        'emergency',
        'prohibited_item',
        'other',
      ];
    }
    return [
      'changed_mind',
      'wait_too_long',
      'wrong_address',
      'other',
    ];
  }

  String _label(String reason, AppLocalizations l10n) {
    switch (reason) {
      case 'changed_mind':
        return l10n.cancellationReasonChangedMind;
      case 'wait_too_long':
        return l10n.cancellationReasonWaitTooLong;
      case 'wrong_address':
        return l10n.cancellationReasonWrongAddress;
      case 'cannot_complete':
        return l10n.cancellationReasonCantComplete;
      case 'vehicle_issue':
        return l10n.cancellationReasonVehicleIssue;
      case 'emergency':
        return l10n.cancellationReasonEmergency;
      case 'prohibited_item':
        return l10n.cancellationReasonProhibitedItem;
      default:
        return l10n.cancellationReasonOther;
    }
  }

  Future<void> _submit(BuildContext context) async {
    final reason = _selectedReason;
    if (reason == null) return;
    await context.read<CancellationCubit>().submit(
          deliveryId: widget.deliveryId,
          reason: reason,
          otherDetails: reason == 'other' ? _otherController.text : null,
        );
  }

  void _onStateChange(BuildContext context, CancellationState state) {
    if (state is CancellationSuccess) {
      _showSuccessSheet(context, state.result);
    } else if (state is CancellationTooLate) {
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).cancellationTooLate,
      );
    } else if (state is CancellationError) {
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).cancellationGenericError,
      );
    }
  }

  void _showSuccessSheet(BuildContext context, CancellationResult result) {
    CancellationSuccessSheet.show(
      context: context,
      result: result,
      onDone: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = _reasons(l10n);

    return BlocListener<CancellationCubit, CancellationState>(
      listener: _onStateChange,
      child: Semantics(
        identifier: 'cancellation_root',
        container: true,
        child: Scaffold(
          appBar: OMDSAppBar(
            title: l10n.cancellationTitle,
            showBackButton: true,
          ),
          body: _Body(
            reasons: reasons,
            selectedReason: _selectedReason,
            otherController: _otherController,
            label: (r) => _label(r, l10n),
            onReasonChanged: (r) => setState(() => _selectedReason = r),
            onSubmit: () => _submit(context),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.reasons,
    required this.selectedReason,
    required this.otherController,
    required this.label,
    required this.onReasonChanged,
    required this.onSubmit,
  });

  final List<String> reasons;
  final String? selectedReason;
  final TextEditingController otherController;
  final String Function(String) label;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PromptText(text: l10n.cancellationReasonPrompt),
            const SizedBox(height: Spacing.medium),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CancellationReasonGroup(
                      reasons: reasons,
                      selectedReason: selectedReason,
                      labelOf: label,
                      onChanged: onReasonChanged,
                    ),
                    if (selectedReason == 'other') ...[
                      const SizedBox(height: Spacing.small),
                      _OtherTextField(controller: otherController),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.medium),
            _SubmitButton(
              isEnabled: selectedReason != null,
              onSubmit: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _OtherTextField extends StatelessWidget {
  const _OtherTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Identifier on a wrapping node so Maestro can locate the free-text "other"
    // reason input; the field owns its own editable semantics underneath.
    return Semantics(
      identifier: 'cancellation_other_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.cancellationOtherHint,
        maxLines: 3,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isEnabled, required this.onSubmit});

  final bool isEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CancellationCubit, CancellationState>(
      builder: (context, state) {
        final loading = state is CancellationLoading;
        return Semantics(
          identifier: 'cancellation_submit_cta',
          container: true,
          button: true,
          child: OmdsPrimaryButton(
            text: loading
                ? l10n.deliveryActionCancellingLabel
                : l10n.cancellationConfirmButton,
            isEnabled: isEnabled && !loading,
            onTap: onSubmit,
          ),
        );
      },
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
// Render tests: test/previews/cancellation/cancellation_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so four things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_cancellationScreenPhoneBox], 390x844, and the 320x568
//    [_cancellationScreenCompactBox] for the narrowest viewport the app
//    supports) rather than the harness default 390x200 — a scrolling reason
//    list with a pinned footer button cannot be judged in a 200 pt strip.
//
// 2. It is mounted under a real `Router`, because the screen navigates.
//    [_CancellationScreenHost] mirrors the production stack: `/orders/:id`
//    (the delivery hub, standing in) with `cancel` PUSHED on top of it, which
//    is the shape `_CancelButton` in `delivery_detail_screen.dart:697`
//    produces. So the app-bar back arrow has somewhere to pop, and the
//    `context.pop()` at the end of the success flow resolves against a real
//    router instead of throwing. Two production wrappers are NOT reproduced,
//    and neither is a defect: the `RootAwareBackScope` that `app_router.dart`
//    puts around this route (`backFallbacks['delivery-cancel'] = '/'`), and the
//    single-navigator assumption behind the success sheet's
//    `Navigator.of(context, rootNavigator: true).pop()` — in the app that IS
//    the router's navigator (every route here is top-level; there is no shell
//    navigator between them), while in the canvas the preview's own
//    `MaterialApp` sits above the router and takes the "root" role. So tapping
//    Done in the canvas dismisses the preview page rather than the sheet. Read
//    the sheet itself in `cancellation_success_sheet.dart`.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy — see
//    [CancellationScreenCaptions]. Three of the six previews render the SAME
//    four client reasons and the same button, because what separates them — a
//    seeded `CancellationError`, a seeded `CancellationTooLate` — lives in the
//    cubit and never reaches the screen (see the first bullet below); a
//    caption is the only thing that tells one card from another, in the
//    canvas and in the render
//    test's `expectedText`. The render test additionally asserts the real state
//    behind each caption — which reason list, whether the submit button is
//    enabled, what the button says — so the caption is never the whole proof.
//
// 4. The states come from `lib/devtool/catalog/fixtures/
//    cancellation_screen_fixtures.dart`, shared verbatim with the Screen
//    Catalog entry (`devtool/catalog/entries/batch_02_entries.dart`), which
//    used to own a private copy of the same fake. Nothing here builds a
//    `DioCancellationRepository` and nothing resolves `sl` — every preview
//    passes `repository:` explicitly — so these are network-free by
//    construction rather than by the guard in [jeebPreviewHost].
//
// ## What these previews exposed in the screen
//
//  * **A failed cancellation has no rendering.** `CancellationSuccess`,
//    `CancellationTooLate` and `CancellationError` are consumed by a
//    `BlocListener`, which fires on state CHANGES only and never on the state a
//    cubit is constructed in. `Rejected · 5xx (seeded)` and
//    `Too late · 409 (seeded)` seed exactly those states through the DT-04
//    `initialState:` seam and render a pristine reason picker: no inline error,
//    no retry, no trace of the failure. The only feedback the screen ever
//    gives for a rejected cancel is a 4-second floating snackbar — and it is
//    `showOmdsSnackbar`, the neutral one, not `showOmdsErrorSnackbar`, so the
//    failure is not even coloured as one. Anything that misses those 4 seconds
//    (backgrounded app, screen reader mid-utterance, a user looking at the
//    reason list) sees a form that looks exactly like one nobody submitted. Tap
//    Confirm on either of those two cards to watch the whole failure appear and
//    evaporate.
//  * **The Jeeber reason list is unreachable in the shipped app.** `isJeeber`
//    is read from `?role=jeeber` (`app_router.dart:860`), and the ONLY in-app
//    entry point — the cancel button on the delivery hub,
//    `delivery_detail_screen.dart:697` — pushes `/orders/$deliveryId/cancel`
//    with no query at all, while its sibling actions in that same file read
//    `RoleCubit` and append `?mode=jeeber`. So a Jeeber cancelling a delivery
//    is offered "Changed my mind / Taking too long / Wrong address", and the
//    four reasons written for them (`cannot_complete`, `vehicle_issue`,
//    `emergency`, `prohibited_item`) are shown by these previews and by the
//    catalog and nowhere else.
//  * **"Other" cannot be seeded, only tapped** — and it is the one choice that
//    changes the screen. `_selectedReason` is a private `State` field with no
//    constructor argument, so no preview and no catalog card can open with a
//    reason selected; the free-text `cancellation_other_field` and the ENABLED
//    submit button exist in the canvas only after a tap. The render test taps
//    through what a still card cannot show, including the consequence: picking
//    "Other" and typing NOTHING leaves Confirm enabled and submits
//    `otherDetails: ''`, because nothing validates the field the reason exists
//    to require.
//  * **Nothing above the button says a submission is happening.**
//    `Submitting · confirm in flight` seeds `CancellationLoading`: the label
//    swaps to "Cancelling…" and the button greys out, and that is the entire
//    in-flight treatment. No overlay, no progress indicator, no dimming — and
//    the reason rows stay live, so a tap moves the radio underneath a request
//    that has already gone out with a different reason.
//  * **At the 200% accessibility ceiling on a 320x568 device, ONE of five
//    reasons is on screen.** Measured on `Jeeber · compact 320x568` and pinned
//    in the render test: the prompt grows to three lines (144 pt) and the CTA
//    holds its 48 pt, both OUTSIDE the scroll view, leaving the reason list
//    208 pt for roughly 784 pt of rows. The first reason ends at 480 pt, the
//    fold is at 488, and the second row starts at 496 — with no scrollbar, no
//    fade and no shadow, so a radio group of five reads as a list of one.
//    Arabic on the 390x844 phone is roomier and still cuts the fifth row
//    (736→784 against a viewport ending at 764). Nothing overflows: the tiles
//    grow and the scroll view absorbs them, which is exactly why this is
//    invisible without a preview at a real device size.
//  * **The pinned CTA clips its own label at 200%.** `OmdsPrimaryButton` is a
//    fixed 48 pt, and "Confirm Cancellation" needs 120 pt at that scale, so
//    the one control that commits the cancellation is laid out into a third of
//    the height its text asks for — silently, with no overflow stripe.
//  * `_reasons(AppLocalizations l10n)` never reads its parameter — the reason
//    CODES are hardcoded and localization happens later in `_label`. Harmless,
//    but it is why the role split is a bare `if (widget.isJeeber)` rather than
//    anything the l10n layer could see.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _cancellationScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
///
/// Height is what this screen runs out of: the prompt and the footer button sit
/// OUTSIDE the scroll view, so only the reason list can give way.
const Size _cancellationScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class CancellationScreenCaptions {
  CancellationScreenCaptions._();

  /// Four client reasons, nothing selected, Confirm disabled.
  static const String clientPicker = 'preview · client · nothing selected';

  /// The five Jeeber reasons no in-app route can reach.
  static const String jeeberPicker = 'preview · jeeber · nothing selected';

  /// The same Jeeber list on the 320x568 viewport.
  static const String compact = 'preview · jeeber · 320x568 viewport';

  /// `POST /v1/deliveries/{id}/cancel` in flight.
  static const String submitting = 'preview · confirm in flight';

  /// A seeded `CancellationError` — and the picture is unchanged.
  static const String rejected = 'preview · 5xx seeded · nothing renders';

  /// A seeded `CancellationTooLate` — likewise.
  static const String tooLate = 'preview · 409 seeded · nothing renders';
}

/// The delivery hub the cancel screen is pushed from, and pops back to.
///
/// The real page is `DeliveryDetailScreen` at `/orders/:id`; here it only has
/// to exist, so BACK and the success sheet's `context.pop()` land on a page
/// instead of emptying the navigator.
class _CancellationScreenOrderStandIn extends StatelessWidget {
  const _CancellationScreenOrderStandIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic, not shipped copy.
          'delivery hub',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [CancellationScreen] and captions the state.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt every frame would drop the navigation state `pop`
/// depends on. `cancel` is a SUBROUTE of `/orders/:id`, so the initial stack is
/// two pages deep — the shape `context.push('/orders/$id/cancel')` produces in
/// production, and the one that decides whether the back arrow and the success
/// sheet's Done have anywhere to go.
class _CancellationScreenHost extends StatefulWidget {
  const _CancellationScreenHost({required this.state, required this.caption});

  /// The designed state, shared with the Screen Catalog.
  final CancellationScreenDesignedState state;

  /// The line painted above the device frame — see note 3 in the prose.
  final String caption;

  @override
  State<_CancellationScreenHost> createState() =>
      _CancellationScreenHostState();
}

class _CancellationScreenHostState extends State<_CancellationScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/orders/${widget.state.deliveryId}/cancel',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (_, _) => const _CancellationScreenOrderStandIn(),
        routes: <RouteBase>[
          GoRoute(
            path: 'cancel',
            builder: (_, _) => CancellationScreen(
              deliveryId: widget.state.deliveryId,
              isJeeber: widget.state.isJeeber,
              repository: widget.state.repository,
              initialState: widget.state.initialState,
            ),
          ),
        ],
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

Widget _cancellationScreenHosted(
  CancellationScreenDesignedState state,
  String caption,
) =>
    _CancellationScreenHost(state: state, caption: caption);

/// The state every client opens: four reasons, none selected, Confirm
/// disabled.
///
/// The disabled button is the whole gate — it is the only thing between a
/// mis-tap and a cancelled delivery, and it is drawn by `isEnabled:` alone, so
/// "disabled" here is a colour and nothing else.
///
/// Matrixed because this is the shipping-reachable reading and the one that has
/// to survive translation: the AR card mirrors four `ListTile`s whose leading
/// radio glyph carries the entire selection state, and the 200% card is where
/// that 24 dp glyph stops growing with the text it marks.
@JeebPreview(
  group: 'cancellation',
  name: 'Client · nothing selected',
  size: _cancellationScreenPhoneBox,
  matrix: true,
)
Widget cancellationScreenClientPicker() => _cancellationScreenHosted(
      cancellationScreenClientPickerState,
      CancellationScreenCaptions.clientPicker,
    );

/// The Jeeber's five reasons — the same screen, a list the app cannot show.
///
/// See the section prose: `isJeeber` is fed by `?role=jeeber` and the only
/// entry point never passes it, so this is the state Jeebers were designed to
/// get and do not get. It also carries the longest shipping labels ("Cannot
/// complete delivery", "Prohibited item detected").
///
/// Matrixed because it is the longest content the screen can hold — five rows
/// plus the prompt and the pinned footer — so it is where AR and 200% text run
/// out of room first.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber · nothing selected',
  size: _cancellationScreenPhoneBox,
  matrix: true,
)
Widget cancellationScreenJeeberPicker() => _cancellationScreenHosted(
      cancellationScreenJeeberPickerState,
      CancellationScreenCaptions.jeeberPicker,
    );

/// The tallest list on the shortest supported device, 320x568.
///
/// The prompt and the Confirm button sit outside the `SingleChildScrollView`,
/// so they are never what gives way; the reason list scrolls under them. At the
/// default text scale all five rows fit. At 200% they do not: the list is left
/// with 208 pt for ~784 pt of rows, the first reason ends 8 pt above the fold
/// and the other four are below it, unannounced. See the pinned measurements in
/// the render test.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber · compact 320x568',
  size: _cancellationScreenCompactBox,
)
Widget cancellationScreenCompact() => _cancellationScreenHosted(
      cancellationScreenJeeberPickerState,
      CancellationScreenCaptions.compact,
    );

/// `POST /v1/deliveries/{id}/cancel` in flight.
///
/// The entire in-flight treatment: the button reads "Cancelling…" and is
/// disabled. No overlay, no progress, and the reason rows above it stay live
/// and tappable while the write is in the air. Held open by a repository whose
/// future never completes, so the state is stable to look at.
@JeebPreview(
  group: 'cancellation',
  name: 'Submitting · confirm in flight',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenSubmitting() => _cancellationScreenHosted(
      cancellationScreenSubmittingState,
      CancellationScreenCaptions.submitting,
    );

/// A seeded `CancellationError` — and this is what it looks like: nothing.
///
/// Read it next to `Client · nothing selected`; they are the same picture. The
/// error lane is delivered entirely by a `BlocListener`, which never sees the
/// state a cubit was constructed in, so the DT-04 `initialState:` seam that can
/// preset "submitting" cannot preset "failed". There is no inline error
/// surface to preset either — a rejected cancellation is a 4-second neutral
/// snackbar over an unchanged form.
///
/// The repository behind this card keeps rejecting, so tapping a reason and
/// then Confirm shows the real thing: `An unexpected error occurred.` — the
/// same string for a 500, a timeout and a malformed body, with the gateway's
/// own message deliberately dropped so it can never leak into the UI.
@JeebPreview(
  group: 'cancellation',
  name: 'Rejected · 5xx (seeded)',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenRejected() => _cancellationScreenHosted(
      cancellationScreenRejectedState,
      CancellationScreenCaptions.rejected,
    );

/// A seeded `CancellationTooLate` — invisible for the same reason.
///
/// 409 is the only failure with copy of its own ("Too late to cancel — your
/// Jeeber is already on the way.") and the only one the user can do nothing
/// about, which makes it the worst one to render as a 4-second snackbar over a
/// form that still offers Confirm. Nothing marks the delivery as
/// no-longer-cancellable; the user can submit again, and again, and get the
/// same snackbar each time. Tap through to see it.
@JeebPreview(
  group: 'cancellation',
  name: 'Too late · 409 (seeded)',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenTooLate() => _cancellationScreenHosted(
      cancellationScreenTooLateState,
      CancellationScreenCaptions.tooLate,
    );
