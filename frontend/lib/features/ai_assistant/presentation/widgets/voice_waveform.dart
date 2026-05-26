import 'package:flutter/material.dart';
import 'dart:math';

class VoiceWaveform extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double height;

  const VoiceWaveform({
    super.key,
    required this.isActive,
    this.color = Colors.blue,
    this.height = 60,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _amplitudes = List.generate(24, (_) => 0.1);
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _controller.addListener(_updateAmplitudes);
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      setState(() {
        for (int i = 0; i < _amplitudes.length; i++) {
          _amplitudes[i] = 0.1;
        }
      });
    }
  }

  void _updateAmplitudes() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _amplitudes.length; i++) {
        _amplitudes[i] = 0.15 + _random.nextDouble() * 0.85;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_amplitudes.length, (i) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 3,
            height: widget.height * _amplitudes[i],
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.7 + _amplitudes[i] * 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class PulsingMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final double size;

  const PulsingMicButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.size = 72,
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isRecording) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: widget.onLongPressStart != null ? (_) => widget.onLongPressStart!() : null,
      onLongPressEnd: widget.onLongPressEnd != null ? (_) => widget.onLongPressEnd!() : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.isRecording ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording ? Colors.red : Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording ? Colors.red : Theme.of(context).primaryColor).withOpacity(0.3),
                    blurRadius: widget.isRecording ? 20 * scale : 8,
                    spreadRadius: widget.isRecording ? 4 * scale : 2,
                  ),
                ],
              ),
              child: Icon(
                widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: widget.size * 0.4,
              ),
            ),
          );
        },
      ),
    );
  }
}
