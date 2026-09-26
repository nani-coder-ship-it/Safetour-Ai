import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/send_chat_message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final SendChatMessage sendChatMessage;

  ChatBloc({required this.sendChatMessage}) : super(const ChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
  }

  Future<void> _onSendMessage(SendMessageEvent event, Emitter<ChatState> emit) async {
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: event.text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final currentMessages = List<ChatMessage>.from(state.messages)..add(userMessage);
    
    emit(ChatLoading(messages: currentMessages));

    try {
      final replyText = await sendChatMessage(event.text);
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: replyText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      emit(ChatLoaded(messages: List.from(currentMessages)..add(aiMessage)));
    } catch (e) {
      emit(ChatError(messages: currentMessages, error: e.toString()));
    }
  }
}
