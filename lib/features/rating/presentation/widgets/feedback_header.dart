import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import 'feedback_avatar.dart';
import 'feedback_star_input.dart';

/// Title + audience-aware subtitle block on the feedback screen
/// (Figma 56614:20132). The subtitle swaps between "evaluate the delivery man"
/// and "evaluate the client" depending on who is rating.
class FeedbackHeader extends StatelessWidget {
  const FeedbackHeader({super.key, required this.isClient});

  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = isClient
        ? l10n.feedbackScreenSubtitleJeeber
        : l10n.feedbackScreenSubtitleClient;
    return Column(
      children: [
        _FeedbackTitle(text: l10n.feedbackScreenTitle),
        const SizedBox(height: Spacing.small),
        _FeedbackSubtitle(text: subtitle),
      ],
    );
  }
}

class _FeedbackTitle extends StatelessWidget {
  const _FeedbackTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FeedbackSubtitle extends StatelessWidget {
  const _FeedbackSubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone the feedback screen is drawn for.
/// Pinned as a real [SizedBox] rather than left to the canvas [Size]: the canvas
const double _feedbackHeaderPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _feedbackHeaderCompactPhoneWidth = 320;

/// `_FeedbackScrollArea`'s horizontal padding, restated from
/// `rating_screen.dart` so the header gets the `390 - 40 = 350`pt column it
const double _feedbackHeaderScreenGutter = Spacing.large;

/// Canvas box for the header on a phone: title, `Spacing.small`, and a subtitle
/// that already wraps to three lines at 1.0. Generous on purpose — the
const Size _feedbackHeaderPhoneBox = Size(390, 340);

/// Taller box for the 320pt state, whose subtitle wraps furthest.
const Size _feedbackHeaderCompactBox = Size(390, 440);

/// The header plus the two neighbours it is spaced against.
const Size _feedbackHeaderContextBox = Size(390, 600);

/// The fixed band [feedbackHeaderBoundedBand] drops the header into.
const double _feedbackHeaderBandHeight = 240;

/// Canvas box for the band, plus its caption.
const Size _feedbackHeaderBandBox = Size(390, 320);

/// The name used wherever a ratee is needed, matching
/// `test/feedback_screen_test.dart`.
const String _feedbackHeaderRateeName = 'Sami Fawaz';

/// Hosts [child] the way `_FeedbackScrollArea` + `_FeedbackContent` really do:
/// a fixed-width phone, the screen's 20/16 padding, a [SingleChildScrollView],
Widget _feedbackHeaderHosted(
  Widget child, {
  double width = _feedbackHeaderPhoneWidth,
  String? caption,
}) => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _feedbackHeaderScreenGutter,
            vertical: Spacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              child,
              if (caption != null) ...<Widget>[
                const SizedBox(height: Spacing.small),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

/// The state that ships to clients, and the one to read first.
/// A client rating the jeeber is the overwhelmingly common arrival at
@JeebPreview(
  group: 'rating',
  name: 'Client rates the jeeber',
  size: _feedbackHeaderPhoneBox,
)
Widget feedbackHeaderClientAudience() =>
    _feedbackHeaderHosted(const FeedbackHeader(isClient: true));

/// The other audience: a jeeber rating the client after handover.
/// Worth its own preview rather than being assumed identical to the state
@JeebPreview(
  group: 'rating',
  name: 'Jeeber rates the client',
  size: _feedbackHeaderPhoneBox,
)
Widget feedbackHeaderJeeberAudience() =>
    _feedbackHeaderHosted(const FeedbackHeader(isClient: false));

/// The layout ceiling: the longest of the two subtitles on the narrowest
/// supported device.
@JeebPreview(
  group: 'rating',
  name: 'Compact 320pt device',
  size: _feedbackHeaderCompactBox,
)
Widget feedbackHeaderCompact() => _feedbackHeaderHosted(
      const FeedbackHeader(isClient: true),
      width: _feedbackHeaderCompactPhoneWidth,
      caption: '320pt device — narrowest supported',
    );

/// The header in the only place it actually appears: between the ratee's avatar
/// and the star row of `_FeedbackContent`, reproduced spacing for spacing.
@JeebPreview(
  group: 'rating',
  name: 'In screen context',
  size: _feedbackHeaderContextBox,
)
Widget feedbackHeaderInScreenContext() => _feedbackHeaderHosted(
      Builder(
        builder: (BuildContext context) {
          final ThemeData theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FeedbackAvatar(name: _feedbackHeaderRateeName),
              const SizedBox(height: Spacing.xLarge),
              const FeedbackHeader(isClient: true),
              const SizedBox(height: Spacing.xLarge),
              Text(
                AppLocalizations.of(
                  context,
                ).feedbackRateName(_feedbackHeaderRateeName),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Spacing.medium),
              FeedbackStarInput(stars: 4, onChanged: (int _) {}),
            ],
          );
        },
      ),
    );

/// The caller hazard, made visible: the same header inside a parent that passes
/// a bounded height.
@JeebPreview(
  group: 'rating',
  name: 'Bounded 240pt band (greedy column)',
  size: _feedbackHeaderBandBox,
)
Widget feedbackHeaderBoundedBand() => _feedbackHeaderHosted(
      Builder(
        builder: (BuildContext context) => SizedBox(
          height: _feedbackHeaderBandHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const FeedbackHeader(isClient: true),
          ),
        ),
      ),
      caption: 'Bounded 240pt band — the column fills it',
    );
