/// Widget previews for [SocialSignInButton] — run with
/// `flutter widget-preview start`.
///
/// [SocialSignInButton] takes a [SocialProvider], two booleans and a callback.
/// There is no cubit, no repository and nothing to fetch — [SocialAuthCubit]
/// lives one level up in [SocialSignInSection] — so these previews are
/// network-free because there is nothing to fetch, not merely because
/// [jeebPreviewHost] guards them. What varies between states is the enum and
/// the two flags.
///
/// Every state below is wrapped in [_Specimen], which names the state and
/// prints a live tap counter under the button. The counter is not decoration:
/// `isBusy`/`isEnabled` do NOT null out `onTap` — the widget swaps in
/// `effectiveOnTap = () {}` and hands that to the same live [GestureDetector] —
/// so "did the tap land?" is invisible in the pixels, and the readout is the
/// only thing on the canvas that answers it.
///
/// Three things are worth staring at in the matrix, none of them visible in a
/// single EN light rendering of the happy path:
///
/// * **Apple, EN light** — `OmdsSocialButtons.apple` no longer flips to a black
///   vendor slab (P0-X02: every provider shares one white pill), but
///   [SocialSignInButton] still derives the glyph colour from the *theme*
///   brightness: light → `_appleBrandWhite`. That paints a white Apple mark on
///   the white pill. The AR RTL **dark** rendering is the one where the glyph
///   appears, which is exactly backwards from the intent in the source comment.
/// * **Disabled vs idle** — `OmdsSocialButtons._branded` never forwards
///   `isEnabled` to [OmdsSocialButton], so the OMDS disabled skin (60 % alpha
///   pill, 38 % alpha label) is unreachable from here. The only pixel that
///   moves is the Google/Facebook glyph disc going grey; Apple has no disabled
///   treatment at all.
/// * **EN 200 % text** — the pill is a hard 48 dp (`Sizes.fourXLarge`) and
///   [OmdsSocialButton] spends 26 of it on `Spacing.small` padding plus its
///   1 dp border, so the label lives in a 22 dp box at every text scale. At
///   200 % that paragraph needs 120 dp and still gets 22: [Text] defaults to
///   [TextOverflow.clip], so roughly four fifths of the label is cut off with
///   no overflow stripe and no exception. Compare it against the specimen's
///   own title in the same rendering, which does scale.
///
/// Scenario titles and notes are deliberately unlocalized: they name the
/// *state*, not the product, so seeing English in the AR RTL rendering is
/// expected. The button's own label is localized and is what the AR rendering
/// is there to check.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/auth/social/social_provider.dart';
import '../../features/auth/social/social_sign_in_button.dart';
import '../harness/jeeb_preview.dart';

/// Phone width, with room for the title, the note, the 48 dp pill and its tap
/// readout. The pill itself is only 48 dp tall — the rest of the height is for
/// the specimen text at 200 %.
const Size _specimenBox = Size(390, 260);

Widget _hosted({
  required String title,
  required String note,
  required SocialProvider provider,
  bool isBusy = false,
  bool isEnabled = true,
}) =>
    _Specimen(
      title: title,
      note: note,
      provider: provider,
      isBusy: isBusy,
      isEnabled: isEnabled,
    );

/// The state every registration screen opens on, and the only one most reviews
/// ever look at.
///
/// Google is the one provider that ships on both platforms, so this is the
/// button the majority of sign-ins go through. Worth pinning for the glyph: the
/// "G" is a text glyph on a Google-Blue-500 disc, not an asset, because
/// `flutter_svg` is not wired up for brand marks yet (JEEB-57). At 200 % text
/// the disc is a fixed 20 dp `Sizes.large` box while the "G" inside it scales,
/// which is where that shortcut shows.
@JeebPreview(group: 'auth', name: 'Google idle', size: _specimenBox)
Widget socialSignInButtonGoogleIdle() => _hosted(
      title: 'Google idle',
      note: 'The default reading. Blue G disc, navy label, white OMDS pill.',
      provider: SocialProvider.google,
    );

/// **The state that breaks.** In flight: the label is replaced by a literal
/// `'…'`.
///
/// While the native SDK sheet is up the button shows one ellipsis character
/// where "Continue with Google" was — no spinner, no dimming, and the pill does
/// not change size. Three things are wrong here and all of them are visible:
/// the ellipsis is a hardcoded literal rather than a localized string or a
/// progress indicator; the announcement still leads with "Continue with
/// Google", so a screen-reader user is told nothing changed; and the button
/// still looks pressable, because `isBusy` never reaches OMDS.
///
/// The announcement is worth reading in full — the [Semantics] wrapper sets a
/// `label` but not `excludeSemantics`, so it MERGES rather than replaces, and
/// the decorative "G" glyph is read out as content: TalkBack says
/// "Continue with Google, G, …".
///
/// The tap readout under the button is the proof of the last point — the pill
/// still swallows taps through a live `onTap`, it just drops them.
@JeebPreview(group: 'auth', name: 'Google busy', size: _specimenBox)
Widget socialSignInButtonGoogleBusy() => _hosted(
      title: 'Google busy',
      note: 'Native sheet is up. Label collapses to a hardcoded ellipsis.',
      provider: SocialProvider.google,
      isBusy: true,
    );

/// Disabled because a *different* provider is signing in.
///
/// This is the real production combination: [SocialSignInSection] passes
/// `isEnabled: !state.isBusy` to every button, so tapping Apple disables
/// Google. Compare it side by side with `Google idle` in the canvas — the only
/// pixel that moves is the glyph disc turning `greyScale400`. The pill, the
/// border and the navy label are byte-identical, because
/// `OmdsSocialButtons._branded` drops `isEnabled` on the floor. A user who taps
/// here gets no press feedback and no explanation.
@JeebPreview(group: 'auth', name: 'Google disabled', size: _specimenBox)
Widget socialSignInButtonGoogleDisabled() => _hosted(
      title: 'Google disabled',
      note: 'Another provider is in flight. Only the glyph disc greys out.',
      provider: SocialProvider.google,
      isEnabled: false,
    );

/// **The state that breaks.** Apple, whose glyph colour is inverted.
///
/// `build` computes `isDark` from the theme brightness and paints the mark
/// `isDark ? black : white`, on the assumption that the OMDS Apple button is a
/// black slab in dark mode. It is not, and has not been since P0-X02:
/// `OmdsSocialButtons.apple` keeps `isDark` only for source compatibility and
/// always renders the same white pill. So the EN light rendering below is a
/// white Apple mark on a white pill — invisible — and the AR RTL dark rendering
/// is the readable one.
///
/// Apple is iOS/macOS-only in production ([SocialSignInButton.isAppleAvailable]
/// gates it at the section), which is why this went unnoticed on the Android
/// screenshots.
@JeebPreview(group: 'auth', name: 'Apple idle', size: _specimenBox)
Widget socialSignInButtonAppleIdle() => _hosted(
      title: 'Apple idle',
      note: 'Light theme paints a white Apple mark on the white pill.',
      provider: SocialProvider.apple,
    );

/// Facebook, whose label never names the provider.
///
/// There is no `socialContinueWithFacebook` key yet, so the button reuses the
/// generic `actionContinue` — "Continue" in EN, "متابعة" in AR. The only thing
/// distinguishing this button from a primary CTA is the small "f" disc on the
/// leading edge, and the [Semantics] label is that same generic string, so a
/// screen reader announces "Continue, button" with no provider at all.
///
/// The AR RTL rendering is the one to look at: mirrored, the disc moves to the
/// right and the label — already provider-less — sits centred in the pill.
@JeebPreview(group: 'auth', name: 'Facebook generic label', size: _specimenBox)
Widget socialSignInButtonFacebookGenericLabel() => _hosted(
      title: 'Facebook generic label',
      note: 'No dedicated key: the label is the generic Continue string.',
      provider: SocialProvider.facebook,
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// Title + note + the button + a live count of the taps that actually landed.
///
/// Stateful only so the canvas is interactive and so the readout is fed by the
/// widget's own `onTap`. There is no controller, no ticker and nothing to
/// settle.
class _Specimen extends StatefulWidget {
  const _Specimen({
    required this.title,
    required this.note,
    required this.provider,
    required this.isBusy,
    required this.isEnabled,
  });

  final String title;
  final String note;
  final SocialProvider provider;
  final bool isBusy;
  final bool isEnabled;

  @override
  State<_Specimen> createState() => _SpecimenState();
}

class _SpecimenState extends State<_Specimen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            widget.note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.medium),
          SocialSignInButton(
            provider: widget.provider,
            isBusy: widget.isBusy,
            isEnabled: widget.isEnabled,
            identifier: 'preview_social_${widget.provider.wireName}',
            onTap: () => setState(() => _taps++),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text('taps landed: $_taps', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
