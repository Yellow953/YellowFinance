import 'package:equatable/equatable.dart';

/// Represents a single message in the AI chat conversation.
class AiMessageModel extends Equatable {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  const AiMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory AiMessageModel.fromMap(Map<String, dynamic> map) => AiMessageModel(
        id: map['id'] as String? ?? '',
        role: map['role'] as String? ?? 'user',
        content: map['content'] as String? ?? '',
        timestamp: map['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [id, role, content, timestamp];
}