/// Who wrote a message of a conversation.
enum ChatRole { user, assistant }

/// One message of a conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.at,
    this.stopped = false,
  });

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
    role: json['r'] == 'a' ? ChatRole.assistant : ChatRole.user,
    text: json['t'] as String? ?? '',
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime(2026),
    stopped: json['s'] == true,
  );

  final ChatRole role;
  final String text;
  final DateTime at;

  /// An answer the user stopped before the model finished it.
  final bool stopped;

  Map<String, Object?> toJson() => {
    'r': role == ChatRole.assistant ? 'a' : 'u',
    't': text,
    'at': at.toUtc().toIso8601String(),
    if (stopped) 's': true,
  };
}

/// One chat: the user's messages and the model's answers, in order.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  /// A new, empty conversation.
  factory Conversation.start(String id, DateTime now) =>
      Conversation(id: id, title: '', createdAt: now, updatedAt: now);

  factory Conversation.fromJson(
    String id,
    Map<String, Object?> json,
    DateTime updatedAt,
  ) => Conversation(
    id: id,
    title: json['title'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created'] as String? ?? '') ?? updatedAt,
    updatedAt: updatedAt,
    messages: [
      for (final message in json['messages'] as List<Object?>? ?? const [])
        if (message is Map)
          ChatMessage.fromJson(Map<String, Object?>.from(message)),
    ],
  );

  final String id;

  /// Shown in the list of chats: the start of the first message, until the
  /// user renames the chat.
  final String title;
  final DateTime createdAt;

  /// The last change, from sync.
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  /// The longest title made from a message.
  static const int titleLength = 48;

  /// A title from the first line of [text].
  static String titleFrom(String text) {
    final line = text.trim().split('\n').first.trim();
    final letters = line.runes.toList();
    if (letters.length <= titleLength) return line;
    return '${String.fromCharCodes(letters.take(titleLength)).trimRight()}…';
  }

  /// This conversation with [message] at the end. The first message of a
  /// conversation without a title names it.
  Conversation withMessage(ChatMessage message) => Conversation(
    id: id,
    title: title.isEmpty && message.role == ChatRole.user
        ? titleFrom(message.text)
        : title,
    createdAt: createdAt,
    updatedAt: message.at,
    messages: [...messages, message],
  );

  Conversation renamed(String newTitle) => Conversation(
    id: id,
    title: newTitle.trim(),
    createdAt: createdAt,
    updatedAt: updatedAt,
    messages: messages,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'created': createdAt.toUtc().toIso8601String(),
    'messages': [for (final message in messages) message.toJson()],
  };
}
