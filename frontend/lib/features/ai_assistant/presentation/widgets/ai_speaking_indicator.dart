import 'package:flutter/material.dart';

class AISpeakingIndicator extends StatefulWidget {
  final bool isSpeaking;
  final Color color;

  const AISpeakingIndicator({
    super.key,
    required this.isSpeaking,
    this.color = Colors.blue,
  });

  @override
  State<AISpeakingIndicator> createState() => _AISpeakingIndicatorState();
}

class _AISpeakingIndicatorState extends State<AISpeakingIndicator> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _barAnimations = List.generate(5, (i) {
      final start = i * 0.12;
      final end = start + 0.5;
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });

    if (widget.isSpeaking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AISpeakingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpeaking) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.1),
              ),
              child: Icon(Icons.smart_toy, size: 18, color: widget.color),
            ),
            const SizedBox(width: 8),
            ...List.generate(5, (i) {
              return Container(
                width: 4,
                height: 20 * _barAnimations[i].value,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.6 + _barAnimations[i].value * 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text('بتكلم...', style: TextStyle(fontSize: 12, color: widget.color, fontWeight: FontWeight.w500)),
          ],
        );
      },
    );
  }
}

class VoiceStateIndicator extends StatelessWidget {
  final String state;
  final String? toolName;

  const VoiceStateIndicator({super.key, required this.state, this.toolName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, label, color) = _getStateInfo(state);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('$state-$toolName'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 14,
            height: 14,
            child: state == 'processing' || state == 'toolExecution'
                ? CircularProgressIndicator(strokeWidth: 2, color: color)
                : Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            toolName ?? label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }

  (IconData, String, Color) _getStateInfo(String state) {
    switch (state) {
      case 'listening':
        return (Icons.mic, 'بسمعك...', Colors.red);
      case 'processing':
        return (Icons.psychology, 'بفكر...', Colors.orange);
      case 'toolExecution':
        return (Icons.build, toolName ?? 'بشتغل...', Colors.purple);
      case 'speaking':
        return (Icons.volume_up, 'بتكلم...', Colors.blue);
      default:
        return (Icons.mic_none, 'جاهز', Colors.grey);
    }
  }
}
