import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'ai_chat_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/tool_indicator.dart';

class AIAssistantPage extends ConsumerStatefulWidget {
  const AIAssistantPage({super.key});

  @override
  ConsumerState<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends ConsumerState<AIAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(aiChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI Assistant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Claude Sonnet', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.read(aiChatProvider.notifier).clearChat(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear Chat'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Ask about sales, inventory, profits, or customers', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Chat area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: chatState.messages.length + (chatState.currentTool != null ? 1 : 0) + (chatState.isLoading && chatState.messages.last.content.isEmpty ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i < chatState.messages.length) {
                          final msg = chatState.messages[i];
                          return ChatBubble(message: msg);
                        }
                        if (chatState.currentTool != null && i == chatState.messages.length) {
                          return ToolIndicator(toolName: chatState.currentTool!);
                        }
                        return const TypingIndicator();
                      },
                    ),
                  ),

                  // Input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: !chatState.isLoading,
                            decoration: InputDecoration(
                              hintText: chatState.isLoading ? 'AI is thinking...' : 'Ask anything about your business...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _send(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: chatState.isLoading ? null : _send,
                          style: IconButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primary.withOpacity(0.5)),
                          icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _focusNode.requestFocus();
  }
}
