import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../devtool/catalog/fixtures/rating_prompt_screen_fixtures.dart';
import '../../core/previews/jeeb_preview.dart';

class RatingPromptScreen extends StatefulWidget {
  const RatingPromptScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<RatingPromptScreen> createState() => _RatingPromptScreenState();
}

class _RatingPromptScreenState extends State<RatingPromptScreen> {
  static const String _featureId = 'rating-prompt';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rating Prompt coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: OMDSAppBar(title: 'Rate your Jeeber', showBackButton: true),
        icon: Icons.construction_outlined,
        title: 'Rating Prompt coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real device plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _ratingPromptScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _ratingPromptScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _ratingPromptScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
/// The `RatingPromptScreen(...)` is constructed HERE rather than inside the
Widget _ratingPromptScreenHosted(RatingPromptScreenWindow window) =>
    RatingPromptScreenPreviewHost(
      window: window,
      screen: RatingPromptScreen(deliveryId: window.deliveryId),
    );

/// The reference reading: an ordinary phone, no system chrome, default text.
/// Everything fits with room to spare — a 56 pt app bar and a 252 pt centred
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone 390 × 844',
  size: _ratingPromptScreenPhoneCanvas,
  matrix: true,
)
Widget ratingPromptScreenPhone() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.phone);

/// The smallest display the app supports, at default text size.
/// Still clean: the fixed 100 pt icon plus both sentences come to 284 pt of the
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact 320 × 568',
  size: _ratingPromptScreenCompactCanvas,
)
Widget ratingPromptScreenCompact() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.compact);

/// The accessibility ceiling on an ordinary phone: 200% text on 390 × 844.
/// Both sentences wrap several times around an icon that did not grow, so the
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone · 200% text',
  size: _ratingPromptScreenPhoneCanvas,
)
Widget ratingPromptScreenPhoneLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.phoneLargeText);

/// The worst case the app supports: the smallest display AND the largest text.
/// This is the state that breaks. The centred column is
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact · 200% text',
  size: _ratingPromptScreenCompactCanvas,
)
Widget ratingPromptScreenCompactLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.compactLargeText);

/// A notched phone at the accessibility ceiling: 59 pt status bar, 34 pt home
/// indicator, 200% text.
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Notched · 200% text',
  size: _ratingPromptScreenNotchedCanvas,
)
Widget ratingPromptScreenNotchedLargeText() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.notchedLargeText);

/// The same reference phone, handed a DIFFERENT deep-link delivery id.
/// Put this card next to `Phone 390 × 844` in the canvas: they are the same
@JeebPreview(
  group: 'deep_link_targets',
  name: 'Deep-link id · never rendered',
  size: _ratingPromptScreenPhoneCanvas,
)
Widget ratingPromptScreenUnusedDeepLinkId() =>
    _ratingPromptScreenHosted(RatingPromptScreenWindows.unusedDeepLinkId);
