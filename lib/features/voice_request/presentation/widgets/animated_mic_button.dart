import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

class AnimatedMicButton extends StatefulWidget {
  const AnimatedMicButton({
    super.key,
    required this.isRecording,
    required this.onPressStart,
    required this.onPressEnd,
    required this.semanticLabel,
    this.diameter = 132,
    this.enabled = true,
  });

  final bool isRecording;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final String semanticLabel;
  final double diameter;
  final bool enabled;

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    if (!widget.enabled) return;
    widget.onPressStart();
  }

  void _handlePressEnd() {
    if (!widget.enabled) return;
    widget.onPressEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = widget.enabled
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.4);
    final haloColor = colorScheme.primary.withValues(
      alpha: widget.isRecording ? 0.25 : 0.0,
    );
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _handlePressStart(),
        onTapUp: (_) => _handlePressEnd(),
        onTapCancel: _handlePressEnd,
        onLongPressStart: (_) => _handlePressStart(),
        onLongPressEnd: (_) => _handlePressEnd(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return SizedBox(
              width: widget.diameter * 1.6,
              height: widget.diameter * 1.6,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isRecording)
                      Container(
                        width: widget.diameter * _pulse.value * 1.35,
                        height: widget.diameter * _pulse.value * 1.35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: haloColor,
                        ),
                      ),
                    Transform.scale(
                      scale: widget.isRecording ? _pulse.value : 1.0,
                      child: Container(
                        width: widget.diameter,
                        height: widget.diameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: base,
                          boxShadow: [
                            BoxShadow(
                              color: base.withValues(alpha: 0.35),
                              blurRadius: widget.isRecording ? 24 : 10,
                              spreadRadius: widget.isRecording ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isRecording ? Icons.mic : Icons.mic_none,
                          size: widget.diameter * 0.45,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/voice_request/animated_mic_button_preview_test.dart
// ===========================================================================
//
// Widget previews for [AnimatedMicButton] — run with
// `flutter widget-preview start`.
//
// The widget is a pure render of its arguments: two booleans, a diameter, a
// label and two callbacks. It owns no cubit and no repository, so every
// preview below is a plain constructor call — network-free by construction,
// not just by the guard in [jeebPreviewHost].
//
// Two properties of the widget shape this file:
//
// * **It renders no text of its own** — a circle and a glyph, and a semantics
//   label that is spoken, never drawn. Six near-identical circles are
//   unreadable in a canvas and, worse, a render test could not tell one
//   preview from another — the exact failure `expectedText` exists to catch.
//   So each preview is a *specimen*: the button, plus a caption naming the
//   state. The caption is preview chrome, not part of the component; it is
//   deliberately `labelSmall` / `onSurfaceVariant` so it never reads as the
//   widget's own label.
// * **Its pulse never stops.** `isRecording: true` starts
//   `AnimationController.repeat(reverse: true)`, which schedules a frame
//   forever, so `pumpAndSettle` — which the shared render harness calls on
//   every preview — would spin until it timed out. Every specimen therefore
//   renders inside `TickerMode(enabled: false)`, which mutes the ticker and
//   freezes the pulse at t=0: the halo is drawn at its base 1.35× diameter and
//   the button at 1.0 scale. What is reviewable here is the recording *pose*,
//   not the motion. Deleting the `TickerMode` is what makes the render test
//   hang, so keep it.
//
// The semantics label is read from the ambient [AppLocalizations] rather than
// hardcoded — it is the only user-facing *string* this widget has, and a
// preview that inlined English would render an identical-looking canvas while
// hiding a missing translation. `voiceRecordingMicSemantic` is the production
// value, read off the live call site in `voice_recording_screen.dart`.

/// Specimen box for the production 132dp button: 1.6 × 132 = 211dp of mic,
/// plus room for the caption to double in the 200%-text rendering.
const Size _animatedMicButtonSpecimenBox = Size(360, 320);

/// Specimen box for the compact specimen — the same layout around a 56dp mic.
const Size _animatedMicButtonCompactBox = Size(300, 220);

/// The production diameter, from `voice_recording_screen.dart` (the constructor
/// default; no call site passes anything else today).
const double _animatedMicButtonDefaultDiameter = 132;

/// Smallest diameter a composer-scale host would plausibly ask for.
const double _animatedMicButtonCompactDiameter = 56;

/// The multiple of `diameter` the widget *reserves* — its outer `SizedBox` is
/// `diameter * 1.6` square.
const double animatedMicButtonReservedFactor = 1.6;

/// The multiple of `diameter` the halo *reaches* at the top of the pulse:
/// `_pulse` ends at 1.25 and the halo is drawn at `1.35 ×` that.
const double animatedMicButtonPeakHaloFactor = 1.25 * 1.35;

/// One specimen: the button under review, captioned with the state it is in.
///
/// [showHaloCeilingGuide] draws two rings behind the button — the box the
/// widget reserves ([animatedMicButtonReservedFactor], outlined in
/// `outline`) and the size the halo grows to at the top of the pulse
/// ([animatedMicButtonPeakHaloFactor], outlined in `error`) — so the
/// relationship between the two is visible rather than arithmetic.
Widget _animatedMicButtonSpecimen({
  required String caption,
  required bool isRecording,
  bool enabled = true,
  double diameter = _animatedMicButtonDefaultDiameter,
  String Function(AppLocalizations l10n)? label,
  bool showHaloCeilingGuide = false,
}) {
  return Builder(
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      final AppLocalizations l10n = AppLocalizations.of(context);
      final String semanticLabel = label == null
          ? l10n.voiceRecordingMicSemantic
          : label(l10n);
      // The pulse is muted, not stopped: see the note at the top of this
      // section. Without it every recording specimen hangs `pumpAndSettle`.
      Widget mic = TickerMode(
        enabled: false,
        child: AnimatedMicButton(
          isRecording: isRecording,
          enabled: enabled,
          diameter: diameter,
          onPressStart: () {},
          onPressEnd: () {},
          semanticLabel: semanticLabel,
        ),
      );
      if (showHaloCeilingGuide) {
        mic = SizedBox(
          width: diameter * animatedMicButtonPeakHaloFactor,
          height: diameter * animatedMicButtonPeakHaloFactor,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _animatedMicButtonRing(
                diameter * animatedMicButtonPeakHaloFactor,
                theme.colorScheme.error,
              ),
              _animatedMicButtonRing(
                diameter * animatedMicButtonReservedFactor,
                theme.colorScheme.outline,
              ),
              mic,
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            mic,
            const SizedBox(height: 8),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A hollow measurement circle for the halo-ceiling specimen.
Widget _animatedMicButtonRing(double size, Color color) => SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
      ),
    );

/// The idle mic exactly as `_MicSurface._buildIdleMic` mounts it: 132dp,
/// enabled, not recording, `Icons.mic_none` on a solid `primary` circle.
///
/// This is the state a user stares at before the first press, and the only one
/// production reaches with `enabled: true, isRecording: false`.
@JeebPreview(
  group: 'voice_request',
  name: 'Idle · hold to record',
  size: _animatedMicButtonSpecimenBox,
)
Widget animatedMicButtonIdle() => _animatedMicButtonSpecimen(
      caption: 'Idle · hold to record',
      isRecording: false,
    );

/// Finger down: the glyph swaps to `Icons.mic` and a `primary` halo at 25%
/// alpha appears behind the circle, with the shadow's blur going 10 → 24.
///
/// Frozen at the bottom of the pulse (see the section note), so this is the
/// *smallest* the recording state ever draws — if the halo is hard to see
/// here, it is hard to see for the first half of every pulse cycle.
///
/// The matrix is on because **AR RTL dark** is the rendering that matters: a
/// 25%-alpha overlay of `primary` is exactly the kind of treatment that
/// survives on a white surface and vanishes on a dark one, and the light card
/// alone will never tell you.
@JeebPreview(
  group: 'voice_request',
  name: 'Recording · pulse frozen',
  size: _animatedMicButtonSpecimenBox,
  matrix: true,
)
Widget animatedMicButtonRecording() => _animatedMicButtonSpecimen(
      caption: 'Recording · pulse frozen',
      isRecording: true,
    );

/// `enabled: false` — the state the host drops into when the mic permission is
/// denied or the recorder is held by another app.
///
/// The circle falls back to `outline` at 40% alpha, but the glyph keeps
/// `colorScheme.onPrimary` — white on a pale warm grey in the light theme.
/// Look at this card before anything else: the mic is the only affordance on
/// the screen, and this is what "unavailable" looks like to a user who cannot
/// see why nothing happens when they press.
@JeebPreview(
  group: 'voice_request',
  name: 'Disabled · mic unavailable',
  size: _animatedMicButtonSpecimenBox,
)
Widget animatedMicButtonDisabled() => _animatedMicButtonSpecimen(
      caption: 'Disabled · mic unavailable',
      isRecording: false,
      enabled: false,
      label: (AppLocalizations l10n) => l10n.voiceRecordingUnavailableTitle,
    );

/// The combination no screen builds today but the widget fully supports:
/// disabled *while* recording.
///
/// It is reachable the moment a host disables the button without also clearing
/// `isRecording` — the 60-second cap tripping under a held finger is the
/// obvious path (`voiceRecordingErrorMaxReached`). The render is contradictory:
/// `haloColor` is derived from `primary` regardless of `enabled`, so a live
/// brand-coloured halo pulses around a dead grey circle. Whoever wires that
/// path should see this card first and decide which half is wrong.
@JeebPreview(
  group: 'voice_request',
  name: 'Disabled mid-recording',
  size: _animatedMicButtonSpecimenBox,
)
Widget animatedMicButtonDisabledMidRecording() => _animatedMicButtonSpecimen(
      caption: 'Disabled mid-recording',
      isRecording: true,
      enabled: false,
      label: (AppLocalizations l10n) => l10n.voiceRecordingErrorMaxReached,
    );

/// The floor of the `diameter` range: 56dp, a composer-scale mic.
///
/// `diameter` is the widget's only sizing seam and it drives everything —
/// glyph (`× 0.45`), halo, shadow spread and the 1.6× hit box — so this is the
/// rendering the first caller to shrink it will get.
///
/// The matrix is on for the **EN 200% text** card: `diameter` is a raw logical
/// size that ignores `textScaleFactor` entirely, so at 200% the caption
/// doubles while the tap target stays 56dp. There is no `IconButton`
/// underneath to enforce Material's 48dp minimum either — at 56dp the button
/// clears it by 8dp, and anything smaller silently drops below it.
@JeebPreview(
  group: 'voice_request',
  name: 'Compact · 56dp',
  size: _animatedMicButtonCompactBox,
  matrix: true,
)
Widget animatedMicButtonCompact() => _animatedMicButtonSpecimen(
      caption: 'Compact · 56dp',
      isRecording: false,
      diameter: _animatedMicButtonCompactDiameter,
    );

/// The geometry the frozen specimens cannot show: where the halo ends up at
/// the *top* of the pulse.
///
/// The widget reserves `diameter × 1.6` (grey ring) but the halo is drawn at
/// `diameter × _pulse × 1.35`, which at the tween's 1.25 ceiling is
/// `diameter × 1.6875` (red ring). The red ring sits outside the grey one, and
/// a `Container` cannot exceed the constraints it is given — so the last ~5%
/// of every pulse is clamped flat instead of growing. Both rings are preview
/// chrome; the widget draws neither.
@JeebPreview(
  group: 'voice_request',
  name: 'Halo ceiling · reserved box',
  size: _animatedMicButtonSpecimenBox,
)
Widget animatedMicButtonHaloCeiling() => _animatedMicButtonSpecimen(
      caption: 'Halo ceiling · reserved box',
      isRecording: true,
      showHaloCeilingGuide: true,
    );
