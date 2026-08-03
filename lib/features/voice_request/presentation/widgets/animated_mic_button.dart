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
/// [showHaloCeilingGuide] draws two rings behind the button — the box the
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
/// `diameter` is the widget's only sizing seam and it drives everything —
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
