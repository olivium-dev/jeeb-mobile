import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_provider.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

// ─────────────────────────────────────────────────────────────────────
// EXEMPT(flutter-material3-colorscheme-discipline,
//        flutter-no-magic-values-design-tokens):
//
// The constants below are *brand-required* values dictated by the
// Google Identity Branding Guidelines and the Apple HIG. They are NOT
// themeable — Google's blue MUST be #4285F4 ("Google Blue 500") and
// Apple's monochrome logo MUST be pure black on a white button or pure
// white on a black button. Mapping these to `colorScheme.*` or to OMDS
// semantic tokens would put us in breach of the developer guidelines
// for both platforms (Apple App Store review item 4.0; Google Identity
// review). Tracked under JEEB-57; revisit if/when OMDS ships
// `OmdsBrandTokens` for third-party identity providers.
// ─────────────────────────────────────────────────────────────────────

/// Google Blue 500 — required by the Google Identity Branding Guidelines
/// for the "G" mark inside the sign-in button.
const Color _googleBrandBlue = Color(0xFF4285F4);

/// Pure white text inside the Google "G" disc — required by the
/// Google Identity Branding Guidelines.
const Color _googleGlyphForeground = Color(0xFFFFFFFF);

/// Facebook Brand Blue (#1877F2) — required by the Facebook Brand Guidelines
/// for the "f" mark inside the sign-in button. Matches `OmdsSocialButtons.facebook`'s
/// background so the glyph disc reads as part of the button.
const Color _facebookBrandBlue = Color(0xFF1877F2);

/// Pure white "f" glyph on the Facebook-blue button — Facebook Brand Guidelines.
const Color _facebookGlyphForeground = Color(0xFFFFFFFF);

/// Pure black for the Apple glyph when it sits on a white button.
const Color _appleBrandBlack = Color(0xFF000000);

/// Pure white for the Apple glyph when it sits on a black button.
const Color _appleBrandWhite = Color(0xFFFFFFFF);

/// Apple HIG specifies a 17pt glyph in a 44pt button; we ship a 22dp
/// raster glyph which keeps the visual weight inside the OMDS 48dp
/// button container. Cannot be mapped to `Sizes.*` (no 22dp token).
const double _appleGlyphIconSize = 22.0;

/// Renders a single OMDS-styled social sign-in button. Hosts the Apple
/// platform gate (the Apple button is hidden on Android per UX direction —
/// Apple's Sign-In on Android requires a separate web fallback the gateway
/// does not host yet).
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.onTap,
    this.isBusy = false,
    this.isEnabled = true,
    this.identifier,
  });

  final SocialProvider provider;
  final VoidCallback onTap;
  final bool isBusy;
  final bool isEnabled;

  /// Screen-scoped Maestro/accessibility identifier the caller stamps on the
  /// button's own interactive node (e.g. `login_social_google`). Null leaves
  /// the button unlabelled for tests — the subtree is otherwise unchanged, so
  /// every existing call site is byte-identical.
  final String? identifier;

  /// Whether the Apple button should render on the current platform. Static
  /// helper so the registration screen can decide whether to add the widget
  /// at all (we don't even build a hidden one).
  static bool isAppleAvailable() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final effectiveOnTap = (isEnabled && !isBusy) ? onTap : () {};

    switch (provider) {
      case SocialProvider.google:
        return Semantics(
          identifier: identifier,
          container: true,
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.registrationContinueWithGoogle,
          child: OmdsSocialButtons.google(
            icon: _GoogleGlyph(enabled: isEnabled && !isBusy),
            text: isBusy ? '…' : l10n.registrationContinueWithGoogle,
            onTap: effectiveOnTap,
          ),
        );
      case SocialProvider.facebook:
        return Semantics(
          identifier: identifier,
          container: true,
          button: true,
          enabled: isEnabled && !isBusy,
          // Visible label reuses the locale-safe generic `actionContinue`
          // ("Continue") — no dedicated Facebook key exists yet (requested in
          // 50_ROUTE_REQUESTS.md for a copy-polish swap to
          // `socialContinueWithFacebook`). Maestro asserts on the caller's
          // `*_social_facebook` identifier, never this text.
          label: l10n.actionContinue,
          child: OmdsSocialButtons.facebook(
            // Facebook brand "f" mark on the brand-blue button. White glyph per
            // the Facebook Brand Guidelines — see the EXEMPT block at top.
            icon: _FacebookGlyph(enabled: isEnabled && !isBusy),
            text: isBusy ? '…' : l10n.actionContinue,
            onTap: effectiveOnTap,
          ),
        );
      case SocialProvider.apple:
        final isDark = brightness == Brightness.dark;
        return Semantics(
          identifier: identifier,
          container: true,
          button: true,
          enabled: isEnabled && !isBusy,
          label: l10n.registrationContinueWithApple,
          child: OmdsSocialButtons.apple(
            // Apple HIG mandates a black glyph on the light "Sign in with
            // Apple" button and a white glyph on the dark variant — see
            // the brand-color EXEMPT block at the top of this file.
            icon: _AppleGlyph(
              color: isDark ? _appleBrandBlack : _appleBrandWhite,
            ),
            text: isBusy ? '…' : l10n.registrationContinueWithApple,
            onTap: effectiveOnTap,
            isDark: isDark,
          ),
        );
    }
  }
}

/// Lightweight glyphs so we don't need to bundle an SVG asset for the MVP.
/// `flutter_svg` is not yet a dependency; switching to a real branded asset
/// (per Google/Apple HIG) is tracked under JEEB-57.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.omdsColorTokens;
    return Container(
      width: Sizes.large,
      height: Sizes.large,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Google's "Sign in with Google" branding guidelines lock the
        // glyph background to Google Blue 500 regardless of app theme;
        // the disabled state falls back to the OMDS grey token. See
        // the brand-color EXEMPT block at the top of this file.
        color: enabled ? _googleBrandBlue : tokens.greyScale400,
        shape: BoxShape.circle,
      ),
      child: Text(
        'G',
        // The Google brand "G" is white on the Google Blue background.
        // Typography intentionally bypasses textTheme color — this glyph
        // is a brand mark, not body copy. See top-of-file EXEMPT block.
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _googleGlyphForeground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Facebook "f" mark. Like [_GoogleGlyph] this is a lightweight text glyph so
/// we don't bundle an SVG for the MVP (real branded asset tracked under
/// JEEB-57). The white "f" sits on a Facebook-blue disc that blends into the
/// brand-blue button background.
class _FacebookGlyph extends StatelessWidget {
  const _FacebookGlyph({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.omdsColorTokens;
    return Container(
      width: Sizes.large,
      height: Sizes.large,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? _facebookBrandBlue : tokens.greyScale400,
        shape: BoxShape.circle,
      ),
      child: Text(
        'f',
        // Brand mark, not body copy — bypasses textTheme color intentionally
        // (see the top-of-file EXEMPT block).
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _facebookGlyphForeground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AppleGlyph extends StatelessWidget {
  const _AppleGlyph({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Glyph size matches Apple HIG-mandated logo proportions inside the
    // 48dp social button. Routed through the named `_appleGlyphIconSize`
    // constant at the top of the file because there is no `Sizes.*`
    // token at 22dp; promotion to `OmdsIconSizes.brandMark` is tracked
    // under JEEB-57.
    return Icon(Icons.apple, size: _appleGlyphIconSize, color: color);
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/auth/social_sign_in_button_preview_test.dart
// ===========================================================================
//
// Widget previews for [SocialSignInButton] — run with
// `flutter widget-preview start`.
//
// [SocialSignInButton] takes a [SocialProvider], two booleans and a callback.
// There is no cubit, no repository and nothing to fetch — [SocialAuthCubit]
// lives one level up in [SocialSignInSection] — so these previews are
// network-free because there is nothing to fetch, not merely because
// [jeebPreviewHost] guards them. What varies between states is the enum and
// the two flags.
//
// Every state below is wrapped in [_SocialSignInButtonSpecimen], which names
// the state and prints a live tap counter under the button. The counter is not
// decoration: `isBusy`/`isEnabled` do NOT null out `onTap` — the widget swaps
// in `effectiveOnTap = () {}` and hands that to the same live
// [GestureDetector] — so "did the tap land?" is invisible in the pixels, and
// the readout is the only thing on the canvas that answers it.
//
// Three things are worth staring at in the matrix, none of them visible in a
// single EN light rendering of the happy path:
//
// * **Apple, EN light** — `OmdsSocialButtons.apple` no longer flips to a black
//   vendor slab (P0-X02: every provider shares one white pill), but
//   [SocialSignInButton] still derives the glyph colour from the *theme*
//   brightness: light → `_appleBrandWhite`. That paints a white Apple mark on
//   the white pill. The AR RTL **dark** rendering is the one where the glyph
//   appears, which is exactly backwards from the intent in the source comment.
// * **Disabled vs idle** — `OmdsSocialButtons._branded` never forwards
//   `isEnabled` to [OmdsSocialButton], so the OMDS disabled skin (60 % alpha
//   pill, 38 % alpha label) is unreachable from here. The only pixel that
//   moves is the Google/Facebook glyph disc going grey; Apple has no disabled
//   treatment at all.
// * **EN 200 % text** — the pill is a hard 48 dp (`Sizes.fourXLarge`) and
//   [OmdsSocialButton] spends 26 of it on `Spacing.small` padding plus its
//   1 dp border, so the label lives in a 22 dp box at every text scale. At
//   200 % that paragraph needs 120 dp and still gets 22: [Text] defaults to
//   [TextOverflow.clip], so roughly four fifths of the label is cut off with
//   no overflow stripe and no exception. Compare it against the specimen's
//   own title in the same rendering, which does scale.
//
// Scenario titles and notes are deliberately unlocalized: they name the
// *state*, not the product, so seeing English in the AR RTL rendering is
// expected. The button's own label is localized and is what the AR rendering
// is there to check.

/// Phone width, with room for the title, the note, the 48 dp pill and its tap
/// readout. The pill itself is only 48 dp tall — the rest of the height is for
/// the specimen text at 200 %.
const Size _socialSignInButtonSpecimenBox = Size(390, 260);

/// Title + note + the button + a live count of the taps that actually landed.
///
/// Stateful only so the canvas is interactive and so the readout is fed by the
/// widget's own `onTap`. There is no controller, no ticker and nothing to
/// settle.
class _SocialSignInButtonSpecimen extends StatefulWidget {
  const _SocialSignInButtonSpecimen({
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
  State<_SocialSignInButtonSpecimen> createState() =>
      _SocialSignInButtonSpecimenState();
}

class _SocialSignInButtonSpecimenState
    extends State<_SocialSignInButtonSpecimen> {
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

Widget _socialSignInButtonHosted({
  required String title,
  required String note,
  required SocialProvider provider,
  bool isBusy = false,
  bool isEnabled = true,
}) =>
    _SocialSignInButtonSpecimen(
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
@JeebPreview(
  group: 'auth',
  name: 'Google idle',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleIdle() => _socialSignInButtonHosted(
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
@JeebPreview(
  group: 'auth',
  name: 'Google busy',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleBusy() => _socialSignInButtonHosted(
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
@JeebPreview(
  group: 'auth',
  name: 'Google disabled',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonGoogleDisabled() => _socialSignInButtonHosted(
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
@JeebPreview(
  group: 'auth',
  name: 'Apple idle',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonAppleIdle() => _socialSignInButtonHosted(
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
@JeebPreview(
  group: 'auth',
  name: 'Facebook generic label',
  size: _socialSignInButtonSpecimenBox,
)
Widget socialSignInButtonFacebookGenericLabel() => _socialSignInButtonHosted(
      title: 'Facebook generic label',
      note: 'No dedicated key: the label is the generic Continue string.',
      provider: SocialProvider.facebook,
    );
