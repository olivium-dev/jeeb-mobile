import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/directional_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';
import 'dm_onboarding_step_header.dart';
import 'dm_onboarding_step_layout.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../domain/dm_onboarding_gateway.dart';

class DmOnboardingServiceAreaStep extends StatelessWidget {
  const DmOnboardingServiceAreaStep({super.key});

  static const Key rootKey = Key('dm-onboarding-service-area-step');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.hasHomeBase != curr.hasHomeBase,
      builder: (context, state) => Semantics(
        identifier: 'dm_onboarding_service_area_root',
        container: true,
        explicitChildNodes: true,
        child: DmOnboardingStepLayout(
          key: rootKey,
          continueIdentifier: 'dm_onboarding_continue',
          enabled: state.hasHomeBase,
          content: const _ServiceAreaContent(),
        ),
      ),
    );
  }
}

class _ServiceAreaContent extends StatelessWidget {
  const _ServiceAreaContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingServiceAreaHeading,
          subtitle: l10n.dmOnboardingServiceAreaSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        Text(
          l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: Spacing.small),
        const _HomeBaseMapPin(),
        const SizedBox(height: Spacing.medium),
        const _SelectLocationRow(),
      ],
    );
  }
}

class _HomeBaseMapPin extends StatelessWidget {
  const _HomeBaseMapPin();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.homeBase != curr.homeBase,
      builder: (context, state) {
        final base = state.homeBase;
        return Semantics(
          identifier: 'service_area_map_pin',
          image: true,
          label: l10n.dmOnboardingServiceAreaPrimaryLocationLabel,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Sizes.small),
            child: Container(
              height: Sizes.elevenXLarge,
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: _HomeBaseMapContent(base: base),
            ),
          ),
        );
      },
    );
  }
}

class _HomeBaseMapContent extends StatelessWidget {
  const _HomeBaseMapContent({required this.base});

  final DmOnboardingHomeBase? base;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = base?.label.trim() ?? '';
    final pinned = label.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          pinned ? Icons.location_on : Icons.map_outlined,
          size: Sizes.threeXLarge,
          color: scheme.tertiary,
        ),
        const SizedBox(height: Spacing.xSmall),
        _HomeBaseMapLabel(
          text: pinned ? label : l10n.dmOnboardingServiceAreaMapPlaceholder,
        ),
      ],
    );
  }
}

class _HomeBaseMapLabel extends StatelessWidget {
  const _HomeBaseMapLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: Spacing.medium),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _SelectLocationRow extends StatelessWidget {
  const _SelectLocationRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'service_area_select_location',
      button: true,
      container: true,
      explicitChildNodes: true,
      label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
      child: InkWell(
        onTap: () => _pickHomeBase(context),
        child: const Padding(
          padding: EdgeInsetsDirectional.symmetric(vertical: Spacing.small),
          child: _SelectLocationRowBody(),
        ),
      ),
    );
  }

  Future<void> _pickHomeBase(BuildContext context) async {
    final cubit = context.read<DmOnboardingCubit>();
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      cubit.setHomeBase(
        DmOnboardingHomeBase(
          lat: 0,
          lng: 0,
          label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
        ),
      );
      return;
    }
    await context.pushNamed('capture-location');
    if (!context.mounted) return;
    cubit.setHomeBase(
      DmOnboardingHomeBase(
        lat: 0,
        lng: 0,
        label: l10n.dmOnboardingServiceAreaLocationFieldLabel,
      ),
    );
  }
}

class _SelectLocationRowBody extends StatelessWidget {
  const _SelectLocationRowBody();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(Icons.location_on, color: scheme.tertiary),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.dmOnboardingServiceAreaLocationFieldLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
        ),
        const Spacer(),
        const _SelectLocationValue(),
        Icon(DirectionalIcons.disclosure(context), color: scheme.primary),
      ],
    );
  }
}

class _SelectLocationValue extends StatelessWidget {
  const _SelectLocationValue();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.homeBase != curr.homeBase,
      builder: (context, state) =>
          _LocationValueText(chosen: state.homeBase?.label.trim() ?? ''),
    );
  }
}

class _LocationValueText extends StatelessWidget {
  const _LocationValueText({required this.chosen});

  final String chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPlaceholder = chosen.isEmpty;
    return Semantics(
      identifier: 'dm_onboarding_location_value',
      child: Text(
        isPlaceholder ? l10n.dmOnboardingServiceAreaLocationPlaceholder : chosen,
        style: theme.textTheme.titleSmall?.copyWith(
          color: isPlaceholder
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A phone body: this step pins its CTA to the bottom of an `Expanded`, so it
/// only reads correctly in a full-height box.
const Size _dmOnboardingServiceAreaStepBox = Size(390, 640);

/// The geocoded label this step is *designed* for, once the map-pin screen
/// returns a resolved place. Reuses the `has_saved_addresses` seam address from
const DmOnboardingHomeBase _dmOnboardingServiceAreaStepGeocodedBase =
    DmOnboardingHomeBase(
  lat: 33.8869,
  lng: 35.5131,
  label: 'Sassine Square, Ashrafieh',
);

/// The longest label a Lebanese reverse-geocode plausibly returns — a mall
/// parking level. Same string as the long-chip fixture in the saved-locations
const DmOnboardingHomeBase _dmOnboardingServiceAreaStepLongLabelBase =
    DmOnboardingHomeBase(
  lat: 33.8938,
  lng: 35.5018,
  label: 'Beirut Souks — Parking Level B2, Weygand Street',
);

/// A gateway whose coverage probe never lands — holds the step in its in-flight
/// frame for as long as the canvas is open.
class _DmOnboardingServiceAreaStepPendingGateway
    implements DmOnboardingGateway {
  const _DmOnboardingServiceAreaStepPendingGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) =>
      Completer<void>().future;
}

/// Builds the cubit the way the wizard screen does, minus the network.
/// [confirmCoverage] presses Continue for you: `next()` on the service-area
DmOnboardingCubit _dmOnboardingServiceAreaStepCubit({
  DmOnboardingHomeBase? base,
  DmOnboardingGateway? gateway,
  bool confirmCoverage = false,
}) {
  final DmOnboardingCubit cubit = DmOnboardingCubit(
    pickerService: StubPhotoPickerService(),
    gateway: gateway ?? FakeDmOnboardingGateway(),
    initialStep: DmOnboardingStep.serviceArea,
  );
  if (base != null) cubit.setHomeBase(base);
  if (confirmCoverage) unawaited(cubit.next());
  return cubit;
}

/// Hosts the step under its own cubit, with a one-line fixture caption beneath.
/// The caption is preview-only chrome, and it is there for the render test: the
Widget _dmOnboardingServiceAreaStepHosted(
  DmOnboardingCubit Function() create, {
  required String fixture,
}) {
  return BlocProvider<DmOnboardingCubit>(
    create: (_) => create(),
    child: Column(
      children: <Widget>[
        const Expanded(child: DmOnboardingServiceAreaStep()),
        _DmOnboardingServiceAreaStepCaption(fixture),
      ],
    ),
  );
}

class _DmOnboardingServiceAreaStepCaption extends StatelessWidget {
  const _DmOnboardingServiceAreaStepCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// The entry state, and the one every Jeeber sees first: nothing pinned.
/// This is the JM-038 AC2 gate — `hasHomeBase` is false, so Continue is dimmed
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'No base pinned · Continue disabled',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepUnpinned() =>
    _dmOnboardingServiceAreaStepHosted(
      _dmOnboardingServiceAreaStepCubit,
      fixture: 'fixture: no home base',
    );

/// A base pinned with a resolved place name — the state the design is drawn for.
/// `hasHomeBase` lights Continue, the map icon swaps `map_outlined` →
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Base pinned · geocoded label',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepPinned() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
      ),
      fixture: 'fixture: geocoded label',
    );

/// **What actually ships today.** The pinned label is the word "Location".
/// `_pickHomeBase` records `DmOnboardingHomeBase(lat: 0, lng: 0, label:
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Pinned by the map screen · stub label',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepStubLabel() => Builder(
      builder: (BuildContext context) {
        final String label = AppLocalizations.of(context)
            .dmOnboardingServiceAreaLocationFieldLabel;
        return _dmOnboardingServiceAreaStepHosted(
          () => _dmOnboardingServiceAreaStepCubit(
            base: DmOnboardingHomeBase(lat: 0, lng: 0, label: label),
          ),
          fixture: 'fixture: stub base recorded on pop',
        );
      },
    );

/// The layout ceiling: a full reverse-geocoded place name, at ordinary text
/// size.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Long geocoded label · row overflow',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepLongLabel() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepLongLabelBase,
      ),
      fixture: 'fixture: long geocoded label',
    );

/// Continue tapped: the coverage probe (`find-jeebers` against the home base)
/// is in flight.
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Checking coverage · CTA spinner',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepCheckingCoverage() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
        gateway: const _DmOnboardingServiceAreaStepPendingGateway(),
        confirmCoverage: true,
      ),
      fixture: 'fixture: coverage probe never lands',
    );

/// The coverage probe failed (JEBV4-13 P1-5) — and this step shows nothing.
/// The cubit emits `DmOnboardingError.submitFailed`, but its only listener is
@JeebPreview(
  group: 'jeeber_onboarding',
  name: 'Coverage check failed · no in-step surface',
  size: _dmOnboardingServiceAreaStepBox,
)
Widget dmOnboardingServiceAreaStepCoverageFailed() =>
    _dmOnboardingServiceAreaStepHosted(
      () => _dmOnboardingServiceAreaStepCubit(
        base: _dmOnboardingServiceAreaStepGeocodedBase,
        gateway: FakeDmOnboardingGateway(shouldFail: true),
        confirmCoverage: true,
      ),
      fixture: 'fixture: coverage probe throws',
    );
