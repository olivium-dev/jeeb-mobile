/// Widget previews for [DmOnboardingProgressHeader] — run with
/// `flutter widget-preview start`.
///
/// ## How the states are driven
///
/// The header is a [BlocBuilder] over [DmOnboardingCubit], so a preview has to
/// put a cubit in the tree. [DmOnboardingCubit] has no `seed:` constructor, so
/// the previews use a local subclass that emits a fixed [DmOnboardingState] and
/// then never moves. Its two dependencies are the in-memory implementations the
/// existing suite already binds — [StubPhotoPickerService] returns canned bytes
/// and [FakeDmOnboardingGateway] records a submission in a field — and nothing
/// below ever calls either one: the header renders no controls, so there is no
/// path from a preview to a request. These previews are network-free by
/// construction, not just by [jeebPreviewHost]'s guard.
///
/// ## The axis the states walk
///
/// [DmOnboardingState.completedSteps] — the only value the header forwards to
/// the bar. It is `step.index`, except when [DmOnboardingState.isSubmitted] is
/// true, in which case it is [DmOnboardingState.totalSteps]. Both branches get
/// previews, plus the in-flight state that must NOT move the bar.
///
/// ## About the captions
///
/// The header renders no text of its own: [OMDSStepperProgress] is a
/// [CustomPaint] drawing two lines, and the "Step n of N" string is a
/// [Semantics] *value*, deliberately invisible to match Figma. `find.text` on
/// the widget's own output therefore cannot tell one state from another, and a
/// render test bound to it would pass while all five previews drew the same
/// bar. Each preview carries a one-line caption naming its state, used by the
/// test only to address a state; the assertions that prove the states really
/// differ — the forwarded `completedSteps`, the screen-reader value, and the
/// painted fill — live in
/// `test/previews/jeeber_onboarding/dm_onboarding_progress_header_preview_test.dart`.
/// This mirrors `tracking_map_surface_preview.dart`, which has the same
/// problem.
///
/// ## What these previews surface in the widget
///
///  * **The fill does not mirror under RTL.** `_StepperPainter` draws from
///    `Offset(0, …)` to `Offset(width * progress, …)` on a raw [Canvas], and
///    Flutter does not flip canvas coordinates for text direction. The Arabic
///    rendering of every state below fills from the LEFT edge, i.e. the bar
///    empties as the Jeeber progresses. The `EdgeInsetsDirectional` padding on
///    the header mirrors correctly, which is what makes this easy to miss.
///  * **Step 1 of 3 shows a completely empty bar.** `completedSteps` is
///    `step.index`, so the first step reports zero and `_StepperPainter` skips
///    the fill entirely (`if (progress > 0)`). The doc on [DmOnboardingStep]
///    says the bar fills `index + 1 / values.length`; the state says otherwise,
///    and the state wins.
///  * **`Submitted · full bar` is unreachable in the app.** Nothing in
///    [DmOnboardingCubit] ever emits `isSubmitted: true` — the service-area
///    step sets `coverageReady` and hands off to the KYC wizard — so the only
///    branch that reaches 100% is dead code today, and the bar tops out at 2/3.
///    It is previewed anyway, because the header's `buildWhen` still watches
///    the flag and a later PR may light it up.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_progress_header.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../harness/jeeb_preview.dart';

/// Phone width. The header itself is only 32 pt tall (12 + 12 + 8); the rest
/// of the box is headroom for the caption at the matrix's 200%-text rendering,
/// where it wraps to three lines. Measured, not guessed — see
/// `the declared canvas box fits the content at 200% text` in the render test.
const Size _headerBox = Size(390, 128);

/// A [DmOnboardingCubit] pinned to one state.
///
/// Both dependencies are in-memory (see the library doc) and neither is ever
/// exercised: the header has no controls, so no preview can reach `next()`,
/// `back()` or a picker.
class _SeededDmOnboardingCubit extends DmOnboardingCubit {
  _SeededDmOnboardingCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: seed.step,
        ) {
    emit(seed);
  }
}

/// Renders the header the way `DmOnboardingScreen` does — the first child of a
/// [Column] under the app bar — with a caption naming the state beneath it.
///
/// The caption is preview scaffolding (see the library doc). It sits OUTSIDE
/// [DmOnboardingProgressHeader] so it can never be mistaken for something the
/// widget draws, and it is deliberately tiny so the 200%-text rendering still
/// shows the bar rather than a wall of label.
Widget _hosted(String caption, DmOnboardingState seed) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => _SeededDmOnboardingCubit(seed),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DmOnboardingProgressHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xLarge,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Entry state, and the one every Jeeber sees first — and the bar is EMPTY.
///
/// `completedSteps` is `step.index`, which is 0 on the photo step, so
/// `_StepperPainter` takes its `if (progress > 0)` early-out and paints the
/// track alone. A wizard that announces "Step 1 of 3" over a bar showing no
/// progress at all reads as broken rather than as "not started"; the doc on
/// [DmOnboardingStep] promises `index + 1 / values.length`, which would be a
/// third of a bar. This preview is the state that disagreement produces.
@JeebPreview(group: 'jeeber_onboarding', name: 'Step 1 · photo', size: _headerBox)
Widget dmOnboardingProgressStepPhoto() => _hosted(
      'Step 1 of 3 — bar empty',
      const DmOnboardingState(),
    );

/// One step done: the address form. 1/3 of the track is filled.
///
/// The first state where anything is painted at all, so it is also the first
/// place the RTL finding is visible — in Arabic this third sits against the
/// LEFT edge, on the wrong end of a mirrored layout.
@JeebPreview(group: 'jeeber_onboarding', name: 'Step 2 · address', size: _headerBox)
Widget dmOnboardingProgressStepAddress() => _hosted(
      'Step 2 of 3 — one third',
      const DmOnboardingState(step: DmOnboardingStep.address),
    );

/// The last step: service area. 2/3 filled — and this is as far as the bar
/// ever gets in the shipping app, because the wizard hands off to KYC rather
/// than marking itself submitted.
@JeebPreview(group: 'jeeber_onboarding', name: 'Step 3 · service area', size: _headerBox)
Widget dmOnboardingProgressStepServiceArea() => _hosted(
      'Step 3 of 3 — two thirds',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: DmOnboardingHomeBase(
          lat: 33.8938,
          lng: 35.5018,
          label: 'Beirut, Lebanon',
        ),
      ),
    );

/// NEGATIVE control: Continue tapped, the coverage check is in flight, and the
/// bar must not move.
///
/// Visually identical to `Step 3 · service area` on purpose — that IS the
/// contract. `buildWhen` compares only `step` and `isSubmitted`, so an
/// `isSubmitting` flip does not even rebuild the header. If this preview ever
/// diverges from the one above, something started reacting to in-flight work
/// and the bar has begun advancing on an outcome that has not happened yet.
@JeebPreview(group: 'jeeber_onboarding', name: 'Submitting on step 3', size: _headerBox)
Widget dmOnboardingProgressSubmitting() => _hosted(
      'Submitting — bar unchanged',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: DmOnboardingHomeBase(
          lat: 33.8938,
          lng: 35.5018,
          label: 'Beirut, Lebanon',
        ),
        isSubmitting: true,
      ),
    );

/// The terminal state: the only one that reaches 100%.
///
/// `completedSteps` short-circuits to [DmOnboardingState.totalSteps] when
/// `isSubmitted` is true, regardless of `step`. Worth previewing for two
/// reasons: it is the full-bar rendering nobody has seen (no code path in
/// [DmOnboardingCubit] emits the flag — see the library doc), and it is the one
/// state where the fill spans the whole track, which is where the missing RTL
/// mirroring stops being visible at all and the bug would go quiet.
@JeebPreview(group: 'jeeber_onboarding', name: 'Submitted · full bar', size: _headerBox)
Widget dmOnboardingProgressSubmitted() => _hosted(
      'Submitted — bar full',
      const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        isSubmitted: true,
      ),
    );
