/// Widget previews for [DmOnboardingStepLayout] — run with
/// `flutter widget-preview start`.
///
/// [DmOnboardingStepLayout] is the *chrome* the three onboarding steps share:
/// a scrollable body under a bottom-pinned, full-width Continue. It owns no
/// copy of its own except that CTA, so every preview below is really asking one
/// of two questions:
///
/// * does the CTA stay pinned, full width, and reachable as the body grows?
/// * does the CTA read as gated / in-flight / live when it is?
///
/// The CTA is driven the way production drives it: an ambient
/// [DmOnboardingCubit] whose `isSubmitting` the layout's `BlocBuilder` watches.
/// The cubit here is built with [StubPhotoPickerService] and
/// [FakeDmOnboardingGateway] — the same in-memory pair `dm_onboarding_*_test`
/// injects — so these previews are network-free by construction, not merely by
/// the guard in [jeebPreviewHost]. Tapping Continue in the canvas therefore
/// advances the wizard's own state and, on the service-area step, resolves
/// against the fake gateway; nothing leaves the process.
///
/// The bodies approximate the three real steps rather than reusing them: each
/// step widget builds its own [DmOnboardingStepLayout], so mounting one here
/// would nest the chrome inside itself, and each step's body class is private.
/// The public parts are reused as-is ([DmOnboardingStepHeader],
/// [DmOnboardingPhotoUploadCard], [DmOnboardingAddressField]) and the copy is
/// pulled from the same ARB keys the steps use, so the AR rendering exercises
/// real Arabic instead of English literals.
///
/// ## Measured on this widget
///
/// Body height inside the scroll viewport, and the CTA block below it, at
/// 390 pt logical width:
///
/// | body                     | 1.0× | 2.0× | AR 1.0× | AR 2.0× |
/// |--------------------------|-----:|-----:|--------:|--------:|
/// | Photo (4:5 drop area)    |  540 |  792 |     540 |     792 |
/// | Address (4 fields)       |  416 |  672 |     416 |     672 |
/// | Service area             |  264 |  636 |     244 |     532 |
///
/// The CTA block is **68 px in every one of those twelve combinations** — a
/// hard 48 px button ([Sizes.fourXLarge]) plus the 20 px bottom gutter — and
/// its rect is x∈[24, 366] in EN and in AR alike, because the page gutter is an
/// `EdgeInsetsDirectional.symmetric`. So the chrome itself never moves; the
/// body scrolls under it. On a 844 pt phone the photo body already overflows
/// the 776 pt viewport at 200%, which is the normal reading, not a defect.
///
/// **Three things that constancy gives away, all visible in the canvas.**
///
/// 1. The CTA does not grow with the text scaler; the label does. Measured, EN:
///    20 px tall at 1.0×, 40 px at 2.0× (comfortable inside 48), exactly 48 px
///    at 2.5×, and 342×48 — the button's whole box — at 3.2×. From 3.2× up the
///    label's render box stays pinned at 342×48 while the glyphs keep growing,
///    so "Continue" is silently clipped: no ellipsis, no overflow stripe, no
///    exception. 2.0× (what the matrix renders) is therefore the last scale at
///    which this CTA is honest.
/// 2. Gated, in-flight and live are one contrast step apart and nothing else —
///    see [dmOnboardingStepLayoutPhotoGated] and
///    [dmOnboardingStepLayoutSubmitting] for what the semantics tree says about
///    each (short version: less than the pixels do).
/// 3. `_ScrollableContent` pads `top` only, so a body scrolled to its end sits
///    flush against the CTA with no gutter and no scroll affordance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_address_field.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_upload_card.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_header.dart';
import '../../features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_layout.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// Phone width; clears the 4:5 drop-area body at 1.0× (556 px of content plus
/// the 68 px CTA block). At 200% the body is 792 px and scrolls — that is the
/// state, not a badly chosen box.
const Size _photoBox = Size(390, 640);

/// Phone width; clears the four-field address body at 1.0× (432 + 68).
const Size _formBox = Size(390, 520);

/// Phone width; clears the service-area body at 1.0× (280 + 68, EN; AR is
/// 20 px shorter).
const Size _serviceAreaBox = Size(390, 360);

/// Deliberately short — a small phone with the keyboard up, or a fold in
/// landscape. `Expanded` hands the body whatever is left (192 px here) and the
/// CTA still lands at the bottom edge. That is the point of this box.
const Size _squeezedBox = Size(390, 260);

/// The canonical QA id for the wizard CTA (65_W2_TEST_PLAN JM-038). All three
/// steps pass this same string — only one step is mounted at a time.
const String _kContinueId = 'dm_onboarding_continue';

/// Reused from `dm_onboarding_cubit_test.dart`: the home base its service-area
/// cases pin.
const DmOnboardingHomeBase _kBeirutBase = DmOnboardingHomeBase(
  lat: 33.89,
  lng: 35.50,
  label: 'Beirut',
);

/// A [DmOnboardingCubit] parked on a fixed [DmOnboardingState].
///
/// The wizard cubit has no `seed:` constructor, so the state is emitted once at
/// construction. Both collaborators are the in-memory implementations the
/// existing tests use: [StubPhotoPickerService] returns canned bytes and only
/// when a pick is requested, and [FakeDmOnboardingGateway] resolves in memory.
/// Neither builds a Dio client.
class _PreviewDmOnboardingCubit extends DmOnboardingCubit {
  _PreviewDmOnboardingCubit(DmOnboardingState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeDmOnboardingGateway(),
          initialStep: seed.step,
        ) {
    emit(seed);
  }
}

/// Mounts the layout with an ambient cubit, exactly as each step does.
Widget _hosted(
  Widget content, {
  bool enabled = true,
  DmOnboardingState seed = const DmOnboardingState(),
}) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => _PreviewDmOnboardingCubit(seed),
    child: DmOnboardingStepLayout(
      content: content,
      continueIdentifier: _kContinueId,
      enabled: enabled,
    ),
  );
}

/// Photo-step body: heading pair + the real 4:5 drop-area card.
class _PhotoBody extends StatelessWidget {
  const _PhotoBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingPhotoUploadTitle,
          subtitle: l10n.dmOnboardingPhotoUploadSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        const DmOnboardingPhotoUploadCard(),
      ],
    );
  }
}

/// Address-step body: the four labeled fields, in the step's own order.
class _AddressBody extends StatelessWidget {
  const _AddressBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final DmOnboardingCubit cubit = context.read<DmOnboardingCubit>();
    final List<DmAddressFieldSpec> specs = <DmAddressFieldSpec>[
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_state_field',
        label: l10n.dmOnboardingAddressStateLabel,
        hint: l10n.dmOnboardingAddressStateHint,
        onChanged: cubit.setStateField,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_country_field',
        label: l10n.dmOnboardingAddressCountryLabel,
        hint: l10n.dmOnboardingAddressCountryHint,
        onChanged: cubit.setCountry,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_street_field',
        label: l10n.dmOnboardingAddressStreetLabel,
        hint: l10n.dmOnboardingAddressStreetHint,
        onChanged: cubit.setStreet,
      ),
      DmAddressFieldSpec(
        identifier: 'dm_onboarding_address_field',
        label: l10n.dmOnboardingAddressAddressLabel,
        hint: l10n.dmOnboardingAddressAddressHint,
        onChanged: cubit.setAddress,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DmAddressFieldSpec spec in specs)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
            child: DmOnboardingAddressField(spec: spec),
          ),
      ],
    );
  }
}

/// Service-area body: heading pair, section label, and the home-base map box —
/// empty (hint) or pinned (place label), matching `_HomeBaseMapContent`.
class _ServiceAreaBody extends StatelessWidget {
  const _ServiceAreaBody({this.homeBaseLabel});

  final String? homeBaseLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String? pinned = homeBaseLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingServiceAreaHeading,
          subtitle: l10n.dmOnboardingServiceAreaSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: Spacing.small),
        // Geometry copied from `_HomeBaseMapPin` / `_HomeBaseMapContent`:
        // a hard 100 px box (`Sizes.elevenXLarge`) holding a min-size Column.
        // Faithful on purpose — see the doc on
        // [dmOnboardingStepLayoutServiceAreaGated] for what that costs at 200%.
        ClipRRect(
          borderRadius: BorderRadius.circular(Sizes.small),
          child: Container(
            height: Sizes.elevenXLarge,
            width: double.infinity,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  pinned == null ? Icons.map_outlined : Icons.location_on,
                  size: Sizes.threeXLarge,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: Spacing.xSmall),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.medium,
                  ),
                  child: Text(
                    pinned ?? l10n.dmOnboardingServiceAreaMapPlaceholder,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 1 as a Jeeber first sees it: nothing uploaded, so Continue is GATED.
///
/// The tallest body the chrome carries — the drop area is a 4:5 `AspectRatio`,
/// so at 390 pt it alone is 427 px and the body (540 px at 1.0×, 792 px at
/// 200%) already exceeds the 776 pt viewport of an iPhone-sized screen. Read
/// here that the card scrolls and the CTA does not move.
///
/// The gate is the thing to look at. `enabled: false` changes exactly one
/// thing: [OmdsLoadingButton] drops the fill to 60% alpha. Same label, same
/// size (342×48), same position, no border change. And the semantics tree says
/// even less than the pixels do — measured on this preview, the node is:
///
/// ```
/// flags: isButton   identifier: "dm_onboarding_continue"   label: "Continue"
/// ```
///
/// No `tap` action (correct) but also **no disabled state at all**: no
/// `hasEnabledState`, so TalkBack/VoiceOver announce a plain, apparently
/// tappable "Continue, button" and the tap silently does nothing. Compare a
/// Material `ElevatedButton(onPressed: null)`, which announces as dimmed.
/// `_ContinueButton` builds `Semantics(identifier:, button: true)` and never
/// passes `enabled:`.
///
/// Check the 60% fill survives the AR RTL **dark** rendering, where the dimmed
/// primary sits on a dark surface rather than on white.
@JeebPreview(group: 'jeeber_onboarding', name: 'Photo step · Continue gated', size: _photoBox)
Widget dmOnboardingStepLayoutPhotoGated() =>
    _hosted(const _PhotoBody(), enabled: false);

/// Step 2: the four-field address form, Continue LIVE.
///
/// The address step never gates its CTA (`enabled` defaults true), so this is
/// the live-button reading of the same chrome — put it next to the photo
/// preview above and the 60%-alpha gate is the only visible difference between
/// a button that works and one that does not.
///
/// This is also the body that finds the scroll seam: `_ScrollableContent` pads
/// `top` only, so the last field's box sits flush against the CTA once the form
/// is scrolled to the end — no gutter, no fade, no hint that there was more.
/// At 200% the four fields are 672 px against a 776 px viewport, so on any
/// phone shorter than an iPhone 15 that contact point is what a Jeeber sees
/// while typing the last line of their address, with the keyboard eating the
/// viewport on top of it.
@JeebPreview(group: 'jeeber_onboarding', name: 'Address step · Continue live', size: _formBox)
Widget dmOnboardingStepLayoutAddressForm() => _hosted(const _AddressBody());

/// Step 3 before a home base is pinned — the JM-038 AC2 gate, in a SHORT box.
///
/// Three things at once, deliberately:
///
/// * the gate itself (`enabled: false` until `state.hasHomeBase`), which is the
///   only place in the wizard where Continue is disabled by data the user must
///   leave the screen to supply;
/// * a 260 px viewport — a small phone with the keyboard up, or a fold in
///   landscape. `Expanded` hands the body the 192 px left after the 68 px CTA
///   block, so the body keeps shrinking and scrolling while the CTA stays put
///   (measured: rect y∈[192, 240] in a 260 px box). If a refactor ever drops
///   that `Expanded`, this is the preview that goes black-and-yellow first; and
/// * **a real defect in the body it borrows.** The home-base map box is a hard
///   100 px (`Sizes.elevenXLarge`) around a min-size `Column`, copied verbatim
///   from `_HomeBaseMapPin`. At 200% text the placeholder line
///   ("Tap Location to set your home base") wraps and that Column overflows by
///   **148 px**, in EN and AR alike. The real `DmOnboardingServiceAreaStep`
///   does the same thing at the same scale — verified, along with a second
///   103 px horizontal overflow in its `_SelectLocationRowBody` that this
///   fixture does not reproduce. So the stripes in the EN 200% rendering below
///   are the step's, not the chrome's; they are kept rather than papered over
///   because the fixed 100 px box is exactly what ships.
///
/// [dmOnboardingStepLayoutServiceAreaPinned] is the same body with a base
/// pinned, and it does NOT overflow — the short place label fits where the long
/// hint does not.
@JeebPreview(group: 'jeeber_onboarding', name: 'Service area · gated, short viewport', size: _squeezedBox)
Widget dmOnboardingStepLayoutServiceAreaGated() =>
    _hosted(const _ServiceAreaBody(), enabled: false);

/// Step 3 with the base pinned: the gate opens and Continue goes live.
///
/// The pair to read against the preview above — same body, same width, and the
/// only differences a Jeeber can see are the CTA's fill alpha and the map box
/// swapping its hint for the place label. Fixture base is the one
/// `dm_onboarding_cubit_test.dart` pins (33.89, 35.50, "Beirut").
///
/// Because that label is short, the 100 px map box survives 200% text here —
/// the overflow described on the gated preview is a property of the long
/// placeholder line, not of the pinned state.
@JeebPreview(group: 'jeeber_onboarding', name: 'Service area · home base pinned', size: _serviceAreaBox)
Widget dmOnboardingStepLayoutServiceAreaPinned() => _hosted(
      const _ServiceAreaBody(homeBaseLabel: 'Beirut'),
      seed: const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: _kBeirutBase,
      ),
    );

/// The coverage check is in flight: `find-jeebers` has not come back yet.
///
/// The layout's `BlocBuilder` watches exactly one field (`isSubmitting`) and
/// hands it to [OmdsLoadingButton], which **replaces the label with a spinner**
/// rather than dimming it — so for the duration of the request there is no
/// "Continue" text on screen at all (measured: zero `Text` matches, one
/// `CircularProgressIndicator`).
///
/// The semantics node measured on this preview:
///
/// ```
/// flags: isButton   identifier: "dm_onboarding_continue"   role: loadingSpinner
/// ```
///
/// The label is **gone** as well as the tap action, and nothing announces the
/// transition — no live region, no "Submitting…" — so a screen-reader user
/// whose focus is on the CTA hears its name disappear and gets no reason why.
/// That is the state to look at here; the spinner itself is unremarkable.
///
/// `enabled: true` on purpose: the button is tap-proof anyway
/// (`isEnabled: enabled && !state.isSubmitting`), and passing `false` would
/// hide which of the two guards is doing the work.
///
/// This is the one preview here that never settles — see the dedicated group in
/// the preview test.
@JeebPreview(group: 'jeeber_onboarding', name: 'Coverage check in flight', size: _serviceAreaBox)
Widget dmOnboardingStepLayoutSubmitting() => _hosted(
      const _ServiceAreaBody(homeBaseLabel: 'Beirut'),
      seed: const DmOnboardingState(
        step: DmOnboardingStep.serviceArea,
        homeBase: _kBeirutBase,
        isSubmitting: true,
      ),
    );
