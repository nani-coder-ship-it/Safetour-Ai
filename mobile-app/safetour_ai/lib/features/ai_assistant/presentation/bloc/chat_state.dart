import '../../domain/entities/chat_message.dart';

abstract class ChatState {
  final List<ChatMessage> messages;
  const ChatState({required this.messages});
}

class ChatInitial extends ChatState {
  const ChatInitial() : super(messages: const []);
}

class ChatLoaded extends ChatState {
  const ChatLoaded({required super.messages});
}

class ChatLoading extends ChatState {
  const ChatLoading({required super.messages});
}

class ChatError extends ChatState {
  final String error;
  const ChatError({required super.messages, required this.error});
}
