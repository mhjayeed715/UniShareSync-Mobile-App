// Data models for the AI Campus Assistant chat feature.

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.suggestions = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  final ChatRole role;
  String content;
  final DateTime timestamp;
  bool isStreaming;
  List<SuggestionChip> suggestions;

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    List<SuggestionChip>? suggestions,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      suggestions: suggestions ?? this.suggestions,
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
