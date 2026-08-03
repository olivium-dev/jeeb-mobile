import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/location_picker_placeholder_screen_fixtures.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _featureId = 'location-picker';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Location Picker coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Location Picker coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The dev-chrome line painted over the top edge of each device box.
class _LocationPickerScreenPlaceholderCaption extends StatelessWidget {
  const _LocationPickerScreenPlaceholderCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // LTR and unscaled: the AR card still reads this as one latin line, and
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Captions [child] without taking any of its height.
/// A `Column` would be simpler, but the caption would then cost the screen
Widget _locationPickerScreenPlaceholderCaptioned(String caption, Widget child) {
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      child,
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: _LocationPickerScreenPlaceholderCaption(caption: caption),
        ),
      ),
    ],
  );
}

/// The single state, hosted for the canvas.
/// `const LocationPickerScreen()` is written out here rather than delegating to
Widget _locationPickerScreenPlaceholderHosted(String caption) =>
    _locationPickerScreenPlaceholderCaptioned(
      caption,
      const LocationPickerScreen(),
    );

/// The reference rendering: a 390x844 phone.
/// `matrix: true` because the AR card is the whole point. The screen renders
@JeebPreview(
  group: 'location',
  name: 'Placeholder · phone',
  size: LocationPickerPlaceholderScreenFixtures.phoneBox,
  matrix: true,
)
Widget locationPickerScreenPlaceholderPhone() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionPhone,
    );

/// The narrowest viewport the app supports (320x568) — and the tight one.
/// `EdgeInsets.all(24)` leaves 272 pt of usable width, and the unclamped
@JeebPreview(
  group: 'location',
  name: 'Placeholder · compact device',
  size: LocationPickerPlaceholderScreenFixtures.compactBox,
  matrix: true,
)
Widget locationPickerScreenPlaceholderCompact() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionCompact,
    );

/// Landscape / split-screen (844x390) — the shortest viewport, and a card that
/// exists to be checked rather than to fail.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · landscape, short viewport',
  size: LocationPickerPlaceholderScreenFixtures.landscapeBox,
)
Widget locationPickerScreenPlaceholderLandscape() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionLandscape,
    );

/// The screen as `/location` actually delivers it: pushed on top of the screen
/// the user came from.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · pushed route, no way back',
  size: LocationPickerPlaceholderScreenFixtures.phoneBox,
)
Widget locationPickerScreenPlaceholderDeadEnd() =>
    _locationPickerScreenPlaceholderCaptioned(
      LocationPickerPlaceholderScreenFixtures.captionDeadEnd,
      Navigator(
        onGenerateInitialRoutes:
            (NavigatorState navigator, String initialRoute) => <Route<void>>[
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const Scaffold(
              body: Center(
                child: Text(
                  LocationPickerPlaceholderScreenFixtures.originRouteLabel,
                ),
              ),
            ),
          ),
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const LocationPickerScreen(),
          ),
        ],
      ),
    );
