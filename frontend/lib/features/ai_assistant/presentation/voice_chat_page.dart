import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ai_repository.dart';
import 'voice_controller.dart';
import 'widgets/voice_waveform.dart';
import 'widgets/ai_speaking_indicator.dart';
import 'widgets/chat_bubble.dart';

class VoiceChatPage extends ConsumerStatefulWidget {
  const VoiceChatPage({super.key});

  @override
  ConsumerState<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends ConsumerState<VoiceChatPage> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showTextInput = false;
  bool _hasPermission = false;
  late AnimationController _bgAnimController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bgAnimController, curve: Curves.easeInOut),
    );
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.request();
    setState(() => _hasPermission = status.isGranted);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _bgAnimController.dispose();
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

  Future<void> _toggleStreaming() async {
    if (!_hasPermission) {
      await _checkPermission();
      if (!_hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب السماح بالوصول للميكروفون')),
        );
        return;
      }
    }

    final voiceState = ref.read(voiceChatProvider);

    if (voiceState.isStreaming) {
      // Stop streaming and trigger AI processing
      _bgAnimController.stop();
      _bgAnimController.reset();
      await ref.read(voiceChatProvider.notifier).stopStreaming();
    } else {
      // Start live streaming
      _bgAnimController.repeat(reverse: true);
      await ref.read(voiceChatProvider.notifier).startStreaming();
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(voiceChatProvider.notifier).sendTextMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceChatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(voiceChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) _scrollToBottom();
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.error),
        );
        ref.read(voiceChatProvider.notifier).clearError();
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          _buildHeader(voiceState, isDark),
          const SizedBox(height: 16),

          // Chat messages
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: voiceState.messages.length,
                      itemBuilder: (_, i) {
                        final msg = voiceState.messages[i];
                        return _VoiceChatBubble(message: msg, isDark: isDark);
                      },
                    ),
                  ),

                  // Live partial transcription display
                  if (voiceState.partialTranscription != null && voiceState.partialTranscription!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hearing, size: 16, color: AppColors.primary.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              voiceState.partialTranscription!,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // State indicator
                  if (voiceState.voiceState != VoiceState.idle && voiceState.partialTranscription == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: VoiceStateIndicator(
                        state: voiceState.voiceState.name,
                        toolName: voiceState.currentTool,
                      ),
                    ),

                  // Speaking indicator
                  if (voiceState.voiceState == VoiceState.speaking)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: AISpeakingIndicator(isSpeaking: true, color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Voice controls
          _buildVoiceControls(voiceState, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(VoiceChatState voiceState, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.record_voice_over, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Voice AI Assistant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: voiceState.isStreaming
                      ? Colors.red
                      : voiceState.voiceState == VoiceState.idle
                          ? AppColors.success
                          : AppColors.warning,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                voiceState.isStreaming
                    ? 'بسمعك...'
                    : voiceState.voiceState == VoiceState.idle
                        ? 'جاهز للمساعدة'
                        : 'بشتغل...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Claude + Whisper', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ),
            ]),
          ]),
        ),
        IconButton(
          onPressed: () => setState(() => _showTextInput = !_showTextInput),
          icon: Icon(_showTextInput ? Icons.mic : Icons.keyboard, size: 20),
          tooltip: _showTextInput ? 'استخدم الصوت' : 'اكتب نص',
        ),
      ],
    );
  }

  Widget _buildVoiceControls(VoiceChatState voiceState, bool isDark) {
    if (_showTextInput) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showTextInput = false),
              icon: const Icon(Icons.mic, color: AppColors.primary),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك هنا...',
                  hintTextDirection: TextDirection.rtl,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: voiceState.voiceState == VoiceState.processing ? null : _sendText,
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          // Waveform
          if (voiceState.voiceState == VoiceState.listening || voiceState.isStreaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VoiceWaveform(isActive: true, color: Colors.red, height: 50),
            )
          else if (voiceState.voiceState == VoiceState.speaking)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VoiceWaveform(isActive: true, color: AppColors.primary, height: 50),
            ),

          // Mic button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Keyboard toggle
              IconButton(
                onPressed: () => setState(() => _showTextInput = true),
                icon: const Icon(Icons.keyboard, size: 22),
                style: IconButton.styleFrom(backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
              ),
              const SizedBox(width: 24),

              // Main mic button - now uses streaming
              PulsingMicButton(
                isRecording: voiceState.isStreaming || voiceState.voiceState == VoiceState.listening,
                onTap: voiceState.voiceState == VoiceState.processing || voiceState.voiceState == VoiceState.speaking
                    ? () {}
                    : _toggleStreaming,
                size: 72,
              ),

              const SizedBox(width: 24),

              // Stop speaking button (visible when AI is speaking)
              if (voiceState.voiceState == VoiceState.speaking)
                IconButton(
                  onPressed: () => ref.read(voiceChatProvider.notifier).onSpeakingDone(),
                  icon: const Icon(Icons.stop_circle, size: 22, color: AppColors.error),
                  style: IconButton.styleFrom(backgroundColor: AppColors.error.withOpacity(0.1)),
                )
              else
                const SizedBox(width: 40),
            ],
          ),

          const SizedBox(height: 12),

          // Instructions
          Text(
            voiceState.isStreaming
                ? 'بسمعك... اتكلم عادي'
                : voiceState.voiceState == VoiceState.processing
                    ? 'بفكر في الإجابة...'
                    : voiceState.voiceState == VoiceState.speaking
                        ? 'برد عليك...'
                        : 'اضغط على الميكروفون للتحدث',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VoiceChatBubble extends StatelessWidget {
  final AIMessage message;
  final bool isDark;

  const _VoiceChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser
        ? AppColors.primary.withOpacity(0.1)
        : isDark
            ? AppColors.darkBackground
            : Colors.grey.shade50;
    final borderColor = isUser ? AppColors.primary.withOpacity(0.3) : (isDark ? AppColors.darkBorder : AppColors.border);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Tool badges
          if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                children: message.toolCalls!.map((tool) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.build, size: 10, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(tool, style: const TextStyle(fontSize: 10, color: Colors.purple)),
                  ]),
                )).toList(),
              ),
            ),

          // Message bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.smart_toy, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                SelectableText(
                  message.content,
                  textDirection: _detectDirection(message.content),
                  style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextDirection _detectDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().codeUnitAt(0);
    if (firstChar >= 0x0600 && firstChar <= 0x06FF) return TextDirection.rtl;
    if (firstChar >= 0xFE70 && firstChar <= 0xFEFF) return TextDirection.rtl;
    return TextDirection.ltr;
  }
}
