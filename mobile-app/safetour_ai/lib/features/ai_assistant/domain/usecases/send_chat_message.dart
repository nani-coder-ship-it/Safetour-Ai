import '../repositories/chat_repository.dart';

class SendChatMessage {
  final ChatRepository repository;

  SendChatMessage(this.repository);

  Future<String> call(String message) async {
    return await repository.sendMessage(message);
  }
}
