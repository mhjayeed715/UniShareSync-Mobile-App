// Data models for the AI Campus Assistant chat feature.

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.suggestions = const [],
    this.citation,
    this.usedRag = false,
    this.fromCache = false,
    this.questionsUsed,
    this.questionsLimit,
    this.usingOwnKey = false,
    this.isQuotaExceeded = false,
  }) : timestamp = timestamp ?? DateTime.now();

  final ChatRole role;
  String content;
  final DateTime timestamp;
  bool isStreaming;
  List<SuggestionChip> suggestions;
  AiCitation? citation;
  bool usedRag;
  bool fromCache;
  int? questionsUsed;
  int? questionsLimit;
  bool usingOwnKey;
  bool isQuotaExceeded;

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    List<SuggestionChip>? suggestions,
    AiCitation? citation,
    bool? usedRag,
    bool? fromCache,
    int? questionsUsed,
    int? questionsLimit,
    bool? usingOwnKey,
    bool? isQuotaExceeded,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      suggestions: suggestions ?? this.suggestions,
      citation: citation ?? this.citation,
      usedRag: usedRag ?? this.usedRag,
      fromCache: fromCache ?? this.fromCache,
      questionsUsed: questionsUsed ?? this.questionsUsed,
      questionsLimit: questionsLimit ?? this.questionsLimit,
      usingOwnKey: usingOwnKey ?? this.usingOwnKey,
      isQuotaExceeded: isQuotaExceeded ?? this.isQuotaExceeded,
    );
  }
}

enum ChatRole {
  user,
  assistant,
  system;

  bool get isUser => this == ChatRole.user;
  bool get isAssistant => this == ChatRole.assistant;
}

class SuggestionChip {
  const SuggestionChip({
    required this.label,
    required this.prompt,
  });

  final String label;
  final String prompt;

  factory SuggestionChip.fromMap(Map<String, dynamic> map) {
    return SuggestionChip(
      label: map['label'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
    );
  }
}

class AiCitation {
  const AiCitation({
    required this.filename,
    required this.resourceId,
    this.preview,
  });

  final String filename;
  final String resourceId;
  final String? preview;

  factory AiCitation.fromMap(Map<String, dynamic> map) {
    return AiCitation(
      filename: map['filename'] as String? ?? '',
      resourceId: map['resource_id'] as String? ?? '',
      preview: map['preview'] as String?,
    );
  }
}
