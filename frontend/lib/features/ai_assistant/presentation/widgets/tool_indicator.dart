import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ToolIndicator extends StatefulWidget {
  final String toolName;
  const ToolIndicator({super.key, required this.toolName});

  @override
  State<ToolIndicator> createState() => _ToolIndicatorState();
}

class _ToolIndicatorState extends State<ToolIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.smart_toy_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: Icon(Icons.settings_rounded, size: 14, color: AppColors.info),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.toolName,
                  style: TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Text('...', style: TextStyle(color: AppColors.info)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
