import 'package:flutter/material.dart';

/// Large press-and-hold mic button used on the voice recording screen.
///
/// While idle the button renders as a solid primary-coloured circle with a
/// microphone glyph. On press, a pulsing halo grows outward to signal that
/// audio is being captured. The host owns the gesture wiring — this widget is
/// a pure render of [isRecording].
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

