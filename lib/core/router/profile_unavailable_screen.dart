import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../l10n/app_localizations.dart';

import '../../devtool/catalog/fixtures/profile_unavailable_screen_fixtures.dart';
import '../previews/jeeb_preview.dart';

class ProfileUnavailableScreen extends StatelessWidget {
  const ProfileUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.profileUnavailableTitle,
        showBackButton: true,
      ),
      body: Center(
        child: OmdsErrorState(
          key: const Key('profile_unavailable_state'),
          title: l10n.profileUnavailableTitle,
          message: l10n.profileUnavailableBody,
          icon: Icons.person_off_outlined,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _profileUnavailableScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _profileUnavailableScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _profileUnavailableScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
Widget _profileUnavailableScreenHosted(
  ProfileUnavailableScreenWindow window, {
  bool parentOnStack = true,
}) =>
    ProfileUnavailableScreenPreviewHost(
      window: window,
      parentOnStack: parentOnStack,
      screen: const ProfileUnavailableScreen(),
    );

/// The reference reading: an ordinary phone, no system chrome, default text,
@JeebPreview(
  group: 'core',
  name: 'Phone 390 × 844',
  size: _profileUnavailableScreenPhoneCanvas,
  matrix: true,
)
Widget profileUnavailableScreenPhone() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phone,
    );

/// The smallest display the app supports, at default text size.
@JeebPreview(
  group: 'core',
  name: 'Compact 320 × 568',
  size: _profileUnavailableScreenCompactCanvas,
)
Widget profileUnavailableScreenCompact() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.compact,
    );

/// A notched phone: 59 pt status bar, 34 pt home indicator.
@JeebPreview(
  group: 'core',
  name: 'Notched 393 × 852 · inset 59/34',
  size: _profileUnavailableScreenNotchedCanvas,
)
Widget profileUnavailableScreenNotched() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.notched,
    );

/// The accessibility ceiling on an ordinary phone: 200% text on 390 x 844.
@JeebPreview(
  group: 'core',
  name: 'Phone · 200% text',
  size: _profileUnavailableScreenPhoneCanvas,
)
Widget profileUnavailableScreenLargeText() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phoneLargeText,
    );

/// The worst case the app supports: the smallest display AND the largest text.
@JeebPreview(
  group: 'core',
  name: 'Compact · 200% text',
  size: _profileUnavailableScreenCompactCanvas,
)
Widget profileUnavailableScreenCompactLargeText() =>
    _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.compactLargeText,
    );

/// The same phone as the reference reading, with nothing underneath it.
@JeebPreview(
  group: 'core',
  name: 'Dead end · nothing to pop',
  size: _profileUnavailableScreenPhoneCanvas,
)
Widget profileUnavailableScreenStackRoot() => _profileUnavailableScreenHosted(
      ProfileUnavailableScreenWindows.phoneStackRoot,
      parentOnStack: false,
    );
