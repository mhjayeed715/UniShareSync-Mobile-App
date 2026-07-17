import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unisharesync_mobile_app/features/ai_chat/chat_models.dart';
import 'package:unisharesync_mobile_app/services/ai_chat_service.dart';
import 'package:unisharesync_mobile_app/features/alumni/presentation/screens/alumni_detail_screen.dart';

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
  static const Color ragGreen = Color(0xFF059669);
  static const Color cacheBlue = Color(0xFF2563EB);
}

// ─── Screen ─────────────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    this.initialPrompt,
    this.resourceCourseCode,
    this.resourceSemester,
  });

  final String? initialPrompt;
  final String? resourceCourseCode;
  final int? resourceSemester;

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

  // Quota tracking
  int _questionsUsed = 0;
  int _questionsLimit = 5;
  bool _usingOwnKey = false;
  bool _hasStoredKey = false;

  static const _defaultSuggestions = <SuggestionChip>[
    SuggestionChip(label: '📅 What\'s my schedule today?', prompt: 'What classes do I have today?'),
    SuggestionChip(label: '🎉 Any upcoming events?', prompt: 'Are there any upcoming events?'),
    SuggestionChip(label: '🏘️ My communities', prompt: 'What communities am I part of?'),
    SuggestionChip(label: '📦 Borrow something', prompt: 'What items are available to borrow on Campus Share?'),
    SuggestionChip(label: '🎓 Find a mentor', prompt: 'Show me alumni available for mentorship'),
    SuggestionChip(label: '📢 Show recent notices', prompt: 'Show me the latest notices'),
  ];

  String? _userGroupName;

  @override
  void initState() {
    super.initState();
    _typingDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadSettings();
    _checkStoredKey();
    _loadQuota();
    // Auto-send if launched from a resource card
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt!);
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userGroupName = prefs.getString('user_group_name');
    });
  }

  Future<void> _checkStoredKey() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await client
          .from('user_ai_keys')
          .select('is_active')
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _hasStoredKey = res != null && (res['is_active'] as bool? ?? false);
          if (_hasStoredKey) _usingOwnKey = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadQuota() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      // Convert to BDT date (UTC+6) to match the database and backend reset boundary
      final today = DateTime.now().toUtc().add(const Duration(hours: 6)).toIso8601String().split('T')[0];
      final res = await client
          .from('daily_ai_usage')
          .select('question_count')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() {
          _questionsUsed = res['question_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveGroupName(String group) async {
    final prefs = await SharedPreferences.getInstance();
    if (group.trim().isEmpty) {
      await prefs.remove('user_group_name');
      setState(() => _userGroupName = null);
    } else {
      await prefs.setString('user_group_name', group.trim());
      setState(() => _userGroupName = group.trim());
    }
  }

  void _showSettingsSheet() {
    final groupController = TextEditingController(text: _userGroupName ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  const Text('AI Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ChatPalette.textPrimary)),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quota banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _usingOwnKey
                        ? [const Color(0xFF059669), const Color(0xFF34D399)]
                        : [_ChatPalette.violetDark, _ChatPalette.violet],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(_usingOwnKey ? Icons.all_inclusive : Icons.bolt_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _usingOwnKey
                            ? 'Unlimited questions with your own Groq key'
                            : '$_questionsUsed / $_questionsLimit free questions used today',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Groq key settings card
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiKeySettingsScreen()),
                  ).then((_) => _checkStoredKey());
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EAFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _ChatPalette.chipBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasStoredKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                        color: _hasStoredKey ? _ChatPalette.ragGreen : _ChatPalette.violet,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasStoredKey ? 'Your Groq Key is saved ✓' : 'Add your own Groq API key',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _hasStoredKey ? _ChatPalette.ragGreen : _ChatPalette.textPrimary,
                              ),
                            ),
                            Text(
                              _hasStoredKey
                                  ? 'Tap to update or remove'
                                  : 'Get unlimited questions for free',
                              style: const TextStyle(fontSize: 11, color: _ChatPalette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _ChatPalette.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('GROUP / SECTION (SCHEDULE FILTER)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ChatPalette.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: _ChatPalette.scaffoldBg, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: groupController,
                  decoration: InputDecoration(
                    hintText: 'e.g. A, B, Group-1, Day-A…',
                    hintStyle: TextStyle(color: _ChatPalette.textSecondary.withOpacity(0.5), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _saveGroupName(groupController.text);
                    if (mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ChatPalette.violet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
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
      _messages.add(ChatMessage(role: ChatRole.assistant, content: '', isStreaming: true));
      _isSending = true;
    });

    _scrollToBottom();
    final assistantIndex = _messages.length - 1;

    _streamSub = _service.streamResponse(
      prompt,
      userGroupName: _userGroupName,
      courseCode: widget.resourceCourseCode,
      semester: widget.resourceSemester,
    ).listen(
      (event) {
        if (!mounted) return;

        switch (event) {
          case AiTokenEvent(:final text):
            setState(() => _messages[assistantIndex].content += text);
            _scrollToBottom();

          case AiDoneEvent(:final suggestions, :final citation, :final usedRag, :final fromCache, :final questionsUsed, :final questionsLimit, :final usingOwnKey):
            setState(() {
              _messages[assistantIndex].isStreaming = false;
              _messages[assistantIndex].suggestions = suggestions;
              _messages[assistantIndex].citation = citation;
              _messages[assistantIndex].usedRag = usedRag;
              _messages[assistantIndex].fromCache = fromCache;
              _messages[assistantIndex].questionsUsed = questionsUsed;
              _messages[assistantIndex].usingOwnKey = usingOwnKey;
              _isSending = false;
              if (questionsUsed != null) _questionsUsed = questionsUsed;
              if (questionsLimit != null) _questionsLimit = questionsLimit;
              if (usingOwnKey) _usingOwnKey = true;
            });
            _scrollToBottom();

          case AiErrorEvent(:final message):
            setState(() {
              final isQuota = message.contains('quota_exceeded') ||
                  message.contains('429') ||
                  message.toLowerCase().contains('quota');
              if (isQuota) {
                _messages[assistantIndex].isQuotaExceeded = true;
                _messages[assistantIndex].content = '';
              } else {
                _messages[assistantIndex].content = '⚠️ $message';
              }
              _messages[assistantIndex].isStreaming = false;
              _isSending = false;
            });
            _scrollToBottom();

          case AiQuotaExceededEvent(:final questionsUsed, :final questionsLimit):
            setState(() {
              _messages[assistantIndex].isStreaming = false;
              _messages[assistantIndex].isQuotaExceeded = true;
              _messages[assistantIndex].content = '';
              _isSending = false;
              _questionsUsed = questionsUsed;
              _questionsLimit = questionsLimit;
            });
            _scrollToBottom();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex].content = '⚠️ Connection error. Please try again.';
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
          if (!_usingOwnKey) _buildQuotaMeter(),
          Expanded(child: _buildChatArea()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Quota meter ─────────────────────────────────────────
  Widget _buildQuotaMeter() {
    final remaining = (_questionsLimit - _questionsUsed).clamp(0, _questionsLimit);
    final fraction = _questionsLimit > 0 ? _questionsUsed / _questionsLimit : 0.0;
    final color = fraction >= 1.0
        ? Colors.red
        : fraction >= 0.6
            ? Colors.orange
            : _ChatPalette.violet;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == 0
                      ? 'Free questions exhausted — add your Groq key for unlimited'
                      : '$remaining free question${remaining == 1 ? '' : 's'} remaining today',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE8E0FF),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showSettingsSheet,
            child: const Text('+ Key', style: TextStyle(fontSize: 11, color: _ChatPalette.violet, fontWeight: FontWeight.w700)),
          ),
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
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Campus Assistant',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(
                      _isSending ? 'Thinking…' : (_usingOwnKey ? 'Unlimited • Own Key' : 'Online • Ask anything'),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _isSending ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (_isSending ? const Color(0xFFFBBF24) : const Color(0xFF34D399)).withOpacity(0.5),
                    blurRadius: 6, spreadRadius: 1,
                  )],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showSettingsSheet,
                icon: Icon(
                  _hasStoredKey ? Icons.vpn_key : Icons.settings_outlined,
                  color: Colors.white, size: 22,
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
    if (_messages.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Column(
          crossAxisAlignment: msg.role.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageBubble(msg),
            if (msg.role.isAssistant && msg.isStreaming && msg.content.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: _TypingIndicator(controller: _typingDotController),
              ),
            // Citation card
            if (msg.role.isAssistant && !msg.isStreaming && msg.citation != null)
              _buildCitationCard(msg.citation!),
            // Suggestion chips
            if (msg.role.isAssistant && !msg.isStreaming && msg.suggestions.isNotEmpty && index == _messages.length - 1)
              _buildSuggestionChips(msg.suggestions),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ─── Citation card ───────────────────────────────────────
  Widget _buildCitationCard(AiCitation citation) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 38),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _ChatPalette.ragGreen.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ChatPalette.ragGreen.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: _ChatPalette.ragGreen, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source from uploaded notes',
                      style: TextStyle(fontSize: 10, color: _ChatPalette.ragGreen, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                  const SizedBox(height: 2),
                  Text(
                    citation.filename,
                    style: const TextStyle(fontSize: 11.5, color: _ChatPalette.textPrimary, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (citation.preview != null) ...[ 
                    const SizedBox(height: 2),
                    Text(
                      citation.preview!,
                      style: const TextStyle(fontSize: 10.5, color: _ChatPalette.textSecondary, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_ChatPalette.violetDark, _ChatPalette.violetLight]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: _ChatPalette.violet.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('Hi! I\'m your AI Campus Assistant 👋',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ChatPalette.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Ask me about your schedule, events, communities, campus share, alumni, notices, projects, or course notes!',
              style: TextStyle(fontSize: 14, color: _ChatPalette.textSecondary, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // RAG capability badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _ChatPalette.ragGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _ChatPalette.ragGreen.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.menu_book_rounded, size: 14, color: _ChatPalette.ragGreen),
                SizedBox(width: 6),
                Text('Can search uploaded course notes', style: TextStyle(fontSize: 12, color: _ChatPalette.ragGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Try asking:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ChatPalette.textSecondary)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _defaultSuggestions
                .map((chip) => _SuggestionChipWidget(chip: chip, onTap: () => _sendMessage(chip.prompt)))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  // ─── Message bubble ─────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role.isUser;

    // Quota exceeded card
    if (!isUser && msg.isQuotaExceeded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 38, right: 16),
          child: _QuotaExceededCard(
            questionsUsed: _questionsUsed,
            questionsLimit: _questionsLimit,
            onAddKey: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiKeySettingsScreen()),
              ).then((_) => _checkStoredKey());
            },
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.92),
        ),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 30, height: 30,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_ChatPalette.violet, _ChatPalette.violetLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
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
                  filter: isUser ? ImageFilter.blur() : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? _ChatPalette.userBubble : _ChatPalette.aiBubbleBg.withOpacity(0.92),
                      border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.7), width: 1),
                      boxShadow: [BoxShadow(
                        color: (isUser ? _ChatPalette.userBubble : Colors.black).withOpacity(0.08),
                        blurRadius: 8, offset: const Offset(0, 2),
                      )],
                    ),
                    child: msg.content.isEmpty && msg.isStreaming
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMessageContent(msg.content, isUser),
                              // Badges row
                              if (!isUser && !msg.isStreaming && (msg.usedRag || msg.fromCache)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.usedRag) _buildBadge('📚 From notes', _ChatPalette.ragGreen),
                                    if (msg.usedRag && msg.fromCache) const SizedBox(width: 4),
                                    if (msg.fromCache) _buildBadge('⚡ Cached', _ChatPalette.cacheBlue),
                                  ],
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
                width: 30, height: 30,
                margin: const EdgeInsets.only(left: 8, bottom: 2),
                decoration: BoxDecoration(
                  color: _ChatPalette.userBubble.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: _ChatPalette.userBubble, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
                    child: _SuggestionChipWidget(chip: chip, onTap: () => _sendMessage(chip.prompt)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
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
                      color: _inputFocus.hasFocus ? _ChatPalette.violet.withOpacity(0.4) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14.5, color: _ChatPalette.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything…',
                      hintStyle: TextStyle(color: _ChatPalette.textSecondary.withOpacity(0.6), fontSize: 14.5),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: _isSending ? null : _sendMessage,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                isEnabled: _inputController.text.trim().isNotEmpty && !_isSending,
                isLoading: _isSending,
                onTap: () => _sendMessage(_inputController.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    if (isUser) {
      return Text(content, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5));
    }

    final detailRegExp = RegExp(r'unisharesync://alumni/detail/([a-zA-Z0-9\-]+)');
    final matchesDetail = detailRegExp.allMatches(content);

    if (matchesDetail.isEmpty) {
      return Text(content, style: const TextStyle(color: _ChatPalette.textPrimary, fontSize: 14.5, height: 1.5));
    }

    final detailIds = matchesDetail.map((m) => m.group(1)!).toSet().toList();
    var cleanText = content;
    for (final match in matchesDetail) {
      cleanText = cleanText.replaceAll(match.group(0)!, '[Alumni Profile]');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cleanText, style: const TextStyle(color: _ChatPalette.textPrimary, fontSize: 14.5, height: 1.5)),
        if (detailIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...detailIds.map((id) => _buildRichAlumniCard(id)),
        ],
      ],
    );
  }

  Widget _buildRichAlumniCard(String id) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniId: id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
            ),
            child: Row(
              children: const [
                Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('View Recommended Alumnus Profile',
                      style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quota exceeded card ──────────────────────────────────────
class _QuotaExceededCard extends StatelessWidget {
  const _QuotaExceededCard({
    required this.questionsUsed,
    required this.questionsLimit,
    required this.onAddKey,
  });

  final int questionsUsed;
  final int questionsLimit;
  final VoidCallback onAddKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Daily limit reached',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ChatPalette.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'You\'ve used all $questionsLimit free questions for today. They reset at midnight UTC.',
            style: const TextStyle(fontSize: 12.5, color: _ChatPalette.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddKey,
              icon: const Icon(Icons.vpn_key_rounded, size: 16),
              label: const Text('Add your Groq API key for unlimited', style: TextStyle(fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ChatPalette.violet,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Free keys available at console.groq.com',
                style: TextStyle(fontSize: 10.5, color: _ChatPalette.textSecondary.withOpacity(0.8))),
          ),
        ],
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
                    final progress = ((controller.value * 3) - index).clamp(0.0, 1.0);
                    final bounce = (progress < 0.5) ? progress * 2 : 2 - progress * 2;
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      child: Transform.translate(
                        offset: Offset(0, -4 * bounce),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _ChatPalette.violet.withOpacity(0.4 + 0.6 * bounce),
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
  const _SendButton({required this.isEnabled, required this.isLoading, required this.onTap});
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
          width: 46, height: 46,
          child: isLoading
              ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─── Suggestion chip widget ─────────────────────────────────
class _SuggestionChipWidget extends StatelessWidget {
  const _SuggestionChipWidget({required this.chip, required this.onTap});
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
          child: Text(chip.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ChatPalette.violet)),
        ),
      ),
    );
  }
}

// ─── AI Key Settings Screen ─────────────────────────────────
class AiKeySettingsScreen extends StatefulWidget {
  const AiKeySettingsScreen({super.key});

  @override
  State<AiKeySettingsScreen> createState() => _AiKeySettingsScreenState();
}

class _AiKeySettingsScreenState extends State<AiKeySettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isSaving = false;
  bool _isVerifying = false;
  bool _hasKey = false;
  bool _obscureText = true;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _checkExistingKey();
  }

  Future<void> _checkExistingKey() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await client.from('user_ai_keys').select('is_active').eq('user_id', userId).maybeSingle();
      if (mounted) setState(() => _hasKey = res != null && (res['is_active'] as bool? ?? false));
    } catch (_) {}
  }

  Future<void> _invokeKeyFunction(String action, {String? groqKey}) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) return;

    final url = Uri.parse('${client.rest.url.replaceAll('/rest/v1', '')}/functions/v1/save-user-ai-key');
    final body = <String, dynamic>{'action': action};
    if (groqKey != null) body['groq_key'] = groqKey;

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': client.rest.headers['apikey'] ?? '',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      if (mounted) {
        setState(() {
          _statusMessage = data['message'] as String? ?? 'Success!';
          _statusIsError = false;
          if (action == 'save') _hasKey = true;
          if (action == 'delete') { _hasKey = false; _keyController.clear(); }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _statusMessage = data['error'] as String? ?? 'Something went wrong';
          _statusIsError = true;
        });
      }
    }
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() { _isSaving = true; _statusMessage = null; });
    try {
      await _invokeKeyFunction('save', groqKey: key);
    } catch (e) {
      setState(() { _statusMessage = 'Error: $e'; _statusIsError = true; });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _verify() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() { _isVerifying = true; _statusMessage = null; });
    try {
      await _invokeKeyFunction('verify', groqKey: key);
    } catch (e) {
      setState(() { _statusMessage = 'Error: $e'; _statusIsError = true; });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove API Key'),
        content: const Text('Your Groq API key will be removed. You\'ll be on the free tier (5 questions/day).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isSaving = true; _statusMessage = null; });
    try {
      await _invokeKeyFunction('delete');
    } catch (e) {
      setState(() { _statusMessage = 'Error: $e'; _statusIsError = true; });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ChatPalette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Groq API Key', style: TextStyle(color: _ChatPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.all_inclusive, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Get Unlimited Questions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const Text(
                    'By adding your own Groq API key, you bypass the 5 questions/day limit. Your key is encrypted server-side and never stored in the app.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse('https://console.groq.com/keys');
                      if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    child: const Text('🔑 Get a free key at console.groq.com ↗',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current status
            if (_hasKey) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _ChatPalette.ragGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ChatPalette.ragGreen.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: _ChatPalette.ragGreen, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Your Groq API key is saved and active',
                          style: TextStyle(color: _ChatPalette.ragGreen, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: _isSaving ? null : _delete,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                          : const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Update key:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ChatPalette.textPrimary)),
              const SizedBox(height: 8),
            ] else ...[
              const Text('Enter your Groq API key', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ChatPalette.textPrimary)),
              const SizedBox(height: 8),
            ],

            // Key input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _keyController,
                obscureText: _obscureText,
                style: const TextStyle(fontSize: 13.5, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'gsk_xxxxxxxxxxxxxxxxxxxxxxxx',
                  hintStyle: TextStyle(color: _ChatPalette.textSecondary.withOpacity(0.5), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: _ChatPalette.textSecondary),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _statusIsError ? Colors.red.withOpacity(0.08) : _ChatPalette.ragGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (_statusIsError ? Colors.red : _ChatPalette.ragGreen).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIsError ? Icons.error_outline : Icons.check_circle_outline,
                        size: 16, color: _statusIsError ? Colors.red : _ChatPalette.ragGreen),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage!,
                        style: TextStyle(fontSize: 12.5, color: _statusIsError ? Colors.red : _ChatPalette.ragGreen))),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_isVerifying || _isSaving) ? null : _verify,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ChatPalette.violet,
                      side: const BorderSide(color: _ChatPalette.violet),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isVerifying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Verify Key'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _isVerifying) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ChatPalette.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_hasKey ? 'Update Key' : 'Save & Activate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
