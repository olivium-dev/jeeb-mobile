import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/jeeb/jeeb_empty_state.dart';
import '../widgets/jeeb/jeeb_midnight_field.dart';
import '../widgets/jeeb/jeeb_top_bar.dart';

import '../../devtool/catalog/fixtures/profile_unavailable_screen_fixtures.dart';
import '../previews/jeeb_preview.dart';

/// The release fallback for `/profile/customer` and `/profile/delivery-man`
/// when no typed `extra` arrives — the profile is not there to show.
class ProfileUnavailableScreen extends StatelessWidget {
  const ProfileUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: SafeArea(
          child: Semantics(
            identifier: 'profile_unavailable_root',
            // Both flags, or this node swallows the bar's own identifier.
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title-less, like both profile twins: the empty block's
                // headline is the same string and is the only place it prints.
                const JeebTopBar.back(
                  identifier: 'profile_unavailable_back',
                ),
                // Scrolls only so 200% text scale cannot overflow the fixed
                // column; at 1.0x the block sits centred in the empty field.
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        0,
                        0,
                        0,
                        Spacing.xLarge,
                      ),
                      child: JeebEmptyState(
                        // FROZEN key — the pre-redesign hook for this state.
                        key: const Key('profile_unavailable_state'),
                        variant: JeebEmptyStateVariant.parcel,
                        status: JeebEmptyStateStatus.error,
                        headline: l10n.profileUnavailableTitle,
                        body: l10n.profileUnavailableBody,
                        identifier: 'profile_unavailable_note',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
