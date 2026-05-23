import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/ai_repository.dart';

class ChatBubble extends StatelessWidget {
  final AIMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_avatar(isDark), const SizedBox(width: 10)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Tool calls indicator
                if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 6,
                      children: message.toolCalls!.map((tool) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.info.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.build_rounded, size: 12, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text(_formatTool(tool), style: TextStyle(fontSize: 11, color: AppColors.info)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBackground : AppColors.background),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 12),
                    ),
                    border: isUser ? null : Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.content,
                        style: TextStyle(
                          color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      if (message.isStreaming)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 10), _userAvatar(isDark)],
        ],
      ),
    );
  }

  Widget _avatar(bool isDark) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.smart_toy_rounded, size: 18, color: AppColors.primary),
    );
  }

  Widget _userAvatar(bool isDark) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.person, size: 18, color: Colors.white),
    );
  }

  String _formatTool(String tool) {
    return tool.replaceAll('get_', '').replaceAll('_', ' ');
  }
}
