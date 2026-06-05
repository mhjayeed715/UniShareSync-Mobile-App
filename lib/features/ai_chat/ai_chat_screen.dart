import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unisharesync_mobile_app/features/ai_chat/chat_models.dart';
import 'package:unisharesync_mobile_app/services/ai_chat_service.dart';

// ─── Palette ────────────────────────────────────────────────
class _ChatPalette {
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetLight = Color(0xFF8B5CF6);
  static const Color violetDark = Color(0xFF5B21B6);
  static const Color scaffoldBg = Color(0xFFF6F4FF);
  static const Color userBubble = Color(0xFF4F9EFF);
  static const Color aiBubbleBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color chipBg = Color(0xFFF0EAFF);
  static const Color chipBorder = Color(0xFFD8CCFF);
  static const Color inputBg = Color(0xFFFFFFFF);
}

// ─── Screen ─────────────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final AiChatService _service = AiChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  StreamSubscription<AiChatEvent>? _streamSub;

  late final AnimationController _typingDotController;

  // Default suggestion chips shown on empty chat
  static const _defaultSuggestions = <SuggestionChip>[
    SuggestionChip(
      label: '📅 What\'s my schedule today?',
      prompt: 'What classes do I have today?',
    ),
    SuggestionChip(
      label: '🎉 Any upcoming events?',
      prompt: 'Are there any upcoming events?',
    ),
    SuggestionChip(
      label: '📢 Show recent notices',
      prompt: 'Show me the latest notices',
    ),
    SuggestionChip(
      label: '📦 Lost & found items',
      prompt: 'Any open lost and found items?',
    ),
  ];

  String? _userApiKey;
  String? _userGroupName;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _typingDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userApiKey = prefs.getString('user_gemini_api_key');
      _userGroupName = prefs.getString('user_group_name');
    });
  }

  Future<void> _saveSettings(String key, String group) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (key.trim().isEmpty) {
      await prefs.remove('user_gemini_api_key');
      setState(() {
        _userApiKey = null;
      });
    } else {
      await prefs.setString('user_gemini_api_key', key.trim());
      setState(() {
        _userApiKey = key.trim();
      });
    }

    if (group.trim().isEmpty) {
      await prefs.remove('user_group_name');
      setState(() {
        _userGroupName = null;
      });
    } else {
      await prefs.setString('user_group_name', group.trim());
      setState(() {
        _userGroupName = group.trim();
      });
    }
  }

  Future<void> _launchAiStudio() async {
    final url = Uri.parse('https://aistudio.google.com/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _launchGroqConsole() async {
    final url = Uri.parse('https://console.groq.com/keys');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showApiKeySettingsSheet() {
    final keyController = TextEditingController(text: _userApiKey ?? '');
    final groupController = TextEditingController(text: _userGroupName ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Assistant Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ChatPalette.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'To bypass developer usage limits, you can provide your own Groq API key or Google Gemini API key. Requests will use your key directly on-the-fly and will never be stored server-side.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _ChatPalette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _launchGroqConsole,
                        child: const Text(
                          '🔑 Get Groq Key (gsk_...) ↗',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _ChatPalette.violet,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _launchAiStudio,
                        child: const Text(
                          '🌟 Get Gemini Key (AIza...) ↗',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _ChatPalette.violet,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'API KEY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _ChatPalette.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _ChatPalette.scaffoldBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Paste your Groq or Gemini API Key here…',
                      hintStyle: TextStyle(
                        color: _ChatPalette.textSecondary.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'GROUP / SECTION (STUDENT SCHEDULE FILTER)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _ChatPalette.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _ChatPalette.scaffoldBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: groupController,
                    decoration: InputDecoration(
                      hintText: 'e.g. A, B, Group-1, Day-A…',
                      hintStyle: TextStyle(
                        color: _ChatPalette.textSecondary.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_userApiKey != null || _userGroupName != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _saveSettings('', '');
                            if (mounted) Navigator.of(context).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Settings cleared. Using system fallbacks.'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Clear Settings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final keyVal = keyController.text.trim();
                          final groupVal = groupController.text.trim();
                          await _saveSettings(keyVal, groupVal);
                          if (mounted) Navigator.of(context).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Assistant settings saved successfully.'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ChatPalette.violet,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _typingDotController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ─── Send message ───────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isSending) return;

    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: prompt));
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        content: '',
        isStreaming: true,
      ));
      _isSending = true;
    });

    _scrollToBottom();

    final assistantIndex = _messages.length - 1;

    _streamSub = _service.streamResponse(
      prompt,
      userApiKey: _userApiKey,
      userGroupName: _userGroupName,
    ).listen(
      (event) {
        if (!mounted) return;

        switch (event) {
          case AiTokenEvent(:final text):
            setState(() {
              _messages[assistantIndex].content += text;
            });
            _scrollToBottom();

          case AiDoneEvent(:final suggestions):
            setState(() {
              _messages[assistantIndex].isStreaming = false;
              _messages[assistantIndex].suggestions = suggestions;
              _isSending = false;
            });
            _scrollToBottom();

          case AiErrorEvent(:final message):
            setState(() {
              String displayError = message;
              if (message.contains('429') ||
                  message.toLowerCase().contains('quota') ||
                  message.toLowerCase().contains('resource_exhausted')) {
                displayError = 'Exceeded free tier API quota or rate limits. Please configure your own Gemini API Key in the settings (top-right key icon) to bypass developer limits and continue without interruptions.';
              }
              _messages[assistantIndex].content =
                  '⚠️ $displayError';
              _messages[assistantIndex].isStreaming = false;
              _isSending = false;
            });
            _scrollToBottom();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex].content =
              '⚠️ Connection error. Please try again.';
          _messages[assistantIndex].isStreaming = false;
          _isSending = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_messages[assistantIndex].isStreaming) {
          setState(() {
            _messages[assistantIndex].isStreaming = false;
            _isSending = false;
          });
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ChatPalette.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildChatArea()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ChatPalette.violetDark, _ChatPalette.violet, _ChatPalette.violetLight],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Campus Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _isSending ? 'Thinking…' : 'Online • Ask anything',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isSending
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isSending
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF34D399))
                          .withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showApiKeySettingsSheet,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Chat area ──────────────────────────────────────────
  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];

        return Column(
          crossAxisAlignment: msg.role.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            _buildMessageBubble(msg),
            // Show typing indicator when streaming and content is still empty
            if (msg.role.isAssistant && msg.isStreaming && msg.content.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: _TypingIndicator(controller: _typingDotController),
              ),
            // Show suggestion chips after the last assistant message
            if (msg.role.isAssistant &&
                !msg.isStreaming &&
                msg.suggestions.isNotEmpty &&
                index == _messages.length - 1)
              _buildSuggestionChips(msg.suggestions),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ─── Empty state ────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_ChatPalette.violetDark, _ChatPalette.violetLight],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _ChatPalette.violet.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hi! I\'m your AI Campus Assistant 👋',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ChatPalette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me about your schedule, events, notices, projects, or anything campus-related!',
            style: TextStyle(
              fontSize: 14,
              color: _ChatPalette.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ChatPalette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _defaultSuggestions
                .map((chip) => _SuggestionChipWidget(
                      chip: chip,
                      onTap: () => _sendMessage(chip.prompt),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  // ─── Message bubble ─────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_ChatPalette.violet, _ChatPalette.violetLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                child: BackdropFilter(
                  filter: isUser
                      ? ImageFilter.blur()
                      : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? _ChatPalette.userBubble
                          : _ChatPalette.aiBubbleBg.withOpacity(0.92),
                      border: isUser
                          ? null
                          : Border.all(
                              color: Colors.white.withOpacity(0.7),
                              width: 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser
                                  ? _ChatPalette.userBubble
                                  : Colors.black)
                              .withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: msg.content.isEmpty && msg.isStreaming
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg.content,
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : _ChatPalette.textPrimary,
                                  fontSize: 14.5,
                                  height: 1.5,
                                ),
                              ),
                              if (!isUser &&
                                  (msg.content.contains('API key is required') ||
                                   msg.content.contains('Gemini API Key') ||
                                   msg.content.contains('free tier API quota'))) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showApiKeySettingsSheet,
                                  icon: const Icon(Icons.vpn_key_rounded, size: 16),
                                  label: const Text('Configure API Key'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _ChatPalette.violet,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
            if (isUser) ...[
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(left: 8, bottom: 2),
                decoration: BoxDecoration(
                  color: _ChatPalette.userBubble.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _ChatPalette.userBubble,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Suggestion chips ───────────────────────────────────
  Widget _buildSuggestionChips(List<SuggestionChip> chips) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 38),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips
              .map((chip) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SuggestionChipWidget(
                      chip: chip,
                      onTap: () => _sendMessage(chip.prompt),
                    ),
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }

  // ─── Input bar ──────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: _ChatPalette.inputBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _ChatPalette.scaffoldBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _inputFocus.hasFocus
                          ? _ChatPalette.violet.withOpacity(0.4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: _ChatPalette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything…',
                      hintStyle: TextStyle(
                        color: _ChatPalette.textSecondary.withOpacity(0.6),
                        fontSize: 14.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _isSending ? null : _sendMessage,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                isEnabled:
                    _inputController.text.trim().isNotEmpty && !_isSending,
                isLoading: _isSending,
                onTap: () => _sendMessage(_inputController.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Typing indicator widget ────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 38),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final progress =
                        ((controller.value * 3) - index).clamp(0.0, 1.0);
                    final bounce = (progress < 0.5)
                        ? progress * 2
                        : 2 - progress * 2;

                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      child: Transform.translate(
                        offset: Offset(0, -4 * bounce),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _ChatPalette.violet
                                .withOpacity(0.4 + 0.6 * bounce),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Send button ────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isEnabled ? _ChatPalette.violet : _ChatPalette.violet.withOpacity(0.3),
      shape: const CircleBorder(),
      elevation: isEnabled ? 4 : 0,
      shadowColor: _ChatPalette.violet.withOpacity(0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isEnabled ? onTap : null,
        child: SizedBox(
          width: 46,
          height: 46,
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

// ─── Suggestion chip widget ─────────────────────────────────
class _SuggestionChipWidget extends StatelessWidget {
  const _SuggestionChipWidget({
    required this.chip,
    required this.onTap,
  });

  final SuggestionChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _ChatPalette.chipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ChatPalette.chipBorder, width: 1),
          ),
          child: Text(
            chip.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ChatPalette.violet,
            ),
          ),
        ),
      ),
    );
  }
}
